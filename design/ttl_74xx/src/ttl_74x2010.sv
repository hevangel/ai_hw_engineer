`timescale 1ns/1ps
// TI GTL2010: ten independent bidirectional NMOS pass-transistor pairs.
// ASSUMPTION: the analog GREF/DREF/SREF bias is valid and settled; see the part spec.
module ttl_74x2010 (
    input  logic [19:0] external_data,
    input  logic [19:0] external_drive,
    output logic [19:0] resolved,
    output logic [19:0] valid,
    output logic [19:0] conflict,
    output logic [19:0] weak_drive
);
    // Flat ordering is S1..S10 at [9:0], then D1..D10 at [19:10].
    for (genvar channel = 0; channel < 10; channel++) begin : g_channel
        logic pair_conflict;
        logic pair_valid;
        logic pair_value;

        always_comb begin
            pair_conflict = external_drive[channel] &&
                            external_drive[channel + 10] &&
                            (external_data[channel] != external_data[channel + 10]);
            pair_valid = (external_drive[channel] || external_drive[channel + 10]) &&
                         !pair_conflict;
            pair_value = external_drive[channel] ? external_data[channel] :
                                                   external_data[channel + 10];

            conflict[channel] = pair_conflict;
            conflict[channel + 10] = pair_conflict;
            valid[channel] = pair_valid;
            valid[channel + 10] = pair_valid;
            resolved[channel] = pair_valid && pair_value;
            resolved[channel + 10] = pair_valid && pair_value;
            // The IC has no internal channel pull-up or pull-down.
            weak_drive[channel] = 1'b0;
            weak_drive[channel + 10] = 1'b0;
        end
    end
endmodule
