// ASSUMPTION: external_drive denotes strong drivers; clamp voltages are omitted.
module ttl_74x1073 (
    input logic [15:0] external_data,external_drive,
    output logic [15:0] resolved,weak_drive
);
    logic [15:0] held;
    for(genvar i=0;i<16;i++) begin : g_keeper
        always_latch if(external_drive[i]) held[i]=external_data[i];
        assign resolved[i]=external_drive[i]?external_data[i]:held[i];
    end
    assign weak_drive=~external_drive;
endmodule
