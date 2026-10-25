`timescale 1ns/1ps
// Reference-model + directed testbench for ttl_74x698 (up/down counter + register
// + R/C mux + /G). A behavioral reference mirrors the semantics; directed checks
// cover up/down counting and the decade wraps in both directions, rco, load,
// hold, register capture/hold, R/C, /G, and the sync counter clear; followed
// by 1500 randomized steps.
module tb_ttl_74x698;
    logic       cck, cclr_n, load_n, u_d, enp, ent, rck, r_c, g_n;
    logic [3:0] d, q;
    logic       rco;
    ttl_74x698 dut (.cck(cck), .cclr_n(cclr_n), .load_n(load_n), .u_d(u_d),
        .enp(enp), .ent(ent), .d(d), .rck(rck), .r_c(r_c), .g_n(g_n),
        .q(q), .rco(rco));

    localparam logic [3:0] MAXV = 4'd9;

    logic [3:0] cnt_r, rreg_r;
    function automatic logic [3:0] exp_q; return g_n ? 4'd0 : (r_c ? rreg_r : cnt_r); endfunction
    function automatic logic       exp_rco; return ent && (u_d ? (cnt_r == MAXV) : (cnt_r == 4'd0)); endfunction

    int errors;

    task automatic chk(input string tag);
        #1;
        // counter clear is synchronous (handled on cck edge)
        if (q !== exp_q())   begin $display("Q mismatch [%s]: got %b exp %b (cnt=%0d reg=%0d r_c=%b g_n=%b)", tag, q, exp_q(), cnt_r, rreg_r, r_c, g_n); errors++; end
        if (rco !== exp_rco()) begin $display("RCO mismatch [%s]: got %b exp %b (cnt=%0d u_d=%b ent=%b)", tag, rco, exp_rco(), cnt_r, u_d, ent); errors++; end
    endtask

    task automatic ctick;
        logic [3:0] nx;
        if (!cclr_n)         nx = 4'd0;
        else if (!load_n)    nx = d;
        else if (enp && ent) nx = u_d ? ((cnt_r == MAXV) ? 4'd0 : cnt_r + 4'd1)
                                      : ((cnt_r == 4'd0) ? MAXV : cnt_r - 4'd1);
        else                 nx = cnt_r;
        cck = 0; #1; cck = 1; #1; cnt_r = nx; cck = 0; #1;
    endtask

    task automatic rtick;
        cck = 0; rck = 0; #1; rck = 1; #1; rreg_r = cnt_r; rck = 0; #1;
    endtask

    logic [31:0] rnd;
    initial begin
        errors = 0;
        cck=0; rck=0; cclr_n=1; load_n=1; u_d=1; enp=0; ent=0; d=0; r_c=0; g_n=0;
        cnt_r=4'dx; rreg_r=4'dx;

        // Known state.
        load_n=0; d=4'd0; ctick; load_n=1; rtick; chk("init");

        // Count up to the wrap.
        enp=1; ent=1; u_d=1;
        load_n=0; d=MAXV; ctick; load_n=1; chk("load max");
        if (cnt_r !== MAXV) begin $display("expected MAXV"); errors++; end
        ctick; chk("up wrap");                 // MAXV -> 0
        if (cnt_r !== 4'd0) begin $display("expected up wrap 0"); errors++; end

        // Count down through the wrap.
        u_d=0; ctick; chk("down wrap");        // 0 -> MAXV
        if (cnt_r !== MAXV) begin $display("expected down wrap MAXV"); errors++; end
        u_d=1;

        // Hold.
        enp=0; ctick; chk("hold"); enp=1;

        // Register capture + R/C mux + hold.
        ctick; ctick; rtick; chk("rcapture");
        r_c=1; chk("sel reg"); r_c=0;
        ctick; r_c=1; chk("reg holds"); r_c=0;

        // /G.
        g_n=1; chk("oe off"); g_n=0; chk("oe on");

        // Synchronous counter clear (takes effect on cck edge).
        cclr_n = 0; ctick; cclr_n = 1; chk("sync clear");

        // Randomized soak.
        rnd = $urandom(32'h02ba_CAFE);
        for (int n = 0; n < 1500; n++) begin
            rnd = $urandom;
            cclr_n = rnd[0]; load_n = rnd[1]; enp = rnd[2]; ent = rnd[3];
            u_d = rnd[4]; r_c = rnd[5]; g_n = rnd[6]; d = rnd[10:7];
            #1;
            // counter clear is synchronous (handled on cck edge)
            if (rnd[11]) ctick; else rtick;
            chk($sformatf("rand %0d", n));
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x698: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x698 (directed + 1500 random)");
        $finish;
    end
endmodule
