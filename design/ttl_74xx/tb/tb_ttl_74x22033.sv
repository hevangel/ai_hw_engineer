`timescale 1ns/1ps
module tb_ttl_74x22033;
    logic [7:0] ai, bi, ao, ao_drive, b_drive;
    logic oeab, oeab_n, oeba, clkab_leab, clkba_leba, loopback;
    logic [1:0] omode, imode;

    ttl_74x22033 dut(.*);

    // Independent reference implementation of the SCES354C tables.
    logic [7:0] r_pff, r_qff, r_plat, r_qlat;
    logic [7:0] r_p_elem, r_q_elem;

    function automatic logic [7:0] elem(input logic [1:0] mode,
                                        input logic [7:0] bufv,
                                        input logic [7:0] ffv,
                                        input logic [7:0] latv);
        case (mode[1])
            1'b0: return mode[0] ? ffv : bufv;
            default: return latv;
        endcase
    endfunction

    always_ff @(posedge clkab_leab)
        r_pff <= ai;
    always_ff @(posedge clkba_leba)
        r_qff <= loopback ? r_p_elem : bi;
    always_latch begin
        if (clkab_leab)
            r_plat = ai;
    end
    always_latch begin
        if (clkba_leba)
            r_qlat = loopback ? r_p_elem : bi;
    end
    always_comb begin
        r_p_elem = elem(omode, ai, r_pff, r_plat);
        r_q_elem = elem(imode, loopback ? r_p_elem : bi, r_qff, r_qlat);
    end

    task automatic tick_ab;
        clkab_leab = 1'b1;
        #1;
        clkab_leab = 1'b0;
        #1;
    endtask

    task automatic tick_ba;
        clkba_leba = 1'b1;
        #1;
        clkba_leba = 1'b0;
        #1;
    endtask

    task automatic check_all;
        if (ao !== (oeba ? ~r_q_elem : '0) || ao_drive !== (oeba ? 8'hFF : 8'h00))
            $fatal(1, "22033 AO mismatch ao=%02x want %02x", ao, ~r_q_elem);
        if (b_drive !== ((oeab && !oeab_n) ? r_p_elem : '0))
            $fatal(1, "22033 B sink mask mismatch b=%02x want %02x",
                   b_drive, r_p_elem);
    endtask

    initial begin
        oeab = 1'b0;
        oeab_n = 1'b1;
        oeba = 1'b0;
        clkab_leab = 1'b0;
        clkba_leba = 1'b0;
        loopback = 1'b0;
        omode = 2'b00;
        imode = 2'b00;
        ai = 8'h00;
        bi = 8'h00;
        #1;

        // Isolation per the enable/disable table.
        ai = 8'hA5;
        bi = 8'h3C;
        #1;
        check_all();

        // Buffer modes, both sides enabled: bus sinks inverted AI, AO inverts B.
        omode = 2'b00;
        imode = 2'b00;
        oeab = 1'b1;
        oeab_n = 1'b0;
        oeba = 1'b1;
        #1;
        check_all();

        // Flip-flop paths capture on rising edges of their own clock pins.
        omode = 2'b01;
        imode = 2'b01;
        ai = 8'h96;
        bi = 8'h69;
        #1;
        check_all();
        tick_ab();
        tick_ba();
        #1;
        check_all();
        ai = 8'h00;
        bi = 8'hFF;
        #1;
        check_all();  // registered values hold through input changes

        // Flip-flop re-capture on the next edges.
        ai = 8'h81;
        bi = 8'h7E;
        #1;
        tick_ab();
        tick_ba();
        #1;
        check_all();

        // Latch paths: transparent while CLK/LE high, hold while low.
        omode = 2'b10;
        imode = 2'b10;
        clkab_leab = 1'b1;
        clkba_leba = 1'b1;
        ai = 8'hF0;
        bi = 8'h0F;
        #1;
        check_all();
        clkab_leab = 1'b0;
        clkba_leba = 1'b0;
        ai = 8'h00;
        bi = 8'hFF;
        #1;
        check_all();  // latched values hold

        // Loopback: Q = P, so the AO path tracks the A-to-B element output.
        ai = 8'hC3;
        bi = 8'h00;
        loopback = 1'b1;
        clkab_leab = 1'b1;
        clkba_leba = 1'b1;
        #1;
        check_all();  // both latches transparent: AO mirrors inverted AI
        clkab_leab = 1'b0;
        ai = 8'h3C;
        #1;
        check_all();  // A-to-B latch holds 0xC3; AO keeps mirroring P

        // Both-enables transparent configuration with buffer modes.
        omode = 2'b00;
        imode = 2'b00;
        loopback = 1'b0;
        #1;
        check_all();

        // Output-enable pins independently isolate each side.
        oeba = 1'b0;
        #1;
        check_all();
        oeba = 1'b1;
        oeab = 1'b0;
        #1;
        check_all();
        oeab = 1'b1;
        oeab_n = 1'b1;
        #1;
        check_all();
        oeab_n = 1'b0;
        #1;
        check_all();

        $display("PASS: tb_ttl_74x22033");
        $finish;
    end
endmodule
