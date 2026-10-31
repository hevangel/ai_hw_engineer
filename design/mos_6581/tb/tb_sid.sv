`timescale 1ns/1ps
// Replays oracle-checked SID clock records in either SV simulator. Each
// record supplies the CPU/POT inputs and the pull-down table answers the
// C++ harness gave for that clock.
module tb_sid #(parameter bit MOS8580 = 1'b0);
    logic clk = 0, rst_n = 0, ce_i = 0, cs_i = 0, rw_i = 1;
    logic [4:0] addr_i = 0;
    logic [7:0] data_i = 0, pot_x_i = 0, pot_y_i = 0, data_o;
    logic [2:0][11:0] pd_value_i = '0, pd_index_o, wave_o;
    logic [2:0][2:0] pd_sel_o;
    logic [2:0][7:0] env_o;
    logic [11:0] osc3_pd_value_i = 0, osc3_pd_index_o;
    logic [10:0] fc_o;
    logic [7:0] res_filt_o, mode_vol_o;
    logic [7:0] want_data;
    logic [23:0] want_env;
    logic [35:0] want_wave, want_index;
    logic [8:0] want_sel;
    logic [11:0] want_osc3_index;
    int source_file, fields_read, expected_records, checks = 0;
    string vector_path, trailing_token;
    mos_6581 #(.MOS8580(MOS8580)) dut (.*);
    // Filter registers are checked by the C++ register tests only.
    logic unused_filter;
    assign unused_filter = ^{fc_o, res_filt_o, mode_vol_o};

    initial begin
        if (!$value$plusargs("vectors=%s", vector_path)) $fatal(1, "missing vectors");
        if (!$value$plusargs("records=%d", expected_records) || expected_records <= 0)
            $fatal(1, "missing record count");
        source_file = $fopen(vector_path, "r");
        if (source_file == 0) $fatal(1, "cannot open vectors");
        repeat (expected_records) begin
            fields_read = $fscanf(source_file,
                "%h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h\n",
                rst_n, ce_i, cs_i, rw_i, addr_i, data_i, pot_x_i, pot_y_i, pd_value_i,
                osc3_pd_value_i, want_data, want_env, want_wave, want_index, want_sel,
                want_osc3_index);
            if (fields_read != 16) $fatal(1, "malformed vector record");
            #1;
            if (rst_n && (data_o !== want_data || env_o !== want_env || wave_o !== want_wave ||
                          pd_index_o !== want_index || pd_sel_o !== want_sel ||
                          osc3_pd_index_o !== want_osc3_index))
                $fatal(1, "record %0d data %h/%h env %h/%h wave %h/%h index %h/%h sel %h/%h",
                       checks, data_o, want_data, env_o, want_env, wave_o, want_wave,
                       pd_index_o, want_index, pd_sel_o, want_sel);
            checks++;
            clk = 1; #1; clk = 0; #1;
        end
        fields_read = $fscanf(source_file, "%s", trailing_token);
        if (fields_read > 0)
            $fatal(1, "unexpected trailing vector data after %0d records: '%s'", checks,
                   trailing_token);
        $fclose(source_file);
        $display("MOS 6581 SID REPLAY PASS: %0d clock records", checks);
        $finish;
    end
endmodule
