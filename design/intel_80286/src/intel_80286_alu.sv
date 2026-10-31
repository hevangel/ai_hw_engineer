// Intel 210498-005, section 3.3 and Appendix B: integer arithmetic and logic.
module intel_80286_alu (
    input logic [2:0] operation_i,
    input logic wide_i,
    input logic [15:0] lhs_i, rhs_i, flags_i,
    output logic [15:0] value_o, flags_o
);
    logic [15:0] lhs, rhs;
    logic [16:0] arithmetic;
    logic subtracting, with_carry, arithmetic_op;
    logic sign_lhs, sign_rhs, sign_value;
    always_comb begin
        lhs = wide_i ? lhs_i : {8'h00,lhs_i[7:0]};
        rhs = wide_i ? rhs_i : {8'h00,rhs_i[7:0]};
        subtracting = operation_i == 3 || operation_i == 5 || operation_i == 7;
        with_carry = (operation_i == 2 || operation_i == 3) && flags_i[0];
        arithmetic_op = operation_i == 0 || operation_i == 2 || subtracting;
        if (subtracting)
            arithmetic = {1'b0,lhs} - {1'b0,rhs} - {16'h0000,with_carry};
        else
            arithmetic = {1'b0,lhs} + {1'b0,rhs} + {16'h0000,with_carry};
        case (operation_i)
            1: value_o = lhs | rhs;
            4: value_o = lhs & rhs;
            6: value_o = lhs ^ rhs;
            default: value_o = arithmetic[15:0];
        endcase
        if (!wide_i) value_o[15:8] = 0;
        sign_lhs = wide_i ? lhs[15] : lhs[7];
        sign_rhs = wide_i ? rhs[15] : rhs[7];
        sign_value = wide_i ? value_o[15] : value_o[7];
        flags_o = flags_i;
        flags_o[7] = sign_value;
        flags_o[6] = value_o == 0;
        flags_o[2] = ~^value_o[7:0];
        flags_o[0] = arithmetic_op && (wide_i ? arithmetic[16] : arithmetic[8]);
        flags_o[11] = arithmetic_op && (sign_lhs ^ sign_value) &&
                      (subtracting ? (sign_lhs ^ sign_rhs) : !(sign_lhs ^ sign_rhs));
        // ASSUMPTION: A3. Preserve AF where Intel leaves it undefined.
        if (arithmetic_op) flags_o[4] = lhs[4] ^ rhs[4] ^ value_o[4];
    end
endmodule
