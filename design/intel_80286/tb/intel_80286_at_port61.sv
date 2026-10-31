// IBM 5170 type 1 sheet 17: U127 four-bit output latch and U128 read buffer.
// Canonical port 61h only; bus strobes are transaction-level fixture inputs.
module intel_80286_at_port61 (
    input  logic       clk, reset_n,
    input  logic       io_req_i, io_ready_i, io_write_i,
    input  logic [15:0] io_addr_i,
    input  logic [3:0] io_wdata_i,
    input  logic       refresh_detect_i, timer2_out_i, iochck_i, pck_i,
    output logic       selected_o, rdata_valid_o,
    output logic [7:0] rdata_o,
    output logic [3:0] control_o
);
    assign selected_o=io_req_i && io_addr_i==16'h0061;
    assign rdata_valid_o=selected_o && io_ready_i && !io_write_i;
    assign rdata_o={pck_i,iochck_i,timer2_out_i,refresh_detect_i,control_o};
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) control_o<=4'h0;
        else if (selected_o && io_ready_i && io_write_i) control_o<=io_wdata_i;
    end
endmodule
