// Native NMOS cycle engine under development; spec/spec_native_bus.md.
// Undocumented unstable operations use an explicit profile; see assumption ledger.
module mos_6502_native #(
    parameter bit DECIMAL_ENABLE = 1,
    parameter logic [7:0] UNSTABLE_MAGIC = 8'hee
) (
    input  logic clk, rst_n, rdy_i, irq_n, nmi_n, so_n,
    output logic [15:0] bus_addr,
    input  logic [7:0] bus_data_i,
    output logic [7:0] bus_data_o,
    output logic bus_we, fetch_o, fault_o, jammed_o,
    output logic [15:0] pc_o,
    output logic [7:0] status_o, a_o, x_o, y_o, s_o
);
    localparam int FC = 0, FZ = 1, FI = 2, FD = 3, FV = 6, FN = 7;
        typedef enum logic [3:0] {
        M_IMP, M_IMM, M_ZP, M_ZPX, M_ZPY, M_ABS, M_ABX, M_ABY,
        M_IZX, M_IZY, M_IND, M_REL, M_SPEC
    } mode_e;

    typedef enum logic [6:0] {
        O_NOP,  O_ORA, O_AND, O_EOR, O_ADC, O_SBC, O_CMP, O_CPX, O_CPY,
        O_BIT,  O_LDA, O_LDX, O_LDY, O_STA, O_STX, O_STY,
        O_ASL,  O_LSR, O_ROL, O_ROR, O_INC, O_DEC,
        O_INX,  O_INY, O_DEX, O_DEY,
        O_TAX,  O_TXA, O_TAY, O_TYA, O_TSX, O_TXS,
        O_CLC,  O_SEC, O_CLI, O_SEI, O_CLV, O_CLD, O_SED,
        O_JMP,  O_JSR, O_RTS, O_BRK, O_RTI,
        O_PHA,  O_PHP, O_PLA, O_PLP,
        O_ASLA, O_LSRA, O_ROLA, O_RORA,
        O_BRA, O_SLO, O_RLA, O_SRE, O_RRA, O_SAX, O_LAX, O_DCP, O_ISC,
        O_ANC, O_ALR, O_ARR, O_ANE, O_LXA, O_AXS, O_AHX, O_TAS, O_SHX, O_SHY, O_LAS
    } op_e;


    typedef enum logic [7:0] {
        S_FETCH, S_IMP, S_IMM, S_ZP, S_ZP_INDEX, S_ABS_L, S_ABS_H,
        S_PTR_L, S_PTR_H, S_INDEXED, S_MEMORY, S_IND_L, S_IND_H,
        S_RMW_OLD, S_RMW_NEW, S_REL, S_BRANCH, S_BRANCH_FIX,
        S_PUSH, S_STACK_DUMMY, S_PULL, S_JSR_L, S_JSR_DUMMY, S_JSR_PH,
        S_JSR_PL, S_JSR_H, S_RTS_L, S_RTS_H, S_RTS_END,
        S_RTI_P, S_RTI_L, S_RTI_H, S_BRK_PAD, S_BRK_PH, S_BRK_PL,
        S_BRK_PS, S_VEC_L, S_VEC_H,
        S_RST_0, S_RST_1, S_RST_2, S_RST_3, S_RST_4, S_RST_L, S_RST_H,
        S_KIL_PC, S_KIL_FF, S_KIL_FE0, S_KIL_FE1, S_KIL_HALT, S_FAULT
    } state_e;
    state_e state;
    logic [15:0] pc, target_q, ptr_q, wrong_q;
    logic [7:0] a, x, y, s, p, opcode, data_q, operand;
    logic page_cross, brk_is_brk, int_nmi_q;
    logic nmi_prev, nmi_pending, nmi_polled, so_prev, irq_pending, irq_sample;
    mode_e mode, fetch_mode;
    op_e op, fetch_op;
    logic is_store, is_rmw, branch_taken, execute_read, execute_alu, complete;
    logic [7:0] store_value, masked_high, axs_value, las_value, arr_rot, arr_value;
    logic [7:0] unstable_a, unstable_ax;
    logic combined_rmw, unstable_store;
    logic [7:0] index_value;
    logic [8:0] index_sum;
    logic [15:0] branch_base, branch_target;

        function automatic mode_e f_mode(input logic [7:0] d);
        case (d)
            8'h0b, 8'h2b, 8'h4b, 8'h6b, 8'h8b, 8'hab, 8'hcb, 8'heb,
            8'h80, 8'h82, 8'h89, 8'hc2, 8'he2: f_mode = M_IMM;
            8'h03, 8'h23, 8'h43, 8'h63, 8'h83, 8'ha3, 8'hc3, 8'he3: f_mode = M_IZX;
            8'h07, 8'h27, 8'h47, 8'h67, 8'h87, 8'ha7, 8'hc7, 8'he7,
            8'h04, 8'h44, 8'h64: f_mode = M_ZP;
            8'h0f, 8'h2f, 8'h4f, 8'h6f, 8'h8f, 8'haf, 8'hcf, 8'hef, 8'h0c: f_mode = M_ABS;
            8'h13, 8'h33, 8'h53, 8'h73, 8'h93, 8'hb3, 8'hd3, 8'hf3: f_mode = M_IZY;
            8'h17, 8'h37, 8'h57, 8'h77, 8'hd7, 8'hf7,
            8'h14, 8'h34, 8'h54, 8'h74, 8'hd4, 8'hf4: f_mode = M_ZPX;
            8'h97, 8'hb7: f_mode = M_ZPY;
            8'h1b, 8'h3b, 8'h5b, 8'h7b, 8'h9b, 8'hbb, 8'hdb, 8'hfb,
            8'hbf, 8'h9e, 8'h9f: f_mode = M_ABY;
            8'h1f, 8'h3f, 8'h5f, 8'h7f, 8'hdf, 8'hff, 8'h9c,
            8'h1c, 8'h3c, 8'h5c, 8'h7c, 8'hdc, 8'hfc: f_mode = M_ABX;
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
        case (d)
            8'h0b, 8'h2b: f_op = O_ANC;
            8'h4b: f_op = O_ALR;
            8'h6b: f_op = O_ARR;
            8'h8b: f_op = O_ANE;
            8'hab: f_op = O_LXA;
            8'hcb: f_op = O_AXS;
            8'heb: f_op = O_SBC;
            8'h93, 8'h9f: f_op = O_AHX;
            8'h9b: f_op = O_TAS;
            8'h9c: f_op = O_SHY;
            8'h9e: f_op = O_SHX;
            8'hbb: f_op = O_LAS;
            8'h89: f_op = O_NOP;
            default: if (d[1:0] == 2'b11) begin
                case (d[7:5])
                    0: f_op = O_SLO; 1: f_op = O_RLA;
                    2: f_op = O_SRE; 3: f_op = O_RRA;
                    4: f_op = O_SAX; 5: f_op = O_LAX;
                    6: f_op = O_DCP; default: f_op = O_ISC;
                endcase
            end else if (d[1:0] == 2'b01) begin
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
        endcase
    endfunction

    function automatic logic f_rmw(input logic [7:0] d);
        case (d)
            8'h06, 8'h16, 8'h0e, 8'h1e, 8'h46, 8'h56, 8'h4e, 8'h5e,
            8'h26, 8'h36, 8'h2e, 8'h3e, 8'h66, 8'h76, 8'h6e, 8'h7e,
            8'he6, 8'hf6, 8'hee, 8'hfe, 8'hc6, 8'hd6, 8'hce, 8'hde:
                f_rmw = 1'b1;
            default: f_rmw = d[1:0] == 2'b11 && d[4:0] != 5'h0b && d[7:6] != 2'b10;
        endcase
    endfunction

    function automatic logic f_store(input logic [7:0] d);
        case (d)
            8'h85, 8'h95, 8'h8d, 8'h9d, 8'h99, 8'h81, 8'h91,
            8'h86, 8'h96, 8'h8e, 8'h84, 8'h94, 8'h8c,
            8'h83, 8'h87, 8'h8f, 8'h97, 8'h93, 8'h9f, 8'h9b, 8'h9c, 8'h9e: f_store = 1'b1;
            default: f_store = 1'b0;
        endcase
    endfunction




    assign mode = f_mode(opcode);
    assign op = f_op(opcode);
    assign is_store = f_store(opcode);
    assign is_rmw = f_rmw(opcode);
    assign fetch_mode = f_mode(bus_data_i);
    assign fetch_op = f_op(bus_data_i);
    assign index_value = (mode == M_ABY || mode == M_IZY || mode == M_ZPY) ? y : x;
    assign index_sum = {1'b0, data_q} + {1'b0, index_value};
    assign branch_base = pc + 16'd1;
    assign branch_target = branch_base + {{8{bus_data_i[7]}}, bus_data_i};
    always_comb begin
        case (opcode[7:6])
            0: branch_taken = p[FN] == opcode[5];
            1: branch_taken = p[FV] == opcode[5];
            2: branch_taken = p[FC] == opcode[5];
            default: branch_taken = p[FZ] == opcode[5];
        endcase
    end
    assign execute_read = state == S_IMM ||
        (state == S_MEMORY && !is_store && !is_rmw) ||
        (state == S_INDEXED && !page_cross && !is_store && !is_rmw);
    assign operand = execute_read ? bus_data_i : data_q;
    assign combined_rmw = op == O_SLO || op == O_RLA || op == O_SRE ||
        op == O_RRA || op == O_DCP || op == O_ISC;
    assign execute_alu = execute_read || (state == S_RMW_NEW && combined_rmw);
    assign masked_high = wrong_q[15:8]+8'd1;
    assign unstable_store = op == O_AHX || op == O_TAS || op == O_SHX || op == O_SHY;
    always_comb begin
        store_value = a;
        case (op)
            O_STX: store_value = x;
            O_STY: store_value = y;
            O_SAX: store_value = a & x;
            O_AHX, O_TAS: store_value = a & x & masked_high;
            O_SHX: store_value = x & masked_high;
            O_SHY: store_value = y & masked_high;
            default: ;
        endcase
    end
    assign axs_value = (a & x)-operand;
    assign las_value = operand & s;
    // ASSUMPTION: EE unstable-immediate profile matches the pinned external corpus;
    // real die/temperature/bus-charge variation is not a universal constant.
    assign unstable_a = (a | UNSTABLE_MAGIC) & operand;
    assign unstable_ax = unstable_a & x;
    assign arr_rot = {p[FC], and_r[7:1]};
    always_comb begin
        arr_value = arr_rot;
        if (p[FD] && DECIMAL_ENABLE) begin
            if (and_r[3:0] >= 4'd5) arr_value[3:0] = arr_rot[3:0]+4'd6;
            if (and_r[7:4] >= 4'd5) arr_value = arr_value+8'h60;
        end
    end

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
    assign ora_r = a | operand;
    assign and_r = a & operand;
    assign eor_r = a ^ operand;

    assign sub    = (op == O_SBC || op == O_ISC);
    assign addend = sub ? ~operand : operand;
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
    assign sbc_cmp    = {1'b0, operand} + {8'b0, ~p[FC]};
    assign sbc_borrow = ({1'b0, a} < sbc_cmp);   // borrow out of a - operand - !C

    assign adc_lo = {1'b0, operand[3:0]} + {1'b0, a[3:0]} + {4'b0, p[FC]};
    assign adc_hc = (adc_lo > 5'd9);
    assign adc_hi = {1'b0, operand[7:4]} + {1'b0, a[7:4]} + {4'b0, adc_hc};
    assign adc_alu  = {adc_hi[3:0], adc_lo[3:0]};   // pre-adjust, per py65
    assign adc_r_hi = operand[7:4] + a[7:4] + {3'b0, adc_hc}
                      + ((adc_hi > 5'd9) ? 4'd6 : 4'd0);
    assign adc_r_lo = adc_lo[3:0] + ((adc_lo > 5'd9) ? 4'd6 : 4'd0);

    // Canonical NMOS decimal SBC (Bruce Clark, validated against real
    // hardware incl. invalid-BCD operands; supersedes the py65 formulation,
    // which deviates in corner cases -- caught by the Klaus regression).
    assign sbc_b1 = ({1'b0, a[3:0]} < {1'b0, operand[3:0]} + {4'b0, ~p[FC]});
    assign sbc_lo_digit = a[3:0] - operand[3:0] - {3'b0, ~p[FC]}
                          - (sbc_b1 ? 4'd6 : 4'd0);
    assign sbc_b2 = ({1'b0, a[7:4]} < {1'b0, operand[7:4]} + {4'b0, sbc_b1});
    assign sbc_hi_digit = a[7:4] - operand[7:4] - {3'b0, sbc_b1}
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


    always_comb begin
        bus_addr = pc;
        case (state)
            S_ZP_INDEX: bus_addr = {8'h00, data_q};
            S_PTR_L: bus_addr = {8'h00, ptr_q[7:0]};
            S_PTR_H: bus_addr = {8'h00, ptr_q[7:0] + 8'd1};
            S_INDEXED, S_BRANCH_FIX: bus_addr = wrong_q;
            S_MEMORY, S_RMW_OLD, S_RMW_NEW: bus_addr = target_q;
            S_IND_L: bus_addr = ptr_q;
            S_IND_H: bus_addr = {ptr_q[15:8], ptr_q[7:0] + 8'd1};
            S_PUSH, S_PULL, S_STACK_DUMMY, S_JSR_DUMMY, S_JSR_PH, S_JSR_PL,
            S_RTS_L, S_RTS_H, S_RTI_P, S_RTI_L, S_RTI_H,
            S_BRK_PH, S_BRK_PL, S_BRK_PS, S_RST_2, S_RST_3, S_RST_4:
                bus_addr = {8'h01, s};
            S_VEC_L: bus_addr = int_nmi_q ? 16'hfffa : 16'hfffe;
            S_VEC_H: bus_addr = int_nmi_q ? 16'hfffb : 16'hffff;
            S_RST_L: bus_addr = 16'hfffc;
            S_RST_H: bus_addr = 16'hfffd;
            S_KIL_FF, S_KIL_HALT: bus_addr = 16'hffff;
            S_KIL_FE0, S_KIL_FE1: bus_addr = 16'hfffe;
            default: ;
        endcase
        bus_we = rst_n && ((state == S_MEMORY && is_store) ||
            state == S_RMW_OLD || state == S_RMW_NEW || state == S_PUSH ||
            state == S_JSR_PH || state == S_JSR_PL || state == S_BRK_PH ||
            state == S_BRK_PL || state == S_BRK_PS);
        if (state == S_MEMORY && is_store && unstable_store && page_cross)
            bus_addr = {store_value, target_q[7:0]};
        bus_data_o = store_value;
        if (state == S_JSR_PH || state == S_BRK_PH) bus_data_o = pc[15:8];
        else if (state == S_JSR_PL || state == S_BRK_PL) bus_data_o = pc[7:0];
        else if (state == S_BRK_PS)
            bus_data_o = brk_is_brk ? (p | 8'h30) : ((p & 8'hef) | 8'h20);
        else if (state == S_PUSH && op == O_PHP) bus_data_o = p | 8'h30;
        else if (state == S_RMW_OLD || state == S_RMW_NEW) bus_data_o = data_q;
        else if (op == O_STX) bus_data_o = x;
        else if (op == O_STY) bus_data_o = y;
    end
    assign fetch_o = state == S_FETCH;
    assign fault_o = state == S_FAULT;
    assign jammed_o = state == S_KIL_HALT;
    assign pc_o = pc;
    assign a_o = a;
    assign x_o = x;
    assign y_o = y;
    assign s_o = s;
    assign status_o = p;

    // Interrupt poll at instruction completion uses the pre-update I flag.
    // Timing races/hijacking remain explicit native verification requirements.
    always_comb begin
        complete = execute_read || state == S_RMW_NEW || state == S_PUSH ||
            state == S_PULL || state == S_JSR_H || state == S_RTS_END ||
            state == S_RTI_H || state == S_IND_H ||
            (state == S_MEMORY && is_store) ||
            (state == S_ABS_H && mode == M_ABS && op == O_JMP) ||
            (state == S_REL && !branch_taken) || (state == S_BRANCH && !page_cross) ||
            state == S_BRANCH_FIX;
        if (state == S_IMP && mode != M_SPEC) complete = 1;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= S_RST_0;
            data_q <= 0; target_q <= 0; ptr_q <= 0; wrong_q <= 0;
            opcode <= 0; page_cross <= 0; brk_is_brk <= 0; int_nmi_q <= 0;
            nmi_prev <= 1; nmi_pending <= 0; nmi_polled <= 0;
            so_prev <= 1; irq_pending <= 0; irq_sample <= 0;
            // NMOS reset does not initialize A/X/Y or the stack pointer.
            p[FI] <= 1; p[5] <= 1; p[4] <= 0;
        end else begin
            nmi_prev <= nmi_n;
            so_prev <= so_n;
            if (nmi_prev && !nmi_n) nmi_pending <= 1;
            irq_sample <= !irq_n;
            // The NMOS address carry latch is not held by RDY: a stalled
            // indexed dummy read presents the corrected high byte next cycle.
            // Independently observed with the pinned Visual6502 netlist.
            if (!rdy_i && state == S_INDEXED && page_cross) wrong_q <= target_q;
            // RDY stops the sequencer, not the implied I-flag write latch.
            if (!rdy_i && state == S_IMP) begin
                if (op == O_SEI) p[FI] <= 1;
                if (op == O_CLI) p[FI] <= 0;
            end
            if (rdy_i || bus_we) begin
                // Same-page taken branches poll at the operand cycle, not
                // their extra branch cycle (die-derived netlist regression).
                if ((complete && !(state == S_BRANCH && !page_cross)) || state == S_REL) begin
                    irq_pending <= irq_sample && !p[FI];
                    nmi_polled <= nmi_pending;
                end
                case (state)
                    S_RST_0: state <= S_RST_1;
                    S_RST_1: state <= S_RST_2;
                    S_RST_2: begin s <= s-8'd1; state <= S_RST_3; end
                    S_RST_3: begin s <= s-8'd1; state <= S_RST_4; end
                    S_RST_4: begin s <= s-8'd1; state <= S_RST_L; end
                    S_RST_L: begin data_q <= bus_data_i; state <= S_RST_H; end
                    S_RST_H: begin pc <= {bus_data_i, data_q}; state <= S_FETCH; end
                    S_FETCH: begin
                        if (nmi_polled || irq_pending) begin
                            opcode <= 0; brk_is_brk <= 0; int_nmi_q <= nmi_polled;
                            if (nmi_polled) nmi_pending <= 0;
                            nmi_polled <= 0; irq_pending <= 0; state <= S_BRK_PAD;
                        end else begin
                            opcode <= bus_data_i; pc <= pc+16'd1;
                            brk_is_brk <= 1; int_nmi_q <= 0;
                            case (fetch_mode)
                                M_IMM: state <= S_IMM;
                                M_ZP, M_ZPX, M_ZPY, M_IZX, M_IZY: state <= S_ZP;
                                M_ABS, M_ABX, M_ABY, M_IND: state <= S_ABS_L;
                                M_REL: state <= S_REL;
                                M_SPEC: state <= fetch_op == O_JSR ? S_JSR_L :
                                                 fetch_op == O_BRK ? S_BRK_PAD : S_IMP;
                                default: state <= S_IMP;
                            endcase
                            if (bus_data_i[3:0] == 4'h2 && bus_data_i[7:4] != 4'h8 &&
                                bus_data_i[7:4] != 4'ha && bus_data_i[7:4] != 4'hc && bus_data_i[7:4] != 4'he)
                                state <= S_KIL_PC;
                        end
                    end
                    S_IMP: begin
                        state <= S_FETCH;
                        if (mode == M_SPEC) begin
                            if (op == O_PHA || op == O_PHP) state <= S_PUSH;
                            else state <= S_STACK_DUMMY;
                        end
                        case (op)
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
                    end
                    S_IMM: begin pc <= pc+16'd1; state <= S_FETCH; end
                    S_ZP: begin
                        data_q <= bus_data_i; pc <= pc+16'd1;
                        ptr_q <= {8'h00, bus_data_i};
                        if (mode == M_IZY) state <= S_PTR_L;
                        else if (mode == M_IZX || mode == M_ZPX || mode == M_ZPY)
                            state <= S_ZP_INDEX;
                        else begin target_q <= {8'h00, bus_data_i}; state <= S_MEMORY; end
                    end
                    S_ZP_INDEX: begin
                        if (mode == M_IZX) begin
                            ptr_q <= {8'h00, data_q+x}; state <= S_PTR_L;
                        end else begin
                            target_q <= {8'h00, data_q+index_value}; state <= S_MEMORY;
                        end
                    end
                    S_ABS_L: begin data_q <= bus_data_i; pc <= pc+16'd1; state <= S_ABS_H; end
                    S_ABS_H: begin
                        pc <= pc+16'd1;
                        if (mode == M_IND) begin ptr_q <= {bus_data_i, data_q}; state <= S_IND_L; end
                        else if (mode == M_ABX || mode == M_ABY) begin
                            target_q <= {bus_data_i, data_q}+{8'h00, index_value};
                            wrong_q <= {bus_data_i, index_sum[7:0]};
                            page_cross <= index_sum[8]; state <= S_INDEXED;
                        end else if (op == O_JMP) begin pc <= {bus_data_i, data_q}; state <= S_FETCH; end
                        else begin target_q <= {bus_data_i, data_q}; state <= S_MEMORY; end
                    end
                    S_PTR_L: begin data_q <= bus_data_i; state <= S_PTR_H; end
                    S_PTR_H: begin
                        if (mode == M_IZY) begin
                            target_q <= {bus_data_i, data_q}+{8'h00, y};
                            wrong_q <= {bus_data_i, index_sum[7:0]};
                            page_cross <= index_sum[8]; state <= S_INDEXED;
                        end else begin target_q <= {bus_data_i, data_q}; state <= S_MEMORY; end
                    end
                    S_INDEXED: state <= page_cross || is_store || is_rmw ? S_MEMORY : S_FETCH;
                    S_MEMORY: begin
                        state <= S_FETCH;
                        if (op == O_TAS) s <= a & x;
                        if (is_rmw) begin data_q <= bus_data_i; state <= S_RMW_OLD; end
                    end
                    S_RMW_OLD: begin
                        state <= S_RMW_NEW;
                        case (op)
                    O_ASL, O_SLO: begin
                        data_q <= {data_q[6:0], 1'b0};
                        p[FC]  <= data_q[7];
                        p[FN]  <= data_q[6];
                        p[FZ]  <= ({data_q[6:0], 1'b0} == 8'd0);
                    end
                    O_LSR, O_SRE: begin
                        data_q <= {1'b0, data_q[7:1]};
                        p[FC]  <= data_q[0];
                        p[FN]  <= 1'b0;
                        p[FZ]  <= ({1'b0, data_q[7:1]} == 8'd0);
                    end
                    O_ROL, O_RLA: begin
                        data_q <= {data_q[6:0], p[FC]};
                        p[FC]  <= data_q[7];
                        p[FN]  <= data_q[6];
                        p[FZ]  <= ({data_q[6:0], p[FC]} == 8'd0);
                    end
                    O_ROR, O_RRA: begin
                        data_q <= {p[FC], data_q[7:1]};
                        p[FC]  <= data_q[0];
                        p[FN]  <= p[FC];
                        p[FZ]  <= ({p[FC], data_q[7:1]} == 8'd0);
                    end
                    O_INC, O_ISC: begin
                        data_q <= data_q + 8'd1;
                        p[FN]  <= ((data_q + 8'd1) >= 8'h80);
                        p[FZ]  <= ((data_q + 8'd1) == 8'd0);
                    end
                    O_DEC, O_DCP: begin
                        data_q <= data_q - 8'd1;
                        p[FN]  <= ((data_q - 8'd1) >= 8'h80);
                        p[FZ]  <= ((data_q - 8'd1) == 8'd0);
                    end
                    default: state <= S_FAULT;
                endcase
                    end
                    S_RMW_NEW: state <= S_FETCH;
                    S_IND_L: begin data_q <= bus_data_i; state <= S_IND_H; end
                    S_IND_H: begin pc <= {bus_data_i, data_q}; state <= S_FETCH; end
                    S_REL: begin
                        pc <= branch_base;
                        target_q <= branch_target;
                        wrong_q <= {branch_base[15:8], branch_target[7:0]};
                        page_cross <= branch_base[15:8] != branch_target[15:8];
                        state <= branch_taken ? S_BRANCH : S_FETCH;
                    end
                    S_BRANCH: begin
                        if (page_cross) state <= S_BRANCH_FIX;
                        else begin pc <= target_q; state <= S_FETCH; end
                    end
                    S_BRANCH_FIX: begin pc <= target_q; state <= S_FETCH; end
                    S_PUSH: begin s <= s-8'd1; state <= S_FETCH; end
                    S_STACK_DUMMY: begin
                        s <= s+8'd1;
                        state <= op == O_RTS ? S_RTS_L : op == O_RTI ? S_RTI_P : S_PULL;
                    end
                    S_PULL: begin
                        if (op == O_PLA) begin a <= bus_data_i; p[FN] <= bus_data_i[7]; p[FZ] <= bus_data_i == 0; end
                        else p <= (bus_data_i & 8'hef) | 8'h20;
                        state <= S_FETCH;
                    end
                    S_JSR_L: begin data_q <= bus_data_i; pc <= pc+16'd1; state <= S_JSR_DUMMY; end
                    S_JSR_DUMMY: state <= S_JSR_PH;
                    S_JSR_PH: begin s <= s-8'd1; state <= S_JSR_PL; end
                    S_JSR_PL: begin s <= s-8'd1; state <= S_JSR_H; end
                    S_JSR_H: begin pc <= {bus_data_i, data_q}; state <= S_FETCH; end
                    S_RTS_L: begin data_q <= bus_data_i; s <= s+8'd1; state <= S_RTS_H; end
                    S_RTS_H: begin pc <= {bus_data_i, data_q}; state <= S_RTS_END; end
                    S_RTS_END: begin pc <= pc+16'd1; state <= S_FETCH; end
                    S_RTI_P: begin p <= (bus_data_i & 8'hef) | 8'h20; s <= s+8'd1; state <= S_RTI_L; end
                    S_RTI_L: begin data_q <= bus_data_i; s <= s+8'd1; state <= S_RTI_H; end
                    S_RTI_H: begin pc <= {bus_data_i, data_q}; state <= S_FETCH; end
                    S_BRK_PAD: begin pc <= pc+(brk_is_brk ? 16'd1 : 16'd0); state <= S_BRK_PH; end
                    S_BRK_PH: begin s <= s-8'd1; state <= S_BRK_PL; end
                    S_BRK_PL: begin s <= s-8'd1; state <= S_BRK_PS; end
                    S_BRK_PS: begin
                        s <= s-8'd1; p[FI] <= 1; state <= S_VEC_L;
                        // T5 clears the edge latch even when a fresh edge is
                        // too late to select the NMI vector in this cycle.
                        nmi_pending <= 0;
                        if (nmi_pending) int_nmi_q <= 1;
                    end
                    S_VEC_L: begin data_q <= bus_data_i; state <= S_VEC_H; end
                    S_VEC_H: begin pc <= {bus_data_i, data_q}; state <= S_FETCH; end
                    S_KIL_PC: state <= S_KIL_FF;
                    S_KIL_FF: state <= S_KIL_FE0;
                    S_KIL_FE0: state <= S_KIL_FE1;
                    S_KIL_FE1: state <= S_KIL_HALT;
                    S_KIL_HALT: state <= S_KIL_HALT;
                    S_FAULT: state <= S_FAULT;
                    default: state <= S_FAULT;
                endcase
                if (execute_alu) begin
                    case (op)
                    O_NOP: ;
                    O_ORA, O_SLO: begin
                        a     <= ora_r;
                        p[FN] <= ora_r >= 8'h80;
                        p[FZ] <= (ora_r == 8'd0);
                    end
                    O_AND, O_RLA: begin
                        a     <= and_r;
                        p[FN] <= and_r >= 8'h80;
                        p[FZ] <= (and_r == 8'd0);
                    end
                    O_EOR, O_SRE: begin
                        a     <= eor_r;
                        p[FN] <= eor_r >= 8'h80;
                        p[FZ] <= (eor_r == 8'd0);
                    end
                    O_ADC, O_RRA: begin
                        if (!p[FD] || !DECIMAL_ENABLE) begin
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
                            p[FV] <= (~(a[7] ^ operand[7])) & (a[7] ^ adc_alu[7]);
                        end
                    end
                    O_SBC, O_ISC: begin
                        if (!p[FD] || !DECIMAL_ENABLE) begin
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
                            p[FV] <= ((a[7] ^ operand[7]) & (a[7] ^ sum9[7]));
                        end
                    end
                    O_CMP, O_DCP: begin
                        p[FC] <= (a >= operand);
                        p[FN] <= (a - operand) >= 8'h80;
                        p[FZ] <= (a == operand);
                    end
                    O_CPX: begin
                        p[FC] <= (x >= operand);
                        p[FN] <= (x - operand) >= 8'h80;
                        p[FZ] <= (x == operand);
                    end
                    O_CPY: begin
                        p[FC] <= (y >= operand);
                        p[FN] <= (y - operand) >= 8'h80;
                        p[FZ] <= (y == operand);
                    end
                    O_BIT: begin
                        p[FZ] <= ((a & operand) == 8'd0);
                        p[FN] <= operand[7];
                        p[FV] <= operand[6];
                    end
                    O_LDA: begin
                        a     <= operand;
                        p[FN] <= operand[7];
                        p[FZ] <= (operand == 8'd0);
                    end
                    O_LDX: begin
                        x     <= operand;
                        p[FN] <= operand[7];
                        p[FZ] <= (operand == 8'd0);
                    end
                    O_LDY: begin
                        y     <= operand;
                        p[FN] <= operand[7];
                        p[FZ] <= (operand == 8'd0);
                    end
                    O_LAX: begin a <= operand; x <= operand; p[FN] <= operand[7]; p[FZ] <= operand == 0; end
                    O_LAS: begin a <= las_value; x <= las_value; s <= las_value; p[FN] <= las_value[7]; p[FZ] <= las_value == 0; end
                    O_ANC: begin a <= and_r; p[FN] <= and_r[7]; p[FZ] <= and_r == 0; p[FC] <= and_r[7]; end
                    O_ALR: begin a <= {1'b0, and_r[7:1]}; p[FN] <= 0; p[FZ] <= and_r[7:1] == 0; p[FC] <= and_r[0]; end
                    O_AXS: begin x <= axs_value; p[FN] <= axs_value[7]; p[FZ] <= axs_value == 0; p[FC] <= (a & x) >= operand; end
                    O_ANE: begin a <= unstable_ax; p[FN] <= unstable_ax[7]; p[FZ] <= unstable_ax == 0; end
                    O_LXA: begin a <= unstable_a; x <= unstable_a; p[FN] <= unstable_a[7]; p[FZ] <= unstable_a == 0; end
                    O_ARR: begin
                        a <= arr_value; p[FN] <= arr_rot[7]; p[FZ] <= arr_rot == 0;
                        p[FV] <= arr_rot[6] ^ arr_rot[5];
                        p[FC] <= p[FD] && DECIMAL_ENABLE ? and_r[7:4] >= 4'd5 : arr_rot[6];
                    end
                    default: state <= S_FAULT;       // unreachable by decode
                endcase
                end
            end
            if (so_prev && !so_n) p[FV] <= 1;
        end
    end
`ifdef FORMAL
    `include "mos_6502_native_props.sv"
`endif
endmodule
