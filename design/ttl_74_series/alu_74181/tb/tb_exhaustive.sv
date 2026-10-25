`timescale 1ns/1ps

module tb_exhaustive;

    logic [3:0] a;
    logic [3:0] b;
    logic [3:0] s;
    logic       m;
    logic       cn;
    logic [3:0] f;
    logic       cn4;
    logic       a_eq_b;
    logic       p_bar;
    logic       g_bar;

    int vector_count;
    int field_check_count;
    int failed_vector_count;
    int failed_field_count;

    alu_74181 dut (
        .a      (a),
        .b      (b),
        .s      (s),
        .m      (m),
        .cn     (cn),
        .f      (f),
        .cn4    (cn4),
        .a_eq_b (a_eq_b),
        .p_bar  (p_bar),
        .g_bar  (g_bar)
    );

    function automatic logic [3:0] reference_logic(
        input logic [3:0] value_a,
        input logic [3:0] value_b,
        input logic [3:0] select
    );
        begin
            case (select)
                4'h0: reference_logic = ~value_a;
                4'h1: reference_logic = ~(value_a | value_b);
                4'h2: reference_logic = ~value_a & value_b;
                4'h3: reference_logic = 4'h0;
                4'h4: reference_logic = ~(value_a & value_b);
                4'h5: reference_logic = ~value_b;
                4'h6: reference_logic = value_a ^ value_b;
                4'h7: reference_logic = value_a & ~value_b;
                4'h8: reference_logic = ~value_a | value_b;
                4'h9: reference_logic = ~(value_a ^ value_b);
                4'ha: reference_logic = value_b;
                4'hb: reference_logic = value_a & value_b;
                4'hc: reference_logic = 4'hf;
                4'hd: reference_logic = value_a | ~value_b;
                4'he: reference_logic = value_a | value_b;
                4'hf: reference_logic = value_a;
                default: reference_logic = 4'hx;
            endcase
        end
    endfunction

    function automatic logic [4:0] reference_arithmetic(
        input logic [3:0] value_a,
        input logic [3:0] value_b,
        input logic [3:0] select,
        input logic       carry_n
    );
        logic [4:0] base_value;
        begin
            case (select)
                4'h0: base_value = {1'b0, value_a};
                4'h1: base_value = {1'b0, value_a | value_b};
                4'h2: base_value = {1'b0, value_a | ~value_b};
                4'h3: base_value = 5'h0f;
                4'h4: base_value = {1'b0, value_a} + {1'b0, value_a & ~value_b};
                4'h5: base_value = {1'b0, value_a | value_b} +
                                     {1'b0, value_a & ~value_b};
                4'h6: base_value = {1'b0, value_a} + {1'b0, ~value_b};
                4'h7: base_value = {1'b0, value_a & ~value_b} + 5'h0f;
                4'h8: base_value = {1'b0, value_a} + {1'b0, value_a & value_b};
                4'h9: base_value = {1'b0, value_a} + {1'b0, value_b};
                4'ha: base_value = {1'b0, value_a | ~value_b} +
                                     {1'b0, value_a & value_b};
                4'hb: base_value = {1'b0, value_a & value_b} + 5'h0f;
                4'hc: base_value = {1'b0, value_a} + {1'b0, value_a};
                4'hd: base_value = {1'b0, value_a | value_b} + {1'b0, value_a};
                4'he: base_value = {1'b0, value_a | ~value_b} + {1'b0, value_a};
                4'hf: base_value = {1'b0, value_a} + 5'h0f;
                default: base_value = 5'hxx;
            endcase
            reference_arithmetic = base_value + {4'b0000, ~carry_n};
        end
    endfunction

    function automatic logic [3:0] reference_x(
        input logic [3:0] value_a,
        input logic [3:0] value_b,
        input logic [1:0] select_low
    );
        begin
            case (select_low)
                2'b00: reference_x = value_a;
                2'b01: reference_x = value_a | value_b;
                2'b10: reference_x = value_a | ~value_b;
                2'b11: reference_x = 4'hf;
                default: reference_x = 4'hx;
            endcase
        end
    endfunction

    function automatic logic [3:0] reference_y(
        input logic [3:0] value_a,
        input logic [3:0] value_b,
        input logic [1:0] select_high
    );
        begin
            case (select_high)
                2'b00: reference_y = 4'h0;
                2'b01: reference_y = value_a & ~value_b;
                2'b10: reference_y = value_a & value_b;
                2'b11: reference_y = value_a;
                default: reference_y = 4'hx;
            endcase
        end
    endfunction

    task automatic check_current_vector;
        logic [4:0] arithmetic_result;
        logic [3:0] expected_f;
        logic [3:0] expected_x;
        logic [3:0] expected_y;
        logic       expected_cn4;
        logic       expected_a_eq_b;
        logic       expected_p_bar;
        logic       expected_g_bar;
        int         vector_field_failures;
        begin
            arithmetic_result = reference_arithmetic(a, b, s, cn);
            expected_f = m ? reference_logic(a, b, s) : arithmetic_result[3:0];
            expected_x = reference_x(a, b, s[1:0]);
            expected_y = reference_y(a, b, s[3:2]);
            expected_cn4 = m ? 1'b1 : ~arithmetic_result[4];
            expected_a_eq_b = &expected_f;
            expected_p_bar = ~&expected_x;
            expected_g_bar = ~(expected_y[3] |
                               (expected_x[3] & expected_y[2]) |
                               (expected_x[3] & expected_x[2] & expected_y[1]) |
                               (expected_x[3] & expected_x[2] &
                                expected_x[1] & expected_y[0]));

            vector_count++;
            field_check_count += 5;
            vector_field_failures = 0;

            if (f !== expected_f) begin
                failed_field_count++;
                vector_field_failures++;
            end
            if (cn4 !== expected_cn4) begin
                failed_field_count++;
                vector_field_failures++;
            end
            if (a_eq_b !== expected_a_eq_b) begin
                failed_field_count++;
                vector_field_failures++;
            end
            if (p_bar !== expected_p_bar) begin
                failed_field_count++;
                vector_field_failures++;
            end
            if (g_bar !== expected_g_bar) begin
                failed_field_count++;
                vector_field_failures++;
            end

            if (vector_field_failures != 0) begin
                if (failed_vector_count < 20) begin
                    $display("FAIL A=%h B=%h S=%h M=%b Cn=%b actual=%h%b%b%b%b expected=%h%b%b%b%b",
                             a, b, s, m, cn, f, cn4, a_eq_b, p_bar, g_bar,
                             expected_f, expected_cn4, expected_a_eq_b,
                             expected_p_bar, expected_g_bar);
                end
                failed_vector_count++;
            end
        end
    endtask

    initial begin
        vector_count = 0;
        field_check_count = 0;
        failed_vector_count = 0;
        failed_field_count = 0;
        a = '0;
        b = '0;
        s = '0;
        m = 1'b0;
        cn = 1'b0;

        for (int mode_value = 0; mode_value < 2; mode_value++) begin
            for (int select_value = 0; select_value < 16; select_value++) begin
                for (int carry_value = 0; carry_value < 2; carry_value++) begin
                    for (int a_value = 0; a_value < 16; a_value++) begin
                        for (int b_value = 0; b_value < 16; b_value++) begin
                            m = mode_value[0];
                            s = select_value[3:0];
                            cn = carry_value[0];
                            a = a_value[3:0];
                            b = b_value[3:0];
                            #1;
                            check_current_vector();
                        end
                    end
                end
            end
        end

        $display("74181 exhaustive result: %0d vectors, %0d field checks,",
                 vector_count, field_check_count);
        $display("Failures: %0d vectors, %0d fields", failed_vector_count, failed_field_count);

        if ((vector_count != 16384) || (field_check_count != 81920)) begin
            $fatal(1, "Exhaustive test did not execute the required vector matrix");
        end
        if ((failed_vector_count != 0) || (failed_field_count != 0)) begin
            $fatal(1, "74181 exhaustive test failed");
        end

        $display("TEST PASSED");
        $finish;
    end

endmodule
