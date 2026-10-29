`timescale 1ns/1ps
module tb_ttl_74x2041;
    logic       oeb;
    logic [2:0] oeb_n, oea;
    logic [6:0] ai_in, b_in;
    logic [6:0] ao_out, b_out, b_drive;
    logic [2:0] ao_drive;
    logic [6:0] exp_ao, exp_b;
    int         s;

    ttl_74x2041 dut(.*);

    initial begin
        // Exhaustive control sweep: shared oeb plus per-section oeb_n and
        // oea (2^7 combinations), across two data vectors, including
        // open-collector release for all-zero A inputs.
        for (int e = 0; e < 128; e++) begin
            oeb = e[6];
            oeb_n = e[2:0];
            oea = e[5:3];
            ai_in = 7'b101_0101;
            b_in = 7'b010_1010;
            #1;
            exp_ao = 7'h00;
            exp_b = 7'h00;
            for (int i = 0; i < 7; i++) begin
                s = (i == 0) ? 0 : (i <= 3) ? 1 : 2;
                if (oea[s])
                    exp_ao[i] = ~b_in[i];
                if (oeb && !oeb_n[s])
                    exp_b[i] = ai_in[i];
            end
            if (ao_drive !== oea || ao_out !== exp_ao ||
                b_drive !== exp_b || b_out !== 7'h00)
                $fatal(1, "2041 control sweep vector 1, e=%0d", e);
            ai_in = 7'h00;                      // nothing to sink: all released
            #1;
            if (b_drive !== 7'h00)
                $fatal(1, "2041 all-zero AI must release every B line, e=%0d", e);
            ai_in = 7'h7F;                      // every line sunk when enabled
            #1;
            exp_b = 7'h00;
            for (int i = 0; i < 7; i++) begin
                s = (i == 0) ? 0 : (i <= 3) ? 1 : 2;
                if (oeb && !oeb_n[s])
                    exp_b[i] = 1'b1;
            end
            if (b_drive !== exp_b)
                $fatal(1, "2041 all-one AI must sink enabled sections, e=%0d", e);
        end

        // Section independence: mixed enables drive disjoint sections only.
        oeb = 1'b1;
        oeb_n = 3'b010;                         // section 1 and 3 enabled
        oea = 3'b010;                           // only section 2 outputs
        ai_in = 7'h7F; b_in = 7'h55;
        #1;
        if (b_drive !== 7'b111_0001)
            $fatal(1, "2041 per-section B enables: 2OEB_n must gate section 2");
        if (ao_out !== 7'b000_1010 || ao_drive !== 3'b010)
            $fatal(1, "2041 per-section AO enables: only 2AO may drive");
        // Simultaneous transfer per enabled section.
        oeb_n = 3'b000; oea = 3'b111;
        #1;
        if (b_drive !== 7'h7F || ao_out !== ~b_in || ao_drive !== 3'b111)
            $fatal(1, "2041 simultaneous transfer with all sections enabled");
        // Shared OEB disables every section at once.
        oeb = 1'b0;
        #1;
        if (b_drive !== 7'h00 || ao_out !== ~b_in)
            $fatal(1, "2041 shared oeb low must release all B lines");

        $display("PASS: tb_ttl_74x2041");
        $finish;
    end
endmodule
