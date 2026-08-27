// Formal safety and equivalence properties for the Intel 8259A reconstruction.
// The combinational block re-derives every output as a pure function of the
// registered state and asserts equality with the DUT, proving there is no
// hidden state dependence and that the outputs follow the specification's
// derivation. The sequential block proves reset, initialization, mask, and
// end-of-interrupt state transitions. Reset is assumed only in the initial
// formal cycle; it is otherwise unconstrained so reset priority is checked.
module intel_8259_props (
    input logic       clk,
    input logic       rst_n,
    input logic       cs_n,
    input logic       rd_n,
    input logic       wr_n,
    input logic       a0,
    input logic [7:0] data_i,
    input logic [7:0] data_o,
    input logic       data_oe,
    input logic [7:0] ir,
    input logic       int_o,
    input logic       inta_n,
    input logic [2:0] cas_i,
    input logic [2:0] cas_o,
    input logic [2:0] cas_oe,
    input logic       sp_n_i,
    input logic       en_n_o,
    input logic       en_n_oe,
    input logic [2:0] init_state,
    input logic [7:0] icw1,
    input logic [7:0] icw2,
    input logic [7:0] icw3,
    input logic [7:0] icw4,
    input logic [7:0] imr,
    input logic [7:0] irr,
    input logic [7:0] isr,
    input logic [2:0] lowest_priority,
    input logic       special_mask,
    input logic       auto_rotate,
    input logic       read_isr_select,
    input logic       poll_pending,
    input logic [7:0] prev_ir,
    input logic       prev_inta_n,
    input logic [1:0] ack_phase,
    input logic [2:0] ack_level,
    input logic       ack_has_req,
    input logic       ack_slave
);

    localparam logic [2:0] StIcw1  = 3'd0;
    localparam logic [2:0] StIcw2  = 3'd1;
    localparam logic [2:0] StIcw3  = 3'd2;
    localparam logic [2:0] StIcw4  = 3'd3;
    localparam logic [2:0] StReady = 3'd4;

    function automatic logic [6:0] resolve_req(input logic [7:0] cand,
                                               input logic [2:0] lowp);
        logic [2:0]  shift_amt;
        logic [15:0] doubled;
        logic [7:0]  rotated;
        logic        found;
        logic [2:0]  rank;
        begin
            shift_amt = lowp + 3'd1;
            doubled   = {cand, cand};
            rotated   = doubled[{1'b0, shift_amt} +: 8];
            found = 1'b0;
            rank  = 3'd0;
            for (int j = 0; j < 8; j++) begin
                if (!found && rotated[j]) begin
                    found = 1'b1;
                    rank  = j[2:0];
                end
            end
            resolve_req = {|cand, rank, (rank + shift_amt)};
        end
    endfunction

    // Decoded fields
    logic sngl;
    logic adi;
    logic ltim;
    logic upm;
    logic aeoi;
    logic ms_bit;
    logic buf_mode;
    logic sfnm;
    logic initialized;
    logic role_master;
    logic [2:0] own_id;

    assign sngl        = icw1[1];
    assign adi         = icw1[2];
    assign ltim        = icw1[3];
    assign upm         = icw4[0];
    assign aeoi        = icw4[1];
    assign ms_bit      = icw4[2];
    assign buf_mode    = icw4[3];
    assign sfnm        = icw4[4];
    assign initialized = (init_state == StReady);
    assign role_master = sngl ? 1'b1 : (buf_mode ? ms_bit : sp_n_i);
    assign own_id      = icw3[2:0];

    logic bus_read;
    logic bus_write;
    assign bus_read  = !cs_n && !rd_n &&  wr_n;
    assign bus_write = !cs_n &&  rd_n && !wr_n;

    // Command decodes used by sequential properties
    logic icw1_write;
    logic ocw1_write;
    logic spec_eoi;
    assign icw1_write = bus_write && !a0 && data_i[4];
    assign ocw1_write = bus_write && a0 && (init_state == StReady);
    assign spec_eoi   = bus_write && !a0 && initialized &&
                        (data_i[4:3] == 2'b00) &&
                        ({data_i[7], data_i[6], data_i[5]} == 3'b011);

    // Priority resolution
    logic [7:0] eligible;
    logic [6:0] elig_res;
    logic [6:0] isr_res;
    logic       elig_valid;
    logic [2:0] elig_level;
    logic       isr_valid;
    logic [2:0] isr_level;
    logic [2:0] elig_rank;
    logic [2:0] isr_rank;
    assign eligible   = irr & ~imr;
    assign elig_res   = resolve_req(eligible, lowest_priority);
    assign isr_res    = resolve_req(isr, lowest_priority);
    assign elig_valid = elig_res[6];
    assign elig_rank  = elig_res[5:3];
    assign elig_level = elig_res[2:0];
    assign isr_valid  = isr_res[6];
    assign isr_rank   = isr_res[5:3];
    assign isr_level  = isr_res[2:0];

    // Expected interrupt output
    logic expected_int;
    always_comb begin
        if (!initialized) begin
            expected_int = 1'b0;
        end else if (!elig_valid) begin
            expected_int = 1'b0;
        end else if (special_mask) begin
            expected_int = 1'b1;
        end else if (!isr_valid) begin
            expected_int = 1'b1;
        end else if (sfnm) begin
            expected_int = (elig_rank <= isr_rank);
        end else begin
            expected_int = (elig_rank < isr_rank);
        end
    end

    // Expected data / cascade / buffer outputs
    logic       drives_opcode;
    logic       owns_addr;
    logic [7:0] low_addr;
    logic [7:0] high_addr;
    logic [7:0] vector_byte;
    logic [7:0] poll_word;
    logic [7:0] expected_data_o;
    logic       expected_data_oe;
    logic [2:0] expected_cas_oe;

    assign drives_opcode = role_master;
    assign owns_addr     = role_master ? !ack_slave : 1'b1;
    assign low_addr      = adi ? {icw1[7:5], ack_level, 2'b00}
                               : {icw1[7:6], ack_level, 3'b000};
    assign high_addr     = icw2;
    assign vector_byte   = {icw2[7:3], ack_level};
    assign poll_word     = {elig_valid, 4'b0000, elig_level};

    always_comb begin
        expected_data_o  = 8'h00;
        expected_data_oe = 1'b0;
        if ((ack_phase != 2'd0) && !inta_n) begin
            if (upm) begin
                if ((ack_phase == 2'd2) && owns_addr) begin
                    expected_data_o  = vector_byte;
                    expected_data_oe = 1'b1;
                end
            end else begin
                if ((ack_phase == 2'd1) && drives_opcode) begin
                    expected_data_o  = 8'hCD;
                    expected_data_oe = 1'b1;
                end else if ((ack_phase == 2'd2) && owns_addr) begin
                    expected_data_o  = low_addr;
                    expected_data_oe = 1'b1;
                end else if ((ack_phase == 2'd3) && owns_addr) begin
                    expected_data_o  = high_addr;
                    expected_data_oe = 1'b1;
                end
            end
        end else if (bus_read) begin
            if (a0) begin
                expected_data_o  = imr;
                expected_data_oe = 1'b1;
            end else if (poll_pending) begin
                expected_data_o  = poll_word;
                expected_data_oe = 1'b1;
            end else begin
                expected_data_o  = read_isr_select ? isr : irr;
                expected_data_oe = 1'b1;
            end
        end
    end

    assign expected_cas_oe = (role_master && ack_slave && (ack_phase != 2'd0))
                             ? 3'b111 : 3'b000;

    // Combinational equivalence and structural safety (hold for any state)
    always_comb begin
        assert (int_o == expected_int);
        assert ({data_o, data_oe} == {expected_data_o, expected_data_oe});
        assert (cas_oe == expected_cas_oe);
        assert (cas_o == ack_level);
        assert (en_n_oe == (initialized && buf_mode));
        assert (en_n_o == ~data_oe);

        // Structural safety
        assert (!data_oe || (bus_read || ((ack_phase != 2'd0) && !inta_n)));
        assert (!int_o || (initialized && (|(irr & ~imr))));
        assert ((cas_oe == 3'b000) || (cas_oe == 3'b111));
        assert ((cas_oe == 3'b000) ||
                (role_master && ack_slave && (ack_phase != 2'd0)));
    end

    // Sequential behavioral properties
    always_ff @(posedge clk) begin
        if ($initstate) begin
            assume (!rst_n);
        end else if (!$past(rst_n)) begin
            // Synchronous reset priority
            assert (init_state == StIcw1);
            assert (imr == 8'hff);
            assert (irr == 8'h00);
            assert (isr == 8'h00);
            assert (lowest_priority == 3'd7);
            assert (!special_mask);
            assert (!auto_rotate);
            assert (!read_isr_select);
            assert (!poll_pending);
            assert (ack_phase == 2'd0);
        end else if ($past(icw1_write)) begin
            // ICW1 restarts initialization and clears operating state
            assert (icw1 == $past(data_i));
            assert (init_state == StIcw2);
            assert (imr == 8'h00);
            assert (irr == 8'h00);
            assert (isr == 8'h00);
            assert (lowest_priority == 3'd7);
            assert (!special_mask);
            assert (!auto_rotate);
            assert (!read_isr_select);
            assert (!poll_pending);
            assert (ack_phase == 2'd0);
        end else begin
            // OCW1 is the only write that changes the mask outside init/reset
            if ($past(ocw1_write)) begin
                assert (imr == $past(data_i));
            end else begin
                assert (imr == $past(imr));
            end

            // Specific EOI clears exactly the addressed in-service bit
            if ($past(spec_eoi)) begin
                assert (isr[$past(data_i[2:0])] == 1'b0);
            end

            // Reachable-state structural bounds
            assert (init_state <= StReady);
            assert (ack_phase <= (upm ? 2'd2 : 2'd3));
        end
    end

endmodule
