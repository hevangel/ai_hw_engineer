`timescale 1ns/1ps
module tb_ttl_74x2040;
    logic       oea, oeb, oeb_n;
    logic [7:0] ai_in, b_in;
    logic [7:0] ao_out, b_out, b_drive;
    logic       ao_drive;
    logic [7:0] exp_ao, exp_b;

    ttl_74x2040 dut(.*);

    initial begin
        // Exhaustive enable sweep (all eight OEA/OEB/OEB_n combinations)
        // across four split-I/O and bus vectors, including open-collector
        // release for all-zero and all-one A inputs.
        for (int e = 0; e < 8; e++) begin
            oea = e[2]; oeb = e[1]; oeb_n = e[0];
            ai_in = 8'hA5; b_in = 8'h3C;
            #1;
            exp_ao = oea ? ~b_in : 8'h00;
            exp_b = (oeb && !oeb_n) ? ai_in : 8'h00;
            if (ao_drive !== oea || ao_out !== exp_ao ||
                b_drive !== exp_b || b_out !== 8'h00)
                $fatal(1, "2040 enable sweep vector 1, e=%0d", e);
            ai_in = 8'h00;                      // nothing to sink: all released
            #1;
            if (b_drive !== 8'h00 || b_out !== 8'h00)
                $fatal(1, "2040 all-zero AI must release every B line, e=%0d", e);
            ai_in = 8'hFF;                      // every line sunk while enabled
            #1;
            exp_b = (oeb && !oeb_n) ? 8'hFF : 8'h00;
            if (b_drive !== exp_b)
                $fatal(1, "2040 all-one AI must sink every line, e=%0d", e);
            ai_in = 8'h5A;
            b_in = 8'hC3;
            #1;
            exp_ao = oea ? ~b_in : 8'h00;
            exp_b = (oeb && !oeb_n) ? ai_in : 8'h00;
            if (ao_drive !== oea || ao_out !== exp_ao || b_drive !== exp_b)
                $fatal(1, "2040 enable sweep vector 2, e=%0d", e);
        end

        // Direction independence: AO readback keeps tracking the bus while
        // the B port is disabled, and vice versa.
        oea = 1'b1; oeb = 1'b0; oeb_n = 1'b0;
        ai_in = 8'hF0; b_in = 8'h96;
        #1;
        if (ao_out !== ~b_in || b_drive !== 8'h00)
            $fatal(1, "2040 B-to-A must work while the B port is off");
        oeb = 1'b1; oea = 1'b0;
        #1;
        if (ao_out !== 8'h00 || b_drive !== ai_in)
            $fatal(1, "2040 A-to-B must work while AO is off");
        // Full simultaneous transfer (function table last row).
        oea = 1'b1;
        #1;
        if (ao_out !== ~b_in || b_drive !== ai_in || ao_drive !== 1'b1)
            $fatal(1, "2040 simultaneous A-bar and B-bar transfer");

        $display("PASS: tb_ttl_74x2040");
        $finish;
    end
endmodule
