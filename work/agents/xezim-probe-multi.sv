`timescale 1ns/1ps
// Does calling several functions inside one expression change the result?
module probe_multi;
    logic [11:0] b;

    function automatic logic [11:0] whole(input logic [12:1] a); return a; endfunction
    function automatic logic        bit1 (input logic [12:1] a); return a[1]; endfunction
    function automatic logic        bit12(input logic [12:1] a); return a[12]; endfunction

    initial begin
        b = 12'b000000000001;   // expect bit1=1, bit12=0
        $display("separate statements:");
        $display("   whole=%b", whole(b));
        $display("   bit1 =%b (expect 1)", bit1(b));
        $display("   bit12=%b (expect 0)", bit12(b));

        $display("all three in one expression:");
        $display("   whole=%b bit1=%b bit12=%b (expect 000000000001 1 0)", whole(b), bit1(b), bit12(b));

        $display("two in one expression:");
        $display("   bit1=%b bit12=%b (expect 1 0)", bit1(b), bit12(b));
        $finish;
    end
endmodule
