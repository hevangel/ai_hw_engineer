`timescale 1ns/1ps
// Reference-model testbench for ttl_74x915. Exhaustively sweeps all 128 segment
// patterns in both invert modes (transparent, enabled) checking BCD/error/minus
// against the library-canonical font, then directed checks for the latch (le)
// and three-state (oe_n), plus random.
module tb_ttl_74x915;
    function automatic [6:0] bcd_to_7seg(input [3:0] bcd);
        case (bcd)
            4'd0:    bcd_to_7seg = 7'b1111110; // a b c d e f
            4'd1:    bcd_to_7seg = 7'b0110000; //   b c
            4'd2:    bcd_to_7seg = 7'b1101101; // a b   d e   g
            4'd3:    bcd_to_7seg = 7'b1111001; // a b c d     g
            4'd4:    bcd_to_7seg = 7'b0110011; //   b c     f g
            4'd5:    bcd_to_7seg = 7'b1011011; // a   c d   f g
            4'd6:    bcd_to_7seg = 7'b1011111; // a   c d e f g
            4'd7:    bcd_to_7seg = 7'b1110000; // a b c
            4'd8:    bcd_to_7seg = 7'b1111111; // a b c d e f g
            4'd9:    bcd_to_7seg = 7'b1111011; // a b c d   f g
            default: bcd_to_7seg = 7'b0000000; // chips that need 0xA-0xF
                                               // patterns override this case
                                               // in their own RTL.
        endcase
    endfunction


    logic       a, b, c, d, e, f, g, invert, le, oe_n;
    logic [3:0] bcd;
    logic       error, minus;
    ttl_74x915 dut(.a(a), .b(b), .c(c), .d(d), .e(e), .f(f), .g(g),
        .invert(invert), .le(le), .oe_n(oe_n), .bcd(bcd), .error(error), .minus(minus));

    logic [3:0] bcd_lat_r;
    int errors;

    function automatic logic [6:0] tpf(input logic [6:0] seg);
        return invert ? ~seg : seg;
    endfunction

    task automatic chk(input string t);
        logic [6:0] seg, tp;
        logic [3:0] dig; logic val;
        #1;
        seg = {a,b,c,d,e,f,g};
        tp  = invert ? ~seg : seg;
        dig = 4'd0; val = 1'b0;
        for (int n=0;n<10;n++) if (tp == bcd_to_7seg(n[3:0])) begin dig=n[3:0]; val=1'b1; end
        if (!le && val) bcd_lat_r = dig;
        if (error !== ~val) begin $display("ERROR flag [%s]: tp=%b got %b exp %b", t, tp, error, ~val); errors++; end
        if (minus !== (tp==7'b0000001)) begin $display("MINUS [%s]: tp=%b got %b", t, tp, minus); errors++; end
        if (bcd !== ((oe_n || ~val) ? 4'b0000 : bcd_lat_r)) begin
            $display("BCD [%s]: tp=%b le=%b oe_n=%b got %b exp %b (lat=%b val=%b)",
                     t, tp, le, oe_n, bcd, (oe_n||~val)?4'b0:bcd_lat_r, bcd_lat_r, val);
            errors++;
        end
    endtask

    logic [31:0] rnd;
    initial begin
        errors=0; invert=0; le=0; oe_n=0; {a,b,c,d,e,f,g}=7'd0; bcd_lat_r=4'dx;

        // Exhaustive over all 128 segment patterns, both invert modes, transparent+enabled.
        for (int inv=0; inv<2; inv++) begin
            invert = inv[0]; le=0; oe_n=0;
            for (int s=0; s<128; s++) begin
                {a,b,c,d,e,f,g} = s[6:0];
                chk($sformatf("inv%0d s%0d", inv, s));
            end
        end

        // Latch hold: load a valid digit, freeze, change segments.
        invert=0; le=0; {a,b,c,d,e,f,g}=bcd_to_7seg(4'd5); chk("load5");
        le=1; {a,b,c,d,e,f,g}=bcd_to_7seg(4'd9); chk("held(5)"); le=0; chk("now9");

        // Three-state.
        oe_n=1; chk("oe off"); oe_n=0; chk("oe on");

        // Random.
        rnd=$urandom(32'h0915_abcd);
        for (int n=0;n<2000;n++) begin
            le=1;#1;
            rnd=$urandom;
            {a,b,c,d,e,f,g}=rnd[6:0]; invert=rnd[7]; oe_n=rnd[9];
            #1; // Settle segment polarity/decode before opening the latch.
            le=rnd[8];
            chk($sformatf("rand%0d", n));
        end

        if (errors!=0) $fatal(1, "tb_ttl_74x915: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x915 (256 exhaustive + directed + 2000 random)");
        $finish;
    end
endmodule
