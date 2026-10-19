// Physical NMOS 6502 package, using the external transistor-level reference.
// See DEPENDENCIES.md. This is a simulation component, not synthesized RTL.
`timescale 1ns/1ps
module a2_mos6502_reference (
    input tri p1, p2,
    output tri p3,
    input tri p4, p5, p6,
    output tri p7,
    input tri p8,
    output tri p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20,
    input tri p21,
    output tri p22, p23, p24, p25,
    inout tri p26, p27, p28, p29, p30, p31, p32, p33,
    output tri p34,
    input tri p35, p36, p37, p38,
    output tri p39,
    input tri p40,
    output integer unknown_read_samples
);
    tri [15:0] address;
    logic powered;
    tri rw, sync, phi1, phi2;
    assign powered=(p1===0 && p21===0 && p8===1);
    reference_cpu_socket transistor_cpu(.phi0(p37),.reset_n(p40),.irq_n(p4),
        .nmi_n(p6),.rdy(p2),.address(address),
        .data({p26,p27,p28,p29,p30,p31,p32,p33}),
        .rw(rw),.sync(sync),.phi1(phi1),.phi2(phi2),.so(p38),
        .unknown_read_samples(unknown_read_samples));
    assign {p25,p24,p23,p22,p20,p19,p18,p17,p16,p15,p14,p13,p12,p11,p10,p9}=
        powered ? address : 16'bx;
    assign p34=powered ? rw : 1'bx;
    assign p7=powered ? sync : 1'bx;
    assign p3=powered ? phi1 : 1'bx;
    assign p39=powered ? phi2 : 1'bx;
endmodule
