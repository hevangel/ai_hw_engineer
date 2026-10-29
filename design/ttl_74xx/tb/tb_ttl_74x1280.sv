`timescale 1ns/1ps
// Testbench for ttl_74x1280. Exhaustively checks the combinational parity over
// all 1024 combinations of {i[7:0], i8, en8}, then directed register checks
// (load, clock-enable hold, async clear, OER three-state), plus a random
// sequential soak against a reference model.
module tb_ttl_74x1280;
    logic [7:0] i;
    logic       i8, en8, clk, cen_n, clr_n, oer_n;
    logic       sum_e, sum_o, q_sum_e, q_sum_o;
    ttl_74x1280 dut(.i(i), .i8(i8), .en8(en8), .clk(clk), .cen_n(cen_n),
        .clr_n(clr_n), .oer_n(oer_n), .sum_e(sum_e), .sum_o(sum_o),
        .q_sum_e(q_sum_e), .q_sum_o(q_sum_o));

    logic qe_r, qo_r;            // reference register
    int errors;

    function automatic logic odd_f; return (^i) ^ (en8 & i8); endfunction

    task automatic chkc(input string t);   // combinational
        #1;
        if (sum_o !== odd_f() || sum_e !== ~odd_f()) begin
            $display("Comb [%s]: i=%h i8=%b en8=%b got e=%b o=%b exp e=%b o=%b",
                     t, i, i8, en8, sum_e, sum_o, ~odd_f(), odd_f());
            errors++;
        end
    endtask

    task automatic chkq(input string t);   // registered (after settling)
        if (q_sum_e !== (oer_n ? 1'b0 : qe_r) || q_sum_o !== (oer_n ? 1'b0 : qo_r)) begin
            $display("Reg [%s]: oer_n=%b got qe=%b qo=%b exp qe=%b qo=%b",
                     t, oer_n, q_sum_e, q_sum_o, oer_n?1'b0:qe_r, oer_n?1'b0:qo_r);
            errors++;
        end
    endtask

    task automatic ctick;       // clock edge, mirror reference
        logic ne, no;
        if (!clr_n)      begin ne=1'b0; no=1'b0; end
        else if (!cen_n) begin ne=~odd_f(); no=odd_f(); end
        else             begin ne=qe_r; no=qo_r; end
        clk=0; #1; clk=1; #1; qe_r=ne; qo_r=no; clk=0; #1;
    endtask

    logic [31:0] rnd;
    initial begin
        errors=0; i=0; i8=0; en8=0; clk=0; cen_n=0; clr_n=1; oer_n=0; qe_r=1'bx; qo_r=1'bx;

        // Exhaustive combinational parity.
        for (int v=0; v<1024; v++) begin
            {en8, i8, i} = v[9:0];
            chkc($sformatf("c%0d", v));
        end

        // Register: clear, then load a known parity, hold, reload.
        i=8'h00; i8=0; en8=0; cen_n=0; oer_n=0;
        clr_n=0; #1; qe_r=0; qo_r=0; chkq("clr");
        clr_n=1;
        i=8'h07; ctick; chkq("load odd(3 ones)");      // 3 ones -> odd
        cen_n=1; i=8'h00; ctick; chkq("hold");          // clock disabled -> hold
        cen_n=0; ctick; chkq("reload even(0)");
        // async clear overrides
        clr_n=0; #1; qe_r=0; qo_r=0; chkq("async clr"); clr_n=1;
        // OER three-state
        oer_n=1; #1; chkq("oer off"); oer_n=0; #1; chkq("oer on");

        // Random sequential soak.
        rnd=$urandom(32'h1280_face);
        for (int n=0; n<2000; n++) begin
            rnd=$urandom;
            i=rnd[7:0]; i8=rnd[8]; en8=rnd[9]; cen_n=rnd[10]; clr_n=rnd[11]; oer_n=rnd[12];
            chkc($sformatf("rc%0d", n));
            if (!clr_n) begin #1; qe_r=0; qo_r=0; end   // async clear (level)
            if (rnd[13]) ctick;
            #1; chkq($sformatf("rq%0d", n));
        end

        if (errors!=0) $fatal(1, "tb_ttl_74x1280: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x1280 (1024 exhaustive comb + directed + 2000 random)");
        $finish;
    end
endmodule
