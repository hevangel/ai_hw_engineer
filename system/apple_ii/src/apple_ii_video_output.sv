// Physical Q3/R5-R11/L1/Cap2/CT3 network. See spec/analog.md.
`timescale 1ns/1ps
module apple_ii_video_output #(
    parameter bit ENABLED=1,
    parameter real STEP_NS=2.0, V_LOW=0.2, V_HIGH=3.5, VCC=5.0,
    parameter real R5=1000.0, R6=2700.0, R7=1500.0, R8=2000.0,
    parameter real R9=10.0, R10=27.0, R11=200.0,
    parameter real L1=27e-6, CAP2=47e-12, CT3=26.216e-12, COIL_R=10.0,
    parameter real BETA=100.0, VBE=0.6, VCE_SAT=0.2,
    parameter real POT_POSITION=1.0, LOAD_OHMS=75.0
) (
    input logic initialize, // Simulator initial-condition control, not a board wire.
    input tri video_data, composite_sync, color_burst,
    output real jack_voltage, emitter_voltage, tank_voltage,
    output logic voltage_valid
);
    real tank=0.0, coil_current=0.0, jack=0.0, emitter=0.0;
    real dt, cap, bottom, equivalent, gain, base_g, sum_g;
    real source, vd, vs, conductance, forcing, a,b,c,d,r1,r2;
    real candidate, next_current, base_voltage, collector, ie;
    bit initialized=0, uncertain=0, conducting;
    assign jack_voltage=jack;
    assign emitter_voltage=emitter;
    assign tank_voltage=voltage_valid ? tank : 0.0;
    // ASSUMPTION: zero initial stored energy, fixed Vbe/beta transistor,
    // ideal TTL sources and configurable coil loss. See the assumption ledger.
    initial begin
        if(STEP_NS<=0 || L1<=0 || CAP2<=0 || CT3<5e-12 || CT3>50e-12 ||
           COIL_R<0 || BETA<=0 || R5<=0 || R6<=0 || R7<=0 || R8<=0 ||
           R9<=0 || R10<=0 || R11<=0 || LOAD_OHMS<0 ||
           POT_POSITION<0 || POT_POSITION>1 || V_HIGH<=V_LOW || VCC<=VBE)
            $fatal(1,"Invalid Q3 network parameters");
        dt=STEP_NS*1e-9; cap=CAP2+CT3;
        bottom=R11*POT_POSITION;
        if(LOAD_OHMS>0 && bottom>0) bottom=1.0/(1.0/(R10+LOAD_OHMS)+1.0/bottom);
        equivalent=R11*(1.0-POT_POSITION)+bottom;
        gain=bottom/equivalent;
        if(LOAD_OHMS>0) gain= gain*LOAD_OHMS/(R10+LOAD_OHMS);
        voltage_valid=0;
        if(ENABLED) forever begin
            #(STEP_NS);
            if(initialize===1'b1) begin
                uncertain=0; initialized=0; voltage_valid=0;
                tank=0; coil_current=0; jack=0; emitter=0;
            end else begin
            if(initialized && ($isunknown(video_data) || $isunknown(composite_sync) ||
                $isunknown(color_burst))) uncertain=1;
            voltage_valid=!uncertain && !$isunknown(video_data) &&
                !$isunknown(composite_sync) && !$isunknown(color_burst);
            if(voltage_valid) begin
                source=color_burst ? V_HIGH : V_LOW;
                vd=video_data ? V_HIGH : V_LOW;
                vs=composite_sync ? V_HIGH : V_LOW;
                conducting=initialized ? emitter>0.0 : 1;
                // Iterate the piecewise base-current branch. The tank is
                // advanced once; every trial uses the same previous state.
                for(integer trial=0;trial<3;trial=trial+1) begin
                    base_g=conducting ? 1.0/(equivalent*(BETA+1.0)) : 0.0;
                    sum_g=1.0/R6+1.0/R7+1.0/R8+base_g;
                    forcing=source/R5+(vd/R7+vs/R8+VBE*base_g)/(R6*sum_g);
                    conductance=1.0/R5+(1.0-1.0/(R6*sum_g))/R6;
                    a=cap/dt+conductance/2.0; b=0.5; c=-0.5;
                    d=L1/dt+COIL_R/2.0;
                    r1=(cap/dt-conductance/2.0)*tank-coil_current/2.0+forcing;
                    r2=tank/2.0+(L1/dt-COIL_R/2.0)*coil_current;
                    candidate=(r1*d-b*r2)/(a*d-b*c);
                    next_current=(a*r2-c*r1)/(a*d-b*c);
                    base_voltage=(candidate/R6+vd/R7+vs/R8+VBE*base_g)/sum_g;
                    conducting=base_voltage>VBE;
                end
                tank=candidate; coil_current=next_current;
                emitter=base_voltage>VBE ? base_voltage-VBE : 0.0;
                ie=emitter/equivalent;
                collector=VCC-ie*BETA/(BETA+1.0)*R9;
                if(emitter>collector-VCE_SAT) emitter=collector-VCE_SAT;
                if(emitter<0) emitter=0.0;
                jack=emitter*gain; initialized=1;
            end else begin
                jack=0.0; emitter=0.0;
            end
            end
        end
    end
endmodule
