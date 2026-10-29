`timescale 1ns/1ps
module tb_ttl_74x779;
    logic clk;
    logic s1, s0, cet_n, oe_n;
    logic [7:0] external_io_data, external_io_drive;
    logic [7:0] io_data, io_drive, io_bus_resolved, io_bus_valid;
    logic [7:0] io_bus_conflict;
    logic tc_n;
    logic [7:0] expected_count;

    ttl_74x779 dut (.*);

    task automatic clock_rise;
        begin
            clk = 1'b0;
            #1;
            clk = 1'b1;
            #1;
        end
    endtask

    task automatic check_count(input logic [7:0] expected_value);
        begin
            if (io_data !== expected_value)
                $fatal(1, "count mismatch: got %02x expected %02x", io_data, expected_value);
        end
    endtask

    initial begin
        clk = 1'b0;
        s1 = 1'b0;
        s0 = 1'b0;
        cet_n = 1'b1;
        oe_n = 1'b1;
        external_io_data = 8'hA5;
        external_io_drive = 8'hFF;
        expected_count = 8'hA5;

        // The published load row requires S1:S0=00 and OE high; CET is immaterial.
        clock_rise();
        check_count(expected_count);
        if (io_drive !== 8'h00 || io_bus_valid !== 8'hFF ||
            io_bus_conflict !== 8'h00 || io_bus_resolved !== 8'hA5)
            $fatal(1, "high-impedance output / externally driven load bus");
        external_io_drive = 8'h00;
        #1;
        if (io_bus_valid !== 8'h00 || io_bus_resolved !== 8'h00)
            $fatal(1, "floating I/O bus must be invalid and masked");
        external_io_drive = 8'hFF;

        // Output-enable is active low; matching external values resolve cleanly.
        oe_n = 1'b0;
        external_io_data = expected_count;
        #1;
        if (io_drive !== 8'hFF || io_bus_valid !== 8'hFF ||
            io_bus_conflict !== 8'h00 || io_bus_resolved !== expected_count)
            $fatal(1, "matching chip and external drivers");

        // Conflicting strong drivers invalidate only the disagreeing bits.
        external_io_data = ~expected_count;
        #1;
        if (io_bus_conflict !== 8'hFF || io_bus_valid !== 8'h00 ||
            io_bus_resolved !== 8'h00)
            $fatal(1, "conflicting chip and external drivers");
        external_io_drive = 8'h00;
        #1;
        if (io_bus_conflict !== 8'h00 || io_bus_valid !== 8'hFF ||
            io_bus_resolved !== expected_count)
            $fatal(1, "chip-only drive resolution");

        // The published load row requires OE high; OE low keeps the outputs active.
        s1 = 1'b0;
        s0 = 1'b0;
        external_io_data = 8'h3C;
        clock_rise();
        check_count(expected_count);

        // Up count and count-disabled hold rows.
        s1 = 1'b1;
        s0 = 1'b0;
        cet_n = 1'b0;
        expected_count = expected_count + 8'd1;
        clock_rise();
        check_count(expected_count);
        cet_n = 1'b1;
        clock_rise();
        check_count(expected_count);

        // Down count and count-disabled hold; verify wrap behavior at zero.
        s1 = 1'b0;
        s0 = 1'b1;
        cet_n = 1'b0;
        expected_count = expected_count - 8'd1;
        clock_rise();
        check_count(expected_count);
        expected_count = 8'h00;
        s1 = 1'b0;
        s0 = 1'b0;
        oe_n = 1'b1;
        external_io_drive = 8'hFF;
        external_io_data = expected_count;
        clock_rise();
        check_count(expected_count);
        s1 = 1'b0;
        s0 = 1'b1;
        expected_count = 8'hFF;
        clock_rise();
        check_count(expected_count);

        // Up/down terminal output is active low while enabled, high while held.
        s1 = 1'b1;
        s0 = 1'b0;
        cet_n = 1'b0;
        external_io_data = 8'hFF;
        #1;
        if (io_data !== 8'hFF || tc_n !== 1'b0)
            $fatal(1, "up terminal count must assert TC low");
        clock_rise();
        check_count(8'h00);
        if (tc_n !== 1'b1) $fatal(1, "TC must deassert after up wrap");

        s1 = 1'b0;
        s0 = 1'b1;
        external_io_data = 8'h00;
        #1;
        if (io_data !== 8'h00 || tc_n !== 1'b0)
            $fatal(1, "down terminal count must assert TC low");
        cet_n = 1'b1;
        clock_rise();
        check_count(8'h00);
        if (tc_n !== 1'b1) $fatal(1, "TC must stay high while counting is disabled");

        // S1:S0=11 is absent from the table; the specified model assumption is hold.
        s1 = 1'b1;
        s0 = 1'b1;
        cet_n = 1'b0;
        clock_rise();
        check_count(8'h00);
        if (tc_n !== 1'b1) $fatal(1, "unlisted 11 mode assumption");

        $display("PASS: tb_ttl_74x779");
        $finish;
    end
endmodule
