module ttl_74x952 (
    input logic [7:0] io_in,
    input logic clk,serial_in,dis_o,dis_i,dis_tu,dis_td,dis_s,
    output logic [7:0] io_out,
    output logic io_drive,serial_out
);
    logic [7:0] upper_reg,shift_reg;
    always_ff @(posedge clk) begin
        if(!dis_i) upper_reg <= io_in | ((!dis_tu && dis_td)?shift_reg:8'd0);
        else if(!dis_tu && !dis_td) upper_reg <= 8'd0;
        else if(!dis_tu) upper_reg <= shift_reg;
        if(!dis_td) begin
            if(!dis_tu) shift_reg <= 8'd0;
            else shift_reg <= dis_i?upper_reg:io_in;
        end else if(!dis_s) shift_reg <= {shift_reg[6:0],serial_in};
    end
    assign io_drive=dis_i && !dis_o;
    assign io_out=io_drive?upper_reg:8'd0;
    assign serial_out=shift_reg[7];
endmodule
