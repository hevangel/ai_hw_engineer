`timescale 1ns/1ps
// A/B: identical calls, but the actual is either module-scope or block-local.
module probe_scope;
    logic [11:0] b_mod;

    function automatic logic bit1 (input logic [12:1] a); return a[1];  endfunction
    function automatic logic bit12(input logic [12:1] a); return a[12]; endfunction

    initial begin
        $display("module-scope actual:");
        b_mod = 12'b000000000001;
        $display("   bit1=%b (expect 1)  bit12=%b (expect 0)", bit1(b_mod), bit12(b_mod));

        $display("block-local actual:");
        begin
            logic [11:0] b_loc;
            b_loc = 12'b000000000001;
            $display("   bit1=%b (expect 1)  bit12=%b (expect 0)", bit1(b_loc), bit12(b_loc));
        end

        $display("loop-local actual (declared in the for body):");
        for (int v = 0; v < 3; v++) begin
            logic [11:0] b_it;
            b_it = 12'b000000000001;
            $display("   v=%0d bit1=%b (expect 1)  bit12=%b (expect 0)", v, bit1(b_it), bit12(b_it));
        end

        $display("no argument at all:");
        begin
            logic [12:1] a_loc;
            a_loc = 12'b000000000001;
            $display("   direct a_loc[1]=%b", a_loc[1]);
        end
        $finish;
    end
endmodule
