// Independent mathematical contracts from Intel 210498-005 sections 3.3/3.4.
// Signed range checks specify overflow; nibble comparisons specify auxiliary
// carry. These do not reuse the implementation's XOR/sign-bit equations.
`ifdef FORMAL
module intel_80286_datapath_props (
    input logic [15:0] lhs, rhs, flags,
    input logic [2:0] operation
);
    for (genvar w=0; w<2; w=w+1) begin : widths
        localparam integer W = w == 0 ? 8 : 16;
        logic [15:0] value, result_flags, shifted;
        logic carry, overflow;
        logic [W:0] a, b, result_unsigned;
        logic signed [W+1:0] sa, sb, result_signed;
        logic [4:0] nibble_rhs;
        logic borrow_in, subtracting, arithmetic;
        intel_80286_alu alu(.operation_i(operation),.wide_i(w != 0),.lhs_i(lhs),.rhs_i(rhs),
                            .flags_i(flags),.value_o(value),.flags_o(result_flags));
        intel_80286_shift shift(.operation_i(operation),.wide_i(w != 0),.carry_i(flags[0]),
                                .value_i(lhs),.value_o(shifted),.carry_o(carry),.overflow_o(overflow));
        always_comb begin
            a = {1'b0,lhs[W-1:0]}; b = {1'b0,rhs[W-1:0]};
            sa = {{2{lhs[W-1]}},lhs[W-1:0]};
            sb = {{2{rhs[W-1]}},rhs[W-1:0]};
            borrow_in = (operation == 2 || operation == 3) && flags[0];
            subtracting = operation == 3 || operation == 5 || operation == 7;
            arithmetic = operation == 0 || operation == 2 || subtracting;
            nibble_rhs = {1'b0,rhs[3:0]} + {4'b0,borrow_in};
            result_unsigned = a + b + {{W{1'b0}},borrow_in};
            result_signed = sa + sb + {{(W+1){1'b0}},borrow_in};
            if (subtracting) begin
                result_unsigned = a - b - {{W{1'b0}},borrow_in};
                result_signed = sa - sb - {{(W+1){1'b0}},borrow_in};
            end
            assert(((result_flags ^ flags) & 16'hf72a) == 0);
            assert(result_flags[6] == (value == 0));
            assert(result_flags[7] == value[W-1]);
            assert(result_flags[2] == ((value[0]+value[1]+value[2]+value[3]+
                                       value[4]+value[5]+value[6]+value[7]) % 2 == 0));
            if (w == 0) assert(value[15:8] == 0 && shifted[15:8] == 0);
            if (arithmetic) begin
                assert(value[W-1:0] == result_unsigned[W-1:0]);
                if (subtracting) begin
                    assert(result_flags[0] == (a < b + {{W{1'b0}},borrow_in}));
                    assert(result_flags[4] == ({1'b0,lhs[3:0]} < nibble_rhs));
                end else begin
                    assert(result_flags[0] == result_unsigned[W]);
                    assert(result_flags[4] == ({1'b0,lhs[3:0]} + nibble_rhs > 31'd15));
                end
                assert(result_flags[11] == (result_signed < -(2**(W-1)) || result_signed > 2**(W-1)-1));
            end else begin
                assert(!result_flags[0] && !result_flags[11]);
                case (operation)
                    1: assert(value[W-1:0] == (lhs[W-1:0] | rhs[W-1:0]));
                    4: assert(value[W-1:0] == (lhs[W-1:0] & rhs[W-1:0]));
                    6: assert(value[W-1:0] == (lhs[W-1:0] ^ rhs[W-1:0]));
                    default: begin end
                endcase
            end
            case (operation)
                0: begin
                    assert(shifted[W-1:0] == {lhs[W-2:0],lhs[W-1]});
                    assert(carry == lhs[W-1]);
                    assert(overflow == (lhs[W-1] != lhs[W-2]));
                end
                1: begin
                    assert(shifted[W-1:0] == {lhs[0],lhs[W-1:1]});
                    assert(carry == lhs[0]);
                    assert(overflow == (lhs[0] != lhs[W-1]));
                end
                2: begin
                    assert(shifted[W-1:0] == {lhs[W-2:0],flags[0]});
                    assert(carry == lhs[W-1]);
                    assert(overflow == (lhs[W-1] != lhs[W-2]));
                end
                3: begin
                    assert(shifted[W-1:0] == {flags[0],lhs[W-1:1]});
                    assert(carry == lhs[0]);
                    assert(overflow == (flags[0] != lhs[W-1]));
                end
                4: begin
                    assert(shifted[W-1:0] == (lhs[W-1:0]*2) % (2**W));
                    assert(carry == lhs[W-1]);
                    assert(overflow == (lhs[W-1] != lhs[W-2]));
                end
                5: begin
                    assert(shifted[W-1:0] == lhs[W-1:0]/2);
                    assert(carry == lhs[0]);
                    assert(overflow == lhs[W-1]);
                end
                7: begin
                    assert(shifted[W-1:0] == {lhs[W-1],lhs[W-1:1]});
                    assert(carry == lhs[0] && !overflow);
                end
                default: begin end
            endcase
            cover(operation == 0 && result_flags[0] && result_flags[11]);
            cover(operation == 3 && flags[0] && result_flags[4]);
            cover(operation == 2 && carry && overflow);
            cover(operation == 7 && lhs[W-1] && shifted[W-1]);
        end
    end
endmodule
`endif
