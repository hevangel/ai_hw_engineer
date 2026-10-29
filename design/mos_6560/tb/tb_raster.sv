`timescale 1ns/1ps
module tb_raster;
    logic clk = 0, rst_n = 0, ce_i = 0, interlace_i = 0;
    logic phi2_i = 0, rw_i = 1;
    logic [13:0] addr_i = 0;
    logic [7:0] data_i = 0;
    logic [63:0] pal_state_o, ntsc_state_o;
    logic [63:0] expected_pal, expected_ntsc;
    int source_file, fields_read, expected_records, checks = 0;
    string vector_path, trailing_token;
    raster_pair dut (.*);

    initial begin
        if (!$value$plusargs("vectors=%s", vector_path)) $fatal(1, "missing vectors");
        if (!$value$plusargs("records=%d", expected_records) || expected_records <= 0)
            $fatal(1, "missing reference record count");
        source_file = $fopen(vector_path, "r");
        if (source_file == 0) $fatal(1, "cannot open vectors");
        #1; clk = 1; #1; clk = 0;
        repeat (expected_records) begin
            fields_read = $fscanf(source_file, "%h %h %h %h %h %h %h %h %h\n",
                rst_n, ce_i, interlace_i, phi2_i, rw_i, addr_i, data_i,
                expected_pal, expected_ntsc);
            if (fields_read != 9) $fatal(1, "malformed vector record");
            #1;
            if (pal_state_o !== expected_pal || ntsc_state_o !== expected_ntsc)
                $fatal(1, "record %0d PAL=%h/%h NTSC=%h/%h", checks,
                       pal_state_o, expected_pal, ntsc_state_o, expected_ntsc);
            checks++;
            clk = 1; #1; clk = 0; #1;
        end
        // Check exact count and reject trailing data without depending on
        // when each simulator sets feof after consuming the final newline.
        fields_read = $fscanf(source_file, "%s", trailing_token);
        if (fields_read > 0)
            $fatal(1, "unexpected trailing vector data after %0d records: '%s'",
                   checks, trailing_token);
        $fclose(source_file);
        $display("MOS 6560 RASTER REPLAY PASS: %0d records, %0d profile comparisons", checks, 2*checks);
        $finish;
    end
endmodule
