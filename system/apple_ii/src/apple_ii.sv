module apple_ii #(
    parameter ROM_FILE = ""
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [6:0] key_data,
    input  logic       key_valid,
    input  logic [9:0] text_addr,
    output logic [7:0] text_data,
    output logic       cpu_fault,
    output logic       cpu_fetch,
    output logic [15:0] cpu_pc,
    output logic [7:0] cpu_status,
    output logic [7:0] cpu_x,
    output logic [7:0] cpu_y
);
    logic [15:0] cpu_addr;
    logic [7:0] cpu_data_i, cpu_data_o;
    logic cpu_we;

    mos_6502 cpu (
        .clk(clk), .rst_n(rst_n), .bus_addr(cpu_addr),
        .bus_data_i(cpu_data_i), .bus_data_o(cpu_data_o), .bus_we(cpu_we),
        .fetch_o(cpu_fetch), .fault_o(cpu_fault), .pc_o(cpu_pc),
        .status_o(cpu_status), .x_o(cpu_x), .y_o(cpu_y)
    );
    apple_ii_memory #(.ROM_FILE(ROM_FILE)) memory (
        .clk(clk), .rst_n(rst_n), .cpu_addr(cpu_addr),
        .cpu_data_o(cpu_data_o), .cpu_we(cpu_we), .cpu_data_i(cpu_data_i),
        .key_data(key_data), .key_valid(key_valid),
        .text_addr(text_addr), .text_data(text_data)
    );
endmodule
