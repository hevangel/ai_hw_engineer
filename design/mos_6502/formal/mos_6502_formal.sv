module mos_6502_formal(input logic clk);
    (* anyseq *) logic rst_n, res_n, irq_n, nmi_n, rdy, so_n;
    (* anyseq *) logic [7:0] bus_data_i;
    logic [15:0] bus_addr,pc_o;
    logic [7:0] bus_data_o,status_o,a_o,x_o,y_o,sp_o;
    logic bus_we, fetch_o, fault_o;
    mos_6502 dut(.*);
    always_ff @(posedge clk) begin
        if($initstate) assume(!rst_n);
        else assume(rst_n);
        cover(rst_n && fetch_o && pc_o==16'h8000);
        cover(rst_n && bus_we);
    end
endmodule
