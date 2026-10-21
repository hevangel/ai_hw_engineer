`timescale 1ns/1ps
// Reference-model + directed testbench for ttl_74x693. A behavioral reference
// mirrors the intended counter/register/mux semantics; randomized stimulus
// (including clear asserted between clock edges, which distinguishes
// asynchronous from synchronous clear) is applied to both and compared every
// step, plus directed checks on the binary wrap value and the R/C and /G muxes.
module tb_ttl_74x693;
    logic       cck, cclr_n, load_n, enp, ent, rck, rclr_n, r_c, g_n;
    logic [3:0] d, q;
    logic       rco;
    ttl_74x693 dut (.cck(cck), .cclr_n(cclr_n), .load_n(load_n), .enp(enp),
        .ent(ent), .d(d), .rck(rck), .rclr_n(rclr_n), .r_c(r_c), .g_n(g_n),
        .q(q), .rco(rco));

    localparam logic [3:0] MAXV = 4'd15;

    // Reference state.
    logic [3:0] cnt_r, rreg_r;
    function automatic logic [3:0] exp_q; return g_n ? 4'd0 : (r_c ? rreg_r : cnt_r); endfunction
    function automatic logic       exp_rco; return ent && (cnt_r == MAXV); endfunction

    int errors;

    task automatic chk(input string tag);
        #1;
        // Model level-sensitive asynchronous clears (the DUT applies these the
        // instant the line goes low, with no clock edge).
        // counter clear is synchronous (handled on cck edge)
        if (!rclr_n) rreg_r = 4'd0;                 // register clear is async
        if (q !== exp_q())   begin $display("Q mismatch [%s]: got %b exp %b (cnt=%0d reg=%0d r_c=%b g_n=%b)", tag, q, exp_q(), cnt_r, rreg_r, r_c, g_n); errors++; end
        if (rco !== exp_rco()) begin $display("RCO mismatch [%s]: got %b exp %b", tag, rco, exp_rco()); errors++; end
    endtask

    // Apply a counter clock edge to DUT and reference together.
    task automatic ctick;
        // reference update mirrors the RTL counter
        logic [3:0] nx;
        if (!cclr_n)         nx = 4'd0;
        else if (!load_n)    nx = d;
        else if (enp && ent) nx = (cnt_r == MAXV) ? 4'd0 : cnt_r + 4'd1;
        else                 nx = cnt_r;
        cck = 0; #1; cck = 1; #1; cnt_r = nx; cck = 0; #1;
    endtask

    // Register clock edge.
    task automatic rtick;
        logic [3:0] nx;
        nx = !rclr_n ? 4'd0 : cnt_r;
        rck = 0; #1; rck = 1; #1; rreg_r = nx; rck = 0; #1;
    endtask

    // Synchronous counter clear: cclr_n takes effect only on a cck edge.
    task automatic sync_clear;
        cclr_n = 0; ctick; cclr_n = 1;
    endtask

    // Asynchronous register clear.
    task automatic rclear; rclr_n = 0; rreg_r = 4'd0; #1; rclr_n = 1; #1; endtask

    logic [31:0] rnd;
    initial begin
        errors = 0;
        cck=0; rck=0; cclr_n=1; load_n=1; enp=0; ent=0; d=0; rclr_n=1; r_c=0; g_n=0;
        cnt_r=4'dx; rreg_r=4'dx;

        // Establish known state.
        load_n=0; d=4'd0; ctick; load_n=1; rtick; chk("init");

        // Directed: load, then count through a full wrap and check rco/wrap.
        load_n=0; d=4'd14; ctick; load_n=1; chk("load");
        enp=1; ent=1;
        ctick; chk("to max");          // -> MAXV
        if (cnt_r !== MAXV) begin $display("expected MAXV"); errors++; end
        ctick; chk("wrap");            // wraps MAXV -> 0
        if (cnt_r !== 4'd0) begin $display("expected wrap to 0"); errors++; end

        // Hold (enp=0).
        enp=0; ctick; chk("hold"); enp=1;

        // Register capture + R/C mux.
        ctick; ctick; rtick; chk("rcapture");
        r_c=1; chk("sel reg"); r_c=0;
        // change counter, register must hold until next rtick
        ctick; r_c=1; chk("reg holds"); r_c=0;

        // /G three-state.
        g_n=1; chk("oe off"); g_n=0; chk("oe on");

        // Register clear.
        rclear; r_c=1; chk("rclr"); r_c=0;

        // Counter clear behavior (synchronous).
        sync_clear; chk("sync clear");

        // Randomized soak: random controls, alternating clock edges.
        rnd = $urandom(32'h02b5_BEEF);
        for (int n = 0; n < 1500; n++) begin
            rnd = $urandom;
            cclr_n = rnd[0]; load_n = rnd[1]; enp = rnd[2]; ent = rnd[3];
            rclr_n = rnd[4]; r_c = rnd[5]; g_n = rnd[6]; d = rnd[10:7];
            #1;
            // Apply level-sensitive async clears to the reference BEFORE the
            // tick, so a register capture sees the same counter the DUT does.
            // counter clear is synchronous (handled on cck edge)
            if (!rclr_n) rreg_r = 4'd0;
            if (rnd[11]) ctick; else rtick;
            chk($sformatf("rand %0d", n));
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x693: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x693 (directed + 1500 random)");
        $finish;
    end
endmodule
