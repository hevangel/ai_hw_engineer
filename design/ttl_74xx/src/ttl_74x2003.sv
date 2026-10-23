`timescale 1ns/1ps
// TI SN74GTL2003: eight independent bidirectional NMOS pass-transistor pairs.
// ASSUMPTION: the analog GREF/DREF/SREF bias is valid and settled; see the part spec.
module ttl_74x2003 (
    input  logic [15:0] external_data,
    input  logic [15:0] external_drive,
    output logic [15:0] resolved,
    output logic [15:0] valid,
    output logic [15:0] conflict,
    output logic [15:0] weak_drive
);
    // Flat ordering is S1..S8 at [7:0], then D1..D8 at [15:8].
    for (genvar channel = 0; channel < 8; channel++) begin : g_channel
        logic pair_conflict;
        logic pair_valid;
        logic pair_value;

        always_comb begin
            pair_conflict = external_drive[channel] &&
                            external_drive[channel + 8] &&
                            (external_data[channel] != external_data[channel + 8]);
            pair_valid = (external_drive[channel] || external_drive[channel + 8]) &&
                         !pair_conflict;
            pair_value = external_drive[channel] ? external_data[channel] :
                                                   external_data[channel + 8];

            conflict[channel] = pair_conflict;
            conflict[channel + 8] = pair_conflict;
            valid[channel] = pair_valid;
            valid[channel + 8] = pair_valid;
            resolved[channel] = pair_valid && pair_value;
            resolved[channel + 8] = pair_valid && pair_value;
            // The IC has no internal channel pull-up or pull-down.
            weak_drive[channel] = 1'b0;
            weak_drive[channel + 8] = 1'b0;
        end
    end
endmodule
