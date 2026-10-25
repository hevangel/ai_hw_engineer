// motorola_6809 third-party test runner (reyco2000/6809_6309_code_tester).
// Free-runs the loaded test image with the suite's DEV device model:
//   $FF00 W  interrupt line levels (bit0 IRQ, bit1 FIRQ, bit2 NMI edge)
//   $FF01 W  deferred line levels
//   $FF02/3 W  deferred-change delay in clocks (big-endian; $FF03 arms)
//   $FF04/5 W  cycle-counter latches; $FF06/7 R  16-bit delta
//   $FF08 W  console output (ignored)
//   $FF0F W  exit: 0 = all tests passed, else failure code
// Termination: DEV_EXIT write (0 = PASS) or watchdog.
`timescale 1ns/1ps

module tb_top;

    localparam int TCK = 100;

    logic clk = 1'b0;
    always #(TCK/2) clk = ~clk;

    logic        rst_n;
    wire  [15:0] bus_addr;
    wire  [7:0]  bus_data_o;
    logic [7:0]  bus_data_i;
    wire         bus_we;
    wire         vma_o;
    wire         irq_n;
    wire         firq_n;
    wire         nmi_n;
    wire         halted_o, sync_o;
    wire  [15:0] pc_o, x_o, y_o, u_o, s_o;
    wire  [7:0]  a_o, b_o, dp_o, cc_o;

    motorola_6809 dut (
        .clk, .rst_n, .bus_addr, .bus_data_i, .bus_data_o, .bus_we,
        .vma_o, .irq_n, .firq_n, .nmi_n, .halted_o, .sync_o,
        .pc_o, .x_o, .y_o, .u_o, .s_o, .a_o, .b_o, .dp_o, .cc_o
    );

    logic [7:0] mem [0:65535];

    // DEV state
    logic [2:0]  dev_lines = 3'b000;
    logic [2:0]  dev_dlines = 3'b000;
    logic [15:0] dev_delay = 16'h0000;
    logic        dev_armed = 1'b0;
    logic [31:0] cyc = 0;
    logic [31:0] cyc0 = 0, cyc1 = 0;
    logic        nmi_pulse = 1'b0;
    logic        done = 1'b0;
    logic [7:0]  exit_code = 8'h00;

    // DEV register reads overlay RAM
    logic [15:0] cycd;
    always_comb cycd = cyc1[15:0] - cyc0[15:0];
    always_comb begin
        if (bus_addr == 16'hFF06) bus_data_i = cycd[15:8];
        else if (bus_addr == 16'hFF07) bus_data_i = cycd[7:0];
        else bus_data_i = mem[bus_addr];
    end

    always_ff @(posedge clk) begin
        if (bus_we) mem[bus_addr] <= bus_data_o;
        cyc <= cyc + 1;
    end

    // DEV write decode + deferred line change (single process)
    always_ff @(posedge clk) begin
        if (bus_we && !done) begin
            case (bus_addr)
                16'hFF00: begin
                    dev_lines <= bus_data_o[2:0];
                    if (!dev_lines[2] && bus_data_o[2]) nmi_pulse <= 1'b1;
                end
                16'hFF01: dev_dlines <= bus_data_o[2:0];
                16'hFF02: dev_delay[15:8] <= bus_data_o;
                16'hFF03: begin
                    dev_delay[7:0] <= bus_data_o;
                    dev_armed <= 1'b1;
                end
                16'hFF04: cyc0 <= cyc;
                16'hFF05: cyc1 <= cyc;
                16'hFF0F: begin
                    done <= 1'b1;
                    exit_code <= bus_data_o;
                end
                default: ;
            endcase
        end
        if (dev_armed) begin
            if (dev_delay == 16'h0000) begin
                dev_armed <= 1'b0;
                dev_lines <= dev_dlines;
                if (!dev_lines[2] && dev_dlines[2]) nmi_pulse <= 1'b1;
            end else begin
                dev_delay <= dev_delay - 16'h1;
            end
        end
        if (nmi_pulse) nmi_pulse <= 1'b0;
    end

    // DEV_LINES bit set = line asserted = pin LOW (active-low inputs)
    assign irq_n  = ~dev_lines[0];
    assign firq_n = ~dev_lines[1];
    assign nmi_n  = nmi_pulse ? 1'b0 : 1'b1;

    string imgfile;
    initial begin
        if (!$value$plusargs("image=%s", imgfile))
            imgfile = "work/sim/mem.hex";
        $readmemh(imgfile, mem);
        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
    end

    initial begin
        #400_000_000_0;   // watchdog (4e9 ns)
        if (!done)
            $display("MC6809 THIRD-PARTY TEST FAILED (timeout, pc=%04x)",
                     pc_o);
        $finish;
    end

    always @(posedge clk) begin
        if (done) begin
            if (exit_code == 8'h00)
                $display("MC6809 THIRD-PARTY TEST PASSED (cycles=%0d)",
                         cyc);
            else
                $display("MC6809 THIRD-PARTY TEST FAILED exit=%02x pc=%04x case=%02x",
                         exit_code, pc_o, mem[16'h0100]);
            $finish;
        end
    end
endmodule
