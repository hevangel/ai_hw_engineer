// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1181.md.
// =============================================================================
// ttl_74x1181 - 4-bit arithmetic logic unit / function generator
//
// Original part number : 74x1181 (SN74AS1181)
// Datasheet reference  : TI SN54AS1181/SN74AS1181 (D1915, May 1985); function
//                        table per the SN74181 family (Fairchild DM74LS181).
//
// Function
// --------
// A member of the '181 ALU family (a speed grade). It has the identical pin set
// to the '181/'881 (operand inputs, S0-S3 function select, mode M, carry Cn, F
// outputs, Cn+4, A=B, and active-low carry-propagate/generate P/G) and the same
// 16-arithmetic / 16-logic function table. The datasheet's own addition-time
// table groups 'AS1181 with 'AS181A and 'AS882, confirming functional identity.
//
// Implemented active-high (matching ttl_74x181 and ttl_74x881); the 'AS1181
// datasheet labels the operand/F pins active-low (the same silicon used in the
// active-low convention — present complemented operands to obtain the
// active-low column of the '181 function table).
//
//   M = 1 : 16 logic functions of A, B selected by S
//   M = 0 : 16 arithmetic functions (Cn added), selected by S
//
// FPGA notes
// ----------
// Pure combinational. Self-contained (replicates the '181 logic so the chip
// builds standalone). Identical function to ttl_74x181 / ttl_74x881.
//
// Pin mapping (24-pin, datasheet active-low labels): /B0=1, /A0=2, S3=3, S2=4,
// S1=5, S0=6, Cn=7, M=8, /F0=9, /F1=10, /F2=11, GND=12, /F3=13, A=B=14, /P=15,
// Cn+4=16, /G=17, /A3=18, /B3=19, /A2=20, /B2=21, /A1=22, /B1=23, Vcc=24.
// (Ports here are active-high; see README.)
//
// Unsupported physical behavior
// -----------------------------
// None beyond electrical drive/timing. Carry look-ahead P/G modeled logically.
// =============================================================================

module ttl_74x1181 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic [3:0] s,
    input  logic       m,        // 1 = logic, 0 = arithmetic
    input  logic       cn,       // carry in (active high)
    output logic [3:0] f,
    output logic       cn_p_4,   // carry out (active high)
    output logic       a_eq_b,
    output logic       p_n,      // carry propagate (active low)
    output logic       g_n       // carry generate (active low)
);
    logic [4:0] arith;
    logic [3:0] logic_f;

    always_comb begin
        case (s)
            4'h0: logic_f = ~a;
            4'h1: logic_f = ~(a | b);
            4'h2: logic_f = (~a) & b;
            4'h3: logic_f = 4'h0;
            4'h4: logic_f = ~(a & b);
            4'h5: logic_f = ~b;
            4'h6: logic_f = a ^ b;
            4'h7: logic_f = a & (~b);
            4'h8: logic_f = (~a) | b;
            4'h9: logic_f = ~(a ^ b);
            4'hA: logic_f = b;
            4'hB: logic_f = a & b;
            4'hC: logic_f = 4'hF;
            4'hD: logic_f = a | (~b);
            4'hE: logic_f = a | b;
            4'hF: logic_f = a;
            default: logic_f = 4'h0;
        endcase
    end

    always_comb begin
        case (s)
            4'h0: arith = {1'b0, a} + {4'b0, cn};
            4'h1: arith = {1'b0, (a | b)} + {4'b0, cn};
            4'h2: arith = {1'b0, (a | (~b))} + {4'b0, cn};
            4'h3: arith = 5'h1F + {4'b0, cn};
            4'h4: arith = {1'b0, a} + {1'b0, (a & (~b))} + {4'b0, cn};
            4'h5: arith = {1'b0, (a | b)} + {1'b0, (a & (~b))} + {4'b0, cn};
            4'h6: arith = {1'b0, a} + {1'b0, (~b)} + {4'b0, cn};
            4'h7: arith = {1'b0, (a & (~b))} + 5'h1F + {4'b0, cn};
            4'h8: arith = {1'b0, a} + {1'b0, (a & b)} + {4'b0, cn};
            4'h9: arith = {1'b0, a} + {1'b0, b} + {4'b0, cn};
            4'hA: arith = {1'b0, (a | (~b))} + {1'b0, (a & b)} + {4'b0, cn};
            4'hB: arith = {1'b0, (a & b)} + 5'h1F + {4'b0, cn};
            4'hC: arith = {1'b0, a} + {1'b0, a} + {4'b0, cn};
            4'hD: arith = {1'b0, (a | b)} + {1'b0, a} + {4'b0, cn};
            4'hE: arith = {1'b0, (a | (~b))} + {1'b0, a} + {4'b0, cn};
            4'hF: arith = {1'b0, a} + 5'h1F + {4'b0, cn};
            default: arith = 5'h00;
        endcase
    end

    assign f      = m ? logic_f : arith[3:0];
    assign cn_p_4 = m ? 1'b1 : arith[4];
    assign a_eq_b = (f == 4'hF);
    assign p_n    = ~|f;
    assign g_n    = ~(arith[4]);
endmodule
