// All 83 motherboard ICs, using the authored documented-instruction NMOS core.
// See spec/analog.md and board/DEPENDENCIES.md for fidelity and license limits.
`timescale 1ns/1ps
module apple_ii_rev0_authored #(
    parameter ROM_D0="", ROM_D8="", ROM_E0="", ROM_E8="", ROM_F0="", ROM_F8="", CHAR_ROM="",
    parameter real CASSETTE_LOAD_OHMS=0.0,
    parameter bit ENABLE_ANALOG_OUTPUTS=0,
    parameter real VIDEO_LOAD_OHMS=75.0, VIDEO_POT_POSITION=1.0,
    parameter real SPEAKER_R=8.0, SPEAKER_L=200e-6
) (
    input logic master_oscillator, reset_n,
    input logic analog_initialize, // Explicit simulator initial conditions only.
    input logic [6:0] keyboard_data,
    input logic keyboard_strobe,
    input logic [2:0] buttons,
    input real paddle0_ohms, paddle1_ohms, paddle2_ohms, paddle3_ohms,
    input real cassette_voltage,
    output tri [15:0] cpu_address,
    inout tri [7:0] cpu_data,
    output tri cpu_rw, cpu_sync, cpu_phi0,
    output tri video_data, composite_sync, speaker, cassette_out,
    output tri [3:0] annunciators,
    output integer unknown_read_samples,
    output real cassette_jack_voltage,
    output logic cassette_jack_valid,
    output real composite_voltage, speaker_voltage, speaker_current,
    output logic composite_voltage_valid, speaker_voltage_valid
);
    logic cpu_fault;
    tri phi1, phi2, irq_n, nmi_n, rdy, cpu_reset_n;
    tri flash, paddle_trigger_n, color_burst;
    logic [3:0] paddle_timer;
    logic cassette_in;
    wire real cassette_amplifier;
    apple_ii_video_output #(.ENABLED(ENABLE_ANALOG_OUTPUTS),
        .LOAD_OHMS(VIDEO_LOAD_OHMS),.POT_POSITION(VIDEO_POT_POSITION)) Q3_network (
        .initialize(analog_initialize),.video_data(video_data),.composite_sync(composite_sync),.color_burst(color_burst),
        .jack_voltage(composite_voltage),.emitter_voltage(),.tank_voltage(),
        .voltage_valid(composite_voltage_valid));
    apple_ii_speaker_output #(.ENABLED(ENABLE_ANALOG_OUTPUTS),
        .SPEAKER_R(SPEAKER_R),.SPEAKER_L(SPEAKER_L)) Q4_network (
        .initialize(analog_initialize),.speaker_level(speaker),.speaker_voltage(speaker_voltage),.speaker_current(speaker_current),
        .collector_voltage(),.voltage_valid(speaker_voltage_valid));
    apple_ii_cassette_output output_divider(.drive_level(cassette_out),
        .load_ohms(CASSETTE_LOAD_OHMS),.jack_voltage(cassette_jack_voltage),
        .voltage_valid(cassette_jack_valid));
    apple_ii_rev0_peripherals analog_support(.paddle_trigger_n(paddle_trigger_n),
        .paddle0_ohms(paddle0_ohms),.paddle1_ohms(paddle1_ohms),
        .paddle2_ohms(paddle2_ohms),.paddle3_ohms(paddle3_ohms),.cassette_voltage(cassette_voltage),
        .flash(flash),.paddle_timer(paddle_timer),.cassette_in(cassette_in),
        .cassette_amplifier_voltage(cassette_amplifier));
    a2_mos6502 H7 (
        .p1(1'b0),.p2(rdy),.p3(phi1),.p4(irq_n),.p5(1'bz),.p6(nmi_n),.p7(cpu_sync),.p8(1'b1),
        .p9(cpu_address[0]),.p10(cpu_address[1]),.p11(cpu_address[2]),.p12(cpu_address[3]),
        .p13(cpu_address[4]),.p14(cpu_address[5]),.p15(cpu_address[6]),.p16(cpu_address[7]),
        .p17(cpu_address[8]),.p18(cpu_address[9]),.p19(cpu_address[10]),.p20(cpu_address[11]),.p21(1'b0),
        .p22(cpu_address[12]),.p23(cpu_address[13]),.p24(cpu_address[14]),.p25(cpu_address[15]),
        .p26(cpu_data[7]),.p27(cpu_data[6]),.p28(cpu_data[5]),.p29(cpu_data[4]),
        .p30(cpu_data[3]),.p31(cpu_data[2]),.p32(cpu_data[1]),.p33(cpu_data[0]),
        .p34(cpu_rw),.p35(1'bz),.p36(1'bz),.p37(cpu_phi0),.p38(1'b0),.p39(phi2),.p40(cpu_reset_n),
        .unknown_read_samples(unknown_read_samples),.fault_o(cpu_fault));
    apple_ii_rev0_digital #(.ROM_D0(ROM_D0),.ROM_D8(ROM_D8),.ROM_E0(ROM_E0),
        .ROM_E8(ROM_E8),.ROM_F0(ROM_F0),.ROM_F8(ROM_F8),.CHAR_ROM(CHAR_ROM)) board (
        .master_oscillator(master_oscillator),.reset_n(reset_n),.keyboard_data(keyboard_data),
        .keyboard_strobe(keyboard_strobe),.flash(flash),.cassette_in(cassette_in),
        .paddle_timer(paddle_timer),.buttons(buttons),.cpu_address(cpu_address),.cpu_data(cpu_data),
        .cpu_rw(cpu_rw),.cpu_phi1(phi1),.cpu_phi2(phi2),.cpu_sync(cpu_sync),.cpu_phi0(cpu_phi0),
        .cpu_reset_n(cpu_reset_n),.cpu_irq_n(irq_n),.cpu_nmi_n(nmi_n),.cpu_rdy(rdy),
        .video_data(video_data),.composite_sync(composite_sync),.speaker(speaker),.cassette_out(cassette_out),
        .annunciators(annunciators),.paddle_trigger_n(paddle_trigger_n),.color_burst(color_burst));
    always_ff @(negedge cpu_phi0) begin
        if(reset_n && cpu_fault) $fatal(1,"Authored CPU unsupported opcode at %h",cpu_address);
    end
endmodule
