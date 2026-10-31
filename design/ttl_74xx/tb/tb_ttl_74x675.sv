`timescale 1ns/1ps
// Testbench for ttl_74x675. Event-driven reference always_ff blocks mirror the
// two clock domains. The directed phase verifies the spec with a known word
// (serial-write -> store -> parallel-load-back -> serial read-out = 0xBEEF);
// the random phase soaks the device.
module tb_ttl_74x675;
    logic        si, cs_n, srcp, stcp, rw, so;
    logic [15:0] q;
    ttl_74x675 dut(.si(si), .cs_n(cs_n), .srcp(srcp), .stcp(stcp), .rw(rw), .so(so), .q(q));

    logic [15:0] sr_r, str_r;
    always_ff @(negedge srcp) begin
        if (!cs_n) begin
            if (!rw) sr_r <= {sr_r[14:0], si};
            else     sr_r <= str_r;
        end
    end
    always_ff @(posedge stcp) if (!cs_n && rw) str_r <= sr_r;

    int errors;
    task automatic chk(input string t);
        #1;
        if (so !== sr_r[15]) begin $display("SO [%s]: got %b exp %b", t, so, sr_r[15]); errors++; end
        if (q  !== str_r)    begin $display("Q [%s]: got %h exp %h", t, q, str_r); errors++; end
    endtask
    task automatic sclk; srcp=1; #1; srcp=0; #2; endtask
    task automatic tclk; stcp=0; #1; stcp=1; #1; stcp=0; #2; endtask

    logic [15:0] wval;
    logic [31:0] rnd;
    initial begin
        errors=0; si=0; cs_n=1; srcp=0; stcp=0; rw=0;

        // Serial-write a word (MSB first), shifting in at Q0 toward Q15.
        cs_n=0; rw=0; wval=16'hBEEF;
        for (int i=0; i<16; i++) begin si = wval[15-i]; sclk; end
        if (dut.sr !== 16'hBEEF) begin $display("write sr=%h exp BEEF", dut.sr); errors++; end

        // Store into the storage register; verify on Q.
        rw=1; tclk; chk("store");
        if (q !== 16'hBEEF) begin $display("Q=%h exp BEEF", q); errors++; end

        // Wipe shift register (serial zeros), then parallel-load it back from storage.
        rw=0; for (int i=0;i<16;i++) begin si=1'b0; sclk; end
        rw=1; sclk; chk("reload from storage");
        if (dut.sr !== 16'hBEEF) begin $display("reload sr=%h exp BEEF", dut.sr); errors++; end

        // Serial read-out via SO (R/W=L shifting; SI bits are discarded).
        rw=0;
        begin
            logic [15:0] cap; cap=16'd0;
            for (int i=0;i<16;i++) begin cap={cap[14:0], so}; si=1'b0; sclk; end
            if (cap !== 16'hBEEF) begin $display("readout=%h exp BEEF", cap); errors++; end
        end

        // Chip-select hold.
        cs_n=1; rw=0; si=1; sclk; chk("hold");

        // Random soak.
        rnd=$urandom(32'h0675_face);
        for (int n=0; n<1500; n++) begin
            rnd=$urandom;
            cs_n=rnd[0]; rw=rnd[1]; si=rnd[2]; #1;
            if (rnd[3]) sclk; else tclk;
            chk($sformatf("rand%0d", n));
        end

        if (errors!=0) $fatal(1, "tb_ttl_74x675: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x675 (directed + 1500 random)");
        $finish;
    end
endmodule
