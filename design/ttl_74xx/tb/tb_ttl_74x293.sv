`timescale 1ns/1ps
module tb_ttl_74x293;
    logic clk_a, clk_b, r0_1, r0_2;

    logic q_a, q_b, q_c, q_d;
    logic [2:0] expected_b;
    ttl_74x293 dut(.*);
    function automatic logic [2:0] table_b(input integer i);
        case (i)
            0: table_b = 3'd0;
            1: table_b = 3'd1;
            2: table_b = 3'd2;
            3: table_b = 3'd3;
            4: table_b = 3'd4;
            5: table_b = 3'd5;
            6: table_b = 3'd6;
            7: table_b = 3'd7;
            default: table_b = 3'd0;
        endcase
    endfunction
    initial begin
        clk_a=1; clk_b=1; r0_1=1; r0_2=1;

        #1;
        if ({q_d,q_c,q_b,q_a} !== 0) $fatal(1,"reset");
        r0_1=0; #1;
        // Test both sections separately and assert no change on rising edges.
        for (int i=1; i<=32; i++) begin
            clk_a=0; #1;
            if (q_a !== 1'(i%2)) $fatal(1,"clock A falling edge");
            clk_a=1; #1;
            if (q_a !== 1'(i%2)) $fatal(1,"clock A rising edge changed Q");
            clk_b=0; #1; expected_b=table_b(i%8);
            if ({q_d,q_c,q_b} !== expected_b) $fatal(1,"section B sequence");
            clk_b=1; #1;
            if ({q_d,q_c,q_b} !== expected_b) $fatal(1,"clock B rising edge changed Q");
        end
        // Both reset inputs must be asserted; one alone does not reset.
        clk_a=0; #1; r0_1=1; r0_2=0; #1;
        if (q_a !== 1) $fatal(1,"single reset input incorrectly reset");
        r0_2=1; #1;
        if ({q_d,q_c,q_b,q_a} !== 0) $fatal(1,"asynchronous reset");
        $display("PASS: tb_ttl_74x293 (native edge and full state-table checks)");
        $finish;
    end
endmodule
