// MOS 6502 — full documented instruction set (stage 2).
// Functional-bus core: one bus transfer per clk, combinational reads
// (spec_full_isa.md section 4; stage-1 assumptions carried forward).
// Reference oracle: vendored py65 MPU (decimal algorithms mirrored from
// references/py65_mpu6502.py); real-software gate: Klaus Dormann's
// functional test. NMOS quirks modeled: JMP ($xxFF) page wrap, NMOS
// decimal-mode ADC/SBC flag behavior, B-flag push rules, IRQ/NMI.
`timescale 1ns/1ps

module mos_6502 (
    input  logic        clk,
    input  logic        rst_n,
    output logic [15:0] bus_addr,
    input  logic [7:0]  bus_data_i,
    output logic [7:0]  bus_data_o,
    output logic        bus_we,
    input  logic        irq_n,     // level, masked by I
    input  logic        nmi_n,     // falling-edge detected
    output logic        fetch_o,
    output logic        fault_o,
    output logic [15:0] pc_o,
    output logic [7:0]  status_o,
    output logic [7:0]  a_o,
    output logic [7:0]  x_o,
    output logic [7:0]  y_o,
    output logic [7:0]  s_o
);

    // P register bits: N V 1 B D I Z C
    localparam int FC = 0, FZ = 1, FI = 2, FD = 3, FV = 6, FN = 7;

    typedef enum logic [3:0] {
        M_IMP, M_IMM, M_ZP, M_ZPX, M_ZPY, M_ABS, M_ABX, M_ABY,
        M_IZX, M_IZY, M_IND, M_REL, M_SPEC
    } mode_e;

    typedef enum logic [5:0] {
        O_NOP,  O_ORA, O_AND, O_EOR, O_ADC, O_SBC, O_CMP, O_CPX, O_CPY,
        O_BIT,  O_LDA, O_LDX, O_LDY, O_STA, O_STX, O_STY,
        O_ASL,  O_LSR, O_ROL, O_ROR, O_INC, O_DEC,
        O_INX,  O_INY, O_DEX, O_DEY,
        O_TAX,  O_TXA, O_TAY, O_TYA, O_TSX, O_TXS,
        O_CLC,  O_SEC, O_CLI, O_SEI, O_CLV, O_CLD, O_SED,
        O_JMP,  O_JSR, O_RTS, O_BRK, O_RTI,
        O_PHA,  O_PHP, O_PLA, O_PLP,
        O_ASLA, O_LSRA, O_ROLA, O_RORA,
        O_BRA
    } op_e;

    typedef enum logic [5:0] {
        S_RST_L, S_RST_H, S_FETCH,
        S_IMM, S_ZP, S_ZPI, S_ABS_L, S_ABS_H,
        S_PTR_L, S_PTR_H, S_IND_L, S_IND_H,
        S_RD, S_WR, S_EXEC, S_EXEC_M, S_RMWR, S_RMWW,
        S_REL, S_PSH, S_PUL,
        S_JSR_L, S_JSR_PH, S_JSR_PL, S_JSR_H,
        S_RTS_L, S_RTS_H,
        S_RTI_P, S_RTI_L, S_RTI_H,
        S_BRK_PAD, S_BRK_PH, S_BRK_PL, S_BRK_PS, S_VEC_L, S_VEC_H,
        S_FAULT
    } state_e;

    state_e      state;
    mode_e       mode;
    op_e         op;
    logic        is_rmw, is_store, brk_is_brk, int_nmi_q;
    logic [15:0] pc, target_q, ptr_q;
    logic [7:0]  a, x, y, p, s, opcode, data_q;
    logic        nmi_prev, nmi_edge;

    // ------------------------------------------------------------------
    // Decoder (functions of an opcode byte: used for the registered
    // opcode and, in FETCH, for the incoming byte)
    // ------------------------------------------------------------------
    function automatic mode_e f_mode(input logic [7:0] d);
        case (d)
            8'h09, 8'h29, 8'h49, 8'h69, 8'he9, 8'hc9, 8'he0, 8'hc0,
            8'ha9, 8'ha2, 8'ha0:                              f_mode = M_IMM;
            8'h05, 8'h25, 8'h45, 8'h65, 8'he5, 8'hc5, 8'he4, 8'hc4,
            8'ha5, 8'ha6, 8'ha4, 8'h85, 8'h86, 8'h84,
            8'h06, 8'h46, 8'h26, 8'h66, 8'he6, 8'hc6,
            8'h24:                                            f_mode = M_ZP;
            8'h15, 8'h35, 8'h55, 8'h75, 8'hf5, 8'hd5, 8'h95, 8'h94,
            8'hb5, 8'hb4, 8'h16, 8'h56, 8'h36, 8'h76, 8'hf6, 8'hd6:  f_mode = M_ZPX;
            8'h96, 8'hb6:                                     f_mode = M_ZPY;
            8'h0d, 8'h2d, 8'h4d, 8'h6d, 8'hed, 8'hcd, 8'hec, 8'hcc,
            8'had, 8'hae, 8'hac, 8'h8d, 8'h8e, 8'h8c,
            8'h0e, 8'h4e, 8'h2e, 8'h6e, 8'hee, 8'hce,
            8'h2c, 8'h4c:                                     f_mode = M_ABS;
            8'h1d, 8'h3d, 8'h5d, 8'h7d, 8'hbd, 8'hfd, 8'hdd, 8'hbc,
            8'h9d, 8'h1e, 8'h3e, 8'h5e, 8'h7e, 8'hfe, 8'hde:  f_mode = M_ABX;
            8'h19, 8'h39, 8'h59, 8'h79, 8'hb9, 8'hf9, 8'hd9, 8'hbe,
            8'h99:                                            f_mode = M_ABY;
            8'h01, 8'h21, 8'h41, 8'h61, 8'ha1, 8'he1, 8'hc1, 8'h81:  f_mode = M_IZX;
            8'h11, 8'h31, 8'h51, 8'h71, 8'hb1, 8'hf1, 8'hd1, 8'h91:  f_mode = M_IZY;
            8'h6c:                                            f_mode = M_IND;
            8'h10, 8'h30, 8'h50, 8'h70, 8'h90, 8'hb0, 8'hd0, 8'hf0:
                                                              f_mode = M_REL;
            8'h20, 8'h60, 8'h00, 8'h40,
            8'h48, 8'h08, 8'h68, 8'h28:                       f_mode = M_SPEC;
            default:                                          f_mode = M_IMP;
        endcase
    endfunction

    function automatic op_e f_op_hi(input logic [7:0] d);
        case (d)
            8'he0, 8'he4, 8'hec: f_op_hi = O_CPX;
            8'hc0, 8'hc4, 8'hcc: f_op_hi = O_CPY;
            8'h24, 8'h2c:        f_op_hi = O_BIT;
            8'h86, 8'h96, 8'h8e: f_op_hi = O_STX;
            8'ha2, 8'ha6, 8'hb6, 8'hae, 8'hbe: f_op_hi = O_LDX;
            8'h84, 8'h94, 8'h8c: f_op_hi = O_STY;
            8'ha0, 8'ha4, 8'hb4, 8'hac, 8'hbc: f_op_hi = O_LDY;
            8'h06, 8'h16, 8'h0e, 8'h1e: f_op_hi = O_ASL;
            8'h0a:                       f_op_hi = O_ASLA;
            8'h46, 8'h56, 8'h4e, 8'h5e: f_op_hi = O_LSR;
            8'h4a:                      f_op_hi = O_LSRA;
            8'h26, 8'h36, 8'h2e, 8'h3e: f_op_hi = O_ROL;
            8'h2a:                      f_op_hi = O_ROLA;
            8'h66, 8'h76, 8'h6e, 8'h7e: f_op_hi = O_ROR;
            8'h6a:                      f_op_hi = O_RORA;
            8'he6, 8'hf6, 8'hee, 8'hfe:        f_op_hi = O_INC;
            8'hc6, 8'hd6, 8'hce, 8'hde:        f_op_hi = O_DEC;
            8'he8:  f_op_hi = O_INX;
            8'hc8:  f_op_hi = O_INY;
            8'hca:  f_op_hi = O_DEX;
            8'h88:  f_op_hi = O_DEY;
            8'haa:  f_op_hi = O_TAX;
            8'h8a:  f_op_hi = O_TXA;
            8'ha8:  f_op_hi = O_TAY;
            8'h98:  f_op_hi = O_TYA;
            8'hba:  f_op_hi = O_TSX;
            8'h9a:  f_op_hi = O_TXS;
            8'h18:  f_op_hi = O_CLC;
            8'h38:  f_op_hi = O_SEC;
            8'h58:  f_op_hi = O_CLI;
            8'h78:  f_op_hi = O_SEI;
            8'hb8:  f_op_hi = O_CLV;
            8'hd8:  f_op_hi = O_CLD;
            8'hf8:  f_op_hi = O_SED;
            8'h4c, 8'h6c: f_op_hi = O_JMP;
            8'h20:  f_op_hi = O_JSR;
            8'h60:  f_op_hi = O_RTS;
            8'h00:  f_op_hi = O_BRK;
            8'h40:  f_op_hi = O_RTI;
            8'h48:  f_op_hi = O_PHA;
            8'h08:  f_op_hi = O_PHP;
            8'h68:  f_op_hi = O_PLA;
            8'h28:  f_op_hi = O_PLP;
            default: f_op_hi = O_NOP;   // incl. EA; undocumented -> FAULT
        endcase
    endfunction

    // Group-01 (aaabbb01): the ALU op is selected by d[7:5]; D1 is plain
    // CMP (zp),Y -- the NMOS opcode matrix has no group-01 exceptions.
    // SBC (zp),Y is F1, not D1.
    function automatic op_e f_op(input logic [7:0] d);
        if (d[1:0] == 2'b01) begin
            case (d[7:5])
                3'b000:  f_op = O_ORA;
                3'b001:  f_op = O_AND;
                3'b010:  f_op = O_EOR;
                3'b011:  f_op = O_ADC;
                3'b100:  f_op = O_STA;
                3'b101:  f_op = O_LDA;
                3'b110:  f_op = O_CMP;
                default: f_op = O_SBC;
            endcase
        end else begin
            f_op = f_op_hi(d);
        end
    endfunction

    function automatic logic f_rmw(input logic [7:0] d);
        case (d)
            8'h06, 8'h16, 8'h0e, 8'h1e, 8'h46, 8'h56, 8'h4e, 8'h5e,
            8'h26, 8'h36, 8'h2e, 8'h3e, 8'h66, 8'h76, 8'h6e, 8'h7e,
            8'he6, 8'hf6, 8'hee, 8'hfe, 8'hc6, 8'hd6, 8'hce, 8'hde:
                f_rmw = 1'b1;
            default: f_rmw = 1'b0;
        endcase
    endfunction

    function automatic logic f_store(input logic [7:0] d);
        case (d)
            8'h85, 8'h95, 8'h8d, 8'h9d, 8'h99, 8'h81, 8'h91,
            8'h86, 8'h96, 8'h8e, 8'h84, 8'h94, 8'h8c: f_store = 1'b1;
            default: f_store = 1'b0;
        endcase
    endfunction

    function automatic logic f_undoc(input logic [7:0] d);
        case (d)
            8'h09, 8'h05, 8'h15, 8'h0d, 8'h1d, 8'h19, 8'h01, 8'h11,
            8'h29, 8'h25, 8'h35, 8'h2d, 8'h3d, 8'h39, 8'h21, 8'h31,
            8'h49, 8'h45, 8'h55, 8'h4d, 8'h5d, 8'h59, 8'h41, 8'h51,
            8'h69, 8'h65, 8'h75, 8'h6d, 8'h7d, 8'h79, 8'h61, 8'h71,
            8'he9, 8'he5, 8'hf5, 8'hed, 8'hfd, 8'hf9, 8'he1, 8'hf1,
            8'hc9, 8'hc5, 8'hd5, 8'hcd, 8'hdd, 8'hd9, 8'hc1, 8'hd1,
            8'he0, 8'he4, 8'hec, 8'hc0, 8'hc4, 8'hcc,
            8'h85, 8'h95, 8'h8d, 8'h9d, 8'h99, 8'h81, 8'h91,
            8'ha9, 8'ha5, 8'hb5, 8'had, 8'hbd, 8'hb9, 8'ha1, 8'hb1,
            8'ha2, 8'ha6, 8'hb6, 8'hae, 8'hbe,
            8'ha0, 8'ha4, 8'hb4, 8'hac, 8'hbc,
            8'h86, 8'h96, 8'h8e, 8'h84, 8'h94, 8'h8c,
            8'h06, 8'h16, 8'h0e, 8'h1e, 8'h46, 8'h56, 8'h4e, 8'h5e,
            8'h26, 8'h36, 8'h2e, 8'h3e, 8'h66, 8'h76, 8'h6e, 8'h7e,
            8'he6, 8'hf6, 8'hee, 8'hfe, 8'hc6, 8'hd6, 8'hce, 8'hde,
            8'hea, 8'h0a, 8'h4a, 8'h2a, 8'h6a,
            8'haa, 8'h8a, 8'ha8, 8'h98, 8'hba, 8'h9a,
            8'he8, 8'hc8, 8'hca, 8'h88,
            8'h18, 8'h38, 8'h58, 8'h78, 8'hb8, 8'hd8, 8'hf8,
            8'h4c, 8'h6c, 8'h20, 8'h60, 8'h00, 8'h40,
            8'h48, 8'h08, 8'h68, 8'h28,
            8'h10, 8'h30, 8'h50, 8'h70, 8'h90, 8'hb0, 8'hd0, 8'hf0,
            8'h24, 8'h2c: f_undoc = 1'b0;
            default: f_undoc = 1'b1;
        endcase
    endfunction

    logic        branch_taken;
    logic        int_req;

    logic [7:0] dec_byte;    // the byte being decoded this cycle
    assign dec_byte = (state == S_FETCH) ? bus_data_i : opcode;
    always_comb begin
        mode         = f_mode(dec_byte);
        op           = f_op(dec_byte);
        is_rmw       = f_rmw(dec_byte);
        is_store     = f_store(dec_byte);
    end

    always_comb begin
        case (opcode[7:6])
            2'b00:   branch_taken = p[FN] == opcode[5];
            2'b01:   branch_taken = p[FV] == opcode[5];
            2'b10:   branch_taken = p[FC] == opcode[5];
            default: branch_taken = p[FZ] == opcode[5];
        endcase
    end

    // ------------------------------------------------------------------
    // Arithmetic (binary paths standard; decimal paths mirror py65)
    // ------------------------------------------------------------------
    logic       sub;
    logic [7:0] addend;
    logic [8:0] sum9;
    logic       sum_v;
    logic       dec_c;
    logic [7:0] dec_r;
    // expression helpers (some tools reject selects on parenthesized exprs)
    logic [7:0] xpi, ypi, xmi, ymi, ora_r, and_r, eor_r;
    assign xpi = x + 8'd1;
    assign ypi = y + 8'd1;
    assign xmi = x - 8'd1;
    assign ymi = y - 8'd1;
    assign ora_r = a | data_q;
    assign and_r = a & data_q;
    assign eor_r = a ^ data_q;
            
    assign sub    = (op == O_SBC);
    assign addend = sub ? ~data_q : data_q;
    assign sum9   = {1'b0, a} + {1'b0, addend} + {8'b0, p[FC]};
    assign sum_v  = (~(a[7] ^ addend[7])) & (a[7] ^ sum9[7]);

    logic [4:0] adc_lo, adc_hi;
    logic       adc_hc;
    logic [3:0] adc_r_hi, adc_r_lo;
    logic [7:0] adc_alu;
    logic       sbc_b1, sbc_b2;
    logic [3:0] sbc_lo_digit, sbc_hi_digit;
    logic [8:0] sbc_cmp;
    logic       sbc_borrow;
    assign sbc_cmp    = {1'b0, data_q} + {8'b0, ~p[FC]};
    assign sbc_borrow = ({1'b0, a} < sbc_cmp);   // borrow out of a - data_q - !C

    assign adc_lo = {1'b0, data_q[3:0]} + {1'b0, a[3:0]} + {4'b0, p[FC]};
    assign adc_hc = (adc_lo > 5'd9);
    assign adc_hi = {1'b0, data_q[7:4]} + {1'b0, a[7:4]} + {4'b0, adc_hc};
    assign adc_alu  = {adc_hi[3:0], adc_lo[3:0]};   // pre-adjust, per py65
    assign adc_r_hi = data_q[7:4] + a[7:4] + {3'b0, adc_hc}
                      + ((adc_hi > 5'd9) ? 4'd6 : 4'd0);
    assign adc_r_lo = adc_lo[3:0] + ((adc_lo > 5'd9) ? 4'd6 : 4'd0);

    // Canonical NMOS decimal SBC (Bruce Clark, validated against real
    // hardware incl. invalid-BCD operands; supersedes the py65 formulation,
    // which deviates in corner cases -- caught by the Klaus regression).
    assign sbc_b1 = ({1'b0, a[3:0]} < {1'b0, data_q[3:0]} + {4'b0, ~p[FC]});
    assign sbc_lo_digit = a[3:0] - data_q[3:0] - {3'b0, ~p[FC]}
                          - (sbc_b1 ? 4'd6 : 4'd0);
    assign sbc_b2 = ({1'b0, a[7:4]} < {1'b0, data_q[7:4]} + {4'b0, sbc_b1});
    assign sbc_hi_digit = a[7:4] - data_q[7:4] - {3'b0, sbc_b1}
                          - (sbc_b2 ? 4'd6 : 4'd0);

    always_comb begin
        dec_c = 1'b0;
        dec_r = sum9[7:0];
        if (!sub) begin
            dec_c = (adc_hi > 5'd9);
            dec_r = {adc_r_hi, adc_r_lo};
        end else begin
            dec_c = ~sbc_borrow;               // carry = no borrow
            dec_r = {sbc_hi_digit, sbc_lo_digit};
        end
    end

    // ------------------------------------------------------------------
    // Bus
    // ------------------------------------------------------------------
    always_comb begin
        case (state)
            S_RST_L:  bus_addr = 16'hfffc;
            S_RST_H:  bus_addr = 16'hfffd;
            S_PUL, S_RTS_L, S_RTS_H, S_RTI_P, S_RTI_L, S_RTI_H:
                      bus_addr = {8'h01, s + 8'd1};   // pull: S++ then read
            S_PSH, S_JSR_PH, S_BRK_PH, S_JSR_PL, S_BRK_PL, S_BRK_PS:
                      bus_addr = {8'h01, s};            // push: write at S
            S_VEC_L:  bus_addr = int_nmi_q ? 16'hfffa : 16'hfffe;
            S_VEC_H:  bus_addr = int_nmi_q ? 16'hfffb : 16'hffff;
            S_JSR_H:  bus_addr = pc;
            S_RD, S_RMWR: bus_addr = target_q;
            S_WR, S_RMWW: bus_addr = target_q;
            S_PTR_L:  bus_addr = {8'h00, ptr_q[7:0]};
            S_PTR_H:  bus_addr = {8'h00, ptr_q[7:0] + 8'd1};
            S_IND_L:  bus_addr = ptr_q;
            S_IND_H:  bus_addr = (ptr_q[7:0] == 8'hff)
                                 ? {ptr_q[15:8], 8'h00}     // NMOS page wrap
                                 : {ptr_q[15:8], ptr_q[7:0] + 8'd1};
            default:  bus_addr = pc;    // FETCH, IMM, ZP, ABS_L/H, REL,
                                        // BRK_PAD, JSR_L, implied
        endcase
    end

    always_comb begin
        if (state == S_FETCH) bus_data_o = 8'h00;   // reads ignore data_o
        else if (state == S_JSR_PH || state == S_BRK_PH) bus_data_o = pc[15:8];
        else if (state == S_JSR_PL || state == S_BRK_PL) bus_data_o = pc[7:0];
        else if (state == S_RMWW) bus_data_o = data_q;
        else if (state == S_BRK_PS) bus_data_o = brk_is_brk ? (p | 8'h30)
                                                            : ((p & ~8'h10) | 8'h20);
        else if (op == O_PHP)     bus_data_o = p | 8'h30;   // B and bit5
        else if (op == O_STX)     bus_data_o = x;
        else if (op == O_STY)     bus_data_o = y;
        else                      bus_data_o = a;           // STA / PHA
    end

    assign bus_we  = (state == S_WR) || (state == S_RMWW)
                   || (state == S_PSH) || (state == S_JSR_PH) || (state == S_JSR_PL)
                   || (state == S_BRK_PH) || (state == S_BRK_PL) || (state == S_BRK_PS);
    assign fetch_o = (state == S_FETCH);
    assign fault_o = (state == S_FAULT);
    assign pc_o = pc;
    assign status_o = p;
    assign a_o = a;
    assign x_o = x;
    assign y_o = y;
    assign s_o = s;

    // NMI edge detect; consumed at the instruction boundary
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            nmi_prev <= 1'b1;
            nmi_edge <= 1'b0;
        end else begin
            nmi_prev <= nmi_n;
            if (nmi_prev && !nmi_n) nmi_edge <= 1'b1;
            else if (state == S_FETCH) nmi_edge <= 1'b0;
        end
    end
    assign int_req = nmi_edge || ((irq_n == 1'b0) && !p[FI]);

    // FETCH next-state selection from the incoming opcode. The decode
    // functions are called through named wires: yosys cannot width-check an
    // enum-returning function used directly as a case expression.
    state_e     fetch_next;
    mode_e      fetch_mode;
    op_e        fetch_op;
    assign fetch_mode = f_mode(bus_data_i);
    assign fetch_op   = f_op(bus_data_i);
    always_comb begin
        case (fetch_mode)
            M_IMM:               fetch_next = S_IMM;
            M_ZP, M_ZPX, M_ZPY,
            M_IZX, M_IZY:        fetch_next = S_ZP;
            M_ABS, M_ABX, M_ABY,
            M_IND:               fetch_next = S_ABS_L;
            M_REL:               fetch_next = S_REL;
            default:             fetch_next = S_FETCH;  // implied / SPEC
        endcase
        if (f_undoc(bus_data_i)) fetch_next = S_FAULT;
    end

    // ------------------------------------------------------------------
    // Sequencer
    // ------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state    <= S_RST_L;
            pc       <= 16'h0000;
            target_q <= 16'h0000;
            ptr_q    <= 16'h0000;
            data_q   <= 8'h00;
            opcode   <= 8'h00;
            a        <= 8'h00;
            x        <= 8'h00;
            y        <= 8'h00;
            s        <= 8'h00;
            p        <= 8'h24;
            brk_is_brk <= 1'b0;
            int_nmi_q  <= 1'b0;
        end else begin
            case (state)
            // ---- reset ----
            S_RST_L: begin data_q <= bus_data_i; state <= S_RST_H; end
            S_RST_H: begin pc <= {bus_data_i, data_q}; state <= S_FETCH; end

            // ---- fetch / implied executes ----
            S_FETCH: begin
                if (int_req) begin
                    opcode     <= 8'h00;
                    brk_is_brk <= 1'b0;
                    int_nmi_q  <= nmi_edge;
                    state      <= S_BRK_PAD;
                end else begin
                    opcode     <= bus_data_i;
                    brk_is_brk <= 1'b1;
                    pc         <= pc + 16'd1;
                    // implied single-cycle executes (keyed on the incoming
                    // byte; the registered decode mirrors it)
                    case (fetch_op)
                        O_TAX: begin x <= a;      p[FN] <= a[7]; p[FZ] <= (a == 8'd0); end
                        O_TXA: begin a <= x;      p[FN] <= x[7]; p[FZ] <= (x == 8'd0); end
                        O_TAY: begin y <= a;      p[FN] <= a[7]; p[FZ] <= (a == 8'd0); end
                        O_TYA: begin a <= y;      p[FN] <= y[7]; p[FZ] <= (y == 8'd0); end
                        O_TSX: begin x <= s;      p[FN] <= s[7]; p[FZ] <= (s == 8'd0); end
                        O_TXS: s <= x;            // no flags
                        O_INX: begin x <= x + 8'd1; p[FN] <= xpi[7]; p[FZ] <= (xpi == 8'd0); end
                        O_INY: begin y <= y + 8'd1; p[FN] <= ypi[7]; p[FZ] <= (ypi == 8'd0); end
                        O_DEX: begin x <= x - 8'd1; p[FN] <= xmi[7]; p[FZ] <= (xmi == 8'd0); end
                        O_DEY: begin y <= y - 8'd1; p[FN] <= ymi[7]; p[FZ] <= (ymi == 8'd0); end
                        O_CLC: p[FC] <= 1'b0;
                        O_SEC: p[FC] <= 1'b1;
                        O_CLI: p[FI] <= 1'b0;
                        O_SEI: p[FI] <= 1'b1;
                        O_CLV: p[FV] <= 1'b0;
                        O_CLD: p[FD] <= 1'b0;
                        O_SED: p[FD] <= 1'b1;
                        O_ASLA: begin
                            p[FC] <= a[7];
                            a     <= {a[6:0], 1'b0};
                            p[FN] <= a[6];
                            p[FZ] <= ({a[6:0], 1'b0} == 8'd0);
                        end
                        O_LSRA: begin
                            p[FC] <= a[0];
                            a     <= {1'b0, a[7:1]};
                            p[FN] <= 1'b0;
                            p[FZ] <= ({1'b0, a[7:1]} == 8'd0);
                        end
                        O_ROLA: begin
                            p[FC] <= a[7];
                            a     <= {a[6:0], p[FC]};
                            p[FN] <= a[6];
                            p[FZ] <= ({a[6:0], p[FC]} == 8'd0);
                        end
                        O_RORA: begin
                            p[FC] <= a[0];
                            a     <= {p[FC], a[7:1]};
                            p[FN] <= p[FC];
                            p[FZ] <= ({p[FC], a[7:1]} == 8'd0);
                        end
                        default: ;
                    endcase
                    // next state
                    if (fetch_mode == M_SPEC) begin
                        case (fetch_op)
                            O_JSR: state <= S_JSR_L;
                            O_RTS: state <= S_RTS_L;
                            O_RTI: state <= S_RTI_P;
                            O_BRK: begin brk_is_brk <= 1'b1; state <= S_BRK_PAD; end
                            O_PHA, O_PHP: state <= S_PSH;
                            default: state <= S_PUL;      // PLA/PLP
                        endcase
                    end else begin
                        state <= fetch_next;
                    end
                end
            end

            // ---- addressing ----
            S_IMM: begin
                data_q <= bus_data_i;
                pc     <= pc + 16'd1;
                state  <= S_EXEC;
            end
            S_ZP: begin
                data_q <= bus_data_i;                // zp address byte
                pc     <= pc + 16'd1;
                if (mode == M_IZX) begin
                    ptr_q <= {8'h00, bus_data_i} + {8'h00, x};
                    state <= S_PTR_L;
                end else if (mode == M_IZY) begin
                    ptr_q <= {8'h00, bus_data_i};
                    state <= S_PTR_L;
                end else if (mode == M_ZPX || mode == M_ZPY) begin
                    state <= S_ZPI;
                end else begin
                    target_q <= {8'h00, bus_data_i};
                    state    <= is_store ? S_WR : (is_rmw ? S_RMWR : S_RD);
                end
            end
            S_ZPI: begin
                target_q <= {8'h00, data_q + ((mode == M_ZPY) ? y : x)};
                state    <= is_store ? S_WR : (is_rmw ? S_RMWR : S_RD);
            end
            S_ABS_L: begin
                data_q <= bus_data_i;
                pc     <= pc + 16'd1;
                state  <= S_ABS_H;
            end
            S_ABS_H: begin
                pc <= pc + 16'd1;
                case (mode)
                    M_IND: begin
                        ptr_q <= {bus_data_i, data_q};
                        state <= S_IND_L;
                    end
                    M_ABX: begin
                        target_q <= {bus_data_i, data_q} + {8'h00, x};
                        state    <= is_store ? S_WR : (is_rmw ? S_RMWR : S_RD);
                    end
                    M_ABY: begin
                        target_q <= {bus_data_i, data_q} + {8'h00, y};
                        state    <= is_store ? S_WR : (is_rmw ? S_RMWR : S_RD);
                    end
                    default: begin                     // M_ABS
                        if (op == O_JMP) begin
                            pc    <= {bus_data_i, data_q};
                            state <= S_FETCH;
                        end else begin
                            target_q <= {bus_data_i, data_q};
                            state    <= is_store ? S_WR
                                      : (is_rmw ? S_RMWR : S_RD);
                        end
                    end
                endcase
            end
            S_PTR_L: begin
                data_q <= bus_data_i;
                state  <= S_PTR_H;
            end
            S_PTR_H: begin
                ptr_q <= {bus_data_i, data_q};       // zero-page pointer
                if (mode == M_IZY) begin
                    target_q <= {bus_data_i, data_q} + {8'h00, y};
                    state    <= is_store ? S_WR : S_RD;
                end else begin
                    target_q <= {bus_data_i, data_q};
                    state    <= is_store ? S_WR : S_RD;
                end
            end
            S_IND_L: begin
                data_q <= bus_data_i;
                state  <= S_IND_H;
            end
            S_IND_H: begin
                pc    <= {bus_data_i, data_q};
                state <= S_FETCH;
            end

            // ---- data access ----
            S_RD: begin
                data_q <= bus_data_i;
                state  <= S_EXEC;
            end
            S_WR: state <= S_FETCH;

            // ---- executes ----
            S_EXEC: begin
                state <= S_FETCH;
                case (op)
                    O_ORA: begin
                        a     <= ora_r;
                        p[FN] <= ora_r >= 8'h80;
                        p[FZ] <= (ora_r == 8'd0);
                    end
                    O_AND: begin
                        a     <= and_r;
                        p[FN] <= and_r >= 8'h80;
                        p[FZ] <= (and_r == 8'd0);
                    end
                    O_EOR: begin
                        a     <= eor_r;
                        p[FN] <= eor_r >= 8'h80;
                        p[FZ] <= (eor_r == 8'd0);
                    end
                    O_ADC: begin
                        if (!p[FD]) begin
                            a     <= sum9[7:0];
                            p[FC] <= sum9[8];
                            p[FN] <= sum9[7];
                            p[FZ] <= (sum9[7:0] == 8'd0);
                            p[FV] <= sum_v;
                        end else begin
                            // py65: N/V/Z from the pre-adjust ALU result
                            a     <= dec_r;
                            p[FC] <= dec_c;
                            p[FN] <= adc_alu[7];
                            p[FZ] <= (adc_alu == 8'd0);
                            p[FV] <= (~(a[7] ^ data_q[7])) & (a[7] ^ adc_alu[7]);
                        end
                    end
                    O_SBC: begin
                        if (!p[FD]) begin
                            a     <= sum9[7:0];
                            p[FC] <= sum9[8];
                            p[FN] <= sum9[7];
                            p[FZ] <= (sum9[7:0] == 8'd0);
                            p[FV] <= sum_v;
                        end else begin
                            a     <= dec_r;
                            p[FC] <= dec_c;
                            p[FN] <= sum9[7];
                            p[FZ] <= (sum9[7:0] == 8'd0);
                            p[FV] <= ((a[7] ^ data_q[7]) & (a[7] ^ sum9[7]));
                        end
                    end
                    O_CMP: begin
                        p[FC] <= (a >= data_q);
                        p[FN] <= (a - data_q) >= 8'h80;
                        p[FZ] <= (a == data_q);
                    end
                    O_CPX: begin
                        p[FC] <= (x >= data_q);
                        p[FN] <= (x - data_q) >= 8'h80;
                        p[FZ] <= (x == data_q);
                    end
                    O_CPY: begin
                        p[FC] <= (y >= data_q);
                        p[FN] <= (y - data_q) >= 8'h80;
                        p[FZ] <= (y == data_q);
                    end
                    O_BIT: begin
                        p[FZ] <= ((a & data_q) == 8'd0);
                        p[FN] <= data_q[7];
                        p[FV] <= data_q[6];
                    end
                    O_LDA: begin
                        a     <= data_q;
                        p[FN] <= data_q[7];
                        p[FZ] <= (data_q == 8'd0);
                    end
                    O_LDX: begin
                        x     <= data_q;
                        p[FN] <= data_q[7];
                        p[FZ] <= (data_q == 8'd0);
                    end
                    O_LDY: begin
                        y     <= data_q;
                        p[FN] <= data_q[7];
                        p[FZ] <= (data_q == 8'd0);
                    end
                    default: state <= S_FAULT;       // unreachable by decode
                endcase
            end

            // ---- RMW ----
            S_RMWR: begin
                data_q <= bus_data_i;
                state  <= S_EXEC_M;
            end
            S_EXEC_M: begin
                state <= S_RMWW;
                case (op)
                    O_ASL: begin
                        data_q <= {data_q[6:0], 1'b0};
                        p[FC]  <= data_q[7];
                        p[FN]  <= data_q[6];
                        p[FZ]  <= ({data_q[6:0], 1'b0} == 8'd0);
                    end
                    O_LSR: begin
                        data_q <= {1'b0, data_q[7:1]};
                        p[FC]  <= data_q[0];
                        p[FN]  <= 1'b0;
                        p[FZ]  <= ({1'b0, data_q[7:1]} == 8'd0);
                    end
                    O_ROL: begin
                        data_q <= {data_q[6:0], p[FC]};
                        p[FC]  <= data_q[7];
                        p[FN]  <= data_q[6];
                        p[FZ]  <= ({data_q[6:0], p[FC]} == 8'd0);
                    end
                    O_ROR: begin
                        data_q <= {p[FC], data_q[7:1]};
                        p[FC]  <= data_q[0];
                        p[FN]  <= p[FC];
                        p[FZ]  <= ({p[FC], data_q[7:1]} == 8'd0);
                    end
                    O_INC: begin
                        data_q <= data_q + 8'd1;
                        p[FN]  <= ((data_q + 8'd1) >= 8'h80);
                        p[FZ]  <= ((data_q + 8'd1) == 8'd0);
                    end
                    O_DEC: begin
                        data_q <= data_q - 8'd1;
                        p[FN]  <= ((data_q - 8'd1) >= 8'h80);
                        p[FZ]  <= ((data_q - 8'd1) == 8'd0);
                    end
                    default: state <= S_FAULT;
                endcase
            end
            S_RMWW: state <= S_FETCH;

            // ---- branch ----
            S_REL: begin
                pc    <= pc + 16'd1 + (branch_taken
                        ? {{8{bus_data_i[7]}}, bus_data_i} : 16'd0);
                state <= S_FETCH;
            end

            // ---- stack ----
            S_PSH: begin
                s     <= s - 8'd1;
                state <= S_FETCH;
            end
            S_PUL: begin
                s <= s + 8'd1;
                if (op == O_PLA) begin
                    a     <= bus_data_i;
                    p[FN] <= bus_data_i[7];
                    p[FZ] <= (bus_data_i == 8'd0);
                end else begin                   // PLP
                    p <= (bus_data_i & ~8'h10) | 8'h20;
                end
                state <= S_FETCH;
            end

            // ---- JSR ----
            S_JSR_L: begin
                data_q <= bus_data_i;
                pc     <= pc + 16'd1;            // pc now = the pushed address
                state  <= S_JSR_PH;
            end
            S_JSR_PH: begin
                s     <= s - 8'd1;
                state <= S_JSR_PL;
            end
            S_JSR_PL: begin
                s     <= s - 8'd1;
                state <= S_JSR_H;
            end
            S_JSR_H: begin
                pc    <= {bus_data_i, data_q};
                state <= S_FETCH;
            end

            // ---- RTS ----
            S_RTS_L: begin
                data_q <= bus_data_i;
                s      <= s + 8'd1;
                state  <= S_RTS_H;
            end
            S_RTS_H: begin
                pc    <= {bus_data_i, data_q} + 16'd1;
                s     <= s + 8'd1;
                state <= S_FETCH;
            end

            // ---- RTI ----
            S_RTI_P: begin
                p     <= (bus_data_i & ~8'h10) | 8'h20;
                s     <= s + 8'd1;
                state <= S_RTI_L;
            end
            S_RTI_L: begin
                data_q <= bus_data_i;
                s      <= s + 8'd1;
                state  <= S_RTI_H;
            end
            S_RTI_H: begin
                pc    <= {bus_data_i, data_q};
                s     <= s + 8'd1;
                state <= S_FETCH;
            end

            // ---- BRK / interrupt ----
            S_BRK_PAD: begin
                // BRK pushes opcode+2; a hijacked IRQ pushes the address of
                // the instruction it displaced (pc was not incremented).
                pc    <= pc + (brk_is_brk ? 16'd1 : 16'd0);
                state <= S_BRK_PH;
            end
            S_BRK_PH: begin
                s     <= s - 8'd1;
                state <= S_BRK_PL;
            end
            S_BRK_PL: begin
                s     <= s - 8'd1;
                state <= S_BRK_PS;
            end
            S_BRK_PS: begin
                s     <= s - 8'd1;
                p[FI] <= 1'b1;               // I sets after the push
                state <= S_VEC_L;
            end
            S_VEC_L: begin
                data_q <= bus_data_i;
                state  <= S_VEC_H;
            end
            S_VEC_H: begin
                pc    <= {bus_data_i, data_q};
                state <= S_FETCH;
            end

            S_FAULT: state <= S_FAULT;
            default: state <= S_FAULT;
            endcase
        end
    end

`ifdef FORMAL
    `include "mos_6502_props.sv"
    `include "mos_6502_cover_setup.sv"
`endif
endmodule
