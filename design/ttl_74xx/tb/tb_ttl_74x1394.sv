`timescale 1ns/1ps
module tb_ttl_74x1394;
    logic [1:0] a_in;
    logic [1:0] b_bus_in;
    logic oeab_n;
    logic oeby_n;
    logic tc;
    logic erc;
    logic [1:0] b_output_enable;
    logic [1:0] b_output_data;
    logic [1:0] y_output_enable;
    logic [1:0] y_output_data;
    logic b_edge_fast;
    int a_code;
    int b_code;
    int code;

    ttl_74x1394 dut (.*);

    initial begin
        for (a_code = 0; a_code < 4; a_code = a_code + 1) begin
            a_in = a_code[1:0];
            for (b_code = 0; b_code < 4; b_code = b_code + 1) begin
                b_bus_in = b_code[1:0];
                for (code = 0; code < 16; code = code + 1) begin
                    tc = code[0];
                    oeab_n = code[1];
                    oeby_n = code[2];
                    erc = code[3];
                    #1;
                    if (b_output_enable !== {2{~oeab_n}}
                        || b_output_data !== (tc ? a_in : ~a_in)
                        || y_output_enable !== {2{~oeby_n}}
                        || y_output_data !== (tc ? b_bus_in : ~b_bus_in)
                        || b_edge_fast !== erc)
                        $fatal(1, "1394 mode or data mismatch a=%0d b=%0d ctrl=%0d", a_code, b_code, code);
                end
            end
        end
        $display("PASS: tb_ttl_74x1394 SN74GTLP1394 control modes, polarity, feedback, and ERC table");
        $finish;
    end
endmodule
