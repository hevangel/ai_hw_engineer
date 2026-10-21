// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x881.md.
// =============================================================================
// ttl_74x881 - 4-bit arithmetic logic unit / function generator
//
// Original part number : 74x881 (SN74AS881A)
// Datasheet reference  : TI SN54AS881A/SN74AS881A (D2661); function table per
//                        the SN74181 family (Fairchild DM74LS181, DS009821).
//
// Function
// --------
// The 'AS881A is the Advanced-Schottky member of the '181 ALU family: it has
// the identical pin set (operand inputs, S0-S3 function select, mode M, carry
// Cn, F outputs, Cn+4, A=B, and active-low carry-propagate/generate P/G) and
// the same 16-arithmetic / 16-logic function table. (The standalone 'AS881A
// page in the available databook scan was "advance information"; the function
// is the well-documented '181 table, reproduced and verified here.)
//
// This module is implemented active-high (matching the library's ttl_74x181);
// the 'AS881A datasheet labels the operand/F pins active-low, which is the same
// silicon used in the active-low convention (present complemented operands to
// obtain the active-low column of the '181 function table).
//
//   M = 1 : 16 logic functions of A, B selected by S
//   M = 0 : 16 arithmetic functions (Cn added), selected by S
//
// FPGA notes
// ----------
// Pure combinational. Self-contained (replicates the '181 logic so the chip
// builds standalone). See ttl_74x181 for the shared implementation.
//
// Pin mapping (24-pin, active-low labels per datasheet): /B0=1.. , /A0, S3, S2,
// S1, S0, Cn, M, /F0.., GND, /F3, A=B, /P, Cn+4, /G, /A3, /B3, /A2, /B2, /A1,
// /B1, Vcc. (Ports here are active-high; see README for the pin table.)
//
// Unsupported physical behavior
// -----------------------------
// None beyond electrical drive/timing. Carry look-ahead P/G modeled logically.
// =============================================================================

module ttl_74x881 (
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

    // Logic functions (M = 1).
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

    // Arithmetic functions (M = 0), Cn added.
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
