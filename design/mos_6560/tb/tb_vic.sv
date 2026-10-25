`timescale 1ns/1ps
// Replays oracle-derived complete-VIC vectors in either SV simulator. Each
// record supplies the CPU/pen/POT inputs and the display-memory response
// that the C++ harness returned for the checked fetch address.
module tb_vic;
    logic clk = 0, rst_n = 0, ce_i = 0, phi2_i = 0, rw_i = 1, lightpen_n_i = 1;
    logic [13:0] addr_i = 0;
    logic [7:0] data_i = 0, pot_x_i = 0, pot_y_i = 0;
    logic [11:0] pal_fetch_data_i = 0, ntsc_fetch_data_i = 0;
    logic [13:0] pal_fetch_addr_o, ntsc_fetch_addr_o;
    logic [63:0] pal_state_o, ntsc_state_o;
    logic [63:0] expected_pal, expected_ntsc;
    int source_file, fields_read, expected_records, checks = 0;
    string vector_path, trailing_token;
    vic_pair dut (.*);

    initial begin
        if (!$value$plusargs("vectors=%s", vector_path)) $fatal(1, "missing vectors");
        if (!$value$plusargs("records=%d", expected_records) || expected_records <= 0)
            $fatal(1, "missing reference record count");
        source_file = $fopen(vector_path, "r");
        if (source_file == 0) $fatal(1, "cannot open vectors");
        #1; clk = 1; #1; clk = 0;
        repeat (expected_records) begin
            fields_read = $fscanf(source_file, "%h %h %h %h %h %h %h %h %h %h %h %h %h\n",
                rst_n, ce_i, phi2_i, rw_i, addr_i, data_i, lightpen_n_i,
                pot_x_i, pot_y_i, pal_fetch_data_i, ntsc_fetch_data_i,
                expected_pal, expected_ntsc);
            if (fields_read != 13) $fatal(1, "malformed vector record");
            #1;
            if (pal_state_o !== expected_pal || ntsc_state_o !== expected_ntsc)
                $fatal(1, "record %0d PAL=%h/%h NTSC=%h/%h", checks,
                       pal_state_o, expected_pal, ntsc_state_o, expected_ntsc);
            // The memory-facing address port must match the packed state.
            if (pal_fetch_addr_o !== expected_pal[15:2] ||
                ntsc_fetch_addr_o !== expected_ntsc[15:2])
                $fatal(1, "record %0d fetch address port mismatch", checks);
            checks++;
            clk = 1; #1; clk = 0; #1;
        end
        // Exact count; trailing data fails without relying on feof timing.
        fields_read = $fscanf(source_file, "%s", trailing_token);
        if (fields_read > 0)
            $fatal(1, "unexpected trailing vector data after %0d records: '%s'",
                   checks, trailing_token);
        $fclose(source_file);
        $display("MOS 6560 VIC REPLAY PASS: %0d records, %0d profile comparisons", checks, 2*checks);
        $finish;
    end
endmodule
