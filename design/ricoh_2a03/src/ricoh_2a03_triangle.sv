// APU triangle channel; its timer is clocked every CPU cycle.
module ricoh_2a03_triangle (
    input  logic clk, rst_n,
    input  logic quarter_i, half_i,
    input  logic enable_i,
    input  logic wr_i,
    input  logic [1:0] reg_i,
    input  logic [7:0] data_i,
    output logic active_o,
    output logic [3:0] out_o
);
    logic control, linear_reload;
    logic [6:0] linear_value, linear;
    logic [10:0] period, timer;
    logic [4:0] step;
    assign out_o = step[4] ? step[3:0] : ~step[3:0];

    ricoh_2a03_length length_unit (
        .clk, .rst_n, .enable_i, .halt_i(control), .load_i(wr_i && reg_i == 2'd3),
        .index_i(data_i[7:3]), .half_i, .active_o
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            control <= 1'b0; linear_reload <= 1'b0; linear_value <= '0; linear <= '0;
            period <= '0; timer <= '0; step <= '0;
        end else begin
            if (timer == 0) begin
                timer <= period;
                if (linear != 0 && active_o) step <= step + 5'd1;
            end else timer <= timer - 11'd1;
            if (quarter_i) begin
                if (linear_reload) linear <= linear_value;
                else if (linear != 0) linear <= linear - 7'd1;
                if (!control) linear_reload <= 1'b0;
            end
            if (wr_i) begin
                case (reg_i)
                    2'd0: begin control <= data_i[7]; linear_value <= data_i[6:0]; end
                    2'd2: period[7:0] <= data_i;
                    2'd3: begin period[10:8] <= data_i[2:0]; linear_reload <= 1'b1; end
                    default: ;
                endcase
            end
        end
    end
endmodule
