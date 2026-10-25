// motorola_6800 third-party test runner (hakanrw/mc6800 programs).
// Free-runs one assembled test image and stops when the program reaches
// its end-of-test self-loop (three consecutive fetches of the same PC),
// then prints the $2000-$20FF marker window for the Python checker.
// +image=<path> selects the memory image (default work/third/mem.hex).
`timescale 1ns/1ps

module tb_thirdparty;

    localparam int TCK = 100;

    logic clk = 1'b0;
    always #(TCK/2) clk = ~clk;

    logic        rst_n;
    wire  [15:0] bus_addr;
    wire  [7:0]  bus_data_o;
    logic [7:0]  bus_data_i;
    wire         bus_we;
    wire         vma_o;
    logic        irq_n = 1'b1;
    logic        nmi_n = 1'b1;
    wire         halted_o, sync_o;
    wire  [15:0] pc_o, ix_o, sp_o;
    wire  [7:0]  a_o, b_o, cc_o;

    motorola_6800 dut (
        .clk, .rst_n, .bus_addr, .bus_data_i, .bus_data_o, .bus_we,
        .vma_o, .irq_n, .nmi_n, .halted_o, .sync_o,
        .pc_o, .a_o, .b_o, .ix_o, .sp_o, .cc_o
    );

    logic [7:0] mem [0:65535];

    always_comb bus_data_i = mem[bus_addr];
    always_ff @(posedge clk) if (bus_we) mem[bus_addr] <= bus_data_o;

    string imgfile;
    logic [15:0] last_pc = 16'hFFFF;
    int          same_pc = 0;
    int          cycles = 0;
    logic        done = 1'b0;

    initial begin
        if (!$value$plusargs("image=%s", imgfile))
            imgfile = "work/third/mem.hex";
        $readmemh(imgfile, mem);
        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
    end

    always_ff @(posedge clk) begin
        if (rst_n && !done) begin
            cycles <= cycles + 1;
            if (sync_o) begin
                if (pc_o == last_pc) begin
                    same_pc <= same_pc + 1;
                    if (same_pc == 2) begin
                        done <= 1'b1;
                    end
                end else begin
                    same_pc <= 0;
                    last_pc <= pc_o;
                end
            end
        end
    end

    initial begin
        #5_000_000_000;   // 50 ms sim time watchdog
        $display("TTIMEOUT pc=%04x", pc_o);
        $finish;
    end

    always @(posedge clk) begin
        if (done) begin
            $display("TSELFLOOP pc=%04x cycles=%0d", pc_o, cycles);
            $write("TWIN");
            for (int i = 0; i < 256; i++)
                $write(" %02x", mem[32'(16'h2000) + i]);
            $write("\n");
            $finish;
        end
    end
endmodule
