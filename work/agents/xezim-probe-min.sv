`timescale 1ns/1ps
// Minimal matrix: does a bit-select of a packed formal depend on its declared range?
module probe_min;
    // non-zero-based descending
    function automatic logic f_12_1(input logic [12:1] a); return a[1]; endfunction
    function automatic logic f_3_1 (input logic [3:1]  a); return a[1]; endfunction
    function automatic logic f_4_2 (input logic [4:2]  a); return a[2]; endfunction
    // zero-based
    function automatic logic f_11_0(input logic [11:0] a); return a[0]; endfunction
    function automatic logic f_2_0 (input logic [2:0]  a); return a[0]; endfunction
    // ascending
    function automatic logic f_1_12(input logic [1:12] a); return a[1]; endfunction
    // non-zero-based, select the top bit
    function automatic logic f_12_1_top(input logic [12:1] a); return a[12]; endfunction
    // non-zero-based, part-select instead of a bit-select
    function automatic logic [3:0] f_ps(input logic [12:1] a); return a[4:1]; endfunction

    initial begin
        $display("f_3_1 (expect 1)   = %b", f_3_1(3'b001));
        $display("f_3_1 (expect 0)   = %b", f_3_1(3'b000));
        $display("f_4_2 (expect 1)   = %b", f_4_2(3'b001));
        $display("f_2_0 (expect 1)   = %b", f_2_0(3'b001));
        $display("f_11_0(expect 1)   = %b", f_11_0(12'b000000000001));
        $display("f_12_1(expect 1)   = %b", f_12_1(12'b000000000001));
        $display("f_12_1(expect 0)   = %b", f_12_1(12'b000000000000));
        $display("f_1_12(expect 0)   = %b", f_1_12(12'b000000000010));
        $display("f_12_1_top(expect 1)= %b", f_12_1_top(12'b100000000000));
        $display("f_ps  (expect 0001)= %b", f_ps(12'b000000001111));
        $finish;
    end
endmodule
