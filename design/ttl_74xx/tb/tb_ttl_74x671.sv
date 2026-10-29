`timescale 1ns/1ps
// Reference-model testbench for ttl_74x671. Event-driven reference always_ff
// blocks mirror the two clock domains; the directed phase verifies the spec
// (load, shift right/left with cascade, storage capture, R/S mux, /G,
// async clear) and the random phase soaks the device.
module tb_ttl_74x671;
    logic       ser_r, srck, ser_l, srclr_n, rck, r_s, g_n, s0, s1, casc;
    logic [3:0] d, q;
    ttl_74x671 dut(.ser_r(ser_r), .srck(srck), .d(d), .ser_l(ser_l),
        .srclr_n(srclr_n), .rck(rck), .r_s(r_s), .g_n(g_n), .s0(s0), .s1(s1),
        .q(q), .casc(casc));

    logic [3:0] sr_r, str_r;
    always_ff @(posedge srck or negedge srclr_n) begin
        if (!srclr_n) sr_r <= 4'd0;
        else unique case ({s1, s0})
            2'b00: ;
            2'b01: sr_r <= {sr_r[2:0], ser_r};
            2'b10: sr_r <= {ser_l, sr_r[3:1]};
            2'b11: sr_r <= d;
        endcase
    end
    always_ff @(posedge rck) str_r <= sr_r;

    function automatic logic [3:0] q_exp; return g_n ? 4'd0 : (r_s ? str_r : sr_r); endfunction
    function automatic logic       casc_exp; return (s1 && !s0) ? sr_r[0] : sr_r[3]; endfunction
    int errors;

    task automatic chk(input string t);
        #1;
        if (q !== q_exp())       begin $display("Q [%s]: got %h exp %h", t, q, q_exp()); errors++; end
        if (casc !== casc_exp()) begin $display("CASC [%s]: got %b exp %b", t, casc, casc_exp()); errors++; end
    endtask
    task automatic sclk; srck=1; #1; srck=0; #2; endtask
    task automatic rclk; rck=1;  #1; rck=0;  #2; endtask

    logic [31:0] rnd;
    initial begin
        errors=0;
        ser_r=0; srck=0; d=0; ser_l=0; srclr_n=1; rck=0; r_s=0; g_n=0; s0=0; s1=0;

        // Clear the shift register.
        s1=0; s0=0; srclr_n=0; sclk; #1; chk("clear"); srclr_n=1;
        if (dut.sr !== 4'd0) begin $display("clear failed sr=%h", dut.sr); errors++; end

        // Parallel load 0b1011 (QA=1,QB=1,QC=0,QD=1).
        s1=1; s0=1; d=4'b1011; sclk; chk("load");
        if (dut.sr !== 4'b1011) begin $display("load sr=%h exp B", dut.sr); errors++; end

        // Capture into storage, then verify via R/S mux.
        rclk; r_s=1; chk("store+sel"); r_s=0;

        // Shift right (QA->QD), ser_r=1: {sr[2:0],ser_r} = 0111.
        s1=0; s0=1; ser_r=1; sclk; chk("shr");
        if (dut.sr !== 4'b0111) begin $display("shr sr=%h", dut.sr); errors++; end

        // Shift left (QD->QA), ser_l=1: {ser_l, sr[3:1]} = 1011.
        s1=1; s0=0; ser_l=1; chk("shl-casc");   // casc should = QA (sr[0]) before clk
        sclk; chk("shl");
        if (dut.sr !== 4'b1011) begin $display("shl sr=%h", dut.sr); errors++; end

        // Hold.
        s1=0; s0=0; sclk; chk("hold");
        if (dut.sr !== 4'b1011) begin $display("hold changed sr", dut.sr); errors++; end

        // Output disable.
        g_n=1; chk("oe off"); g_n=0; chk("oe on");

        // Random soak.
        rnd=$urandom(32'h029f_a5a5);
        for (int n=0; n<1500; n++) begin
            rnd=$urandom;
            s0=rnd[0]; s1=rnd[1]; ser_r=rnd[2]; ser_l=rnd[3]; srclr_n=rnd[4];
            r_s=rnd[5]; g_n=rnd[6]; d=rnd[10:7];
            #1;
            if (rnd[11]) sclk; else rclk;
            chk($sformatf("rand%0d", n));
        end

        if (errors!=0) $fatal(1, "tb_ttl_74x671: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x671 (directed + 1500 random)");
        $finish;
    end
endmodule
