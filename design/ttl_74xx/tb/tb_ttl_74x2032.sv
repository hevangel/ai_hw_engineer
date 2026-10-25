`timescale 1ns/1ps
// The bench wires two 'FB2032 instances onto one wired-AND bus with pullups,
// emulating two identical modules competing on a BTL arbitration line set:
// a released line resolves high, a line sunk by either module reads low, and
// each device observes the same resolved levels at its B inputs.
module tb_ttl_74x2032;
    // module-under-test side
    logic       oea, oeb, oeb_n, le, compete;
    logic [8:0] a_in;
    logic [8:0] a_out, b_out, b_drive;
    logic       a_drive, win;
    // rival side
    logic       oea_r, oeb_r, oeb_n_r, le_r, compete_r;
    logic [8:0] a_in_r;
    logic [8:0] a_out_r, b_out_r, b_drive_r;
    logic       a_drive_r, win_r;
    // shared resolved bus
    logic [8:0] b_in;

    ttl_74x2032 dut(.*);

    ttl_74x2032 rival(
        .oea(oea_r), .oeb(oeb_r), .oeb_n(oeb_n_r), .le(le_r), .compete(compete_r),
        .a_in(a_in_r), .b_in(b_in), .win(win_r),
        .a_out(a_out_r), .a_drive(a_drive_r), .b_out(b_out_r), .b_drive(b_drive_r)
    );

    assign b_in = ~(b_drive | b_drive_r);

    initial begin
        // Phase A: plain transceiver (compete high, LE transparent) with the
        // rival idle: exhaustive enable sweep with two vectors.
        compete = 1'b1; le = 1'b0;
        oea_r = 1'b0; oeb_r = 1'b0; oeb_n_r = 1'b0; le_r = 1'b0;
        compete_r = 1'b1; a_in_r = 9'h000;
        for (int e = 0; e < 8; e++) begin
            oea = e[2]; oeb = e[1]; oeb_n = e[0];
            a_in = 9'b1_0110_1001;
            #1;
            if (a_drive !== oea || b_out !== 9'h000 || win !== 1'b0)
                $fatal(1, "2032 enable sweep flags, e=%0d", e);
            if (a_out !== (oea ? ~b_in : 9'h000))
                $fatal(1, "2032 A readback must be inverted live B data, e=%0d", e);
            if (b_drive !== ((oeb && !oeb_n) ? a_in : 9'h000))
                $fatal(1, "2032 B drive must follow the A-bar rule, e=%0d", e);
            a_in = 9'b0_1001_0110;
            #1;
            if (b_drive !== ((oeb && !oeb_n) ? a_in : 9'h000))
                $fatal(1, "2032 B drive vector 2, e=%0d", e);
        end

        // Phase B: LE latches the A-port data (high = latched, low = clear).
        // The number is made transparent first; taking LE high then freezes
        // exactly the value present at the latch.
        oea = 1'b1; oeb = 1'b1; oeb_n = 1'b0;
        a_in = 9'h12C; le = 1'b0;
        #1;
        le = 1'b1;
        #1;
        a_in = 9'h341;
        #1;
        if (b_drive !== 9'h12C)
            $fatal(1, "2032 LE high must hold the latched A data");
        le = 1'b0;
        #1;
        if (b_drive !== 9'h341)
            $fatal(1, "2032 LE low must make the latches transparent");

        // Phase C: parity bit (bit 8 = AP/BP) drives like a data bit and is
        // independent of the arbitration chain and of the data bits.
        a_in = 9'h100;
        #1;
        le = 1'b1;
        #1;
        if (b_drive !== 9'h100)
            $fatal(1, "2032 AP high must sink BP while B is enabled");
        compete = 1'b0;
        #1;
        if (win !== 1'b1 || b_drive !== 9'h100)
            $fatal(1, "2032 released data lines must not block win");

        // Phase D: two-module competition (both compete low, both enabled).
        // Each case re-loads both latches through their transparent state.
        compete_r = 1'b0; oeb_r = 1'b1; oeb_n_r = 1'b0;
        // D1: our greater number wins; the rival releases below its loss
        // point and the bus carries our number for readback.
        le = 1'b0; le_r = 1'b0;
        a_in = 9'h1F0; a_in_r = 9'h070;
        #1;
        le = 1'b1; le_r = 1'b1;
        #1;
        if (win !== 1'b1 || b_drive !== 9'h1F0)
            $fatal(1, "2032 greater number must win and stay asserted");
        if (win_r !== 1'b0 || b_drive_r !== 9'h000)
            $fatal(1, "2032 rival must lose and release its lines");
        if (a_out !== 9'h1F0)
            $fatal(1, "2032 winner readback must show its own number");
        // D2: reversed roles.
        le = 1'b0; le_r = 1'b0;
        a_in = 9'h070; a_in_r = 9'h1F0;
        #1;
        le = 1'b1; le_r = 1'b1;
        #1;
        if (win !== 1'b0 || b_drive !== 9'h000)
            $fatal(1, "2032 lesser number must lose and release its lines");
        if (win_r !== 1'b1 || b_drive_r !== 9'h1F0)
            $fatal(1, "2032 rival greater number must win");
        if (a_out !== 9'h1F0)
            $fatal(1, "2032 loser readback must show the winner's number");
        // D3: non-prefix pair; the release dynamics still elect the max.
        le = 1'b0; le_r = 1'b0;
        a_in = 9'h080; a_in_r = 9'h07F;
        #1;
        le = 1'b1; le_r = 1'b1;
        #1;
        if (win !== 1'b1 || b_drive !== 9'h080 || b_in !== 9'h17F)
            $fatal(1, "2032 competition must settle on the binary maximum");
        if (win_r !== 1'b0 || b_drive_r !== 9'h000)
            $fatal(1, "2032 non-prefix loser must fully release");
        // D4: tie; both modules see win (wired-OR cannot break ties).
        le = 1'b0; le_r = 1'b0;
        a_in = 9'h0AA; a_in_r = 9'h0AA;
        #1;
        le = 1'b1; le_r = 1'b1;
        #1;
        if (win !== 1'b1 || win_r !== 1'b1 || b_drive !== 9'h0AA)
            $fatal(1, "2032 tie must leave both modules asserting");
        // D5: rival leaves competition (compete high): it transmits its
        // number ungated and its own win is forced low.
        compete_r = 1'b1;
        #1;
        if (win_r !== 1'b0 || b_drive_r !== 9'h0AA)
            $fatal(1, "2032 rival compete high must ungate and clear win_r");
        if (win !== 1'b1 || b_drive !== 9'h0AA)
            $fatal(1, "2032 non-competing rival lines must not block win");
        compete_r = 1'b0;

        // Phase E: enable rows during competition; win is not qualified by
        // the output enables.
        oeb = 1'b0;
        #1;
        if (b_drive !== 9'h000)
            $fatal(1, "2032 oeb low must release the B port");
        if (win !== 1'b1)
            $fatal(1, "2032 win is not qualified by the output enables");
        oeb = 1'b1; oeb_n = 1'b1;
        #1;
        if (b_drive !== 9'h000)
            $fatal(1, "2032 oeb_n high must release the B port");
        oeb_n = 1'b0;

        // Phase F: B-to-A readback stays live even with data latched; the
        // rival latch is opened so its live number varies the bus.
        oea = 1'b1; le_r = 1'b0;
        a_in_r = 9'h0F0;
        #1;
        if (a_out !== ~b_in)
            $fatal(1, "2032 B-to-A path must be transparent while LE holds");
        a_in_r = 9'h081;
        #1;
        if (a_out !== ~b_in)
            $fatal(1, "2032 B-to-A readback must track the live bus");

        $display("PASS: tb_ttl_74x2032");
        $finish;
    end
endmodule
