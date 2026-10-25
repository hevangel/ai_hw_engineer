// Motorola MC6800 — full documented instruction set (197 opcodes).
// Functional-bus core: one bus transfer per clk (spec/spec.md section 3.2).
// Semantics sourced from the Motorola M6800 Programming Reference Manual
// M68PRM(D) Nov 1976: CPX N/V from the high-byte compare with full-16-bit Z
// and C unaffected; shift V = N ^ C after the shift (LSR clears N); DAA
// truth table (A-34); interrupt frame PCL, PCH, IXL, IXH, ACCA, ACCB, CC
// with bits 7-6 set, stored CC keeping the pre-interrupt I, and live I set
// after the push. Oracle: independent Python ISS (scripts/make_isa_vectors.py);
// third-party gate: hakanrw/mc6800 self-checking test programs.
`timescale 1ns/1ps

module motorola_6800 (
    input  logic        clk,
    input  logic        rst_n,
    output logic [15:0] bus_addr,
    input  logic [7:0]  bus_data_i,
    output logic [7:0]  bus_data_o,
    output logic        bus_we,
    output logic        vma_o,
    input  logic        irq_n,     // level, masked by CC.I
    input  logic        nmi_n,     // falling-edge detected
    output logic        halted_o,
    output logic        sync_o,    // instruction boundary (fetch cycle)
    output logic [15:0] pc_o,
    output logic [7:0]  a_o,
    output logic [7:0]  b_o,
    output logic [15:0] ix_o,
    output logic [15:0] sp_o,
    output logic [7:0]  cc_o
);

    // CC bits: 7 6 H I N Z V C; bits 7-6 always read as 1
    localparam int FC = 0, FV = 1, FZ = 2, FN = 3, FI = 4, FH = 5;

    localparam logic [15:0] VEC_IRQ = 16'hFFF8,
                            VEC_SWI = 16'hFFFA,
                            VEC_NMI = 16'hFFFC,
                            VEC_RST = 16'hFFFE;

    typedef enum logic [2:0] {
        M_IMP, M_IMM, M_DIR, M_EXT, M_IND, M_REL
    } mode_e;

    typedef enum logic [6:0] {
        // 8-bit ALU against ACCA/ACCB (acc_q selects)
        O_SUB, O_CMP, O_SBC, O_AND, O_BIT, O_LDA, O_STA,
        O_EOR, O_ADC, O_ORA, O_ADD,
        // 16-bit
        O_LDX, O_CPX, O_LDS, O_STS, O_STX,
        // read-modify-write (memory or accumulator)
        O_NEG, O_COM, O_LSR, O_ROR, O_ASR, O_ASL, O_ROL,
        O_DEC, O_INC, O_TST, O_CLR,
        // inherent
        O_ABA, O_SBA, O_CBA, O_DAA, O_TAB, O_TBA, O_TAP, O_TPA,
        O_TSX, O_TXS, O_INS, O_DES, O_INX, O_DEX,
        O_CLC, O_SEC, O_CLI, O_SEI, O_CLV, O_SEV, O_NOP,
        // flow
        O_JMP, O_JSR, O_BSR, O_RTS, O_RTI, O_WAI, O_SWI,
        O_PSHA, O_PSHB, O_PULA, O_PULB,
        // branches
        O_BRA, O_BHI, O_BLS, O_BCC, O_BCS, O_BNE, O_BEQ,
        O_BVC, O_BVS, O_BPL, O_BMI, O_BGE, O_BLT, O_BGT, O_BLE
    } op_e;

    typedef enum logic [4:0] {
        S_RST_L, S_RST_H, S_FETCH,
        S_IMM, S_DIR, S_EXT_L, S_EXT_H, S_IND, S_REL,
        S_RD, S_RD_H, S_RD_L, S_WR, S_WR_H, S_WR_L,
        S_RMW_R, S_RMW_E, S_RMW_W,
        S_PUSH, S_PULL,
        S_INT_PUSH, S_VEC_L, S_VEC_H, S_WAIT,
        S_JSR1, S_JSR2, S_JSR_GO,
        S_RTS_H, S_RTS_L, S_RTI_PULL
    } state_e;

    state_e      state;
    mode_e       mode;
    op_e         op;
    logic        acc;          // 0 = ACCB, 1 = ACCA (ALU/RMW accumulator ops)
    logic [15:0] pc, ix, sp, ea_q, vec_q, ret_q;
    logic [7:0]  a, b, cc, opcode, data_q, rmw_val, rmw_res_q;
    logic [2:0]  cnt;          // interrupt-push / RTI byte counter
    logic        wai_flag;     // INT_PUSH came from WAI (no live I update)
    logic        nmi_prev, nmi_pend;

    assign pc_o = pc;
    assign a_o  = a;
    assign b_o  = b;
    assign ix_o = ix;
    assign sp_o = sp;
    assign cc_o = cc;

    wire irq_req  = !irq_n && !cc[FI];
    wire int_take = (state == S_FETCH) && (nmi_pend || irq_req);

    assign sync_o   = (state == S_FETCH) && !int_take;
    assign halted_o = (state == S_WAIT);

    // ------------------------------------------------------------------
    // Decoder. Rows 0-7 enumerated; rows 8-F algorithmic on the column
    // (Table 3-1 of the M68PRM: 197 valid codes, 59 unassigned).
    // ------------------------------------------------------------------
    function automatic mode_e f_rowmode(input logic [2:0] row);
        case (row[1:0])
            2'h0:    f_rowmode = M_IMM;
            2'h1:    f_rowmode = M_DIR;
            2'h2:    f_rowmode = M_IND;
            default: f_rowmode = M_EXT;
        endcase
    endfunction    function automatic void f_decode(input logic [7:0] d,
                                     output op_e    o_op,
                                     output mode_e  o_mode,
                                     output logic   o_acc);
        o_op   = O_NOP;
        o_acc  = 1'b0;
        o_mode = M_IMP;
        if (d[7]) begin
            // Rows 8-F: ALU instructions; ACCA rows 8-B, ACCB rows C-F
            o_acc  = ~d[6];   // d[6]=0 selects ACCA (rows 8-B)
            o_mode = f_rowmode(d[6:4]);
            case (d[3:0])
                4'h0: o_op = O_SUB;
                4'h1: o_op = O_CMP;
                4'h2: o_op = O_SBC;
                4'h4: o_op = O_AND;
                4'h5: o_op = O_BIT;
                4'h6: o_op = O_LDA;
                4'h7: o_op = O_STA;
                4'h8: o_op = O_EOR;
                4'h9: o_op = O_ADC;
                4'hA: o_op = O_ORA;
                4'hB: o_op = O_ADD;
                4'hC: if (d[6:4] <= 3'h3) o_op = O_CPX;   // 8C..BC
                4'hD: begin
                    if (d[6:4] == 3'h0) begin             // 8D BSR
                        o_op   = O_BSR;
                        o_mode = M_REL;
                    end else if (d[6:4] == 3'h2 || d[6:4] == 3'h3)
                        o_op = O_JSR;                     // AD, BD
                    // 9D JSR-direct is 6801+; unassigned on the 6800
                end
                4'hE: o_op = (d[6:4] <= 3'h3) ? O_LDS : O_LDX;
                4'hF: begin
                    if (d[6:4] == 3'h0) ;                 // 8F, CF unassigned
                    else if (d[6:4] <= 3'h3) o_op = O_STS;
                    else                     o_op = O_STX;
                end
                default: ;                                // col 3: unassigned
            endcase
            // STA has no immediate form (87, C7 unassigned)
            if (d[3:0] == 4'h7 && (d[6:4] == 3'h0 || d[6:4] == 3'h4))
                o_op = O_NOP;
        end else begin
            case (d)
                8'h01: o_op = O_NOP;
                8'h06: o_op = O_TAP;
                8'h07: o_op = O_TPA;
                8'h08: o_op = O_INX;
                8'h09: o_op = O_DEX;
                8'h0A: o_op = O_CLV;
                8'h0B: o_op = O_SEV;
                8'h0C: o_op = O_CLC;
                8'h0D: o_op = O_SEC;
                8'h0E: o_op = O_CLI;
                8'h0F: o_op = O_SEI;
                8'h10: o_op = O_SBA;
                8'h11: o_op = O_CBA;
                8'h16: o_op = O_TAB;
                8'h17: o_op = O_TBA;
                8'h19: o_op = O_DAA;
                8'h1B: o_op = O_ABA;
                8'h20: begin o_op = O_BRA; o_mode = M_REL; end
                8'h22: begin o_op = O_BHI; o_mode = M_REL; end
                8'h23: begin o_op = O_BLS; o_mode = M_REL; end
                8'h24: begin o_op = O_BCC; o_mode = M_REL; end
                8'h25: begin o_op = O_BCS; o_mode = M_REL; end
                8'h26: begin o_op = O_BNE; o_mode = M_REL; end
                8'h27: begin o_op = O_BEQ; o_mode = M_REL; end
                8'h28: begin o_op = O_BVC; o_mode = M_REL; end
                8'h29: begin o_op = O_BVS; o_mode = M_REL; end
                8'h2A: begin o_op = O_BPL; o_mode = M_REL; end
                8'h2B: begin o_op = O_BMI; o_mode = M_REL; end
                8'h2C: begin o_op = O_BGE; o_mode = M_REL; end
                8'h2D: begin o_op = O_BLT; o_mode = M_REL; end
                8'h2E: begin o_op = O_BGT; o_mode = M_REL; end
                8'h2F: begin o_op = O_BLE; o_mode = M_REL; end
                8'h30: o_op = O_TSX;
                8'h31: o_op = O_INS;
                8'h32: o_op = O_PULA;
                8'h33: o_op = O_PULB;
                8'h34: o_op = O_DES;
                8'h35: o_op = O_TXS;
                8'h36: o_op = O_PSHA;
                8'h37: o_op = O_PSHB;
                8'h39: o_op = O_RTS;
                8'h3B: o_op = O_RTI;
                8'h3E: o_op = O_WAI;
                8'h3F: o_op = O_SWI;
                // ACCA/ACCB inherent RMW (0x4x = ACCA, 0x5x = ACCB:
                // the discriminator is bit 4, not bit 6)
                8'h40, 8'h50: begin o_op = O_NEG; o_acc = ~d[4]; end
                8'h43, 8'h53: begin o_op = O_COM; o_acc = ~d[4]; end
                8'h44, 8'h54: begin o_op = O_LSR; o_acc = ~d[4]; end
                8'h46, 8'h56: begin o_op = O_ROR; o_acc = ~d[4]; end
                8'h47, 8'h57: begin o_op = O_ASR; o_acc = ~d[4]; end
                8'h48, 8'h58: begin o_op = O_ASL; o_acc = ~d[4]; end
                8'h49, 8'h59: begin o_op = O_ROL; o_acc = ~d[4]; end
                8'h4A, 8'h5A: begin o_op = O_DEC; o_acc = ~d[4]; end
                8'h4C, 8'h5C: begin o_op = O_INC; o_acc = ~d[4]; end
                8'h4D, 8'h5D: begin o_op = O_TST; o_acc = ~d[4]; end
                8'h4F, 8'h5F: begin o_op = O_CLR; o_acc = ~d[4]; end
                // indexed RMW / JMP
                8'h60: begin o_op = O_NEG; o_mode = M_IND; end
                8'h63: begin o_op = O_COM; o_mode = M_IND; end
                8'h64: begin o_op = O_LSR; o_mode = M_IND; end
                8'h66: begin o_op = O_ROR; o_mode = M_IND; end
                8'h67: begin o_op = O_ASR; o_mode = M_IND; end
                8'h68: begin o_op = O_ASL; o_mode = M_IND; end
                8'h69: begin o_op = O_ROL; o_mode = M_IND; end
                8'h6A: begin o_op = O_DEC; o_mode = M_IND; end
                8'h6C: begin o_op = O_INC; o_mode = M_IND; end
                8'h6D: begin o_op = O_TST; o_mode = M_IND; end
                8'h6E: begin o_op = O_JMP; o_mode = M_IND; end
                8'h6F: begin o_op = O_CLR; o_mode = M_IND; end
                // extended RMW / JMP
                8'h70: begin o_op = O_NEG; o_mode = M_EXT; end
                8'h73: begin o_op = O_COM; o_mode = M_EXT; end
                8'h74: begin o_op = O_LSR; o_mode = M_EXT; end
                8'h76: begin o_op = O_ROR; o_mode = M_EXT; end
                8'h77: begin o_op = O_ASR; o_mode = M_EXT; end
                8'h78: begin o_op = O_ASL; o_mode = M_EXT; end
                8'h79: begin o_op = O_ROL; o_mode = M_EXT; end
                8'h7A: begin o_op = O_DEC; o_mode = M_EXT; end
                8'h7C: begin o_op = O_INC; o_mode = M_EXT; end
                8'h7D: begin o_op = O_TST; o_mode = M_EXT; end
                8'h7E: begin o_op = O_JMP; o_mode = M_EXT; end
                8'h7F: begin o_op = O_CLR; o_mode = M_EXT; end
                default: ;                                // unassigned codes
            endcase
        end
    endfunction

    // ------------------------------------------------------------------
    // ALU flag helpers
    // ------------------------------------------------------------------
    function automatic logic [8:0] f_add8(input logic [7:0] x, y,
                                          input logic ci);
        f_add8 = {1'b0, x} + {1'b0, y} + ci;
    endfunction

    // Overflow for addition: sign changes between operands and result,
    // (x^r)&(y^r); (x^y)&(x^r) is the subtract formula
    function automatic logic f_vadd(input logic [7:0] x, y, r);
        f_vadd = (x[7] ^ r[7]) & (y[7] ^ r[7]);
    endfunction

    // [8] = borrow occurred, [7:0] = difference
    function automatic logic [8:0] f_sub8(input logic [7:0] x, y,
                                          input logic borrow_in);
        f_sub8 = {1'b0, x} - {1'b0, y} - borrow_in;
    endfunction

    function automatic logic f_vsub(input logic [7:0] x, y, r);
        f_vsub = (x[7] ^ y[7]) & (x[7] ^ r[7]);
    endfunction

    // DAA per M68PRM table A-34; reproduces all nine documented rows and
    // applies the same rule to the remaining (documented-invalid) inputs.
    function automatic logic [8:0] f_daa(input logic [7:0] val,
                                         input logic h, c_in);
        logic [3:0] lo, hi;
        logic       nd, md;
        logic [7:0] addend;
        lo     = val[3:0];
        hi     = val[7:4];
        nd     = (lo > 4'h9) || h;
        md     = c_in || (hi > 4'h9) || (hi == 4'h9 && (lo > 4'h9));
        // addend = (md ? 0x60 : 0) + (nd ? 0x06 : 0)
        addend = {1'b0, md, md, 2'b00, nd, nd, 1'b0};
        f_daa = {md, val + addend};
    endfunction

    function automatic logic f_branch(input op_e o, input logic [7:0] c);
        case (o)
            O_BRA:    f_branch = 1'b1;
            O_BCC:    f_branch = !c[FC];
            O_BCS:    f_branch =  c[FC];
            O_BNE:    f_branch = !c[FZ];
            O_BEQ:    f_branch =  c[FZ];
            O_BVC:    f_branch = !c[FV];
            O_BVS:    f_branch =  c[FV];
            O_BPL:    f_branch = !c[FN];
            O_BMI:    f_branch =  c[FN];
            O_BGE:    f_branch = !(c[FN] ^ c[FV]);
            O_BLT:    f_branch =  (c[FN] ^ c[FV]);
            O_BGT:    f_branch = !c[FZ] && !(c[FN] ^ c[FV]);
            O_BLE:    f_branch =  c[FZ] ||  (c[FN] ^ c[FV]);
            O_BHI:    f_branch = !c[FC] && !c[FZ];
            O_BLS:    f_branch =  c[FC] ||  c[FZ];
            default:  f_branch = 1'b0;
        endcase
    endfunction

    // RMW result + C/V for one operand byte. Returns {c_new, v_new, res}.
    function automatic logic [9:0] f_rmw(input op_e o,
                                         input logic [7:0] val,
                                         input logic c_in);
        logic [7:0] res;
        logic       cn, vn;
        case (o)
            O_NEG: begin res = -val;        cn = (val != 8'h00); vn = (val == 8'h80); end
            O_COM: begin res = ~val;        cn = 1'b1;           vn = 1'b0;           end
            O_LSR: begin res = {1'b0, val[7:1]}; cn = val[0]; vn = val[0];  end // N:=0 -> V=C
            O_ROR: begin res = {c_in, val[7:1]}; cn = val[0]; vn = c_in ^ val[0]; end
            O_ASR: begin res = {val[7], val[7:1]}; cn = val[0]; vn = val[7] ^ val[0]; end
            O_ASL: begin res = {val[6:0], 1'b0}; cn = val[7]; vn = res[7] ^ val[7]; end
            O_ROL: begin res = {val[6:0], c_in}; cn = val[7]; vn = res[7] ^ val[7]; end
            O_DEC: begin res = val - 8'h01; cn = c_in;           vn = (val == 8'h80); end
            O_INC: begin res = val + 8'h01; cn = c_in;           vn = (val == 8'h7F); end
            O_TST: begin res = val;         cn = 1'b0;           vn = 1'b0;           end
            O_CLR: begin res = 8'h00;       cn = 1'b0;           vn = 1'b0;           end
            default: begin res = val; cn = c_in; vn = 1'b0; end
        endcase
        f_rmw = {cn, vn, res};
    endfunction

    function automatic logic f_hcarry(input logic [7:0] x, y,
                                      input logic ci);
        f_hcarry = ({1'b0, x[3:0]} + {1'b0, y[3:0]} + ci) > 5'd15;
    endfunction

    // Next state after the effective address is complete
    function automatic state_e f_route(input op_e o);
        case (o)
            O_STA:              f_route = S_WR;
            O_STS, O_STX:       f_route = S_WR_H;
            O_JSR:              f_route = S_JSR1;
            O_LDX, O_LDS, O_CPX: f_route = S_RD_H;
            O_NEG, O_COM, O_LSR, O_ROR, O_ASR, O_ASL, O_ROL,
            O_DEC, O_INC, O_TST, O_CLR:
                                f_route = S_RMW_R;
            default:            f_route = S_RD;
        endcase
    endfunction

    function automatic logic f_is16(input op_e o);
        f_is16 = (o == O_LDX) || (o == O_LDS) || (o == O_CPX);
    endfunction

    function automatic logic f_is_rmw(input op_e o);
        case (o)
            O_NEG, O_COM, O_LSR, O_ROR, O_ASR, O_ASL, O_ROL,
            O_DEC, O_INC, O_TST, O_CLR: f_is_rmw = 1'b1;
            default:                    f_is_rmw = 1'b0;
        endcase
    endfunction

    // ------------------------------------------------------------------
    // Decoder outputs for the incoming fetch byte
    // ------------------------------------------------------------------
    op_e    dec_op;
    mode_e  dec_mode;
    logic   dec_acc;
    always_comb f_decode(bus_data_i, dec_op, dec_mode, dec_acc);

    // ------------------------------------------------------------------
    // Bus outputs
    // ------------------------------------------------------------------
    always_comb begin
        bus_addr   = pc;
        bus_data_o = 8'h00;
        bus_we     = 1'b0;
        vma_o      = 1'b1;
        case (state)
            S_RST_L, S_VEC_L: bus_addr = vec_q;
            S_RST_H, S_VEC_H: bus_addr = vec_q + 16'h1;
            S_IMM, S_DIR, S_EXT_L, S_EXT_H, S_IND, S_REL:
                bus_addr = pc;
            S_RD, S_RD_H:     bus_addr = ea_q;
            S_RD_L:           bus_addr = ea_q + 16'h1;
            S_WR: begin
                bus_addr = ea_q; bus_we = 1'b1;
                bus_data_o = acc ? a : b;
            end
            S_WR_H: begin
                bus_addr = ea_q; bus_we = 1'b1;
                bus_data_o = (op == O_STS) ? sp[15:8] : ix[15:8];
            end
            S_WR_L: begin
                bus_addr = ea_q + 16'h1; bus_we = 1'b1;
                bus_data_o = (op == O_STS) ? sp[7:0] : ix[7:0];
            end
            S_RMW_R: bus_addr = ea_q;
            S_RMW_W: begin
                bus_addr = ea_q; bus_we = 1'b1; bus_data_o = rmw_res_q;
            end
            S_PUSH: begin
                bus_addr = sp; bus_we = 1'b1; bus_data_o = acc ? a : b;
            end
            S_PULL:        bus_addr = sp + 16'h1;
            S_JSR1: begin
                bus_addr = sp; bus_we = 1'b1; bus_data_o = ret_q[7:0];
            end
            S_JSR2: begin
                bus_addr = sp; bus_we = 1'b1; bus_data_o = ret_q[15:8];
            end
            S_INT_PUSH: begin
                bus_addr = sp; bus_we = 1'b1;
                case (cnt)
                    3'd0:    bus_data_o = pc[7:0];
                    3'd1:    bus_data_o = pc[15:8];
                    3'd2:    bus_data_o = ix[7:0];
                    3'd3:    bus_data_o = ix[15:8];
                    3'd4:    bus_data_o = a;
                    3'd5:    bus_data_o = b;
                    default: bus_data_o = {2'b11, cc[5:0]};
                endcase
            end
            S_RTS_H, S_RTS_L, S_RTI_PULL:
                bus_addr = sp + 16'h1;
            S_WAIT, S_RMW_E: vma_o = 1'b0;
            default: bus_addr = pc;
        endcase
    end

    // ------------------------------------------------------------------
    // Sequencer
    // ------------------------------------------------------------------
    logic [8:0] t9;
    logic [7:0] rv;
    logic [9:0] rres;
    logic [15:0] r16;
    logic [8:0] daa9;

    // The sequencer uses write-before-read module-level temporaries (t9,
    // rv, rres, r16, daa9) as combinational intermediates inside this
    // single clocked process — a synthesis-safe idiom; BLKSEQ is a style
    // warning here, waived for the block.
    /* verilator lint_off BLKSEQ */
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state    <= S_RST_L;
            mode     <= M_IMP;
            op       <= O_NOP;
            acc      <= 1'b0;
            pc       <= 16'h0000;
            ix       <= 16'h0000;
            sp       <= 16'h0000;
            a        <= 8'h00;
            b        <= 8'h00;
            cc       <= 8'hD0;             // bits 7-6 set, I set
            opcode   <= 8'h00;
            data_q   <= 8'h00;
            ea_q     <= 16'h0000;
            vec_q    <= VEC_RST;
            ret_q    <= 16'h0000;
            cnt      <= 3'd0;
            wai_flag <= 1'b0;
            nmi_prev <= 1'b1;
            nmi_pend <= 1'b0;
        end else begin
            case (state)
                // ---------------- reset ----------------
                S_RST_L: begin
                    data_q <= bus_data_i;
                    state  <= S_RST_H;
                end
                S_RST_H: begin
                    pc       <= {data_q, bus_data_i};
                    cc[FI]   <= 1'b1;
                    nmi_pend <= 1'b0;
                    state    <= S_FETCH;
                end

                // ---------------- fetch / decode ----------------
                S_FETCH: begin
                    if (nmi_pend || irq_req) begin
                        vec_q    <= nmi_pend ? VEC_NMI : VEC_IRQ;
                        cnt      <= 3'd0;
                        wai_flag <= 1'b0;
                        if (nmi_pend) nmi_pend <= 1'b0;
                        state    <= S_INT_PUSH;
                    end else begin
                        opcode <= bus_data_i;
                        pc     <= pc + 16'h1;
                        op     <= dec_op;
                        mode   <= dec_mode;
                        acc    <= dec_acc;
                        state  <= S_FETCH;      // default; overridden below
                        if (dec_mode == M_IMP) begin
                            // inherent: execute on this edge
                            case (dec_op)
                                O_TAP: cc <= {2'b11, a[5:0]};
                                O_TPA: a  <= cc;
                                O_INX: begin
                                    ix <= ix + 16'h1;
                                    cc[FZ] <= ((ix + 16'h1) == 16'h0);
                                end
                                O_DEX: begin
                                    ix <= ix - 16'h1;
                                    cc[FZ] <= ((ix - 16'h1) == 16'h0);
                                end
                                O_CLV: cc[FV] <= 1'b0;
                                O_SEV: cc[FV] <= 1'b1;
                                O_CLC: cc[FC] <= 1'b0;
                                O_SEC: cc[FC] <= 1'b1;
                                O_CLI: cc[FI] <= 1'b0;
                                O_SEI: cc[FI] <= 1'b1;
                                O_SBA, O_CBA: begin
                                    t9 = f_sub8(b, a, 1'b0);
                                    cc[FC] <= t9[8];   // 6800 subtract C = borrow (PRM: |M| > |ACCX|)
                                    cc[FV] <= f_vsub(b, a, t9[7:0]);
                                    cc[FN] <= t9[7];
                                    cc[FZ] <= (t9[7:0] == 8'h00);
                                    if (dec_op == O_SBA) b <= t9[7:0];
                                end
                                O_TAB: begin
                                    b      <= a;
                                    cc[FN] <= a[7];
                                    cc[FZ] <= (a == 8'h00);
                                    cc[FV] <= 1'b0;
                                end
                                O_TBA: begin
                                    a      <= b;
                                    cc[FN] <= b[7];
                                    cc[FZ] <= (b == 8'h00);
                                    cc[FV] <= 1'b0;
                                end
                                O_DAA: begin
                                    daa9   = f_daa(a, cc[FH], cc[FC]);
                                    a      <= daa9[7:0];
                                    cc[FC] <= daa9[8];
                                    cc[FN] <= daa9[7];
                                    cc[FZ] <= (daa9[7:0] == 8'h00);
                                end
                                O_ABA: begin
                                    t9 = f_add8(a, b, 1'b0);
                                    a      <= t9[7:0];
                                    cc[FC] <= t9[8];
                                    cc[FV] <= f_vadd(a, b, t9[7:0]);
                                    cc[FH] <= f_hcarry(a, b, 1'b0);
                                    cc[FN] <= t9[7];
                                    cc[FZ] <= (t9[7:0] == 8'h00);
                                end
                                O_TSX: ix <= sp + 16'h1;
                                O_TXS: sp <= ix - 16'h1;
                                O_INS: sp <= sp + 16'h1;
                                O_DES: sp <= sp - 16'h1;
                                O_PSHA: begin
                                    acc   <= 1'b1;
                                    state <= S_PUSH;
                                end
                                O_PSHB: begin
                                    acc   <= 1'b0;
                                    state <= S_PUSH;
                                end
                                O_PULA: begin
                                    acc   <= 1'b1;
                                    state <= S_PULL;
                                end
                                O_PULB: begin
                                    acc   <= 1'b0;
                                    state <= S_PULL;
                                end
                                O_RTS: state <= S_RTS_H;
                                O_RTI: begin
                                    cnt   <= 3'd0;
                                    state <= S_RTI_PULL;
                                end
                                O_WAI: begin
                                    cnt      <= 3'd0;
                                    wai_flag <= 1'b1;
                                    state    <= S_INT_PUSH;
                                end
                                O_SWI: begin
                                    cnt      <= 3'd0;
                                    wai_flag <= 1'b0;
                                    vec_q    <= VEC_SWI;
                                    state    <= S_INT_PUSH;
                                end
                                default: begin
                                    if (f_is_rmw(dec_op)) begin
                                        rres = f_rmw(dec_op, dec_acc ? a : b,
                                                     cc[FC]);
                                        if (dec_acc) a <= rres[7:0];
                                        else         b <= rres[7:0];
                                        cc[FC] <= rres[9];
                                        cc[FV] <= rres[8];
                                        cc[FN] <= rres[7];
                                        cc[FZ] <= (rres[7:0] == 8'h00);
                                    end
                                end
                            endcase
                        end else begin
                            case (dec_mode)
                                M_IMM: begin
                                    if (f_is16(dec_op)) begin
                                        ea_q  <= pc + 16'h1;
                                        pc    <= pc + 16'h3;  // op + hi + lo
                                        state <= S_RD_H;
                                    end else begin
                                        state <= S_IMM;
                                    end
                                end
                                M_DIR: state <= S_DIR;
                                M_EXT: state <= S_EXT_L;
                                M_IND: state <= S_IND;
                                M_REL: state <= S_REL;
                                default: state <= S_FETCH;
                            endcase
                        end
                    end
                end

                // ---------------- operand / address fetch ----------------
                S_IMM: begin
                    data_q <= bus_data_i;
                    pc     <= pc + 16'h1;
                    rv     = acc ? a : b;
                    case (op)
                        O_LDA: begin
                            if (acc) a <= bus_data_i; else b <= bus_data_i;
                            cc[FN] <= bus_data_i[7];
                            cc[FZ] <= (bus_data_i == 8'h00);
                            cc[FV] <= 1'b0;
                        end
                        O_AND, O_BIT: begin
                            rv = rv & bus_data_i;
                            cc[FN] <= rv[7];
                            cc[FZ] <= (rv == 8'h00);
                            cc[FV] <= 1'b0;
                            if (op == O_AND) begin
                                if (acc) a <= rv; else b <= rv;
                            end
                        end
                        O_ORA: begin
                            rv = rv | bus_data_i;
                            cc[FN] <= rv[7];
                            cc[FZ] <= (rv == 8'h00);
                            cc[FV] <= 1'b0;
                            if (acc) a <= rv; else b <= rv;
                        end
                        O_EOR: begin
                            rv = rv ^ bus_data_i;
                            cc[FN] <= rv[7];
                            cc[FZ] <= (rv == 8'h00);
                            cc[FV] <= 1'b0;
                            if (acc) a <= rv; else b <= rv;
                        end
                        O_ADD: begin
                            t9 = f_add8(rv, bus_data_i, 1'b0);
                            cc[FC] <= t9[8];
                            cc[FV] <= f_vadd(rv, bus_data_i, t9[7:0]);
                            cc[FH] <= f_hcarry(rv, bus_data_i, 1'b0);
                            cc[FN] <= t9[7];
                            cc[FZ] <= (t9[7:0] == 8'h00);
                            if (acc) a <= t9[7:0]; else b <= t9[7:0];
                        end
                        O_ADC: begin
                            t9 = f_add8(rv, bus_data_i, cc[FC]);
                            cc[FC] <= t9[8];
                            cc[FV] <= f_vadd(rv, bus_data_i, t9[7:0]);
                            cc[FH] <= f_hcarry(rv, bus_data_i, cc[FC]);
                            cc[FN] <= t9[7];
                            cc[FZ] <= (t9[7:0] == 8'h00);
                            if (acc) a <= t9[7:0]; else b <= t9[7:0];
                        end
                        O_SUB, O_CMP: begin
                            t9 = f_sub8(rv, bus_data_i, 1'b0);
                            cc[FC] <= t9[8];   // 6800 subtract C = borrow (PRM: |M| > |ACCX|)
                            cc[FV] <= f_vsub(rv, bus_data_i, t9[7:0]);
                            cc[FN] <= t9[7];
                            cc[FZ] <= (t9[7:0] == 8'h00);
                            if (op == O_SUB) begin
                                if (acc) a <= t9[7:0]; else b <= t9[7:0];
                            end
                        end
                        O_SBC: begin
                            t9 = f_sub8(rv, bus_data_i, cc[FC]);
                            cc[FC] <= t9[8];   // 6800 subtract C = borrow (PRM: |M| > |ACCX|)
                            cc[FV] <= f_vsub(rv, bus_data_i, t9[7:0]);
                            cc[FN] <= t9[7];
                            cc[FZ] <= (t9[7:0] == 8'h00);
                            if (acc) a <= t9[7:0]; else b <= t9[7:0];
                        end
                        default: ;
                    endcase
                    state <= S_FETCH;
                end

                S_DIR: begin
                    ea_q <= {8'h00, bus_data_i};
                    pc   <= pc + 16'h1;
                    ret_q <= pc + 16'h1;
                    if (op == O_JMP) begin
                        pc    <= {8'h00, bus_data_i};
                        state <= S_FETCH;
                    end else begin
                        state <= f_route(op);
                    end
                end

                S_EXT_L: begin
                    data_q <= bus_data_i;
                    pc     <= pc + 16'h1;
                    state  <= S_EXT_H;
                end

                S_EXT_H: begin
                    ea_q  <= {data_q, bus_data_i};
                    pc    <= pc + 16'h1;
                    ret_q <= pc + 16'h1;
                    if (op == O_JMP) begin
                        pc    <= {data_q, bus_data_i};
                        state <= S_FETCH;
                    end else begin
                        state <= f_route(op);
                    end
                end

                S_IND: begin
                    ea_q  <= ix + {8'h00, bus_data_i};
                    pc    <= pc + 16'h1;
                    ret_q <= pc + 16'h1;
                    if (op == O_JMP) begin
                        pc    <= ix + {8'h00, bus_data_i};
                        state <= S_FETCH;
                    end else begin
                        state <= f_route(op);
                    end
                end

                S_REL: begin
                    pc <= pc + 16'h1;
                    if (op == O_BSR) begin
                        ret_q <= pc + 16'h1;
                        ea_q  <= pc + 16'h1 +
                                 {{8{bus_data_i[7]}}, bus_data_i};
                        state <= S_JSR1;
                    end else if (f_branch(op, cc)) begin
                        pc    <= pc + 16'h1 +
                                 {{8{bus_data_i[7]}}, bus_data_i};
                        state <= S_FETCH;
                    end else begin
                        state <= S_FETCH;
                    end
                end

                // ---------------- operand read / execute ----------------
                S_RD: begin
                    rv = acc ? a : b;
                    case (op)
                        O_LDA: begin
                            if (acc) a <= bus_data_i; else b <= bus_data_i;
                            cc[FN] <= bus_data_i[7];
                            cc[FZ] <= (bus_data_i == 8'h00);
                            cc[FV] <= 1'b0;
                        end
                        O_AND, O_BIT: begin
                            rv = rv & bus_data_i;
                            cc[FN] <= rv[7];
                            cc[FZ] <= (rv == 8'h00);
                            cc[FV] <= 1'b0;
                            if (op == O_AND) begin
                                if (acc) a <= rv; else b <= rv;
                            end
                        end
                        O_ORA: begin
                            rv = rv | bus_data_i;
                            cc[FN] <= rv[7];
                            cc[FZ] <= (rv == 8'h00);
                            cc[FV] <= 1'b0;
                            if (acc) a <= rv; else b <= rv;
                        end
                        O_EOR: begin
                            rv = rv ^ bus_data_i;
                            cc[FN] <= rv[7];
                            cc[FZ] <= (rv == 8'h00);
                            cc[FV] <= 1'b0;
                            if (acc) a <= rv; else b <= rv;
                        end
                        O_ADD: begin
                            t9 = f_add8(rv, bus_data_i, 1'b0);
                            cc[FC] <= t9[8];
                            cc[FV] <= f_vadd(rv, bus_data_i, t9[7:0]);
                            cc[FH] <= f_hcarry(rv, bus_data_i, 1'b0);
                            cc[FN] <= t9[7];
                            cc[FZ] <= (t9[7:0] == 8'h00);
                            if (acc) a <= t9[7:0]; else b <= t9[7:0];
                        end
                        O_ADC: begin
                            t9 = f_add8(rv, bus_data_i, cc[FC]);
                            cc[FC] <= t9[8];
                            cc[FV] <= f_vadd(rv, bus_data_i, t9[7:0]);
                            cc[FH] <= f_hcarry(rv, bus_data_i, cc[FC]);
                            cc[FN] <= t9[7];
                            cc[FZ] <= (t9[7:0] == 8'h00);
                            if (acc) a <= t9[7:0]; else b <= t9[7:0];
                        end
                        O_SUB, O_CMP: begin
                            t9 = f_sub8(rv, bus_data_i, 1'b0);
                            cc[FC] <= t9[8];   // 6800 subtract C = borrow (PRM: |M| > |ACCX|)
                            cc[FV] <= f_vsub(rv, bus_data_i, t9[7:0]);
                            cc[FN] <= t9[7];
                            cc[FZ] <= (t9[7:0] == 8'h00);
                            if (op == O_SUB) begin
                                if (acc) a <= t9[7:0]; else b <= t9[7:0];
                            end
                        end
                        O_SBC: begin
                            t9 = f_sub8(rv, bus_data_i, cc[FC]);
                            cc[FC] <= t9[8];   // 6800 subtract C = borrow (PRM: |M| > |ACCX|)
                            cc[FV] <= f_vsub(rv, bus_data_i, t9[7:0]);
                            cc[FN] <= t9[7];
                            cc[FZ] <= (t9[7:0] == 8'h00);
                            if (acc) a <= t9[7:0]; else b <= t9[7:0];
                        end
                        default: ;
                    endcase
                    state <= S_FETCH;
                end

                S_RD_H: begin
                    data_q <= bus_data_i;
                    state  <= S_RD_L;
                end

                S_RD_L: begin
                    r16 = {data_q, bus_data_i};
                    case (op)
                        O_LDX: begin
                            ix     <= r16;
                            cc[FN] <= r16[15];
                            cc[FZ] <= (r16 == 16'h0);
                            cc[FV] <= 1'b0;
                        end
                        O_LDS: begin
                            sp     <= r16;
                            cc[FN] <= r16[15];
                            cc[FZ] <= (r16 == 16'h0);
                            cc[FV] <= 1'b0;
                        end
                        O_CPX: begin
                            r16    = ix - r16;
                            cc[FN] <= r16[15];
                            cc[FZ] <= (r16 == 16'h0);
                            cc[FV] <= (ix[15] != data_q[7]) &&
                                      (ix[15] != r16[15]);
                        end
                        default: ;
                    endcase
                    state <= S_FETCH;
                end

                S_WR: state <= S_FETCH;
                // STS/STX: N, Z from the stored 16-bit value, V cleared
                S_WR_H: begin
                    cc[FN] <= (op == O_STS) ? sp[15] : ix[15];
                    cc[FZ] <= ((op == O_STS) ? sp : ix) == 16'h0;
                    cc[FV] <= 1'b0;
                    state  <= S_WR_L;
                end
                S_WR_L: state <= S_FETCH;

                // ---------------- read-modify-write ----------------
                S_RMW_R: begin
                    rmw_val <= bus_data_i;
                    state   <= S_RMW_E;
                end

                S_RMW_E: begin
                    rres       = f_rmw(op, rmw_val, cc[FC]);
                    rmw_res_q  <= rres[7:0];
                    cc[FC]     <= rres[9];
                    cc[FV]     <= rres[8];
                    cc[FN]     <= rres[7];
                    cc[FZ]     <= (rres[7:0] == 8'h00);
                    state      <= S_RMW_W;
                end

                S_RMW_W: state <= S_FETCH;

                // ---------------- stack ----------------
                S_PUSH: begin
                    sp    <= sp - 16'h1;
                    state <= S_FETCH;
                end

                S_PULL: begin
                    if (acc) a <= bus_data_i; else b <= bus_data_i;
                    sp    <= sp + 16'h1;
                    state <= S_FETCH;
                end

                S_JSR1: begin
                    sp    <= sp - 16'h1;
                    state <= S_JSR2;
                end

                S_JSR2: begin
                    sp    <= sp - 16'h1;
                    state <= S_JSR_GO;
                end

                S_JSR_GO: begin
                    pc    <= ea_q;
                    state <= S_FETCH;
                end

                S_RTS_H: begin
                    data_q <= bus_data_i;
                    sp     <= sp + 16'h1;
                    state  <= S_RTS_L;
                end

                S_RTS_L: begin
                    pc    <= {data_q, bus_data_i};
                    sp    <= sp + 16'h1;
                    state <= S_FETCH;
                end

                S_RTI_PULL: begin
                    sp <= sp + 16'h1;
                    case (cnt)
                        3'd0: cc    <= {2'b11, bus_data_i[5:0]};
                        3'd1: b     <= bus_data_i;
                        3'd2: a     <= bus_data_i;
                        3'd3: ix[15:8] <= bus_data_i;
                        3'd4: ix[7:0]  <= bus_data_i;
                        3'd5: data_q   <= bus_data_i;
                        default: begin
                            pc    <= {data_q, bus_data_i};
                            state <= S_FETCH;
                        end
                    endcase
                    if (cnt != 3'd6) cnt <= cnt + 3'd1;
                end

                // ---------------- interrupts ----------------
                S_INT_PUSH: begin
                    sp <= sp - 16'h1;
                    if (cnt == 3'd6) begin
                        if (wai_flag) begin
                            state <= S_WAIT;
                        end else begin
                            cc[FI] <= 1'b1;
                            state  <= S_VEC_L;
                        end
                    end else begin
                        cnt <= cnt + 3'd1;
                    end
                end

                S_WAIT: begin
                    if (nmi_pend || (!irq_n && !cc[FI])) begin
                        vec_q <= nmi_pend ? VEC_NMI : VEC_IRQ;
                        if (nmi_pend) nmi_pend <= 1'b0;
                        cc[FI] <= 1'b1;
                        state  <= S_VEC_L;
                    end
                end

                S_VEC_L: begin
                    data_q <= bus_data_i;
                    state  <= S_VEC_H;
                end

                S_VEC_H: begin
                    pc    <= {data_q, bus_data_i};
                    state <= S_FETCH;
                end

                default: state <= S_FETCH;
            endcase

            // NMI edge detect (after the state case so an edge arriving on
            // the same cycle as an NMI acceptance is not lost)
            nmi_prev <= nmi_n;
            if (!nmi_n && nmi_prev) nmi_pend <= 1'b1;
        end
    end
    /* verilator lint_on BLKSEQ */

`ifdef FORMAL
    `include "motorola_6800_props.sv"
    `include "motorola_6800_cover_setup.sv"
`endif
endmodule
