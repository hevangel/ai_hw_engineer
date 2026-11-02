// Write-data margin monitor for one 4116. Simulation-only; it observes the
// package pins and never drives them. The write edge is the later of CAS fall
// (early write, WE already low) and WE fall (read-modify-write, CAS already
// low), which is where the device latches DIN.
//
// T_DS/T_DH default to 0, so the monitor reports the measured margin without
// inventing a datasheet limit. Pass the published values once they are sourced.
`timescale 1ns/1ps
`default_nettype none
module dram_write_check #(parameter real T_DS = 0.0, parameter real T_DH = 0.0) (
    input tri ras_n, cas_n, we_n, din
);
    real last_change = 0.0;
    real last_edge = 0.0;
    real min_setup = 1.0e12;
    real min_hold = 1.0e12;
    integer edges = 0;
    integer setup_violations = 0;
    integer hold_violations = 0;
    logic sampled = 1'b0;
    logic pending = 1'b0;

    always @(din) begin
        last_change = $realtime;
        if (pending) begin
            if ($realtime - last_edge < min_hold) min_hold = $realtime - last_edge;
            if ($realtime - last_edge < T_DH) hold_violations = hold_violations + 1;
            pending = 1'b0;
        end
    end

    task automatic record_edge;
        real setup;
        setup = $realtime - last_change;
        if (setup < min_setup) min_setup = setup;
        if (setup < T_DS) setup_violations = setup_violations + 1;
        edges = edges + 1;
        sampled = din;
        last_edge = $realtime;
        pending = 1'b1;
    endtask

    // Early write: CAS falls with RAS low and WE already low.
    always @(negedge cas_n) if (!ras_n && !we_n) record_edge();
    // Late write: WE falls with RAS and CAS low.
    always @(negedge we_n) if (!ras_n && !cas_n) record_edge();
endmodule
`default_nettype wire
