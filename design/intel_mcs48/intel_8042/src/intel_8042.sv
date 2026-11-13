// Intel 8042 UPI-42: the upi42_core with its 2048 x 8 mask ROM.
// ROM_FILE is a $readmemh image of the firmware (one byte per line).
module intel_8042 #(
    parameter string ROM_FILE = ""
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ce_i,
    input  logic        cs_n_i,
    input  logic        rd_n_i,
    input  logic        wr_n_i,
    input  logic        a0_i,
    input  logic [7:0]  d_i,
    output logic [7:0]  d_o,
    output logic        d_oe_o,
    output logic [7:0]  p1_o,
    input  logic [7:0]  p1_i,
    output logic [7:0]  p2_o,
    input  logic [7:0]  p2_i,
    input  logic        t0_i,
    input  logic        t1_i,
    output logic        retire_o,
    output logic [10:0] retire_pc_o,
    output logic [7:0]  retire_op_o,
    output logic [1:0]  retire_kind_o,
    output logic        illegal_o
);
    logic [7:0]  rom [0:2047];
    logic [10:0] rom_addr;
    logic [7:0]  rom_data;

    initial begin
        if (ROM_FILE != "")
            $readmemh(ROM_FILE, rom);
    end

    assign rom_data = rom[rom_addr];

    /* verilator lint_off PINCONNECTEMPTY */
    upi42_core core (
        .clk, .rst_n, .ce_i,
        .rom_addr_o (rom_addr),
        .rom_data_i (rom_data),
        .cs_n_i, .rd_n_i, .wr_n_i, .a0_i, .d_i, .d_o, .d_oe_o,
        .p1_o, .p1_i, .p2_o, .p2_i, .t0_i, .t1_i,
        .retire_o, .retire_pc_o, .retire_op_o, .retire_kind_o, .illegal_o,
        .pc_o (), .a_o (), .psw_o (), .sts_o (), .t_o (),
        .dbbin_o (), .dbbout_o (), .misc_o ()
    );
    /* verilator lint_on PINCONNECTEMPTY */
endmodule
