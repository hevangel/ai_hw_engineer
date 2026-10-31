`timescale 1ns/1ps
module probe_align;
    function automatic logic [11:0] showA(input logic [12:1] a); return a; endfunction
    function automatic logic bit1 (input logic [12:1] a); return a[1]; endfunction
    function automatic logic bit12(input logic [12:1] a); return a[12]; endfunction

    initial begin
        logic [11:0] b;
        b = 12'b000000000001;   // only b[0] set
        $display("b=%b  as [12:1] via function=%b  bit1=%b bit12=%b",
                 b, showA(b), bit1(b), bit12(b));
        b = 12'b100000000000;   // only b[11] set
        $display("b=%b  as [12:1] via function=%b  bit1=%b bit12=%b",
                 b, showA(b), bit1(b), bit12(b));
        b = 12'b000100000000;
        $display("b=%b  as [12:1] via function=%b  bit1=%b bit12=%b",
                 b, showA(b), bit1(b), bit12(b));

        // direct, no function call
        begin
            logic [12:1] a;
            a = 12'b000000000001;
            $display("direct a=%b a[1]=%b a[12]=%b", a, a[1], a[12]);
        end
        $finish;
    end
endmodule
