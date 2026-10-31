`timescale 1ns/1ps
module tb_ttl_74x2010;
    localparam int LANES = 10;
    logic [2*LANES-1:0] external_data, external_drive;
    logic [2*LANES-1:0] resolved, valid, conflict, weak_drive;
    logic [31:0] rng;

    ttl_74x2010 dut (.*);

    task automatic check_all;
        logic expected_conflict;
        logic expected_valid;
        logic expected_value;
        for (int channel = 0; channel < LANES; channel++) begin
            expected_conflict = external_drive[channel] &&
                                external_drive[channel + LANES] &&
                                (external_data[channel] != external_data[channel + LANES]);
            expected_valid = (external_drive[channel] || external_drive[channel + LANES]) &&
                             !expected_conflict;
            expected_value = expected_valid &&
                             (external_drive[channel] ? external_data[channel] :
                                                        external_data[channel + LANES]);
            if (conflict[channel] !== expected_conflict ||
                conflict[channel + LANES] !== expected_conflict ||
                valid[channel] !== expected_valid ||
                valid[channel + LANES] !== expected_valid ||
                resolved[channel] !== expected_value ||
                resolved[channel + LANES] !== expected_value ||
                weak_drive[channel] !== 1'b0 ||
                weak_drive[channel + LANES] !== 1'b0)
                $fatal(1, "resolution mismatch on channel %0d", channel);
        end
    endtask

    initial begin
        int pair_code;
        int state_s;
        int state_d;
        external_data = '0;
        external_drive = '0;
        rng = 32'h6e21_73b5;

        // Exercise all 3x3 pairs of external states on every independent lane:
        // float, driven low, and driven high on each side.
        for (int code = 0; code < 9; code++) begin
            external_data = '0;
            external_drive = '0;
            for (int channel = 0; channel < LANES; channel++) begin
                pair_code = (code + 4*channel) % 9;
                state_s = pair_code / 3;
                state_d = pair_code % 3;
                external_drive[channel] = (state_s != 0);
                external_data[channel] = (state_s == 2);
                external_drive[channel + LANES] = (state_d != 0);
                external_data[channel + LANES] = (state_d == 2);
            end
            #1;
            check_all();
        end

        // Deterministic mixed-channel stress, including unrelated simultaneous
        // sources and opposite-value contention on any subset of channels.
        for (int pattern = 0; pattern < 128; pattern++) begin
            for (int pin_index = 0; pin_index < 2*LANES; pin_index++) begin
                rng = (rng << 1) ^ (rng[31] ? 32'h04c1_1db7 : 32'h0);
                external_data[pin_index] = rng[0];
                rng = (rng << 1) ^ (rng[31] ? 32'h04c1_1db7 : 32'h0);
                external_drive[pin_index] = rng[1];
            end
            #1;
            check_all();
        end

        $display("PASS: tb_ttl_74x2010");
        $finish;
    end
endmodule
