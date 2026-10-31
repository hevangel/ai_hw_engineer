`timescale 1ns/1ps
// Selectable CPU + actual original RRIOT masks/ROMs. Not a system release.
module tb_kim_boot;
    logic clk = 0, rst_n = 0;
    logic phi2;
    logic [15:0] bus_addr, pc;
    logic [7:0] bus_data_i, bus_data_o, status, a, x, y, sp;
    logic bus_we, fetch, fault, jammed;
    logic [7:0] data_2, data_3;
    logic oe_2, oe_3, irq_2, irq_3;
    logic [7:0] pa_2, pb_2, pa_oe_2, pb_oe_2, pa_3, pb_3, pa_oe_3, pb_oe_3;
    logic [7:0] ram [0:1023];
    int boot_fetches = 0, scans = 0, next_digit = 0, segment_writes = 0;
    int mask_ram_writes = 0, cycles = 0;
    logic [15:0] expected_pc [0:3];
    logic [7:0] expected_opcode [0:3];
    // CPU completes each bus transfer at posedge. The peripheral PHI2 falls
    // there too. Native variants model CPU cycles; analog phase timing is open.
    assign phi2 = !clk;
`ifdef CPU_6507
    logic [12:0] physical_addr;
    logic [15:0] debug_addr;
    assign bus_addr = {3'b000, physical_addr};
    mos_6507 cpu (
        .clk, .rst_n, .rdy_i(1'b1),
        .bus_addr(physical_addr), .debug_bus_addr_o(debug_addr),
        .bus_data_i, .bus_data_o, .bus_we,
        .fetch_o(fetch), .fault_o(fault), .jammed_o(jammed),
        .pc_o(pc), .status_o(status), .a_o(a), .x_o(x), .y_o(y), .s_o(sp)
    );
    // Assert the physical truncation without using debug bits as board inputs.
    always_ff @(posedge clk) if (rst_n) begin
        if (debug_addr[12:0] !== physical_addr || (fetch && debug_addr !== pc))
            $fatal(1, "6507 physical/fetch address mismatch");
    end
`elsif CPU_6510
    logic address_oe, rw_oe, data_oe;
    logic [5:0] processor_port, processor_oe;
    logic [7:0] processor_ddr, processor_latch;
    mos_6510 cpu (
        .clk, .rst_n, .rdy_i(1'b1), .irq_n(1'b1), .nmi_n(1'b1), .aec_i(1'b1),
        .bus_addr, .bus_data_i, .bus_data_o, .bus_we,
        .bus_addr_oe(address_oe), .bus_rw_oe(rw_oe), .bus_data_oe(data_oe),
        .port_i(6'h3f), .port_o(processor_port), .port_oe(processor_oe),
        .ddr_o(processor_ddr), .latch_o(processor_latch),
        .fetch_o(fetch), .fault_o(fault), .jammed_o(jammed),
        .pc_o(pc), .status_o(status), .a_o(a), .x_o(x), .y_o(y), .s_o(sp)
    );
    always_ff @(posedge clk) if (rst_n) begin
        if (!address_oe || !rw_oe || data_oe !== (bus_we && bus_addr > 1) ||
            processor_port !== processor_latch[5:0] || processor_oe !== processor_ddr[5:0])
            $fatal(1,"6510 processor bus/port wiring");
        if (fetch && boot_fetches == 0 && (processor_ddr !== 0 || processor_latch !== 0))
            $fatal(1,"6510 processor-port reset profile");
    end
`elsif NATIVE_CPU
    mos_6502_native cpu (
        .clk, .rst_n, .rdy_i(1'b1), .irq_n(1'b1), .nmi_n(1'b1), .so_n(1'b1),
        .bus_addr, .bus_data_i, .bus_data_o, .bus_we,
        .fetch_o(fetch), .fault_o(fault), .jammed_o(jammed),
        .pc_o(pc), .status_o(status), .a_o(a), .x_o(x), .y_o(y), .s_o(sp)
    );
`else
    assign jammed = 0;
    mos_6502 cpu (
        .clk, .rst_n, .bus_addr, .bus_data_i, .bus_data_o, .bus_we,
        .irq_n(1'b1), .nmi_n(1'b1), .fetch_o(fetch), .fault_o(fault),
        .pc_o(pc), .status_o(status), .a_o(a), .x_o(x), .y_o(y), .s_o(sp)
    );
`endif
    mos_6530_kim chip_2 (
        .clk(phi2), .rst_n, .rw(!bus_we), .board_addr(bus_addr[12:0]),
        .data_i(bus_data_o), .data_o(data_2), .data_oe(oe_2),
        .pa_i(8'hff), .pb_i(8'hff), .pa_o(pa_2), .pb_o(pb_2),
        .pa_oe(pa_oe_2), .pb_oe(pb_oe_2), .irq_n(irq_2)
    );
    mos_6530_kim #(.SECOND(1)) chip_3 (
        .clk(phi2), .rst_n, .rw(!bus_we), .board_addr(bus_addr[12:0]),
        .data_i(bus_data_o), .data_o(data_3), .data_oe(oe_3),
        .pa_i(8'hff), .pb_i(8'hff), .pa_o(pa_3), .pb_o(pb_3),
        .pa_oe(pa_oe_3), .pb_oe(pb_oe_3), .irq_n(irq_3)
    );
    always_comb begin
        bus_data_i = 8'hff;
        if (bus_addr[12:0] < 13'h0400) bus_data_i = ram[bus_addr[9:0]];
        else if (bus_addr[12:0] >= 13'h1c00 ||
                 (bus_addr[12:0] >= 13'h17c0 && bus_addr[12:0] < 13'h1800) ||
                 (bus_addr[12:0] >= 13'h1740 && bus_addr[12:0] < 13'h1780))
            bus_data_i = data_2;
        else if (bus_addr[12:0] >= 13'h1800 ||
                 (bus_addr[12:0] >= 13'h1780 && bus_addr[12:0] < 13'h17c0) ||
                 (bus_addr[12:0] >= 13'h1700 && bus_addr[12:0] < 13'h1740))
            bus_data_i = data_3;
    end
    always_ff @(posedge clk) begin
        if (rst_n && bus_we && bus_addr[12:0] < 13'h0400)
`ifdef CPU_6510
            ram[bus_addr[9:0]] <= data_oe ? bus_data_o : 8'hff;
`else
            ram[bus_addr[9:0]] <= bus_data_o;
`endif
    end
    task automatic fail(input string why);
        $fatal(1, "%s PC=%04x bus=%04x A=%02x X=%02x Y=%02x S=%02x P=%02x ports=%02x/%02x/%02x/%02x oe=%02x/%02x/%02x/%02x irq=%b%b",
               why, pc, bus_addr, a, x, y, sp, status, pa_2, pb_2, pa_3, pb_3,
               pa_oe_2, pb_oe_2, pa_oe_3, pb_oe_3, irq_2, irq_3);
    endtask
    initial begin
        expected_pc[0] = 16'h1c22; expected_opcode[0] = 8'ha2;
        expected_pc[1] = 16'h1c24; expected_opcode[1] = 8'h9a;
        expected_pc[2] = 16'h1c25; expected_opcode[2] = 8'h86;
        expected_pc[3] = 16'h1c27; expected_opcode[3] = 8'h20;
        foreach (ram[i]) ram[i] = 0;
        repeat (2) begin #1; clk = 1; #1; clk = 0; end
        rst_n = 1;
        for (cycles = 0; cycles < 100000; cycles++) begin
            #1;
            if (fault || jammed) fail("CPU fault/lock-up in original monitor");
            if (oe_2 && oe_3) fail("RRIOT bus contention");
            if (fetch && boot_fetches < 4) begin
                if (pc !== expected_pc[boot_fetches] || bus_data_i !== expected_opcode[boot_fetches])
                    fail("Exact manufacturer reset instruction/next-PC mismatch");
                boot_fetches++;
            end
            if (bus_we && bus_addr >= 16'h17c0 && bus_addr <= 16'h17ff) mask_ram_writes++;
            if (bus_we && bus_addr == 16'h1742) begin
                if (next_digit == 0) begin
                    if (bus_data_o == 8'h09) next_digit = 1;
                end else begin
                    if (bus_data_o != 8'(9+2*next_digit)) fail("Exact six-digit display order");
                    next_digit++;
                    if (next_digit == 7) begin next_digit = 0; scans++; end
                end
            end
            if (bus_we && bus_addr == 16'h1740 && bus_data_o != 0) begin
                if (bus_data_o != 8'hbf) fail("Manufacturer seven-segment zero encoding");
                segment_writes++;
            end
            if (scans == 2) begin
                if (boot_fetches != 4 || segment_writes != 12 || mask_ram_writes == 0)
                    fail("Incomplete real-firmware exercise");
                break;
            end
            clk = 1; #1; clk = 0;
        end
        if (scans != 2) fail("Original monitor boot watchdog");
        $display("KIM-1 ORIGINAL MONITOR PASS: scans=%0d segments=%0d mask_ram_writes=%0d cycles=%0d", scans, segment_writes, mask_ram_writes, cycles);
        $finish;
    end
endmodule
