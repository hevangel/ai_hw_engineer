// Revision-0 J13 pin 8 -> R19 -> J2 tip, with R18 from tip to ground.
`timescale 1ns/1ps
module apple_ii_cassette_output #(
    parameter real R18_OHMS=100.0, R19_OHMS=12000.0,
    parameter real V_LOW=0.2, V_HIGH=4.0
) (
    input tri drive_level,
    input real load_ohms,
    output real jack_voltage,
    output logic voltage_valid
);
    real shunt, voltage;
    assign jack_voltage=voltage;
    // ASSUMPTION: ideal configurable TTL levels, zero source impedance,
    // purely resistive recorder load, and no cable capacitance. See spec/analog.md.
    initial begin
        if(R18_OHMS<=0 || R19_OHMS<=0 || V_HIGH<=V_LOW)
            $fatal(1,"Invalid cassette output divider parameters");
    end
    always_comb begin
        shunt=R18_OHMS;
        if(load_ohms>0.0) shunt=1.0/(1.0/R18_OHMS+1.0/load_ohms);
        voltage_valid=(load_ohms>=0.0 && !$isunknown(drive_level));
        voltage=0.0;
        if(voltage_valid)
            voltage=(drive_level ? V_HIGH : V_LOW)*shunt/(R19_OHMS+shunt);
    end
endmodule
