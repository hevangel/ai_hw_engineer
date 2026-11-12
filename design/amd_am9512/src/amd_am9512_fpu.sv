`timescale 1ns/1ps
// Parameterized Am9512 floating-point unit for one precision.
// MANT_W includes the hidden leading one.  The unit implements add, subtract,
// multiply and divide with round-to-nearest-even and the documented status
// bits.  It is a functional reconstruction, not recovered AMD microcode.
module amd_am9512_fpu #(
    parameter int MANT_W = 24,
    parameter int EXP_W = 8,
    parameter int BIAS = 127
) (
    input  logic clk_i,
    input  logic reset_i,
    input  logic start_i,
    input  logic [1:0] op_i,       // 0 add, 1 subtract, 2 multiply, 3 divide
    input  logic [MANT_W+EXP_W-1:0] a_i,  // TOS
    input  logic [MANT_W+EXP_W-1:0] b_i,  // NOS
    output logic done_o,
    output logic busy_o,
    output logic [MANT_W+EXP_W-1:0] result_o,
    output logic [4:0] status_o    // {S,Z,U,V,D}
);
    localparam int FRAC_W = MANT_W - 1;
    localparam int WORD_W = MANT_W + EXP_W;
    localparam int ACC_W = MANT_W + 3;       // hidden bit + fraction + G,R,S
    localparam int DIV_DW = MANT_W;
    localparam int DIV_QW = 2 * MANT_W + 4;
    localparam int DIV_NW = DIV_QW;
    localparam int SUM_W = ACC_W + 1;
    localparam int PROD_W = 2 * MANT_W;

    localparam logic [1:0] OP_ADD = 2'd0;
    localparam logic [1:0] OP_SUB = 2'd1;
    localparam logic [1:0] OP_MUL = 2'd2;
    localparam logic [1:0] OP_DIV = 2'd3;

    localparam logic [WORD_W+4:0] ZERO_RESULT = {
        {WORD_W{1'b0}}, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0
    };

    logic [WORD_W-1:0] a_q, b_q;
    logic [WORD_W-1:0] result_q;
    logic [4:0] status_q;
    logic [1:0] state;
    localparam logic [1:0] ST_IDLE = 2'd0;
    localparam logic [1:0] ST_DIV = 2'd1;
    localparam logic [1:0] ST_DONE = 2'd2;

    logic div_start, div_busy, div_done;
    logic [DIV_QW-1:0] div_q;
    logic [DIV_DW-1:0] div_rem;
    logic [MANT_W-1:0] a_mag, b_mag;
    logic [WORD_W+4:0] div_result;

    assign a_mag = {1'b1, a_q[FRAC_W-1:0]};
    assign b_mag = {1'b1, b_q[FRAC_W-1:0]};

    function automatic integer leading_one_index(input logic [DIV_QW-1:0] value);
        integer i;
        begin
            leading_one_index = -1;
            for (i = DIV_QW - 1; i >= 0; i = i - 1)
                if (value[i] && leading_one_index < 0)
                    leading_one_index = i;
        end
    endfunction

    // Round an accumulator whose hidden bit is at bit MANT_W+2.  Bits 2,1,0
    // are guard, round and sticky.  The result vector is
    // {result, S, Z, U, V, D}.
    function automatic logic [WORD_W+4:0] round_pack(
        input logic [ACC_W-1:0] acc,
        input integer exp_biased,
        input logic sign
    );
        logic [ACC_W:0] rounded;
        logic [WORD_W-1:0] result;
        logic s, z, u, v;
        integer e;
        begin
            rounded = {1'b0, acc} + 4;
            // Round to even: add one at the guard position, then clear the
            // retained LSB when the guard/round/sticky bits are all zero.
            if (rounded[2:0] == 3'b000)
                rounded[3] = 1'b0;
            e = exp_biased;
            if (rounded[ACC_W]) begin
                rounded = rounded >> 1;
                rounded[0] = 1'b0;
                e = e + 1;
            end
            s = 1'b0;
            z = 1'b1;
            u = 1'b0;
            v = 1'b0;
            result = {WORD_W{1'b0}};
            if (rounded[MANT_W+2]) begin
                s = sign;
                z = (rounded[MANT_W+2:3] == {MANT_W{1'b0}});
                if (e < 1) begin
                    u = 1'b1;
                    s = 1'b0;
                    z = 1'b1;
                    result = {WORD_W{1'b0}};
                end else if (e > (2**EXP_W - 1)) begin
                    v = 1'b1;
                    result = {sign, e[EXP_W-1:0], rounded[MANT_W+1:3]};
                end else begin
                    result = {sign, e[EXP_W-1:0], rounded[MANT_W+1:3]};
                end
            end
            round_pack = {result, s, z, u, v, 1'b0};
        end
    endfunction

    // Return an existing packed word with its documented status bits.
    function automatic logic [WORD_W+4:0] pack_existing(
        input logic [WORD_W-1:0] word,
        input logic divide
    );
        logic [EXP_W-1:0] exp;
        logic zero;
        begin
            exp = word[FRAC_W +: EXP_W];
            zero = (exp == {EXP_W{1'b0}});
            pack_existing = {
                zero ? {WORD_W{1'b0}} : word,
                zero ? 1'b0 : word[WORD_W-1],
                zero,
                1'b0,
                1'b0,
                divide
            };
        end
    endfunction

    function automatic logic [WORD_W+4:0] add_subtract(
        input logic [WORD_W-1:0] a,
        input logic [WORD_W-1:0] b,
        input logic subtract
    );
        logic sa, sb, x_sign, y_sign;
        logic [EXP_W-1:0] ea, eb;
        logic [MANT_W-1:0] ma, mb;
        logic a_zero, b_zero;
        integer exp_max, shift, lead, norm;
        logic [ACC_W-1:0] x_ext, y_ext, y_full;
        logic [SUM_W-1:0] sum_ext;
        logic sticky;
        begin
            sa = a[WORD_W-1];
            sb = b[WORD_W-1];
            ea = a[FRAC_W +: EXP_W];
            eb = b[FRAC_W +: EXP_W];
            a_zero = (ea == {EXP_W{1'b0}});
            b_zero = (eb == {EXP_W{1'b0}});
            ma = {1'b1, a[FRAC_W-1:0]};
            mb = {1'b1, b[FRAC_W-1:0]};
            if (subtract)
                sa = ~sa;

            if (a_zero && b_zero) begin
                add_subtract = ZERO_RESULT;
            end else if (a_zero) begin
                add_subtract = pack_existing(b, 1'b0);
            end else if (b_zero) begin
                add_subtract = pack_existing(
                    {(subtract ? ~a[WORD_W-1] : a[WORD_W-1]), a[WORD_W-2:0]}, 1'b0);
            end else begin
                if (ea >= eb) begin
                    exp_max = int'(ea);
                    x_ext = {ma, 3'b000};
                    y_full = {mb, 3'b000};
                    x_sign = sa;
                    y_sign = sb;
                    shift = int'(ea) - int'(eb);
                end else begin
                    exp_max = int'(eb);
                    x_ext = {mb, 3'b000};
                    y_full = {ma, 3'b000};
                    x_sign = sb;
                    y_sign = sa;
                    shift = int'(eb) - int'(ea);
                end

                if (shift == 0) begin
                    y_ext = y_full;
                    sticky = 1'b0;
                end else if (shift >= ACC_W) begin
                    y_ext = {ACC_W{1'b0}};
                    sticky = (y_full != {ACC_W{1'b0}});
                end else begin
                    y_ext = y_full >> shift;
                    sticky = (y_full & (({ACC_W{1'b1}} >> (ACC_W - shift)))) !=
                             {ACC_W{1'b0}};
                end

                if (x_sign == y_sign) begin
                    sum_ext = {1'b0, x_ext} + {1'b0, y_ext};
                    exp_max = exp_max;
                end else if (x_ext >= y_ext) begin
                    sum_ext = {1'b0, x_ext} - {1'b0, y_ext};
                end else begin
                    sum_ext = {1'b0, y_ext} - {1'b0, x_ext};
                    x_sign = y_sign;
                end

                if (sum_ext == {SUM_W{1'b0}}) begin
                    add_subtract = ZERO_RESULT;
                end else begin
                    if (sum_ext[ACC_W]) begin
                        sticky = sticky | sum_ext[0];
                        sum_ext = sum_ext >> 1;
                        sum_ext[0] = 1'b0;
                        exp_max = exp_max + 1;
                    end
                    lead = leading_one_index({{(DIV_QW-SUM_W){1'b0}}, sum_ext});
                    if (lead < 0)
                        lead = 0;
                    if (lead < MANT_W + 2) begin
                        norm = (MANT_W + 2) - lead;
                        sum_ext = sum_ext << norm;
                        exp_max = exp_max - norm;
                    end else if (lead > MANT_W + 2) begin
                        norm = lead - (MANT_W + 2);
                        sticky = sticky | ((sum_ext &
                                 ({SUM_W{1'b1}} >> (SUM_W - norm))) != {SUM_W{1'b0}});
                        sum_ext = sum_ext >> norm;
                        exp_max = exp_max + norm;
                    end
                    add_subtract = round_pack(sum_ext[ACC_W-1:0], exp_max, x_sign);
                end
            end
        end
    endfunction

    function automatic logic [WORD_W+4:0] multiply(
        input logic [WORD_W-1:0] a,
        input logic [WORD_W-1:0] b
    );
        logic sa, sb;
        logic [EXP_W-1:0] ea, eb;
        logic [MANT_W-1:0] ma, mb;
        logic [PROD_W-1:0] prod;
        integer exp_unbiased, lead, e, high;
        logic [MANT_W-1:0] sig;
        logic guard, round, sticky;
        begin
            sa = a[WORD_W-1];
            sb = b[WORD_W-1];
            ea = a[FRAC_W +: EXP_W];
            eb = b[FRAC_W +: EXP_W];
            ma = {1'b1, a[FRAC_W-1:0]};
            mb = {1'b1, b[FRAC_W-1:0]};
            if ((ea == {EXP_W{1'b0}}) || (eb == {EXP_W{1'b0}})) begin
                multiply = ZERO_RESULT;
            end else begin
                prod = ma * mb;
                exp_unbiased = int'(ea) + int'(eb) - 2*BIAS;
                lead = leading_one_index({{(DIV_QW-PROD_W){1'b0}}, prod});
                e = lead - (2 * MANT_W - 2);
                exp_unbiased = exp_unbiased + e;
                sig = prod[lead -: MANT_W];
                high = lead - MANT_W;
                guard = (high >= 0) ? prod[high] : 1'b0;
                round = (high - 1 >= 0) ? prod[high-1] : 1'b0;
                sticky = 1'b0;
                for (int i = 0; i < PROD_W; i = i + 1)
                    if (i <= high - 2)
                        sticky = sticky | prod[i];
                multiply = round_pack({sig, guard, round, sticky},
                                      exp_unbiased + BIAS, sa ^ sb);
            end
        end
    endfunction

    function automatic logic [WORD_W+4:0] divide_result(
        input logic [DIV_QW-1:0] q,
        input logic [DIV_DW-1:0] rem,
        input logic [WORD_W-1:0] a,
        input logic [WORD_W-1:0] b
    );
        logic sa, sb;
        logic [EXP_W-1:0] ea, eb;
        integer exp_unbiased, lead, e, high;
        logic [MANT_W-1:0] sig;
        logic guard, round, sticky;
        begin
            sa = a[WORD_W-1];
            sb = b[WORD_W-1];
            ea = a[FRAC_W +: EXP_W];
            eb = b[FRAC_W +: EXP_W];
            if (ea == {EXP_W{1'b0}}) begin
                divide_result = pack_existing(b, 1'b1);
            end else if (eb == {EXP_W{1'b0}}) begin
                divide_result = ZERO_RESULT;
            end else begin
                lead = leading_one_index(q);
                e = lead - (MANT_W + 3);
                exp_unbiased = int'(eb) - int'(ea) + e;
                sig = q[lead -: MANT_W];
                high = lead - MANT_W;
                guard = (high >= 0) ? q[high] : 1'b0;
                round = (high - 1 >= 0) ? q[high-1] : 1'b0;
                sticky = (rem != {DIV_DW{1'b0}});
                for (int i = 0; i < DIV_QW; i = i + 1)
                    if (i <= high - 2)
                        sticky = sticky | q[i];
                divide_result = round_pack({sig, guard, round, sticky},
                                           exp_unbiased + BIAS, sa ^ sb);
            end
        end
    endfunction

    logic [WORD_W+4:0] comb_result;
    always_comb begin
        comb_result = ZERO_RESULT;
        if (op_i == OP_ADD)
            comb_result = add_subtract(a_i, b_i, 1'b0);
        else if (op_i == OP_SUB)
            comb_result = add_subtract(a_i, b_i, 1'b1);
        else if (op_i == OP_MUL)
            comb_result = multiply(a_i, b_i);
    end

    amd_am9512_divider #(
        .DIV_QW(DIV_QW),
        .DIV_DW(DIV_DW),
        .DIV_NW(DIV_NW)
    ) divider (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .start_i(div_start),
        .numerator_i({{(DIV_NW-(2*MANT_W+3)){1'b0}}, b_mag, {(MANT_W+3){1'b0}}}),
        .denominator_i({{(DIV_DW-MANT_W){1'b0}}, a_mag}),
        .busy_o(div_busy),
        .done_o(div_done),
        .quotient_o(div_q),
        .remainder_o(div_rem)
    );

    always_comb begin
        div_result = divide_result(div_q, div_rem, a_q, b_q);
    end

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            state <= ST_IDLE;
            done_o <= 1'b0;
            busy_o <= 1'b0;
            result_q <= {WORD_W{1'b0}};
            status_q <= 5'd0;
            a_q <= {WORD_W{1'b0}};
            b_q <= {WORD_W{1'b0}};
            div_start <= 1'b0;
        end else begin
            done_o <= 1'b0;
            div_start <= 1'b0;
            case (state)
                ST_IDLE: begin
                    busy_o <= 1'b0;
                    if (start_i) begin
                        a_q <= a_i;
                        b_q <= b_i;
                        if (op_i == OP_DIV) begin
                            div_start <= 1'b1;
                            busy_o <= 1'b1;
                            state <= ST_DIV;
                        end else begin
                            result_q <= comb_result[WORD_W+4:5];
                            status_q <= comb_result[4:0];
                            done_o <= 1'b1;
                            state <= ST_DONE;
                        end
                    end
                end
                ST_DIV: begin
                    busy_o <= div_busy;
                    if (div_done) begin
                        result_q <= div_result[WORD_W+4:5];
                        status_q <= div_result[4:0];
                        done_o <= 1'b1;
                        busy_o <= 1'b0;
                        state <= ST_DONE;
                    end
                end
                ST_DONE: begin
                    busy_o <= 1'b0;
                    state <= ST_IDLE;
                end
                default: begin
                    state <= ST_IDLE;
                    busy_o <= 1'b0;
                end
            endcase
        end
    end

    assign result_o = result_q;
    assign status_o = status_q;
endmodule
