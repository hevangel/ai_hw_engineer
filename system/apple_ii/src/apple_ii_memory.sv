module apple_ii_memory #(
    parameter ROM_FILE = ""
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [15:0] cpu_addr,
    input  logic [7:0]  cpu_data_o,
    input  logic        cpu_we,
    output logic [7:0]  cpu_data_i,
    input  logic [6:0]  key_data,
    input  logic        key_valid,
    input  logic [9:0]  text_addr,
    output logic [7:0]  text_data
);
    logic [7:0] ram [0:49151];
    logic [7:0] rom [0:12287];
    logic [6:0] key_latch;
    logic key_strobe;
    logic [13:0] rom_addr;

    assign rom_addr = cpu_addr[13:0] - 14'h1000;

    initial begin
        for (integer i = 0; i < 12288; i++) rom[i] = 8'h00;
        if (ROM_FILE != "") $readmemh(ROM_FILE, rom);
    end

    // Text page 1 is $0400-$07FF. Video timing and row mapping are separate.
    assign text_data = ram[16'h0400 + {6'b0, text_addr}];

    always_comb begin
        cpu_data_i = 8'h00;
        if (cpu_addr < 16'hc000)
            cpu_data_i = ram[cpu_addr];
        else if (cpu_addr == 16'hc000)
            cpu_data_i = {key_strobe, key_latch};
        else if (cpu_addr >= 16'hd000)
            cpu_data_i = rom[rom_addr];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            key_latch <= 7'h00;
            key_strobe <= 1'b0;
        end else begin
            if (cpu_we && cpu_addr < 16'hc000)
                ram[cpu_addr] <= cpu_data_o;
            if (cpu_addr == 16'hc010)
                key_strobe <= 1'b0;
            if (key_valid) begin
                key_latch <= key_data;
                key_strobe <= 1'b1;
            end
        end
    end
endmodule
