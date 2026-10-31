`timescale 1ns/1ps
module tb_ttl_74x16648;
    logic [15:0] a_in, b_in, a_out, b_out;
    logic [1:0] oe_n, dir, clkab, clkba, sab, sba;
    logic [1:0] a_drive, b_drive;
    logic [15:0] expected_a, expected_b;
    logic [15:0] saved_a, saved_b;

    ttl_74x16648 dut(.*);

    initial begin
        // One section transfers B->A in real time, the other A->B.
        a_in = 16'hA55A;
        b_in = 16'h3CC3;
        oe_n = 2'b00;
        dir = 2'b10;
        clkab = 2'b00;
        clkba = 2'b00;
        sab = 2'b00;
        sba = 2'b00;
        expected_a = 16'h0000;
        expected_b = 16'h0000;
        #1;
        if (a_drive !== 2'b01 || b_drive !== 2'b10 ||
            a_out[7:0] !== ~b_in[7:0] || b_out[15:8] !== ~a_in[15:8])
            $fatal(1, "16648 independent real-time transfers");

        // Capture B for section 0 and A for section 1 while outputs are isolated.
        saved_b = 16'h96E1;
        saved_a = 16'h4B72;
        b_in[7:0] = saved_b[7:0];
        a_in[15:8] = saved_a[15:8];
        oe_n[0] = 1'b1;
        oe_n[1] = 1'b1;
        clkba[0] = 1'b1;
        clkab[1] = 1'b1;
        #1;
        clkba[0] = 1'b0;
        clkab[1] = 1'b0;
        #1;
        oe_n = 2'b00;
        dir = 2'b10;
        sba[0] = 1'b1;
        sab[1] = 1'b1;
        #1;
        expected_a = 16'h0000;
        expected_b = 16'h0000;
        expected_a[7:0] = ~saved_b[7:0];
        expected_b[15:8] = ~saved_a[15:8];
        if (a_drive !== 2'b01 || b_drive !== 2'b10 ||
            a_out !== expected_a || b_out !== expected_b)
            $fatal(1, "16648 stored transfer from both independent banks");

        // Stored outputs hold their captured data when the bus inputs change.
        a_in = 16'hFFFF;
        b_in = 16'h0000;
        #1;
        if (a_out !== expected_a || b_out !== expected_b)
            $fatal(1, "16648 stored data must hold");

        // Restore the captured values because the next rising edges also capture input data.
        b_in[7:0] = saved_b[7:0];
        a_in[15:8] = saved_a[15:8];

        // A stored selection is enabled only with its associated clock pin low.
        clkba[0] = 1'b1;
        clkab[1] = 1'b1;
        #1;
        if (a_drive[0] !== 1'b0 || b_drive[1] !== 1'b0 ||
            a_out[7:0] !== 8'h00 || b_out[15:8] !== 8'h00)
            $fatal(1, "16648 stored transfer requires low clock level");
        clkba[0] = 1'b0;
        clkab[1] = 1'b0;
        #1;
        if (a_drive[0] !== 1'b1 || b_drive[1] !== 1'b1 ||
            a_out !== expected_a || b_out !== expected_b)
            $fatal(1, "16648 stored transfer resumes with low clock level");

        // Capture the opposite-direction registers; stored capture is independent of OE.
        saved_a = 16'h5DA3;
        saved_b = 16'hC8F4;
        a_in[7:0] = saved_a[7:0];
        b_in[15:8] = saved_b[15:8];
        oe_n = 2'b11;
        clkab[0] = 1'b1;
        clkba[1] = 1'b1;
        #1;
        clkab[0] = 1'b0;
        clkba[1] = 1'b0;
        #1;
        oe_n = 2'b00;
        dir = 2'b01;
        sab[0] = 1'b1;
        sba[1] = 1'b1;
        #1;
        expected_a = 16'h0000;
        expected_b = 16'h0000;
        expected_b[7:0] = ~saved_a[7:0];
        expected_a[15:8] = ~saved_b[15:8];
        if (a_drive !== 2'b10 || b_drive !== 2'b01 ||
            a_out !== expected_a || b_out !== expected_b)
            $fatal(1, "16648 stored transfers in opposite directions");

        // Isolation and per-section enable independence.
        oe_n = 2'b11;
        #1;
        if (a_drive !== 2'b00 || b_drive !== 2'b00 ||
            a_out !== 16'h0000 || b_out !== 16'h0000)
            $fatal(1, "16648 output isolation");
        oe_n = 2'b01;
        #1;
        if (a_drive !== 2'b10 || b_drive !== 2'b00 ||
            a_out !== expected_a || b_out !== 16'h0000)
            $fatal(1, "16648 independent output enables");

        $display("PASS: tb_ttl_74x16648");
        $finish;
    end
endmodule
