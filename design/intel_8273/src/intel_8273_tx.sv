`timescale 1ns/1ps
// Bit-serial transmitter. Byte order/FCS follow Intel 210479 and RFC 1662.
module intel_8273_tx (
    input logic clk, rst_n, tick, start, abort_req, cts_n,
    input logic [1:0] abort_kind,
    input logic buffered, transparent, nrzi, pre_sync, flag_stream,
    input logic [15:0] length,
    input logic [7:0] address, control, data,
    input logic data_valid,
    output logic take, busy, txd,
    output logic done,
    output logic [7:0] result
);
    typedef enum logic [3:0] {IDLE, WAIT_CTS, SYNC, OPEN, ADDR, CTRL,
        PAYLOAD, FCS1, FCS2, CLOSE, ABORT} state_t;
    state_t state_q, state_n;
    logic [7:0] shift_q, shift_n, error_q, error_n;
    logic [15:0] crc_q, crc_n, left_q, left_n, fcs_q, fcs_n;
    logic [2:0] bit_q, bit_n, ones_q, ones_n;
    logic sync_second_q, sync_second_n, loaded_q, loaded_n;
    logic line_q, line_n, done_n;
    logic [7:0] result_n;
    logic raw_bit, stuffed, payload_ready;

    function automatic [15:0] crc_bit(input logic [15:0] crc,input logic b);
        crc_bit = (crc >> 1) ^ ((crc[0] ^ b) ? 16'h8408 : 16'h0000);
    endfunction
    assign busy = state_q != IDLE;
    assign txd = line_q;
    always_comb begin
        state_n=state_q; shift_n=shift_q; error_n=error_q;
        crc_n=crc_q; left_n=left_q; fcs_n=fcs_q; bit_n=bit_q;
        ones_n=ones_q; sync_second_n=sync_second_q; loaded_n=loaded_q;
        line_n=line_q; done_n=0; result_n=result; take=0;
        raw_bit=1; stuffed=0; payload_ready=1;
        if (state_q==PAYLOAD && !loaded_q) begin
            if (data_valid) begin shift_n=data; loaded_n=1; take=1; end
            else payload_ready=0;
        end
        if (start && state_q==IDLE) begin
            state_n=WAIT_CTS; left_n=length; crc_n=16'hffff;
            ones_n=0; bit_n=0; loaded_n=0; sync_second_n=0;
        end else if (abort_req && state_q!=IDLE) begin
            state_n=ABORT; shift_n=abort_kind==1 ? 8'h7e : 8'hff; bit_n=0; ones_n=0;
            error_n=8'h10; loaded_n=0;
            if (abort_kind==2) begin state_n=IDLE; done_n=1; result_n=8'h10; end
        end else if (state_q==WAIT_CTS && !cts_n) begin
            bit_n=0;
            if (transparent) begin
                if (left_q==0) begin state_n=IDLE; done_n=1; result_n=8'h0d; end
                else state_n=PAYLOAD;
            end else if (pre_sync) begin
                state_n=SYNC; shift_n=nrzi ? 8'h00 : 8'h55;
            end else begin state_n=OPEN; shift_n=8'h7e; end
        end else if (cts_n && state_q!=IDLE && state_q!=WAIT_CTS && state_q!=ABORT) begin
            state_n=ABORT; shift_n=8'hff; bit_n=0; error_n=8'h0f;
        end else if (tick && state_q!=WAIT_CTS) begin
            if (state_q==IDLE) begin
                raw_bit=flag_stream ? ((8'h7e >> bit_q) & 8'h01)!=0 : 1'b1;
                bit_n=bit_q+1'b1;
            end else if (!payload_ready) begin
                state_n=ABORT; shift_n=8'hff; bit_n=0; error_n=8'h0e;
            end else begin
                stuffed = !transparent && ones_q==5 &&
                    (state_q==ADDR || state_q==CTRL || state_q==PAYLOAD ||
                     state_q==FCS1 || state_q==FCS2 || (state_q==CLOSE && bit_q==0));
                raw_bit=stuffed ? 1'b0 : shift_n[0];
                if (stuffed) ones_n=0;
                else begin
                    if (!transparent && (state_q==ADDR || state_q==CTRL || state_q==PAYLOAD ||
                        state_q==FCS1 || state_q==FCS2))
                        ones_n=raw_bit ? ones_q+1'b1 : 3'd0;
                    else ones_n=0;
                    if (!transparent && (state_q==ADDR || state_q==CTRL || state_q==PAYLOAD))
                        crc_n=crc_bit(crc_q,raw_bit);
                    shift_n={1'b0,shift_n[7:1]}; bit_n=bit_q+1'b1;
                    if (bit_q==7) begin
                        bit_n=0;
                        case (state_q)
                            SYNC: if (!sync_second_q) begin
                                sync_second_n=1; shift_n=nrzi ? 8'h00 : 8'h55;
                            end else begin state_n=OPEN; shift_n=8'h7e; end
                            OPEN: if (buffered) begin state_n=ADDR; shift_n=address; end
                                else if (left_q!=0) begin state_n=PAYLOAD; loaded_n=0; end
                                else begin state_n=FCS1; fcs_n=~crc_n; shift_n=~crc_n[7:0]; end
                            ADDR: begin state_n=CTRL; shift_n=control; end
                            CTRL: if (left_q!=0) begin state_n=PAYLOAD; loaded_n=0; end
                                else begin state_n=FCS1; fcs_n=~crc_n; shift_n=~crc_n[7:0]; end
                            PAYLOAD: begin
                                loaded_n=0; left_n=left_q-1'b1;
                                if (left_q==1) begin
                                    if (transparent) begin state_n=IDLE; done_n=1; result_n=8'h0d; end
                                    else begin state_n=FCS1; fcs_n=~crc_n; shift_n=~crc_n[7:0]; end
                                end
                            end
                            FCS1: begin state_n=FCS2; shift_n=fcs_q[15:8]; end
                            FCS2: begin state_n=CLOSE; shift_n=8'h7e; end
                            CLOSE: begin state_n=IDLE; done_n=1; result_n=8'h0d; end
                            ABORT: begin state_n=IDLE; done_n=1; result_n=error_q; end
                            default: begin end
                        endcase
                    end
                end
            end
            // Even an underrun consumes this bit slot as an idle/abort one.
            line_n=nrzi ? (raw_bit ? line_q : ~line_q) : raw_bit;
        end
    end
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_q<=IDLE; shift_q<=0; error_q<=0; crc_q<=16'hffff;
            left_q<=0; fcs_q<=0; bit_q<=0; ones_q<=0;
            sync_second_q<=0; loaded_q<=0; line_q<=1; done<=0; result<=0;
        end else begin
            state_q<=state_n; shift_q<=shift_n; error_q<=error_n;
            crc_q<=crc_n; left_q<=left_n; fcs_q<=fcs_n; bit_q<=bit_n;
            ones_q<=ones_n; sync_second_q<=sync_second_n; loaded_q<=loaded_n;
            line_q<=line_n; done<=done_n; result<=result_n;
        end
    end
`ifdef FORMAL
    always_ff @(posedge clk) if (rst_n) begin
        assert(state_q<=ABORT);
        assert(ones_q<=5 || transparent);
        if (take) assert(state_q==PAYLOAD && !loaded_q && data_valid);
    end
`endif
endmodule
