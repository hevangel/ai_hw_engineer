`timescale 1ns/1ps
module tb_ttl_74x670;
    logic gw_n, gr_n;
    logic [1:0] wa, ra;
    logic [3:0] d, q;
    logic q_oe_n;
    ttl_74x670 dut(.*);
    int errors;

    task automatic write(input [1:0] addr, input [3:0] data);
        wa = addr; d = data; gw_n = 0; #1; gw_n = 1; #1;
    endtask

    task automatic check_read(input [1:0] addr, input [3:0] exp);
        ra = addr; gr_n = 0; #1;
        if (q !== exp) begin
            errors++; $display("read[%0d] got=%h exp=%h", addr, q, exp);
        end
    endtask

    initial begin
        errors = 0;
        gw_n = 1; gr_n = 1; wa = 0; ra = 0; d = 0; #1;
        if (q_oe_n !== 1) errors++;

        write(2'd0, 4'hA);
        write(2'd1, 4'h5);
        write(2'd2, 4'h3);
        write(2'd3, 4'hC);

        check_read(2'd0, 4'hA);
        check_read(2'd1, 4'h5);
        check_read(2'd2, 4'h3);
        check_read(2'd3, 4'hC);

        // Independence: read cell 0 while writing to cell 3.
        ra = 2'd0; gr_n = 0;
        wa = 2'd3; d = 4'hF; gw_n = 0; #1;
        if (q !== 4'hA) errors++;  // cell 0 still A
        gw_n = 1;
        check_read(2'd3, 4'hF);

        // Output disabled.
        gr_n = 1; #1;
        if (q !== 0 || q_oe_n !== 1) errors++;

        // Transparent write: while /GW low, addressed cell follows D.
        gr_n = 0; ra = 2'd1; wa = 2'd1; gw_n = 0;
        d = 4'h1; #1;
        if (q !== 4'h1) errors++;
        d = 4'h9; #1;
        if (q !== 4'h9) errors++;
        gw_n = 1;
        d = 4'h0; #1;
        if (q !== 4'h9) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x670: %0d errors", errors);
        $display("PASS: tb_ttl_74x670");
        $finish;
    end
endmodule
