// WDC W65C816S: 16-bit 6502-family CPU with 24-bit addressing, as used in
// the Ricoh 5A22 (SNES). One bus cycle per enabled clock edge; the address
// and bus qualifiers for the current cycle are combinational from state, the
// read data is sampled at the end of the cycle. See spec/spec.md.
module wdc_65c816 (
    input  logic clk,
    input  logic ce,             // end of the current bus cycle
    input  logic rst_n,
    input  logic irq_n, nmi_n,
    output logic [23:0] addr_o,
    input  logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic we_o,           // write cycle (inverse of RWB)
    output logic vda_o, vpa_o,   // valid data / program address
    output logic vpb_o,          // vector pull (active high here)
    output logic ml_o,           // memory lock during read-modify-write (active high)
    output logic e_o, m_o, x_o,  // emulation flag and register widths
    output logic fetch_o,        // opcode fetch cycle (instruction boundary)
    output logic waiting_o,      // WAI asleep
    output logic stopped_o,      // STP
    output logic [15:0] pc_o, a_o, x_reg_o, y_reg_o, s_o, d_o,
    output logic [7:0] p_o, dbr_o, pbr_o
);
    // ---------------- Architectural state ----------------
    logic [15:0] pc, a, x, y, s, d;
    logic [7:0] p, dbr, pbr;
    logic e;
    localparam int FC = 0, FZ = 1, FI = 2, FD = 3, FX = 4, FM = 5, FV = 6, FN = 7;
    wire mf = p[FM];
    wire xf = p[FX];

    // ---------------- Decode ----------------
    typedef enum logic [4:0] {
        M_IMP, M_IMM, M_DP, M_DPX, M_DPY, M_IDP, M_IDX, M_IDY, M_IDL, M_IDLY,
        M_ABS, M_ABX, M_ABY, M_ABL, M_ABLX, M_SR, M_SRIY,
        M_JMP, M_JML, M_JMPI, M_JMLI, M_JMPX, M_JSR, M_JSL, M_JSRX,
        M_BR, M_BRL, M_PUSH, M_PULL, M_SPEC
    } mode_e;
    typedef enum logic [6:0] {
        O_ORA, O_AND, O_EOR, O_ADC, O_STA, O_LDA, O_CMP, O_SBC,
        O_BIT, O_BITI, O_LDX, O_LDY, O_CPX, O_CPY, O_STX, O_STY, O_STZ,
        O_ASL, O_LSR, O_ROL, O_ROR, O_INC, O_DEC, O_TSB, O_TRB,
        // implied / accumulator
        O_ASLA, O_LSRA, O_ROLA, O_RORA, O_INA, O_DEA,
        O_INX, O_INY, O_DEX, O_DEY,
        O_CLC, O_SEC, O_CLI, O_SEI, O_CLD, O_SED, O_CLV,
        O_TAX, O_TAY, O_TXA, O_TYA, O_TSX, O_TXS, O_TXY, O_TYX,
        O_TCD, O_TDC, O_TCS, O_TSC, O_XCE, O_NOP, O_XBA, O_WAI, O_STP,
        O_REP, O_SEP, O_WDM,
        // stack
        O_PHA, O_PHX, O_PHY, O_PHP, O_PHB, O_PHK, O_PHD, O_PEA, O_PEI, O_PER,
        O_PLA, O_PLX, O_PLY, O_PLP, O_PLB, O_PLD,
        O_RTS, O_RTL, O_RTI, O_BRK, O_COP, O_MVN, O_MVP,
        O_BRA, O_BRL, O_JMP
    } op_e;

    mode_e f_mode;
    op_e f_op;
    always_comb begin
        f_mode = M_IMP;
        f_op = O_NOP;
        // Group 1 (ORA AND EOR ADC STA LDA CMP SBC).
        if (data_i[1:0] == 2'b01 || (data_i[1:0] == 2'b11 && data_i[3:2] != 2'b10) ||
            data_i[4:0] == 5'b10010) begin
            case (data_i[7:5])
                3'd0: f_op = O_ORA;  3'd1: f_op = O_AND;
                3'd2: f_op = O_EOR;  3'd3: f_op = O_ADC;
                3'd4: f_op = O_STA;  3'd5: f_op = O_LDA;
                3'd6: f_op = O_CMP;  default: f_op = O_SBC;
            endcase
            if (data_i[4:0] == 5'b10010) f_mode = M_IDP;
            else if (data_i[1:0] == 2'b01) begin
                case (data_i[4:2])
                    3'd0: f_mode = M_IDX;  3'd1: f_mode = M_DP;
                    3'd2: f_mode = M_IMM;  3'd3: f_mode = M_ABS;
                    3'd4: f_mode = M_IDY;  3'd5: f_mode = M_DPX;
                    3'd6: f_mode = M_ABY;  default: f_mode = M_ABX;
                endcase
            end else begin
                case (data_i[4:2])
                    3'd0: f_mode = M_SR;   3'd1: f_mode = M_IDL;
                    3'd3: f_mode = M_ABL;  3'd4: f_mode = M_SRIY;
                    3'd5: f_mode = M_IDLY; default: f_mode = M_ABLX;
                endcase
            end
        end
        case (data_i)
            8'h89: begin f_op = O_BITI; f_mode = M_IMM; end
            8'h24: begin f_op = O_BIT; f_mode = M_DP; end
            8'h2c: begin f_op = O_BIT; f_mode = M_ABS; end
            8'h34: begin f_op = O_BIT; f_mode = M_DPX; end
            8'h3c: begin f_op = O_BIT; f_mode = M_ABX; end
            8'ha2: begin f_op = O_LDX; f_mode = M_IMM; end
            8'ha6: begin f_op = O_LDX; f_mode = M_DP; end
            8'hae: begin f_op = O_LDX; f_mode = M_ABS; end
            8'hb6: begin f_op = O_LDX; f_mode = M_DPY; end
            8'hbe: begin f_op = O_LDX; f_mode = M_ABY; end
            8'ha0: begin f_op = O_LDY; f_mode = M_IMM; end
            8'ha4: begin f_op = O_LDY; f_mode = M_DP; end
            8'hac: begin f_op = O_LDY; f_mode = M_ABS; end
            8'hb4: begin f_op = O_LDY; f_mode = M_DPX; end
            8'hbc: begin f_op = O_LDY; f_mode = M_ABX; end
            8'he0: begin f_op = O_CPX; f_mode = M_IMM; end
            8'he4: begin f_op = O_CPX; f_mode = M_DP; end
            8'hec: begin f_op = O_CPX; f_mode = M_ABS; end
            8'hc0: begin f_op = O_CPY; f_mode = M_IMM; end
            8'hc4: begin f_op = O_CPY; f_mode = M_DP; end
            8'hcc: begin f_op = O_CPY; f_mode = M_ABS; end
            8'h86: begin f_op = O_STX; f_mode = M_DP; end
            8'h8e: begin f_op = O_STX; f_mode = M_ABS; end
            8'h96: begin f_op = O_STX; f_mode = M_DPY; end
            8'h84: begin f_op = O_STY; f_mode = M_DP; end
            8'h8c: begin f_op = O_STY; f_mode = M_ABS; end
            8'h94: begin f_op = O_STY; f_mode = M_DPX; end
            8'h64: begin f_op = O_STZ; f_mode = M_DP; end
            8'h74: begin f_op = O_STZ; f_mode = M_DPX; end
            8'h9c: begin f_op = O_STZ; f_mode = M_ABS; end
            8'h9e: begin f_op = O_STZ; f_mode = M_ABX; end
            8'h06: begin f_op = O_ASL; f_mode = M_DP; end
            8'h0e: begin f_op = O_ASL; f_mode = M_ABS; end
            8'h16: begin f_op = O_ASL; f_mode = M_DPX; end
            8'h1e: begin f_op = O_ASL; f_mode = M_ABX; end
            8'h46: begin f_op = O_LSR; f_mode = M_DP; end
            8'h4e: begin f_op = O_LSR; f_mode = M_ABS; end
            8'h56: begin f_op = O_LSR; f_mode = M_DPX; end
            8'h5e: begin f_op = O_LSR; f_mode = M_ABX; end
            8'h26: begin f_op = O_ROL; f_mode = M_DP; end
            8'h2e: begin f_op = O_ROL; f_mode = M_ABS; end
            8'h36: begin f_op = O_ROL; f_mode = M_DPX; end
            8'h3e: begin f_op = O_ROL; f_mode = M_ABX; end
            8'h66: begin f_op = O_ROR; f_mode = M_DP; end
            8'h6e: begin f_op = O_ROR; f_mode = M_ABS; end
            8'h76: begin f_op = O_ROR; f_mode = M_DPX; end
            8'h7e: begin f_op = O_ROR; f_mode = M_ABX; end
            8'he6: begin f_op = O_INC; f_mode = M_DP; end
            8'hee: begin f_op = O_INC; f_mode = M_ABS; end
            8'hf6: begin f_op = O_INC; f_mode = M_DPX; end
            8'hfe: begin f_op = O_INC; f_mode = M_ABX; end
            8'hc6: begin f_op = O_DEC; f_mode = M_DP; end
            8'hce: begin f_op = O_DEC; f_mode = M_ABS; end
            8'hd6: begin f_op = O_DEC; f_mode = M_DPX; end
            8'hde: begin f_op = O_DEC; f_mode = M_ABX; end
            8'h04: begin f_op = O_TSB; f_mode = M_DP; end
            8'h0c: begin f_op = O_TSB; f_mode = M_ABS; end
            8'h14: begin f_op = O_TRB; f_mode = M_DP; end
            8'h1c: begin f_op = O_TRB; f_mode = M_ABS; end
            8'h0a: f_op = O_ASLA;  8'h4a: f_op = O_LSRA;
            8'h2a: f_op = O_ROLA;  8'h6a: f_op = O_RORA;
            8'h1a: f_op = O_INA;   8'h3a: f_op = O_DEA;
            8'he8: f_op = O_INX;   8'hc8: f_op = O_INY;
            8'hca: f_op = O_DEX;   8'h88: f_op = O_DEY;
            8'h18: f_op = O_CLC;   8'h38: f_op = O_SEC;
            8'h58: f_op = O_CLI;   8'h78: f_op = O_SEI;
            8'hd8: f_op = O_CLD;   8'hf8: f_op = O_SED;
            8'hb8: f_op = O_CLV;
            8'haa: f_op = O_TAX;   8'ha8: f_op = O_TAY;
            8'h8a: f_op = O_TXA;   8'h98: f_op = O_TYA;
            8'hba: f_op = O_TSX;   8'h9a: f_op = O_TXS;
            8'h9b: f_op = O_TXY;   8'hbb: f_op = O_TYX;
            8'h5b: f_op = O_TCD;   8'h7b: f_op = O_TDC;
            8'h1b: f_op = O_TCS;   8'h3b: f_op = O_TSC;
            8'hfb: f_op = O_XCE;   8'hea: f_op = O_NOP;
            8'heb: f_op = O_XBA;   8'hcb: f_op = O_WAI;
            8'hdb: f_op = O_STP;
            8'hc2: begin f_op = O_REP; f_mode = M_SPEC; end
            8'he2: begin f_op = O_SEP; f_mode = M_SPEC; end
            8'h42: begin f_op = O_WDM; f_mode = M_SPEC; end
            8'h48: begin f_op = O_PHA; f_mode = M_PUSH; end
            8'hda: begin f_op = O_PHX; f_mode = M_PUSH; end
            8'h5a: begin f_op = O_PHY; f_mode = M_PUSH; end
            8'h08: begin f_op = O_PHP; f_mode = M_PUSH; end
            8'h8b: begin f_op = O_PHB; f_mode = M_PUSH; end
            8'h4b: begin f_op = O_PHK; f_mode = M_PUSH; end
            8'h0b: begin f_op = O_PHD; f_mode = M_PUSH; end
            8'hf4: begin f_op = O_PEA; f_mode = M_SPEC; end
            8'hd4: begin f_op = O_PEI; f_mode = M_SPEC; end
            8'h62: begin f_op = O_PER; f_mode = M_SPEC; end
            8'h68: begin f_op = O_PLA; f_mode = M_PULL; end
            8'hfa: begin f_op = O_PLX; f_mode = M_PULL; end
            8'h7a: begin f_op = O_PLY; f_mode = M_PULL; end
            8'h28: begin f_op = O_PLP; f_mode = M_PULL; end
            8'hab: begin f_op = O_PLB; f_mode = M_PULL; end
            8'h2b: begin f_op = O_PLD; f_mode = M_PULL; end
            8'h60: begin f_op = O_RTS; f_mode = M_SPEC; end
            8'h6b: begin f_op = O_RTL; f_mode = M_SPEC; end
            8'h40: begin f_op = O_RTI; f_mode = M_SPEC; end
            8'h00: begin f_op = O_BRK; f_mode = M_SPEC; end
            8'h02: begin f_op = O_COP; f_mode = M_SPEC; end
            8'h54: begin f_op = O_MVN; f_mode = M_SPEC; end
            8'h44: begin f_op = O_MVP; f_mode = M_SPEC; end
            8'h10, 8'h30, 8'h50, 8'h70, 8'h90, 8'hb0, 8'hd0, 8'hf0, 8'h80:
                begin f_op = O_BRA; f_mode = M_BR; end
            8'h82: begin f_op = O_BRL; f_mode = M_BRL; end
            8'h4c: begin f_op = O_JMP; f_mode = M_JMP; end
            8'h5c: begin f_op = O_JMP; f_mode = M_JML; end
            8'h6c: begin f_op = O_JMP; f_mode = M_JMPI; end
            8'hdc: begin f_op = O_JMP; f_mode = M_JMLI; end
            8'h7c: begin f_op = O_JMP; f_mode = M_JMPX; end
            8'h20: begin f_op = O_JMP; f_mode = M_JSR; end
            8'h22: begin f_op = O_JMP; f_mode = M_JSL; end
            8'hfc: begin f_op = O_JMP; f_mode = M_JSRX; end
            default: ;
        endcase
    end

    // ---------------- Sequencer state ----------------
    typedef enum logic [6:0] {
        S_FETCH,
        S_IMP, S_IMP2,                 // implied internal cycles
        S_IMM_LO, S_IMM_HI,
        S_DP_OP, S_DP_IO, S_IDX_IO,    // direct operand, DL penalty, d,x add
        S_PTR_LO, S_PTR_HI, S_PTR_BANK, S_PAGE_IO, S_SR_IO, S_SRIY_IO,
        S_ABS_LO, S_ABS_HI, S_ABS_BANK,
        S_RD_LO, S_RD_HI, S_WR_LO, S_WR_HI,
        S_RMW_LO, S_RMW_HI, S_RMW_IO, S_RMW_WH, S_RMW_WL,
        S_PUSH_IO, S_PUSH_HI, S_PUSH_LO,
        S_PULL_IO1, S_PULL_IO2, S_PULL_LO, S_PULL_HI,
        S_SPEC_OP, S_SPEC_OP2, S_SPEC_IO,
        S_JSR_IO, S_JSR_PCH, S_JSR_PCL,
        S_JSL_PBR, S_JSL_IO, S_JSL_BANK,
        S_JSRX_PCH, S_JSRX_PCL, S_JSRX_HI, S_JSRX_IO,
        S_JMPX_IO,
        S_RET_IO1, S_RET_IO2, S_RET_P, S_RET_LO, S_RET_HI, S_RET_BANK, S_RET_IO3,
        S_BRK_SIG, S_INT_IO, S_BRK_PBR, S_BRK_PCH, S_BRK_PCL, S_BRK_P, S_VEC_LO, S_VEC_HI,
        S_BR_OP, S_BR_IO, S_BR_PAGE, S_BRL_LO, S_BRL_HI, S_BRL_IO,
        S_MV_DST, S_MV_SRC, S_MV_RD, S_MV_WR, S_MV_IO1, S_MV_IO2,
        S_WAIT, S_STOP, S_WDM,
        S_RST0, S_RST1, S_RST2, S_RST3, S_RST4
    } state_e;
    state_e state;

    logic [7:0] opcode;
    mode_e mode;
    op_e op;
    logic w16;                     // current data access is 16-bit
    logic [23:0] ea;               // effective data address
    logic ea_b0;                   // high byte wraps within bank 0 (direct/stack)
    logic [23:0] ptr;              // pointer address
    logic ptr_page;                // pointer high byte wraps within its page
    logic [15:0] aa;               // operand / pointer value
    logic [7:0] bank;              // long pointer bank
    logic [7:0] dlo;               // first data byte read
    logic [15:0] rmw_val;          // RMW result
    logic stk_n;                   // native-style stack access in emulation mode
    logic int_q;                   // servicing a hardware interrupt
    logic int_nmi;                 // which one
    logic nmi_prev, nmi_pend;

    // ---------------- Helpers ----------------
    wire dl_nz = d[7:0] != 8'h00;
    wire e_page = e && !dl_nz;     // emulation-mode direct-page wrapping
    wire [15:0] pc_m1 = pc - 16'd1;
    wire [23:0] ea_inc = ea_b0 ? {8'h00, ea[15:0] + 16'd1} : ea + 24'd1;
    wire [23:0] ptr_inc = ptr_page ? {ptr[23:8], ptr[7:0] + 8'd1}
                                   : {ptr[23:16], ptr[15:0] + 16'd1};
    wire [23:0] ptr_inc2 = {ptr[23:16], ptr[15:0] + 16'd2};
    // Stack address: page 1 in emulation mode for 6502-heritage operations.
    wire stk_page = e && !stk_n;
    wire [23:0] stk_addr = stk_page ? {16'h0001, s[7:0]} : {8'h00, s};
    wire [15:0] s_dec = stk_page ? {8'h01, s[7:0] - 8'd1} : s - 16'd1;
    wire [15:0] s_inc = stk_page ? {8'h01, s[7:0] + 8'd1} : s + 16'd1;
    wire [23:0] stk_next = stk_page ? {16'h0001, s[7:0] + 8'd1} : {8'h00, s + 16'd1};

    function automatic logic is_read(input op_e o);
        is_read = (o == O_ORA || o == O_AND || o == O_EOR || o == O_ADC || o == O_LDA || o == O_CMP || o == O_SBC || o == O_BIT || o == O_LDX || o == O_LDY || o == O_CPX || o == O_CPY);
    endfunction
    function automatic logic is_write(input op_e o);
        is_write = (o == O_STA || o == O_STX || o == O_STY || o == O_STZ);
    endfunction
    function automatic logic is_rmw(input op_e o);
        is_rmw = (o == O_ASL || o == O_LSR || o == O_ROL || o == O_ROR || o == O_INC || o == O_DEC || o == O_TSB || o == O_TRB);
    endfunction
    function automatic logic x_width(input op_e o);
        x_width = (o == O_LDX || o == O_LDY || o == O_CPX || o == O_CPY || o == O_STX || o == O_STY);
    endfunction

    // Data-phase entry for the current operation.
    state_e data_state;
    always_comb begin
        if (is_write(op)) data_state = S_WR_LO;
        else if (is_rmw(op)) data_state = S_RMW_LO;
        else data_state = S_RD_LO;
    end

    // Store value.
    logic [15:0] store_val;
    always_comb begin
        case (op)
            O_STX: store_val = x;
            O_STY: store_val = y;
            O_STZ: store_val = 16'h0000;
            default: store_val = a;
        endcase
    end

    // ---------------- ALU ----------------
    // ADC/SBC with 65C816 decimal behaviour (nibble-serial correction; V from
    // the uncorrected high digit), 8- or 16-bit.
    function automatic logic [17:0] addsub(input logic [15:0] acc, input logic [15:0] opnd,
                                           input logic cin, input logic dec, input logic wide,
                                           input logic sub);
        int av, bv, r, digit, top, lim;
        logic c, v;
        logic [15:0] b16;
        b16 = sub ? ~opnd : opnd;
        av = wide ? $signed(32'(acc)) : $signed(32'(acc[7:0]));
        bv = wide ? $signed(32'(b16)) : $signed(32'(b16[7:0]));
        top = wide ? 12 : 4;
        lim = wide ? 'h10000 : 'h100;
        if (!dec) begin
            r = av + bv + $signed(32'(cin));
        end else begin
            // Low digits: add, correct, carry on.
            c = cin;
            r = 0;
            for (int sh = 0; sh < 12; sh = sh + 4) if (sh < top) begin
                digit = ((av >> sh) & 'hf) + ((bv >> sh) & 'hf) + $signed(32'(c));
                if (!sub && digit > 9) digit = digit + 6;
                if (sub && digit <= 15) digit = digit - 6;
                c = digit > 15;
                r = r | ((digit & 'hf) << sh);
            end
            // Top digit: uncorrected until after V is taken.
            r = r + ((((av >> top) & 'hf) + ((bv >> top) & 'hf) + $signed(32'(c))) << top);
        end
        v = ((~(av ^ bv) & (av ^ r)) & (lim >> 1)) != 0;
        if (dec) begin
            if (!sub && r >= ('ha << top)) r = r + (6 << top);
            if (sub && r < lim) r = r - (6 << top);
        end
        addsub[15:0] = wide ? r[15:0] : {acc[15:8], r[7:0]};
        addsub[16] = r >= lim;
        addsub[17] = v;
    endfunction

    // Operand of the completing read (immediate or memory).
    logic [15:0] rd_val;
    always_comb begin
        if (state == S_IMM_HI || state == S_RD_HI) rd_val = {data_i, dlo};
        else rd_val = {8'h00, data_i};
    end

    // Result of a completing read operation.
    logic [15:0] r_a, r_x, r_y;
    logic [7:0] r_p;
    always_comb begin
        logic [17:0] as;
        logic [16:0] cmp;
        logic [15:0] acc_w, res;
        acc_w = a;
        r_a = a; r_x = x; r_y = y; r_p = p;
        as = addsub(a, rd_val, p[FC], p[FD], w16, op == O_SBC);
        res = 16'h0000;
        cmp = 17'h0;
        case (op)
            O_ORA: begin res = a | rd_val; r_a = w16 ? res : {a[15:8], res[7:0]}; end
            O_AND: begin res = a & rd_val; r_a = w16 ? res : {a[15:8], res[7:0]}; end
            O_EOR: begin res = a ^ rd_val; r_a = w16 ? res : {a[15:8], res[7:0]}; end
            O_LDA: begin res = rd_val; r_a = w16 ? res : {a[15:8], res[7:0]}; end
            O_LDX: begin res = rd_val; r_x = res; end
            O_LDY: begin res = rd_val; r_y = res; end
            O_ADC, O_SBC: begin
                res = as[15:0]; r_a = as[15:0];
                r_p[FC] = as[16]; r_p[FV] = as[17];
            end
            O_CMP, O_CPX, O_CPY: begin
                acc_w = op == O_CMP ? a : (op == O_CPX ? x : y);
                if (w16) cmp = {1'b0, acc_w} - {1'b0, rd_val};
                else cmp = {9'h0, acc_w[7:0]} - {9'h0, rd_val[7:0]};
                res = cmp[15:0];
                r_p[FC] = w16 ? !cmp[16] : !cmp[8];
            end
            O_BIT, O_BITI: begin
                res = a & rd_val;
                if (op == O_BIT) begin
                    r_p[FN] = w16 ? rd_val[15] : rd_val[7];
                    r_p[FV] = w16 ? rd_val[14] : rd_val[6];
                end
            end
            default: ;
        endcase
        r_p[FZ] = w16 ? (res == 16'h0) : (res[7:0] == 8'h0);
        if (op != O_BIT && op != O_BITI) r_p[FN] = w16 ? res[15] : res[7];
    end

    // Read-modify-write result.
    logic [15:0] rmw_in, rmw_res;
    logic rmw_c, rmw_z, rmw_n;
    always_comb begin
        rmw_in = w16 ? a : {8'h00, a[7:0]};
        if (state == S_RMW_LO) rmw_in = {8'h00, data_i};
        if (state == S_RMW_HI) rmw_in = {data_i, dlo};
        if (state == S_RMW_IO) rmw_in = w16 ? aa : {8'h00, aa[7:0]};
        rmw_c = p[FC];
        rmw_res = rmw_in;
        case (op)
            O_ASL, O_ASLA: begin rmw_c = w16 ? rmw_in[15] : rmw_in[7]; rmw_res = rmw_in << 1; end
            O_ROL, O_ROLA: begin rmw_c = w16 ? rmw_in[15] : rmw_in[7]; rmw_res = {rmw_in[14:0], p[FC]}; end
            O_LSR, O_LSRA: begin rmw_c = rmw_in[0]; rmw_res = rmw_in >> 1; end
            O_ROR, O_RORA: begin
                rmw_c = rmw_in[0];
                rmw_res = w16 ? {p[FC], rmw_in[15:1]} : {8'h00, p[FC], rmw_in[7:1]};
            end
            O_INC, O_INA: rmw_res = rmw_in + 16'd1;
            O_DEC, O_DEA: rmw_res = rmw_in - 16'd1;
            O_TSB: rmw_res = rmw_in | a;
            O_TRB: rmw_res = rmw_in & ~a;
            default: ;
        endcase
        if (op == O_TSB || op == O_TRB)
            rmw_z = w16 ? ((rmw_in & a) == 16'h0) : ((rmw_in[7:0] & a[7:0]) == 8'h0);
        else
            rmw_z = w16 ? (rmw_res == 16'h0) : (rmw_res[7:0] == 8'h0);
        rmw_n = w16 ? rmw_res[15] : rmw_res[7];
    end

    // Flags for an 8/16-bit value.
    function automatic logic [7:0] nz(input logic [7:0] pin, input logic [15:0] v, input logic wide);
        nz = pin;
        nz[FZ] = wide ? (v == 16'h0) : (v[7:0] == 8'h0);
        nz[FN] = wide ? v[15] : v[7];
    endfunction

    // Branch condition.
    logic br_taken;
    always_comb begin
        case (opcode[7:5])
            3'd0: br_taken = !p[FN];
            3'd1: br_taken = p[FN];
            3'd2: br_taken = !p[FV];
            3'd3: br_taken = p[FV];
            3'd4: br_taken = opcode == 8'h80 ? 1'b1 : !p[FC];
            3'd5: br_taken = p[FC];
            3'd6: br_taken = !p[FZ];
            default: br_taken = p[FZ];
        endcase
    end

    // Value pushed by push operations / BRK / JSR.
    logic [15:0] push_val;
    logic push_wide;
    always_comb begin
        push_val = a;
        push_wide = 1'b0;
        case (op)
            O_PHA: begin push_val = a; push_wide = !mf; end
            O_PHX: begin push_val = x; push_wide = !xf; end
            O_PHY: begin push_val = y; push_wide = !xf; end
            O_PHP: begin push_val = {8'h00, p}; end
            O_PHB: begin push_val = {8'h00, dbr}; end
            O_PHK: begin push_val = {8'h00, pbr}; end
            O_PHD: begin push_val = d; push_wide = 1'b1; end
            O_PEA, O_PEI, O_PER: begin push_val = aa; push_wide = 1'b1; end
            default: ;
        endcase
    end

    // Return address pushed by JSR (last operand byte), JSL, JSR (a,x), BRK.
    wire [15:0] ret_pc = mode == M_JSR ? pc_m1 : pc;

    // Interrupt request sampled at instruction boundaries.
    wire int_req = nmi_pend || (!irq_n && !p[FI]);

    // ---------------- Bus outputs ----------------
    always_comb begin
        addr_o = {pbr, pc};
        data_o = 8'h00;
        we_o = 1'b0;
        vda_o = 1'b0;
        vpa_o = 1'b0;
        vpb_o = 1'b0;
        ml_o = 1'b0;
        case (state)
            S_FETCH: begin vda_o = 1'b1; vpa_o = 1'b1; end
            S_IMP, S_IMP2, S_PUSH_IO, S_PULL_IO1, S_PULL_IO2, S_RET_IO1, S_RET_IO2,
            S_INT_IO, S_WAIT, S_STOP: ;
            S_IMM_LO, S_IMM_HI, S_DP_OP, S_ABS_LO, S_ABS_HI, S_ABS_BANK, S_SPEC_OP,
            S_SPEC_OP2, S_BR_OP, S_BRL_LO, S_BRL_HI, S_JSL_BANK, S_JSRX_HI, S_BRK_SIG,
            S_MV_DST, S_MV_SRC:
                vpa_o = 1'b1;
            S_DP_IO, S_IDX_IO, S_SR_IO, S_SPEC_IO, S_JSR_IO, S_JSRX_IO, S_JMPX_IO,
            S_BR_IO, S_BR_PAGE, S_BRL_IO:
                addr_o = {pbr, pc_m1};
            S_PAGE_IO: addr_o = {dbr, aa[15:8], ea[7:0]};
            S_SRIY_IO: addr_o = ptr_inc;
            S_PTR_LO: begin addr_o = ptr; vda_o = 1'b1; end
            S_PTR_HI: begin addr_o = ptr_inc; vda_o = 1'b1; end
            S_PTR_BANK: begin addr_o = ptr_inc2; vda_o = 1'b1; end
            S_RD_LO: begin addr_o = ea; vda_o = 1'b1; end
            S_RD_HI: begin addr_o = ea_inc; vda_o = 1'b1; end
            S_WR_LO: begin addr_o = ea; vda_o = 1'b1; we_o = 1'b1; data_o = store_val[7:0]; end
            S_WR_HI: begin addr_o = ea_inc; vda_o = 1'b1; we_o = 1'b1; data_o = store_val[15:8]; end
            S_RMW_LO: begin addr_o = ea; vda_o = 1'b1; ml_o = 1'b1; end
            S_RMW_HI: begin addr_o = ea_inc; vda_o = 1'b1; ml_o = 1'b1; end
            S_RMW_IO: begin
                ml_o = 1'b1;
                addr_o = w16 ? ea_inc : ea;
                if (e) begin we_o = 1'b1; data_o = aa[7:0]; end
            end
            S_RMW_WH: begin addr_o = ea_inc; vda_o = 1'b1; ml_o = 1'b1; we_o = 1'b1; data_o = rmw_val[15:8]; end
            S_RMW_WL: begin addr_o = ea; vda_o = 1'b1; ml_o = 1'b1; we_o = 1'b1; data_o = rmw_val[7:0]; end
            S_PUSH_HI: begin addr_o = stk_addr; vda_o = 1'b1; we_o = 1'b1; data_o = push_val[15:8]; end
            S_PUSH_LO: begin addr_o = stk_addr; vda_o = 1'b1; we_o = 1'b1; data_o = push_val[7:0]; end
            S_PULL_LO, S_PULL_HI, S_RET_P, S_RET_LO, S_RET_HI, S_RET_BANK:
                begin addr_o = stk_next; vda_o = 1'b1; end
            S_RET_IO3: addr_o = stk_addr;
            S_JSR_PCH, S_JSRX_PCH, S_BRK_PCH: begin
                addr_o = stk_addr; vda_o = 1'b1; we_o = 1'b1; data_o = ret_pc[15:8];
            end
            S_JSR_PCL, S_JSRX_PCL, S_BRK_PCL: begin
                addr_o = stk_addr; vda_o = 1'b1; we_o = 1'b1; data_o = ret_pc[7:0];
            end
            S_JSL_PBR, S_BRK_PBR: begin
                addr_o = stk_addr; vda_o = 1'b1; we_o = 1'b1; data_o = pbr;
            end
            S_JSL_IO: addr_o = {8'h00, s + 16'd1};
            S_BRK_P: begin
                addr_o = stk_addr; vda_o = 1'b1; we_o = 1'b1;
                data_o = e ? {p[7:6], 1'b1, !int_q, p[3:0]} : p;
            end
            S_VEC_LO: begin addr_o = {8'h00, aa}; vda_o = 1'b1; vpb_o = 1'b1; end
            S_VEC_HI: begin addr_o = {8'h00, aa + 16'd1}; vda_o = 1'b1; vpb_o = 1'b1; end
            S_MV_RD: begin addr_o = {bank, x}; vda_o = 1'b1; end
            S_MV_WR: begin addr_o = {dbr, y}; vda_o = 1'b1; we_o = 1'b1; data_o = dlo; end
            S_MV_IO1, S_MV_IO2: addr_o = {dbr, y};
            S_RST0, S_RST1: ;
            S_RST2, S_RST3, S_RST4: addr_o = stk_addr;
            default: ;
        endcase
    end

    assign e_o = e;
    assign m_o = mf;
    assign x_o = xf;
    assign fetch_o = state == S_FETCH;
    assign waiting_o = state == S_WAIT;
    assign stopped_o = state == S_STOP;
    assign pc_o = pc;
    assign a_o = a;
    assign x_reg_o = x;
    assign y_reg_o = y;
    assign s_o = s;
    assign d_o = d;
    assign p_o = p;
    assign dbr_o = dbr;
    assign pbr_o = pbr;

    // Index register value / indexed effective address helpers.
    wire [15:0] idx = (mode == M_DPY || mode == M_ABY || mode == M_IDY || mode == M_IDLY ||
                       mode == M_SRIY) ? y : x;

    // End of instruction: emulation mode keeps the stack in page 1.
    // A pending interrupt replaces the next opcode fetch.
    task automatic finish;
        state <= S_FETCH;
        int_q <= int_req;
        int_nmi <= nmi_pend;
    endtask

    // Apply a P value, enforcing the register-width side effects.
    task automatic set_p(input logic [7:0] np);
        if (e) begin
            p <= {np[7:6], 2'b11, np[3:0]};
            x[15:8] <= 8'h00;
            y[15:8] <= 8'h00;
        end else begin
            p <= np;
            if (np[FX]) begin x[15:8] <= 8'h00; y[15:8] <= 8'h00; end
        end
    endtask

    // ---------------- Sequencer ----------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= S_RST0;
            e <= 1'b1;
            p <= {p[7:6], 2'b11, 1'b0, 1'b1, p[1:0]};
            d <= 16'h0000;
            dbr <= 8'h00;
            pbr <= 8'h00;
            s[15:8] <= 8'h01;
            x[15:8] <= 8'h00;
            y[15:8] <= 8'h00;
            int_q <= 1'b0;
            int_nmi <= 1'b0;
            nmi_prev <= 1'b1;
            nmi_pend <= 1'b0;
            stk_n <= 1'b0;
        end else if (ce) begin
            nmi_prev <= nmi_n;
            if (nmi_prev && !nmi_n) nmi_pend <= 1'b1;
            case (state)
            // ---------------------------------------------------------------
            S_FETCH: begin
                stk_n <= 1'b0;
                if (int_q) begin
                    // Hardware interrupt: the fetched opcode is discarded.
                    state <= S_INT_IO;
                    op <= O_BRK;
                    mode <= M_SPEC;
                end else begin
                    opcode <= data_i;
                    mode <= f_mode;
                    op <= f_op;
                    pc <= pc + 16'd1;
                    w16 <= x_width(f_op) ? !xf : !mf;
                    ea_b0 <= 1'b0;
                    case (f_mode)
                        M_IMP: state <= S_IMP;
                        M_IMM: state <= S_IMM_LO;
                        M_DP, M_DPX, M_DPY, M_IDP, M_IDX, M_IDY, M_IDL, M_IDLY: state <= S_DP_OP;
                        M_SR, M_SRIY: state <= S_DP_OP;
                        M_ABS, M_ABX, M_ABY, M_ABL, M_ABLX, M_JMP, M_JML, M_JMPI, M_JMLI,
                        M_JMPX, M_JSR, M_JSL, M_JSRX: state <= S_ABS_LO;
                        M_BR: state <= S_BR_OP;
                        M_BRL: state <= S_BRL_LO;
                        M_PUSH: state <= S_PUSH_IO;
                        M_PULL: state <= S_PULL_IO1;
                        default: begin
                            case (f_op)
                                O_RTS, O_RTL, O_RTI: state <= S_RET_IO1;
                                O_BRK, O_COP: state <= S_BRK_SIG;
                                O_MVN, O_MVP: state <= S_MV_DST;
                                O_PEI: state <= S_DP_OP;
                                O_WDM: state <= S_WDM;
                    default: state <= S_SPEC_OP; // REP SEP PEA PER
                            endcase
                        end
                    endcase
                    stk_n <= (f_op == O_PHD || f_op == O_PLD || f_op == O_PLB || f_op == O_PEA || f_op == O_PEI || f_op == O_PER || f_op == O_RTL);
                    if (f_mode == M_JSL || f_mode == M_JSRX) stk_n <= 1'b1;
                end
            end
            // ---------------------------------------------------------------
            S_IMP: begin
                finish();
                case (op)
                    O_ASLA, O_LSRA, O_ROLA, O_RORA, O_INA, O_DEA: begin
                        if (mf) a[7:0] <= rmw_res[7:0]; else a <= rmw_res;
                        p[FZ] <= rmw_z; p[FN] <= rmw_n;
                        if (!((op == O_INA || op == O_DEA))) p[FC] <= rmw_c;
                    end
                    O_INX: begin x <= xf ? {8'h00, x[7:0] + 8'd1} : x + 16'd1;
                                 p <= nz(p, x + 16'd1, !xf); end
                    O_INY: begin y <= xf ? {8'h00, y[7:0] + 8'd1} : y + 16'd1;
                                 p <= nz(p, y + 16'd1, !xf); end
                    O_DEX: begin x <= xf ? {8'h00, x[7:0] - 8'd1} : x - 16'd1;
                                 p <= nz(p, x - 16'd1, !xf); end
                    O_DEY: begin y <= xf ? {8'h00, y[7:0] - 8'd1} : y - 16'd1;
                                 p <= nz(p, y - 16'd1, !xf); end
                    O_CLC: p[FC] <= 1'b0;
                    O_SEC: p[FC] <= 1'b1;
                    O_CLI: p[FI] <= 1'b0;
                    O_SEI: p[FI] <= 1'b1;
                    O_CLD: p[FD] <= 1'b0;
                    O_SED: p[FD] <= 1'b1;
                    O_CLV: p[FV] <= 1'b0;
                    O_TAX: begin x <= xf ? {8'h00, a[7:0]} : a; p <= nz(p, a, !xf); end
                    O_TAY: begin y <= xf ? {8'h00, a[7:0]} : a; p <= nz(p, a, !xf); end
                    O_TXA: begin if (mf) a[7:0] <= x[7:0]; else a <= x; p <= nz(p, x, !mf); end
                    O_TYA: begin if (mf) a[7:0] <= y[7:0]; else a <= y; p <= nz(p, y, !mf); end
                    O_TXY: begin y <= xf ? {8'h00, x[7:0]} : x; p <= nz(p, x, !xf); end
                    O_TYX: begin x <= xf ? {8'h00, y[7:0]} : y; p <= nz(p, y, !xf); end
                    O_TSX: begin x <= xf ? {8'h00, s[7:0]} : s; p <= nz(p, s, !xf); end
                    O_TXS: s <= e ? {8'h01, x[7:0]} : x;
                    O_TCD: begin d <= a; p <= nz(p, a, 1'b1); end
                    O_TDC: begin a <= d; p <= nz(p, d, 1'b1); end
                    O_TCS: s <= e ? {8'h01, a[7:0]} : a;
                    O_TSC: begin a <= s; p <= nz(p, s, 1'b1); end
                    O_XCE: begin
                        e <= p[FC];
                        p[FC] <= e;
                        if (p[FC]) begin
                            p[FM] <= 1'b1; p[FX] <= 1'b1;
                            x[15:8] <= 8'h00; y[15:8] <= 8'h00;
                            s[15:8] <= 8'h01;
                        end
                    end
                    O_XBA, O_WAI, O_STP: state <= S_IMP2;
                    default: ;
                endcase
            end
            S_IMP2: begin
                case (op)
                    O_XBA: begin
                        a <= {a[7:0], a[15:8]};
                        p <= nz(p, {8'h00, a[15:8]}, 1'b0);
                        finish();
                    end
                    O_WAI: state <= S_WAIT;
                    default: state <= S_STOP;
                endcase
            end
            S_WAIT: if (nmi_pend || !irq_n) finish();
            S_STOP: ;
            // ---------------------------------------------------------------
            S_IMM_LO: begin
                pc <= pc + 16'd1;
                dlo <= data_i;
                if (w16) state <= S_IMM_HI;
                else begin a <= r_a; x <= r_x; y <= r_y; p <= r_p; finish(); end
            end
            S_IMM_HI: begin
                pc <= pc + 16'd1;
                a <= r_a; x <= r_x; y <= r_y; p <= r_p;
                finish();
            end
            // ---------------------------------------------------------------
            // Direct page / stack relative operand byte.
            S_DP_OP: begin
                pc <= pc + 16'd1;
                aa <= {8'h00, data_i};
                if (mode == M_SR || mode == M_SRIY) state <= S_SR_IO;
                else if (dl_nz) state <= S_DP_IO;
                else dp_after(data_i);
            end
            S_DP_IO: dp_after(aa[7:0]);
            S_IDX_IO: begin
                // d,x / d,y / (d,x): index added.
                if (mode == M_IDX) begin
                    ptr <= e_page ? {8'h00, d[15:8], aa[7:0] + x[7:0]} : {8'h00, d + aa + x};
                    ptr_page <= e_page;
                    state <= S_PTR_LO;
                end else begin
                    ea <= e_page ? {8'h00, d[15:8], aa[7:0] + idx[7:0]} : {8'h00, d + aa + idx};
                    ea_b0 <= 1'b1;
                    state <= data_state;
                end
            end
            S_SR_IO: begin
                if (mode == M_SR) begin
                    ea <= {8'h00, s + aa};
                    ea_b0 <= 1'b1;
                    state <= data_state;
                end else begin
                    ptr <= {8'h00, s + aa};
                    ptr_page <= 1'b0;
                    state <= S_PTR_LO;
                end
            end
            // ---------------------------------------------------------------
            S_PTR_LO: begin
                aa[7:0] <= data_i;
                state <= S_PTR_HI;
            end
            S_PTR_HI: begin
                aa[15:8] <= data_i;
                case (mode)
                    M_IDL, M_IDLY, M_JMLI: state <= S_PTR_BANK;
                    M_IDP, M_IDX: begin
                        ea <= {dbr, data_i, aa[7:0]};
                        state <= data_state;
                    end
                    M_IDY: begin
                        ea <= {dbr, data_i, aa[7:0]} + {8'h00, y};
                        if (!xf || is_write(op) || is_rmw(op) || ({1'b0, aa[7:0]} + {1'b0, y[7:0]}) > 9'h0ff)
                            state <= S_PAGE_IO;
                        else state <= data_state;
                    end
                    M_SRIY: begin
                        ea <= {dbr, data_i, aa[7:0]} + {8'h00, y};
                        state <= S_SRIY_IO;
                    end
                    M_JMPI, M_JMPX, M_JSRX: begin
                        pc <= {data_i, aa[7:0]};
                        if (e) s[15:8] <= 8'h01;
                        finish();
                    end
                    default: begin // PEI
                        state <= S_PUSH_HI;
                    end
                endcase
            end
            S_PTR_BANK: begin
                if (mode == M_JMLI) begin
                    pbr <= data_i;
                    pc <= aa;
                    finish();
                end else begin
                    ea <= {data_i, aa} + (mode == M_IDLY ? {8'h00, y} : 24'h0);
                    state <= data_state;
                end
            end
            S_PAGE_IO, S_SRIY_IO: state <= data_state;
            // ---------------------------------------------------------------
            S_ABS_LO: begin
                pc <= pc + 16'd1;
                aa[7:0] <= data_i;
                if (mode == M_JSRX) state <= S_JSRX_PCH;
                else state <= S_ABS_HI;
            end
            S_ABS_HI: begin
                pc <= pc + 16'd1;
                aa[15:8] <= data_i;
                case (mode)
                    M_ABS: begin ea <= {dbr, data_i, aa[7:0]}; state <= data_state; end
                    M_ABX, M_ABY: begin
                        ea <= {dbr, data_i, aa[7:0]} + {8'h00, idx};
                        if (!xf || is_write(op) || is_rmw(op) || ({1'b0, aa[7:0]} + {1'b0, idx[7:0]}) > 9'h0ff)
                            state <= S_PAGE_IO;
                        else state <= data_state;
                    end
                    M_ABL, M_ABLX, M_JML: state <= S_ABS_BANK;
                    M_JMP: begin pc <= {data_i, aa[7:0]}; finish(); end
                    M_JMPI, M_JMLI: begin
                        ptr <= {8'h00, data_i, aa[7:0]};
                        ptr_page <= 1'b0;
                        state <= S_PTR_LO;
                    end
                    M_JMPX: state <= S_JMPX_IO;
                    M_JSR: state <= S_JSR_IO;
                    M_JSL: state <= S_JSL_PBR;
                    M_JSRX: state <= S_JSRX_IO;
                    default: state <= S_FETCH;
                endcase
            end
            S_ABS_BANK: begin
                pc <= pc + 16'd1;
                if (mode == M_JML) begin
                    pbr <= data_i;
                    pc <= aa;
                    finish();
                end else begin
                    ea <= {data_i, aa} + (mode == M_ABLX ? {8'h00, x} : 24'h0);
                    state <= data_state;
                end
            end
            // ---------------------------------------------------------------
            S_RD_LO: begin
                dlo <= data_i;
                if (w16) state <= S_RD_HI;
                else begin a <= r_a; x <= r_x; y <= r_y; p <= r_p; finish(); end
            end
            S_RD_HI: begin
                a <= r_a; x <= r_x; y <= r_y; p <= r_p;
                finish();
            end
            S_WR_LO: if (w16) state <= S_WR_HI; else finish();
            S_WR_HI: finish();
            S_RMW_LO: begin
                dlo <= data_i;
                aa <= {8'h00, data_i};
                state <= w16 ? S_RMW_HI : S_RMW_IO;
            end
            S_RMW_HI: begin
                aa <= {data_i, dlo};
                state <= S_RMW_IO;
            end
            S_RMW_IO: begin
                rmw_val <= rmw_res;
                p[FZ] <= rmw_z;
                if (!((op == O_TSB || op == O_TRB))) p[FN] <= rmw_n;
                if ((op == O_ASL || op == O_LSR || op == O_ROL || op == O_ROR)) p[FC] <= rmw_c;
                state <= w16 ? S_RMW_WH : S_RMW_WL;
            end
            S_RMW_WH: state <= S_RMW_WL;
            S_RMW_WL: finish();
            // ---------------------------------------------------------------
            S_PUSH_IO: state <= push_wide ? S_PUSH_HI : S_PUSH_LO;
            S_PUSH_HI: begin s <= s_dec; state <= S_PUSH_LO; end
            S_PUSH_LO: begin
                s <= s_dec;
                if (e && stk_n) s[15:8] <= 8'h01;
                finish();
            end
            S_PULL_IO1: state <= S_PULL_IO2;
            S_PULL_IO2: state <= S_PULL_LO;
            S_PULL_LO: begin
                s <= s_inc;
                dlo <= data_i;
                if ((op == O_PLA && !mf) || ((op == O_PLX || op == O_PLY) && !xf) || op == O_PLD)
                    state <= S_PULL_HI;
                else begin
                    finish();
                    if (e && stk_n) s[15:8] <= 8'h01;
                    case (op)
                        O_PLA: begin a[7:0] <= data_i; p <= nz(p, {8'h00, data_i}, 1'b0); end
                        O_PLX: begin x <= {8'h00, data_i}; p <= nz(p, {8'h00, data_i}, 1'b0); end
                        O_PLY: begin y <= {8'h00, data_i}; p <= nz(p, {8'h00, data_i}, 1'b0); end
                        O_PLB: begin dbr <= data_i; p <= nz(p, {8'h00, data_i}, 1'b0); end
                        default: set_p(data_i); // PLP
                    endcase
                end
            end
            S_PULL_HI: begin
                s <= s_inc;
                if (e && stk_n) s[15:8] <= 8'h01;
                finish();
                case (op)
                    O_PLA: a <= {data_i, dlo};
                    O_PLX: x <= {data_i, dlo};
                    O_PLY: y <= {data_i, dlo};
                    default: d <= {data_i, dlo};
                endcase
                p <= nz(p, {data_i, dlo}, 1'b1);
            end
            // ---------------------------------------------------------------
            // REP, SEP, WDM, PEA, PER operand bytes.
            S_SPEC_OP: begin
                pc <= pc + 16'd1;
                aa[7:0] <= data_i;
                case (op)
                    O_REP, O_SEP: state <= S_SPEC_IO;
                    default: state <= S_SPEC_OP2;
                endcase
            end
            // WDM: the reserved operand byte is skipped without a program fetch.
            S_WDM: begin pc <= pc + 16'd1; finish(); end
            S_SPEC_OP2: begin
                pc <= pc + 16'd1;
                aa[15:8] <= data_i;
                if (op == O_PEA) state <= S_PUSH_HI;
                else begin
                    aa <= pc + 16'd1 + {data_i, aa[7:0]};
                    state <= S_SPEC_IO;
                end
            end
            S_SPEC_IO: begin
                if (op == O_PER) state <= S_PUSH_HI;
                else begin
                    finish();
                    set_p(op == O_REP ? (p & ~aa[7:0]) : (p | aa[7:0]));
                end
            end
            // ---------------------------------------------------------------
            S_JSR_IO: state <= S_JSR_PCH;
            S_JSR_PCH: begin s <= s_dec; state <= S_JSR_PCL; end
            S_JSR_PCL: begin
                s <= s_dec;
                pc <= aa;
                if (mode == M_JML) pbr <= bank;
                if (e && stk_n) s[15:8] <= 8'h01;
                finish();
            end
            S_JSL_PBR: begin s <= s_dec; state <= S_JSL_IO; end
            S_JSL_IO: state <= S_JSL_BANK;
            S_JSL_BANK: begin
                bank <= data_i;
                state <= S_JSR_PCH;
                mode <= M_JML;
            end
            S_JSRX_PCH: begin s <= s_dec; state <= S_JSRX_PCL; end
            S_JSRX_PCL: begin s <= s_dec; state <= S_JSRX_HI; end
            S_JSRX_HI: begin
                pc <= pc + 16'd1;
                aa[15:8] <= data_i;
                state <= S_JSRX_IO;
            end
            S_JSRX_IO, S_JMPX_IO: begin
                ptr <= {pbr, aa + x};
                ptr_page <= 1'b0;
                state <= S_PTR_LO;
            end
            // ---------------------------------------------------------------
            S_RET_IO1: state <= S_RET_IO2;
            S_RET_IO2: state <= op == O_RTI ? S_RET_P : S_RET_LO;
            S_RET_P: begin
                s <= s_inc;
                bank <= data_i;
                state <= S_RET_LO;
            end
            S_RET_LO: begin
                s <= s_inc;
                aa[7:0] <= data_i;
                state <= S_RET_HI;
            end
            S_RET_HI: begin
                s <= s_inc;
                aa[15:8] <= data_i;
                case (op)
                    O_RTS: state <= S_RET_IO3;
                    O_RTL: state <= S_RET_BANK;
                    default: begin // RTI
                        pc <= {data_i, aa[7:0]};
                        if (e) begin set_p(bank); finish(); end
                        else state <= S_RET_BANK;
                    end
                endcase
            end
            S_RET_BANK: begin
                s <= s_inc;
                if (e && stk_n) s[15:8] <= 8'h01;
                pbr <= data_i;
                if (op == O_RTL) pc <= aa + 16'd1;
                else set_p(bank);
                finish();
            end
            S_RET_IO3: begin
                pc <= aa + 16'd1;
                finish();
            end
            // ---------------------------------------------------------------
            S_BRK_SIG: begin
                pc <= pc + 16'd1;
                state <= e ? S_BRK_PCH : S_BRK_PBR;
            end
            S_INT_IO: state <= e ? S_BRK_PCH : S_BRK_PBR;
            S_BRK_PBR: begin s <= s_dec; state <= S_BRK_PCH; end
            S_BRK_PCH: begin s <= s_dec; state <= S_BRK_PCL; end
            S_BRK_PCL: begin s <= s_dec; state <= S_BRK_P; end
            S_BRK_P: begin
                s <= s_dec;
                p[FI] <= 1'b1;
                p[FD] <= 1'b0;
                pbr <= 8'h00;
                state <= S_VEC_LO;
                if (int_q) aa <= int_nmi ? (e ? 16'hfffa : 16'hffea) : (e ? 16'hfffe : 16'hffee);
                else if (op == O_COP) aa <= e ? 16'hfff4 : 16'hffe4;
                else aa <= e ? 16'hfffe : 16'hffe6;
                if (int_q && int_nmi) nmi_pend <= 1'b0;
            end
            S_VEC_LO: begin
                dlo <= data_i;
                state <= S_VEC_HI;
            end
            S_VEC_HI: begin
                pc <= {data_i, dlo};
                state <= S_FETCH;
                int_q <= 1'b0;
            end
            // ---------------------------------------------------------------
            S_BR_OP: begin
                pc <= pc + 16'd1;
                aa <= pc + 16'd1 + {{8{data_i[7]}}, data_i};
                if (br_taken) state <= S_BR_IO;
                else finish();
            end
            S_BR_IO: begin
                if (e && aa[15:8] != pc[15:8]) state <= S_BR_PAGE;
                else begin pc <= aa; finish(); end
            end
            S_BR_PAGE: begin pc <= aa; finish(); end
            S_BRL_LO: begin
                pc <= pc + 16'd1;
                aa[7:0] <= data_i;
                state <= S_BRL_HI;
            end
            S_BRL_HI: begin
                pc <= pc + 16'd1;
                aa <= pc + 16'd1 + {data_i, aa[7:0]};
                state <= S_BRL_IO;
            end
            S_BRL_IO: begin pc <= aa; finish(); end
            // ---------------------------------------------------------------
            S_MV_DST: begin
                pc <= pc + 16'd1;
                dbr <= data_i;
                state <= S_MV_SRC;
            end
            S_MV_SRC: begin
                pc <= pc + 16'd1;
                bank <= data_i;
                state <= S_MV_RD;
            end
            S_MV_RD: begin dlo <= data_i; state <= S_MV_WR; end
            S_MV_WR: state <= S_MV_IO1;
            S_MV_IO1: state <= S_MV_IO2;
            S_MV_IO2: begin
                if (op == O_MVN) begin
                    x <= xf ? {8'h00, x[7:0] + 8'd1} : x + 16'd1;
                    y <= xf ? {8'h00, y[7:0] + 8'd1} : y + 16'd1;
                end else begin
                    x <= xf ? {8'h00, x[7:0] - 8'd1} : x - 16'd1;
                    y <= xf ? {8'h00, y[7:0] - 8'd1} : y - 16'd1;
                end
                a <= a - 16'd1;
                if (a != 16'h0000) pc <= pc - 16'd3;
                finish();
            end
            // ---------------------------------------------------------------
            S_RST0: state <= S_RST1;
            S_RST1: state <= S_RST2;
            S_RST2: begin s <= s_dec; state <= S_RST3; end
            S_RST3: begin s <= s_dec; state <= S_RST4; end
            S_RST4: begin
                s <= s_dec;
                aa <= 16'hfffc;
                state <= S_VEC_LO;
            end
            default: state <= S_FETCH;
            endcase
        end
    end

    // Direct-page continuation after the operand (and DL penalty) cycle.
    task automatic dp_after(input logic [7:0] off);
        case (mode)
            M_DP: begin
                ea <= {8'h00, d + {8'h00, off}};
                ea_b0 <= 1'b1;
                state <= data_state;
            end
            M_DPX, M_DPY, M_IDX: state <= S_IDX_IO;
            M_IDP, M_IDY: begin
                ptr <= {8'h00, d + {8'h00, off}};
                ptr_page <= e_page;
                state <= S_PTR_LO;
            end
            default: begin // [d], [d],y, PEI
                ptr <= {8'h00, d + {8'h00, off}};
                ptr_page <= 1'b0;
                state <= S_PTR_LO;
            end
        endcase
    endtask
endmodule
