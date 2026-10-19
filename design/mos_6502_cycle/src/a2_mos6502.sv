// Physical-pin authored NMOS socket model. Initialization assumptions: spec/spec.md.
`timescale 1ns/1ps
module a2_mos6502 (
    input tri p1,p2, output tri p3, input tri p4,p5,p6, output tri p7,
    input tri p8,
    output tri p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,
    input tri p21, output tri p22,p23,p24,p25,
    inout tri p26,p27,p28,p29,p30,p31,p32,p33,
    output tri p34, input tri p35,p36,p37,p38, output tri p39, input tri p40,
    output integer unknown_read_samples,
    output logic fault_o
);
    logic powered, initialization_n, write_cycle, sync;
    logic [15:0] address;
    logic [7:0] output_data,sampled_data;
    tri [7:0] data;
    // Simulation adapter startup is an explicit assumption, not chip RTL reset.
    /* verilator lint_off PROCASSINIT */
    logic [1:0] startup_count=0;
    assign powered=(p1===0 && p21===0 && p8===1);
    // ASSUMPTION: canonical internal model initialization for three clocks;
    // this is not a motherboard power-on-reset wire. p40 remains warm RES.
    always_ff @(negedge p37) begin
        if(!powered) startup_count<=0;
        else if(startup_count!=3) startup_count<=startup_count+2'd1;
    end
    /* verilator lint_on PROCASSINIT */
    assign initialization_n=powered && startup_count==3;
    assign data={p26,p27,p28,p29,p30,p31,p32,p33};
    assign {p26,p27,p28,p29,p30,p31,p32,p33}=
        powered && write_cycle ? output_data : 8'bz;
    // ASSUMPTION: unresolved input bits sample high at the ideal digital
    // socket boundary, consistently with the external reference comparison.
    always_comb begin
        for(int i=0;i<8;i++) sampled_data[i]=(data[i]!==1'b0);
    end
    always_ff @(negedge p37) begin
        if(!initialization_n) unknown_read_samples<=0;
        else if(p40 && !write_cycle && $isunknown(data))
            unknown_read_samples<=unknown_read_samples+1;
    end
    mos_6502_cycle core(.clk(~p37),.rst_n(initialization_n),.res_n(p40),
        .irq_n(p4),.nmi_n(p6),.rdy(p2),.so_n(p38),
        .bus_addr(address),.bus_data_i(sampled_data),.bus_data_o(output_data),
        .bus_we(write_cycle),.fetch_o(sync),.fault_o(fault_o),
        .pc_o(),.status_o(),.a_o(),.x_o(),.y_o(),.sp_o());
    assign {p25,p24,p23,p22,p20,p19,p18,p17,p16,p15,p14,p13,p12,p11,p10,p9}=
        powered ? address : 16'bx;
    assign p34=powered ? !write_cycle : 1'bx;
    assign p7=powered ? sync : 1'bx;
    // ASSUMPTION: ideal complementary clock-output levels; analog clock
    // delays/non-overlap are outside the synchronous core contract.
    assign p3=powered ? ~p37 : 1'bx;
    assign p39=powered ? p37 : 1'bx;
    // NC pins are electrically unused in the physical package.
endmodule
