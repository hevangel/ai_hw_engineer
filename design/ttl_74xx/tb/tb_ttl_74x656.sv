`timescale 1ns/1ps
module tb_ttl_74x656;
    logic [7:0] d_in;
    logic parity_in;
    logic [2:0] oe_n;
    logic [7:0] q_out;
    logic q_drive, po, po_n, parity_drive;
    logic expected_drive, expected_po, expected_po_n;
    logic [7:0] expected_q;
    int errors, d_value, parity_value, enable_value, bit_index, high_count;

    ttl_74x656 dut (.*);

    initial begin
        errors = 0;
        for (d_value = 0; d_value < 256; d_value = d_value + 1) begin
            for (parity_value = 0; parity_value < 2; parity_value = parity_value + 1) begin
                for (enable_value = 0; enable_value < 8; enable_value = enable_value + 1) begin
                    d_in = d_value[7:0];
                    parity_in = parity_value[0];
                    oe_n = enable_value[2:0];
                    #1;
                    high_count = parity_value;
                    for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                        high_count = high_count + d_in[bit_index];
                    expected_drive = (enable_value == 0);
                    expected_q = expected_drive ? d_in : 8'h00;
                    expected_po = expected_drive && ((high_count % 2) != 0);
                    expected_po_n = expected_drive && ((high_count % 2) == 0);
                    if (q_drive !== expected_drive || parity_drive !== expected_drive ||
                        q_out !== expected_q || po !== expected_po || po_n !== expected_po_n)
                        errors = errors + 1;
                end
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x656: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x656");
        $finish;
    end
endmodule
