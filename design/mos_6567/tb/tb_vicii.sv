`timescale 1ns/1ps
// Replays oracle-checked VIC-II dot records in either SV simulator.
module tb_vicii #(parameter int VARIANT = 0);
    logic clk = 0, rst_n = 0, cs_i = 0, rw_i = 1, lp_n_i = 1, rom_window_i = 1;
    logic [5:0] addr_i = 0;
    logic [7:0] data_i = 0, phi1_data_i = 0, phi2_data_i = 0;
    logic [3:0] color_data_i = 0;
    logic [7:0] data_o, last_data;
    logic irq_n_o, ba_o, aec_o, cycle_edge_o, phi2_fetch_o, color_fetch_o, pixel_valid_o;
    logic [13:0] phi1_addr_o, phi2_addr_o;
    logic [9:0] color_addr_o, pixel_col_o;
    logic [3:0] pixel_o, dot;
    logic [8:0] pixel_row_o, rasterline;
    logic [6:0] cycle;
    logic [34:0] got_a, want_a;
    logic [40:0] got_b, want_b;
    int source_file, fields_read, expected_records, checks = 0;
    string vector_path, trailing_token;
    mos_6567 #(.VARIANT(VARIANT)) dut (
        .clk, .rst_n, .cs_i, .rw_i, .addr_i, .data_i, .data_o, .irq_n_o, .ba_o, .aec_o,
        .lp_n_i, .rom_window_i, .cycle_edge_o, .phi1_addr_o, .phi1_data_i, .phi2_fetch_o,
        .phi2_addr_o, .phi2_data_i, .color_fetch_o, .color_addr_o, .color_data_i,
        .pixel_valid_o, .pixel_o, .pixel_row_o, .pixel_col_o, .cycle_o(cycle),
        .rasterline_o(rasterline), .dot_o(dot), .last_data_o(last_data)
    );
    assign got_a = {pixel_valid_o, pixel_o, pixel_row_o, pixel_col_o, data_o, irq_n_o, ba_o, aec_o};
    assign got_b = {cycle_edge_o, phi1_addr_o, phi2_fetch_o, phi2_addr_o, color_fetch_o,
                    color_addr_o};
    // Status outputs are covered by the C++ comparison only.
    logic unused_status;
    assign unused_status = ^{cycle, rasterline, dot, last_data};

    initial begin
        if (!$value$plusargs("vectors=%s", vector_path)) $fatal(1, "missing vectors");
        if (!$value$plusargs("records=%d", expected_records) || expected_records <= 0)
            $fatal(1, "missing record count");
        source_file = $fopen(vector_path, "r");
        if (source_file == 0) $fatal(1, "cannot open vectors");
        repeat (expected_records) begin
            fields_read = $fscanf(source_file, "%h %h %h %h %h %h %h %h %h %h %h %h\n",
                rst_n, cs_i, rw_i, addr_i, data_i, lp_n_i, rom_window_i,
                phi1_data_i, phi2_data_i, color_data_i, want_a, want_b);
            if (fields_read != 12) $fatal(1, "malformed vector record");
            #1;
            // Outputs before reset release are not part of the contract.
            if (rst_n && (got_a !== want_a || got_b !== want_b))
                $fatal(1, "record %0d A=%h/%h B=%h/%h", checks, got_a, want_a, got_b, want_b);
            checks++;
            clk = 1; #1; clk = 0; #1;
        end
        fields_read = $fscanf(source_file, "%s", trailing_token);
        if (fields_read > 0)
            $fatal(1, "unexpected trailing vector data after %0d records: '%s'", checks,
                   trailing_token);
        $fclose(source_file);
        $display("MOS 6567 VIC-II REPLAY PASS: variant %0d, %0d dot records", VARIANT, checks);
        $finish;
    end
endmodule
