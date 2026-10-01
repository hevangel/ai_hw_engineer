// Mixed-signal boundary for the three analog IC packages. See spec/analog.md.
`timescale 1ns/1ps
module apple_ii_rev0_peripherals #(
    parameter int PADDLE_STEP_NS=100,
    parameter int FLASH_STEP_NS=10000,
    parameter real FLASH_R12=12000.0, FLASH_R13=3300000.0,
    parameter real FLASH_CAP15=1.0e-7,
    parameter real PADDLE_SERIES_R=100.0, PADDLE_CAP=22.0e-9
) (
    input logic paddle_trigger_n,
    input real paddle0_ohms, paddle1_ohms, paddle2_ohms, paddle3_ohms,
    input real cassette_voltage,
    output tri flash,
    output logic [3:0] paddle_timer,
    output logic cassette_in,
    output real cassette_amplifier_voltage
);
    real flash_cap_voltage;
    tri discharge;
    real flash_seconds, resistance;
    a2_ne555 B3(.p1(0.0),.p2(flash_cap_voltage),.p3(flash),.p4(5.0),
        .p5(-1.0),.p6(flash_cap_voltage),.p7(discharge),.p8(5.0));
    // ASSUMPTION: ideal RC networks, discharged capacitors, and ideal sink.
    // R12/R13/Cap15 connections are recorded in rev0_connectivity.json.
    initial begin
        if(FLASH_STEP_NS<=0 || FLASH_R12<=0 || FLASH_R13<=0 || FLASH_CAP15<=0)
            $fatal(1,"Invalid flash RC parameters");
        flash_cap_voltage=0.0;
        flash_seconds=FLASH_STEP_NS*1.0e-9;
        forever begin
            #(FLASH_STEP_NS);
            if(discharge===1'b0)
                flash_cap_voltage=flash_cap_voltage*$exp(-flash_seconds/(FLASH_R13*FLASH_CAP15));
            else
                flash_cap_voltage=5.0+(flash_cap_voltage-5.0)*$exp(-flash_seconds/((FLASH_R12+FLASH_R13)*FLASH_CAP15));
        end
    end
    real timing_a, timing_b, timing_c, timing_d;
    real paddle_seconds;
    tri out_a, out_b, out_c, out_d;
    logic [3:0] timing_sink;
    a2_ne558 H13(.p1(out_a),.p2(timing_a),.p3(paddle_trigger_n),.p4(-1.0),.p5(5.0),
        .p6(paddle_trigger_n),.p7(timing_b),.p8(out_b),.p9(out_c),.p10(timing_c),
        .p11(paddle_trigger_n),.p12(0.0),.p13(1'b1),.p14(paddle_trigger_n),.p15(timing_d),
        .p16(out_d),.timing_sink(timing_sink));
    // ASSUMPTION: choose inactive timer latches at power-up; no reset signal
    // is added to the motherboard's permanently high H13 pin 13.
    initial begin H13.active=0; H13.previous_trigger=0; end
    // The original board relies on TTL input bias when the open collectors
    // release. Make that assumption explicit at this electrical boundary.
    always_comb begin
        paddle_timer[0]=(out_a===1'bz) ? 1'b1 : out_a;
        paddle_timer[1]=(out_d===1'bz) ? 1'b1 : out_d;
        paddle_timer[2]=(out_c===1'bz) ? 1'b1 : out_c;
        paddle_timer[3]=(out_b===1'bz) ? 1'b1 : out_b;
    end
    function automatic real charge(input real voltage,input real external_r);
        return 5.0+(voltage-5.0)*$exp(-paddle_seconds/((external_r+PADDLE_SERIES_R)*PADDLE_CAP));
    endfunction
    initial begin
        if(PADDLE_STEP_NS<=0 || PADDLE_SERIES_R<=0 || PADDLE_CAP<=0)
            $fatal(1,"Invalid paddle RC parameters");
        timing_a=0.0; timing_b=0.0; timing_c=0.0; timing_d=0.0;
        paddle_seconds=PADDLE_STEP_NS*1.0e-9;
        forever begin
            #(PADDLE_STEP_NS);
            if(paddle0_ohms<0 || paddle1_ohms<0 || paddle2_ohms<0 || paddle3_ohms<0)
                $fatal(1,"Negative paddle resistance");
            timing_a=timing_sink[0] ? 0.0 : charge(timing_a,paddle0_ohms);
            timing_b=timing_sink[1] ? 0.0 : charge(timing_b,paddle3_ohms);
            timing_c=timing_sink[2] ? 0.0 : charge(timing_c,paddle2_ohms);
            timing_d=timing_sink[3] ? 0.0 : charge(timing_d,paddle1_ohms);
        end
    end
    wire real amplifier;
    real ac_input, previous_cassette, comparator_input;
    // Cap10/R17 form an AC input coupling network; R15/R16 provide positive
    // feedback. This reduced network assumes zero op-amp input current.
    // ASSUMPTION: cassette_voltage is the voltage at Cap10's input side;
    // the jack attenuator/connector and capacitor parasitics are not modeled.
    initial begin
        ac_input=0.0; previous_cassette=0.0;
        forever begin
            #100;
            ac_input=(ac_input+cassette_voltage-previous_cassette)*$exp(-1.0e-7/(12000.0*1.0e-7));
            previous_cassette=cassette_voltage;
        end
    end
    always_comb comparator_input=amplifier*(12000.0/(220000.0+12000.0));
    a2_lm741 K13(.p1(0.0),.p2(ac_input),.p3(comparator_input),.p4(-5.0),
        .p5(0.0),.p6(amplifier),.p7(5.0),.p8(0.0));
    assign cassette_amplifier_voltage=amplifier;
    // R29 isolates the TTL input. Output loading is not modeled; threshold
    // uses explicit TTL bounds and preserves state in the ambiguous interval.
    always_latch begin
        if(amplifier>=2.0) cassette_in=1;
        else if(amplifier<=0.8) cassette_in=0;
    end
endmodule
