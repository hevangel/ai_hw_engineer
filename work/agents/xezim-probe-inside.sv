`timescale 1ns/1ps
module probe_inside;
    function automatic logic see(input logic [12:1] a);
        $display("   inside: a=%b a[1]=%b a[2]=%b a[12]=%b", a, a[1], a[2], a[12]);
        return a[1];
    endfunction

    initial begin
        logic [12:1] same;
        logic [11:0] narrow;
        logic [13:0] wide;

        same   = 12'b000000000001;
        narrow = 12'b000000000001;
        wide   = 14'b00000000000001;

        $display("1) same-width [12:1] actual:");
        $display("   returned %b", see(same));

        $display("2) narrow [11:0] actual:");
        $display("   returned %b", see(narrow));

        $display("3) wide [13:0] actual:");
        $display("   returned %b", see(wide));

        $display("4) literal:");
        $display("   returned %b", see(12'b000000000001));

        $display("5) same-width, local declared [12:1] and set via literal:");
        same = 12'b100000000000;
        $display("   returned %b", see(same));

        $finish;
    end
endmodule
