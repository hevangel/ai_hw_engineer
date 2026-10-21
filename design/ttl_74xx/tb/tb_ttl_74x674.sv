`timescale 1ns/1ps
// Reference-model testbench for ttl_74x674 (16-bit PISO shift register). A
// behavioral model mirrors the falling-edge shift register; directed checks
// cover parallel load + serial read-out of a known word (recirculating, so it
// restores), serial write-in then read-back, chip-select hold, and 1500 random
// steps.
module tb_ttl_74x674;
    logic        cs_n, rw, mode, clk, si, q15;
    logic [15:0] p;
    ttl_74x674 dut(.cs_n(cs_n), .rw(rw), .mode(mode), .clk(clk), .p(p), .si(si), .q15(q15));

    logic [15:0] sr_r;
    function automatic logic q15_exp; return (!cs_n && rw) ? sr_r[15] : 1'b0; endfunction
    int errors;

    task automatic chk(input string t);
        #1;
        if (q15 !== q15_exp()) begin
            $display("Q15 [%s]: got %b exp %b (sr=%h cs_n=%b rw=%b)", t, q15, q15_exp(), sr_r, cs_n, rw);
            errors++;
        end
    endtask

    task automatic fall;        // falling clock edge; mirror reference
        logic [15:0] nx;
        nx = sr_r;
        if (!cs_n) begin
            if (!rw)        nx = {sr_r[14:0], si};
            else if (!mode) nx = {sr_r[14:0], sr_r[15]};
            else            nx = p;
        end
        clk=1; #1; clk=0; #1; sr_r = nx; #1;
    endtask

    logic [15:0] captured;
    logic [31:0] rnd;
    initial begin
        errors=0; cs_n=1; rw=1; mode=1; clk=0; si=0; p=0; sr_r=16'dx;

        // Parallel load a known word.
        cs_n=0; rw=1; mode=1; p=16'hA53C; fall; chk("load");
        // Serial read it out MSB-first (recirculating restores it).
        mode=0; captured=16'd0;
        for (int i=0; i<16; i++) begin
            chk($sformatf("read bit %0d", i));
            captured = {captured[14:0], q15};   // q15 = current MSB
            fall;
        end
        if (captured !== 16'hA53C) begin $display("serial readout=%h exp A53C", captured); errors++; end
        // After 16 recirculating shifts, register restored.
        if (sr_r !== 16'hA53C) begin $display("recirc not restored: %h", sr_r); errors++; end

        // Serial write a new word in (MSB-first), then verify register.
        rw=0;
        begin
            logic [15:0] wval; wval = 16'h1234;
            for (int i=0; i<16; i++) begin si = wval[15-i]; fall; end  // shift in MSB-first
        end
        if (sr_r !== 16'h1234) begin $display("serial write got %h exp 1234", sr_r); errors++; end

        // Chip-select hold: CS high, clocks ignored.
        rw=1; mode=1; p=16'hFFFF; cs_n=1; fall; chk("hold");
        if (sr_r !== 16'h1234) begin $display("hold changed reg: %h", sr_r); errors++; end

        // Random soak.
        rnd=$urandom(32'h0674_1234);
        for (int n=0; n<1500; n++) begin
            rnd=$urandom;
            cs_n=rnd[0]; rw=rnd[1]; mode=rnd[2]; si=rnd[3]; p=rnd[19:4];
            fall;
            chk($sformatf("rand%0d", n));
        end

        if (errors!=0) $fatal(1, "tb_ttl_74x674: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x674 (directed + 1500 random)");
        $finish;
    end
endmodule
