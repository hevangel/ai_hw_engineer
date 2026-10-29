`timescale 1ns/1ps
// Testbench for ttl_74x676 (16-bit PISO shift register, single register). An
// event-driven reference mirrors the falling-edge register. Directed phase
// verifies parallel-load + serial read-out and serial-write + read-out of known
// words; random phase soaks the device.
module tb_ttl_74x676;
    logic [15:0] p;
    logic        cs_n, cp, m, si, so;
    ttl_74x676 dut(.p(p), .cs_n(cs_n), .cp(cp), .m(m), .si(si), .so(so));

    logic [15:0] sr_r;
    always_ff @(negedge cp) begin
        if (!cs_n) begin
            if (!m) sr_r <= {sr_r[14:0], si};
            else    sr_r <= p;
        end
    end

    int errors;
    task automatic chk(input string t);
        #1;
        if (so !== sr_r[15]) begin $display("SO [%s]: got %b exp %b", t, so, sr_r[15]); errors++; end
    endtask
    task automatic clk; cp=1; #1; cp=0; #2; endtask

    logic [15:0] wval;
    logic [31:0] rnd;
    initial begin
        errors=0; p=0; cs_n=1; cp=0; m=0; si=0;

        // Parallel-load a word, then serially read it out via SO (MSB first).
        cs_n=0; m=1; p=16'hBEEF; clk; chk("pload");
        if (dut.sr !== 16'hBEEF) begin $display("pload sr=%h exp BEEF", dut.sr); errors++; end
        m=0;
        begin
            logic [15:0] cap; cap=16'd0;
            for (int i=0;i<16;i++) begin cap={cap[14:0], so}; si=1'b0; clk; end
            if (cap !== 16'hBEEF) begin $display("readout=%h exp BEEF", cap); errors++; end
        end

        // Serial-write a word (MSB first), then verify register.
        m=0; wval=16'h1234;
        for (int i=0;i<16;i++) begin si=wval[15-i]; clk; end
        if (dut.sr !== 16'h1234) begin $display("serial write sr=%h exp 1234", dut.sr); errors++; end

        // Chip-select hold.
        cs_n=1; m=1; p=16'hFFFF; clk; chk("hold");
        if (dut.sr !== 16'h1234) begin $display("hold changed sr=%h", dut.sr); errors++; end

        // Random soak.
        rnd=$urandom(32'h0676_beef);
        for (int n=0; n<1500; n++) begin
            rnd=$urandom;
            cs_n=rnd[0]; m=rnd[1]; si=rnd[2]; p=rnd[18:3]; #1;
            clk;
            chk($sformatf("rand%0d", n));
        end

        if (errors!=0) $fatal(1, "tb_ttl_74x676: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x676 (directed + 1500 random)");
        $finish;
    end
endmodule
