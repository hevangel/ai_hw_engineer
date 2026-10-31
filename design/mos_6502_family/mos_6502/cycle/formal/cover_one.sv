module cover_one(input logic clk);
    (* anyseq *) logic rst_n, res_n, irq_n, nmi_n, rdy, so_n;
    (* anyseq *) logic [7:0] bus_data_i;
    logic [15:0] bus_addr,pc_o;
    logic [7:0] bus_data_o,status_o,a_o,x_o,y_o,sp_o;
    logic bus_we, fetch_o, fault_o;
    mos_6502_cycle dut(.*);
    always_ff @(posedge clk) begin
        if($initstate) assume(!rst_n);
        else assume(rst_n);
        cover(dut.state == 6'd13);
    end
endmodule
