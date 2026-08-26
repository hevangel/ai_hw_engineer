// Independent combinational reference properties for the SN74LS181.
module alu_74181_props (
    input logic [3:0] a,
    input logic [3:0] b,
    input logic [3:0] s,
    input logic       m,
    input logic       cn,
    input logic [3:0] f,
    input logic       cn4,
    input logic       a_eq_b,
    input logic       p_bar,
    input logic       g_bar
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

    logic [4:0] arithmetic_result;
    logic [3:0] expected_f;
    logic [3:0] expected_x;
    logic [3:0] expected_y;
    logic       expected_cn4;
    logic       expected_a_eq_b;
    logic       expected_p_bar;
    logic       expected_g_bar;

    always_comb begin
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

        assert ({f, cn4, a_eq_b, p_bar, g_bar} ==
                {expected_f, expected_cn4, expected_a_eq_b,
                 expected_p_bar, expected_g_bar});

        cover (m == 1'b0);
        cover (m == 1'b1);
        cover (cn4 == 1'b0);
        cover (cn4 == 1'b1);
        cover (p_bar == 1'b0);
        cover (p_bar == 1'b1);
        cover (g_bar == 1'b0);
        cover (g_bar == 1'b1);
        cover (a_eq_b == 1'b0);
        cover (a_eq_b == 1'b1);
    end

endmodule

module alu_74181_formal (
    input logic       clk,
    input logic [3:0] a,
    input logic [3:0] b,
    input logic [3:0] s,
    input logic       m,
    input logic       cn
);
    logic [3:0] sampled_a;
    logic [3:0] sampled_b;
    logic [3:0] sampled_s;
    logic       sampled_m;
    logic       sampled_cn;
    logic [3:0] f;
    logic       cn4;
    logic       a_eq_b;
    logic       p_bar;
    logic       g_bar;

    // An unconstrained sampling stage gives BMC a state boundary without
    // restricting the 14 functional inputs. Its initial state is also
    // symbolic, so every input assignment is checked from frame zero.
    always_ff @(posedge clk) begin
        sampled_a <= a;
        sampled_b <= b;
        sampled_s <= s;
        sampled_m <= m;
        sampled_cn <= cn;
    end

    alu_74181 dut (
        .a      (sampled_a),
        .b      (sampled_b),
        .s      (sampled_s),
        .m      (sampled_m),
        .cn     (sampled_cn),
        .f      (f),
        .cn4    (cn4),
        .a_eq_b (a_eq_b),
        .p_bar  (p_bar),
        .g_bar  (g_bar)
    );

    alu_74181_props properties (
        .a      (sampled_a),
        .b      (sampled_b),
        .s      (sampled_s),
        .m      (sampled_m),
        .cn     (sampled_cn),
        .f      (f),
        .cn4    (cn4),
        .a_eq_b (a_eq_b),
        .p_bar  (p_bar),
        .g_bar  (g_bar)
    );

endmodule
