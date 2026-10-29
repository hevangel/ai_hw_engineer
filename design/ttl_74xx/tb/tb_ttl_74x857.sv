`timescale 1ns/1ps
module tb_ttl_74x857;
    logic s0, s1, comp;
    logic [5:0] a, b, y;
    logic oper_zero, y_oe_n, oper_oe_n;
    ttl_74x857 dut(.*);
    int errors;
    initial begin
        errors = 0;
        a = 6'b101010; b = 6'b010101;

        // Select A, no invert.
        s1 = 0; s0 = 0; comp = 0; #1;
        if (y !== 6'b101010 || y_oe_n !== 0) errors++;
        if (oper_zero !== 0 || oper_oe_n !== 0) errors++;  // not all-zero A

        // All-A-zero produces oper_zero=1.
        a = 6'h00; #1;
        if (oper_zero !== 1) errors++;
        a = 6'b101010;

        // Select B.
        s1 = 0; s0 = 1; #1;
        if (y !== 6'b010101) errors++;
        b = 6'h00; #1;
        if (oper_zero !== 1) errors++;
        b = 6'b010101;

        // AND mask: y = a & b, oper Hi-Z.
        s1 = 1; s0 = 0; #1;
        if (y !== (6'b101010 & 6'b010101)) errors++;
        if (oper_oe_n !== 1) errors++;

        // Force low: y=0, oper=0 driven.
        s1 = 1; s0 = 1; comp = 0; #1;
        if (y !== 0 || oper_zero !== 0 || oper_oe_n !== 0) errors++;

        // Select ~A.
        s1 = 0; s0 = 0; comp = 1; #1;
        if (y !== ~6'b101010) errors++;

        // Select ~B.
        s1 = 0; s0 = 1; comp = 1; #1;
        if (y !== ~6'b010101) errors++;

        // NAND mask: y = ~(a & b).
        s1 = 1; s0 = 0; comp = 1; #1;
        if (y !== ~(6'b101010 & 6'b010101)) errors++;
        if (oper_oe_n !== 1) errors++;

        // All Hi-Z.
        s1 = 1; s0 = 1; comp = 1; #1;
        if (y_oe_n !== 1 || oper_oe_n !== 1) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x857: %0d errors", errors);
        $display("PASS: tb_ttl_74x857");
        $finish;
    end
endmodule
