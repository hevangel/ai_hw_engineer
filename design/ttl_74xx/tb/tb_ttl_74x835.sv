`timescale 1ns/1ps
// Testbench for ttl_74x835. Event-driven reference mirrors the B latch and the
// shift register. Directed phase verifies each operating mode by loading a word
// (via A, via transparent B, via latched B) and shifting it out on Q7, plus a
// serial-shift-in; random phase soaks the device.
module tb_ttl_74x835;
    logic       pe_n, cp, le, s_ab, ds, q7;
    logic [7:0] da, db;
    ttl_74x835 dut(.pe_n(pe_n), .cp(cp), .le(le), .s_ab(s_ab), .da(da), .db(db), .ds(ds), .q7(q7));

    logic [7:0] b_lat_r, sr_r, mux_r;
    always_latch if (le) b_lat_r = db;
    assign mux_r = s_ab ? b_lat_r : da;
    always_ff @(posedge cp) begin
        if (!pe_n) sr_r <= mux_r;
        else       sr_r <= {sr_r[6:0], ds};
    end

    int errors;
    task automatic chk(input string t);
        #1;
        if (q7 !== sr_r[7]) begin $display("Q7 [%s]: got %b exp %b (sr=%h)", t, q7, sr_r[7], sr_r); errors++; end
    endtask
    task automatic clk; cp=0; #1; cp=1; #1; cp=0; #1; endtask

    // Load a word via the chosen path, then shift it out on Q7 and compare.
    task automatic load_and_readout(input [7:0] word, input string tag);
        logic [7:0] cap;
        clk;                                   // parallel load (pe_n must be 0, mux set)
        if (dut.sr !== word) begin $display("%s load sr=%h exp %h", tag, dut.sr, word); errors++; end
        pe_n=1; ds=0; cap=8'd0;
        for (int i=0;i<8;i++) begin cap={cap[6:0], q7}; clk; end   // shift out MSB first
        if (cap !== word) begin $display("%s readout=%h exp %h", tag, cap, word); errors++; end
    endtask

    logic [31:0] rnd;
    initial begin
        errors=0; pe_n=1; cp=0; le=0; s_ab=0; ds=0; da=0; db=0;

        // Parallel load A data, read out.
        pe_n=0; s_ab=0; da=8'hA5; load_and_readout(8'hA5, "loadA");

        // Parallel load B (transparent): le=1, s_ab=1.
        pe_n=0; le=1; s_ab=1; db=8'h3C; load_and_readout(8'h3C, "loadB-transp");

        // Latch B then load from latch: capture 8'h99 with le high, drop le, change db.
        le=1; db=8'h99; #1; le=0; db=8'h00;    // b_lat holds 0x99
        pe_n=0; s_ab=1; load_and_readout(8'h99, "loadB-latched");

        // Serial shift a word in (MSB first), then read out.
        pe_n=1; le=0; s_ab=0;
        begin
            logic [7:0] w; w=8'h5A;
            for (int i=0;i<8;i++) begin ds=w[7-i]; clk; end
            if (dut.sr !== 8'h5A) begin $display("serial in sr=%h exp 5A", dut.sr); errors++; end
        end

        // Random soak.
        rnd=$urandom(32'h0835_face);
        for (int n=0;n<1500;n++) begin
            rnd=$urandom;
            pe_n=rnd[0]; le=rnd[1]; s_ab=rnd[2]; ds=rnd[3]; da=rnd[11:4]; db=rnd[19:12]; #1;
            clk;
            chk($sformatf("rand%0d", n));
        end

        if (errors!=0) $fatal(1, "tb_ttl_74x835: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x835 (directed + 1500 random)");
        $finish;
    end
endmodule
