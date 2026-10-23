`timescale 1ns/1ps
module tb_ttl_74x1395;
    logic [1:0] a_in;
    logic [1:0] b_bus_in;
    logic [1:0] oeab_n;
    logic [1:0] oeby_n;
    logic [1:0] tc;
    logic erc;
    logic [1:0] b_output_enable;
    logic [1:0] b_output_data;
    logic [1:0] y_output_enable;
    logic [1:0] y_output_data;
    logic b_edge_fast;
    int a_code;
    int b_code;
    int code;

    ttl_74x1395 dut (.*);

    initial begin
        for (a_code = 0; a_code < 4; a_code = a_code + 1) begin
            a_in = a_code[1:0];
            for (b_code = 0; b_code < 4; b_code = b_code + 1) begin
                b_bus_in = b_code[1:0];
                for (code = 0; code < 2048; code = code + 1) begin
                    tc = code[1:0];
                    oeab_n = code[3:2];
                    oeby_n = code[5:4];
                    erc = code[6];
                    #1;
                    if (b_output_enable !== ~oeab_n
                        || b_output_data !== (a_in ^ ~tc)
                        || y_output_enable !== ~oeby_n
                        || y_output_data !== (b_bus_in ^ ~tc)
                        || b_edge_fast !== ~erc)
                        $fatal(1, "1395 independent lane mode/data mismatch a=%0d b=%0d ctrl=%0d", a_code, b_code, code);
                end
            end
        end
        $display("PASS: tb_ttl_74x1395 SN74GTLP1395 all independent per-lane controls, polarity, feedback, and ERC");
        $finish;
    end
endmodule
