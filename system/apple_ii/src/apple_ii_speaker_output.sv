// Physical J13/Cap11/R24/CR1/Q4/R25/Cap12/SPKR1 network.
`timescale 1ns/1ps
module apple_ii_speaker_output #(
    parameter bit ENABLED=1,
    parameter real STEP_NS=100.0, V_LOW=0.2, V_HIGH=3.5, VCC=5.0,
    parameter real CAP11=100e-9, R24=47000.0, R25=27.0, CAP12=100e-9,
    parameter real BETA=5000.0, VBE=1.2, VCE_SAT=0.8, DIODE_DROP=0.65,
    parameter real SPEAKER_R=8.0, SPEAKER_L=200e-6
) (
    input logic initialize, // Simulator initial-condition control, not a board wire.
    input tri speaker_level,
    output real speaker_voltage, speaker_current, collector_voltage,
    output logic voltage_valid
);
    real coupled=0.0, node=VCC, current=0.0, previous_drive=0.0;
    real dt, drive, requested, g, offset, a,b,c,d,r1,r2;
    real candidate, next_current, collector, volts;
    bit initialized=0, uncertain=0, saturated;
    assign speaker_voltage=volts;
    assign speaker_current=voltage_valid ? current : 0.0;
    assign collector_voltage=collector;
    // ASSUMPTION: initially unenergized RL load; reduced constant-drop
    // Darlington/diode, and configurable speaker inductance. See spec/analog.md.
    initial begin
        if(STEP_NS<=0 || CAP11<=0 || CAP12<=0 || R24<=0 || R25<=0 ||
           SPEAKER_R<=0 || SPEAKER_L<=0 || BETA<=0 || V_HIGH<=V_LOW ||
           VBE<=0 || DIODE_DROP<=0 || VCE_SAT<0 || VCC<=VCE_SAT)
            $fatal(1,"Invalid Q4 network parameters");
        dt=STEP_NS*1e-9; volts=0.0; collector=VCC; voltage_valid=0;
        if(ENABLED) forever begin
            #(STEP_NS);
            if(initialize===1'b1) begin
                uncertain=0; initialized=0; voltage_valid=0;
                coupled=0; node=VCC; current=0; volts=0; collector=VCC;
            end else begin
            if(initialized && $isunknown(speaker_level)) uncertain=1;
            voltage_valid=!uncertain && !$isunknown(speaker_level);
            if(voltage_valid) begin
                drive=speaker_level ? V_HIGH : V_LOW;
                if(initialized) coupled=coupled+drive-previous_drive;
                previous_drive=drive; initialized=1;
                if(coupled>VBE) coupled=VBE+(coupled-VBE)*$exp(-dt/(R24*CAP11));
                else if(coupled < -DIODE_DROP)
                    coupled=-DIODE_DROP+(coupled+DIODE_DROP)*$exp(-dt/(R24*CAP11));
                requested=coupled>VBE ? BETA*(coupled-VBE)/R24 : 0.0;
                saturated=requested>(node-VCE_SAT)/R25 && requested>0;
                for(integer trial=0;trial<3;trial=trial+1) begin
                    g=saturated ? 1.0/R25 : 0.0;
                    offset=saturated ? -VCE_SAT/R25 : requested;
                    a=CAP12/dt+g/2.0; b=-0.5; c=0.5;
                    d=SPEAKER_L/dt+SPEAKER_R/2.0;
                    r1=(CAP12/dt-g/2.0)*node+current/2.0-offset;
                    r2=VCC-node/2.0+(SPEAKER_L/dt-SPEAKER_R/2.0)*current;
                    candidate=(r1*d-b*r2)/(a*d-b*c);
                    next_current=(a*r2-c*r1)/(a*d-b*c);
                    saturated=requested>(candidate-VCE_SAT)/R25 && requested>0;
                end
                node=candidate; current=next_current;
                collector=node-R25*(saturated ? (node-VCE_SAT)/R25 : requested);
                volts=VCC-node;
            end else begin
                volts=0.0; collector=0.0;
            end
            end
        end
    end
endmodule
