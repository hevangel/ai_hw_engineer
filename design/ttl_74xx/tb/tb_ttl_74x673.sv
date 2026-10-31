`timescale 1ns/1ps
// Testbench for ttl_74x673 (16-bit shift register + 16-bit storage register).
// The reference uses event-driven always_ff blocks mirroring the device's two
// clock domains (so it tracks the exact dual-use mode_strclk edge semantics).
// The DIRECTED phase verifies the spec against hand-derived values (a known
// word written serially, stored, parallel-loaded back, and read out); the
// random phase then soaks the device against the reference.
module tb_ttl_74x673;
    logic        cs_n, rw, sh_clk, strclr_n, mode_strclk, si, q15;
    logic [15:0] y;
    ttl_74x673 dut(.cs_n(cs_n), .rw(rw), .sh_clk(sh_clk), .strclr_n(strclr_n),
        .mode_strclk(mode_strclk), .si(si), .q15(q15), .y(y));

    // Reference registers, mirroring the device's clock domains exactly.
    logic [15:0] sr_r, str_r;
    always_ff @(negedge sh_clk) begin
        if (!cs_n) begin
            if (!rw)               sr_r <= {sr_r[14:0], si};
            else if (!mode_strclk) sr_r <= {sr_r[14:0], sr_r[15]};
            else                   sr_r <= str_r;
        end
    end
    always_ff @(posedge mode_strclk or negedge strclr_n) begin
        if (!strclr_n)         str_r <= 16'd0;
        else if (!cs_n && !rw) str_r <= sr_r;
    end

    function automatic logic q15_exp; return (!cs_n && rw) ? sr_r[15] : 1'b0; endfunction
    int errors;

    task automatic chk(input string t);
        #1;
        if (q15 !== q15_exp()) begin $display("Q15 [%s]: got %b exp %b", t, q15, q15_exp()); errors++; end
        if (y !== str_r)       begin $display("Y [%s]: got %h exp %h", t, y, str_r); errors++; end
    endtask

    task automatic sh_fall;  sh_clk=1; #1; sh_clk=0; #2; endtask
    task automatic strclk;   mode_strclk=0; #1; mode_strclk=1; #2; endtask

    logic [15:0] wval;
    logic [31:0] rnd;
    initial begin
        errors=0;
        cs_n=1; rw=1; sh_clk=0; strclr_n=1; mode_strclk=0; si=0;

        // Init storage to 0.
        strclr_n=0; #2; chk("strclr"); strclr_n=1;

        // Serial-write a word (MSB first) into the shift register.
        cs_n=0; rw=0; mode_strclk=0; wval=16'hBEEF;
        for (int i=0; i<16; i++) begin si = wval[15-i]; sh_fall; end
        if (dut.sr !== 16'hBEEF) begin $display("serial write sr=%h exp BEEF", dut.sr); errors++; end

        // Load storage from shift register (R/W=L), then verify on Y.
        rw=0; strclk; chk("storage load");
        if (y !== 16'hBEEF) begin $display("Y=%h exp BEEF", y); errors++; end

        // Wipe the shift register, then parallel-load it back from storage.
        rw=0; mode_strclk=0;
        for (int i=0; i<16; i++) begin si=1'b0; sh_fall; end
        rw=1; mode_strclk=1; sh_fall; chk("ploadfromstr");
        if (dut.sr !== 16'hBEEF) begin $display("parallel load sr=%h exp BEEF", dut.sr); errors++; end

        // Serial read-out (recirculating), reconstruct the word.
        rw=1; mode_strclk=0;
        begin
            logic [15:0] cap; cap=16'd0;
            for (int i=0;i<16;i++) begin chk($sformatf("rd%0d",i)); cap={cap[14:0], q15}; sh_fall; end
            if (cap !== 16'hBEEF) begin $display("readout=%h exp BEEF", cap); errors++; end
        end

        // Chip-select hold.
        cs_n=1; rw=0; si=1; sh_fall; chk("hold");
        // Async storage clear mid-stream.
        strclr_n=0; #2; chk("clr2"); strclr_n=1;

        // Random soak.
        rnd=$urandom(32'h0673_5a5a);
        for (int n=0; n<1500; n++) begin
            rnd=$urandom;
            cs_n=rnd[0]; rw=rnd[1]; strclr_n=rnd[2]; si=rnd[3]; mode_strclk=rnd[5]; #1;
            if (rnd[6]) sh_fall; else strclk;
            chk($sformatf("rand%0d", n));
        end

        if (errors!=0) $fatal(1, "tb_ttl_74x673: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x673 (directed + 1500 random)");
        $finish;
    end
endmodule
