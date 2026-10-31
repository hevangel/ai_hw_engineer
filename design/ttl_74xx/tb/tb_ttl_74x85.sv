`timescale 1ns/1ps
module tb_ttl_74x85;
    logic [3:0] a,b;
    logic i_a_gt_b,i_a_eq_b,i_a_lt_b,a_gt_b,a_eq_b,a_lt_b;
    logic [2:0] expected;
    ttl_74x85 dut(.*);
    initial begin
        for(int ai=0;ai<16;ai++) for(int bi=0;bi<16;bi++)
        for(int ci=0;ci<8;ci++) begin
            a=4'(ai); b=4'(bi); {i_a_gt_b,i_a_eq_b,i_a_lt_b}=3'(ci); #1;
            if(ai>bi) expected=3'b100;
            else if(ai<bi) expected=3'b001;
            else case(ci)
                0: expected=3'b101;
                1: expected=3'b001;
                2,3,6,7: expected=3'b010;
                4: expected=3'b100;
                5: expected=3'b000;
                default: expected='x;
            endcase
            if({a_gt_b,a_eq_b,a_lt_b} !== expected) $fatal(1,"cascade table %d",ci);
        end
        $display("PASS: tb_ttl_74x85 (2048 independent cascade-table vectors)");
        $finish;
    end
endmodule
