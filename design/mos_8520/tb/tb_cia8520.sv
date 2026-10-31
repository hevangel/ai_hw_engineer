`timescale 1ns/1ps
// Replays mos_8520 cycle records from tb/cia8520_compare.cpp in either SV
// simulator: read data during phase two and /IRQ after the cycle.
module tb_cia8520;
    logic clk = 0, rst_n = 0, cs = 0, rw = 1, tod_i = 0;
    logic [3:0] addr = 0;
    logic [7:0] data_i = 0, pa_i = 8'hff, pb_i = 8'hff, data_o;
    logic data_oe, cnt_o, cnt_oe, sp_o, sp_oe, pc_n, irq_n;
    logic [7:0] pa_o, pb_o, pa_oe, pb_oe;
    logic [7:0] want_data;
    logic want_irq;
    int source_file, fields_read, expected_records, checks = 0;
    string vector_path, trailing_token;
    mos_8520 dut (
        .clk, .rst_n, .cs_n(!cs), .rw, .addr, .data_i, .data_o, .data_oe,
        .pa_i, .pb_i, .pa_o, .pb_o, .pa_oe, .pb_oe,
        .cnt_i(1'b1), .sp_i(1'b1), .flag_n_i(1'b1), .tod_i,
        .cnt_o, .cnt_oe, .sp_o, .sp_oe, .pc_n, .irq_n
    );
    // Port, serial and handshake outputs are covered by the C++ comparison.
    logic unused_outputs;
    assign unused_outputs = ^{data_oe, cnt_o, cnt_oe, sp_o, sp_oe, pc_n, pa_o, pb_o, pa_oe, pb_oe};

    initial begin
        if (!$value$plusargs("vectors=%s", vector_path)) $fatal(1, "missing vectors");
        if (!$value$plusargs("records=%d", expected_records) || expected_records <= 0)
            $fatal(1, "missing record count");
        source_file = $fopen(vector_path, "r");
        if (source_file == 0) $fatal(1, "cannot open vectors");
        repeat (4) begin clk = 1; #1; clk = 0; #1; end
        rst_n = 1;
        repeat (expected_records) begin
            fields_read = $fscanf(source_file, "%h %h %h %h %h %h %h %h %h\n",
                cs, rw, addr, data_i, pa_i, pb_i, tod_i, want_data, want_irq);
            if (fields_read != 9) $fatal(1, "malformed vector record");
            #1;
            clk = 1; #1;
            if (cs && rw && data_o !== want_data)
                $fatal(1, "record %0d read %h/%h", checks, data_o, want_data);
            clk = 0; #1;
            if (irq_n !== want_irq)
                $fatal(1, "record %0d irq_n %b/%b", checks, irq_n, want_irq);
            checks++;
        end
        fields_read = $fscanf(source_file, "%s", trailing_token);
        if (fields_read > 0)
            $fatal(1, "unexpected trailing vector data after %0d records: '%s'", checks,
                   trailing_token);
        $fclose(source_file);
        $display("MOS 8520 REPLAY PASS: %0d cycle records", checks);
        $finish;
    end
endmodule
