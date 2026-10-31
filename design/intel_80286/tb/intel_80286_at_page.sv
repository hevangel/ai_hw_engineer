// Digital register fixture for the IBM AT page-register CPU interface.
// ASSUMPTION: reset clears storage for determinism; historical 74LS612
// power-up contents are not established here. The BIOS must write before read.
module intel_80286_at_page (
    input  logic        clk, rst_n,
    input  logic        io_req_i, io_ready_i, io_write_i,
    input  logic [15:0] io_addr_i,
    input  logic [7:0]  io_wdata_i,
    input  logic [3:0]  map_index_i,
    output logic        selected_o, rdata_valid_o,
    output logic [7:0]  rdata_o, map_data_o
);
    logic [7:0] registers [0:15];
    assign selected_o = io_req_i && io_addr_i[15:4] == 12'h008;
    assign rdata_valid_o = selected_o && io_ready_i && !io_write_i;
    assign rdata_o = registers[io_addr_i[3:0]];
    assign map_data_o = registers[map_index_i];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int index=0; index<16; index++) registers[index] <= 8'h00;
        end else if (selected_o && io_ready_i && io_write_i) begin
            registers[io_addr_i[3:0]] <= io_wdata_i;
        end
    end
endmodule
