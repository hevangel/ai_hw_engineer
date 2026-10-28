// Sony SPC700 CPU core (the processor inside the SNES S-SMP). One bus cycle
// per enabled clock edge: a read, a write, or an internal (idle) cycle.
// The current cycle's bus request is combinational from the opcode/step
// registers; read data is used at the end of the cycle. See spec/spec.md.
module sony_spc700 (
    input  logic clk,
    input  logic ce,              // end of the current bus cycle
    input  logic rst_n,
    output logic [15:0] addr_o,
    input  logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic rd_o,            // read cycle (includes dummy reads)
    output logic we_o,            // write cycle
    output logic fetch_o,         // opcode fetch (instruction boundary)
    output logic halted_o,        // SLEEP / STOP
    output logic [15:0] pc_o,
    output logic [7:0] a_o, x_o, y_o, sp_o, psw_o
);
    localparam int FC = 0, FZ = 1, FI = 2, FH = 3, FB = 4, FP = 5, FV = 6, FN = 7;

    logic [15:0] pc, ea;
    logic [7:0] a, x, y, sp, psw, op, t, dp;
    logic [3:0] step;
    logic halted, resetting;

    logic [15:0] n_pc, n_ea;
    logic [7:0] n_a, n_x, n_y, n_sp, n_psw, n_op, n_t, n_dp;
    logic [3:0] n_step;
    logic n_halted, n_resetting;

    // ---------------- ALU ----------------
    // f: 0 OR, 1 AND, 2 EOR, 3 CMP, 4 ADC, 5 SBC, 6/7 MOV (load). {psw, result}.
    function automatic logic [15:0] alu(input logic [2:0] f, input logic [7:0] l,
                                        input logic [7:0] r, input logic [7:0] pin);
        logic [8:0] sum;
        logic [7:0] res, rr, pout;
        /* verilator lint_off UNUSEDSIGNAL */
        logic [4:0] hsum;
        /* verilator lint_on UNUSEDSIGNAL */
        pout = pin;
        case (f)
            3'd0: res = l | r;
            3'd1: res = l & r;
            3'd2: res = l ^ r;
            3'd3: begin
                sum = {1'b0, l} - {1'b0, r};
                res = sum[7:0];
                pout[FC] = !sum[8];
            end
            3'd4, 3'd5: begin
                rr = f == 3'd5 ? ~r : r;
                sum = {1'b0, l} + {1'b0, rr} + {8'h00, pin[FC]};
                hsum = {1'b0, l[3:0]} + {1'b0, rr[3:0]} + {4'h0, pin[FC]};
                res = sum[7:0];
                pout[FC] = sum[8];
                pout[FH] = hsum[4];
                pout[FV] = !(l[7] ^ rr[7]) && (l[7] ^ res[7]);
            end
            default: res = r;
        endcase
        pout[FZ] = res == 8'h00;
        pout[FN] = res[7];
        alu = {pout, res};
    endfunction

    function automatic logic [7:0] nz(input logic [7:0] pin, input logic [7:0] v);
        nz = pin;
        nz[FZ] = v == 8'h00;
        nz[FN] = v[7];
    endfunction

    // f: 0 ASL, 1 ROL, 2 LSR, 3 ROR, 4 DEC, 5 INC. {psw, result}.
    function automatic logic [15:0] rmw(input logic [2:0] f, input logic [7:0] v,
                                        input logic [7:0] pin);
        logic [7:0] res, pout;
        pout = pin;
        case (f)
            3'd0: begin pout[FC] = v[7]; res = {v[6:0], 1'b0}; end
            3'd1: begin pout[FC] = v[7]; res = {v[6:0], pin[FC]}; end
            3'd2: begin pout[FC] = v[0]; res = {1'b0, v[7:1]}; end
            3'd3: begin pout[FC] = v[0]; res = {pin[FC], v[7:1]}; end
            3'd4: res = v - 8'd1;
            default: res = v + 8'd1;
        endcase
        rmw = {nz(pout, res), res};
    endfunction

    wire pg = psw[FP];
    wire [15:0] ya = {y, a};
    function automatic logic [15:0] dpa(input logic page, input logic [7:0] off);
        dpa = {7'h00, page, off};
    endfunction

    // ---------------- Decode ----------------
    typedef enum logic [3:0] {
        K_NONE, K_READ, K_STORE, K_RMW, K_IMM, K_DPIMM, K_DPDP, K_XY
    } kind_e;
    typedef enum logic [3:0] {
        AM_DP, AM_DPX, AM_DPY, AM_ABS, AM_ABX, AM_ABY, AM_IX, AM_IDX, AM_IDY
    } am_e;
    kind_e kind;
    am_e am;
    logic [1:0] rsel;     // 0 A, 1 X, 2 Y
    logic [2:0] fn;
    always_comb begin
        logic [3:0] h, l;
        h = op[7:4];
        l = op[3:0];
        kind = K_NONE;
        am = AM_DP;
        rsel = 2'd0;
        fn = h[3:1];
        case (l)
            4'h4, 4'h5, 4'h6, 4'h7: begin
                kind = h == 4'hc || h == 4'hd ? K_STORE : K_READ;
                case (l)
                    4'h4: am = h[0] ? AM_DPX : AM_DP;
                    4'h5: am = h[0] ? AM_ABX : AM_ABS;
                    4'h6: am = h[0] ? AM_ABY : AM_IX;
                    default: am = h[0] ? AM_IDY : AM_IDX;
                endcase
                if (h >= 4'he) fn = 3'd6;
            end
            4'h8: begin
                case (h)
                    4'hc: begin kind = K_IMM; rsel = 2'd1; fn = 3'd3; end
                    4'hd: begin kind = K_STORE; rsel = 2'd1; am = AM_DP; end
                    4'he: begin kind = K_IMM; fn = 3'd6; end
                    4'hf: begin kind = K_READ; rsel = 2'd1; am = AM_DP; fn = 3'd6; end
                    default: kind = h[0] ? K_DPIMM : K_IMM;
                endcase
            end
            4'h9: begin
                case (h)
                    4'hc: begin kind = K_STORE; rsel = 2'd1; am = AM_ABS; end
                    4'hd: begin kind = K_STORE; rsel = 2'd1; am = AM_DPY; end
                    4'he: begin kind = K_READ; rsel = 2'd1; am = AM_ABS; fn = 3'd6; end
                    4'hf: begin kind = K_READ; rsel = 2'd1; am = AM_DPY; fn = 3'd6; end
                    default: kind = h[0] ? K_XY : K_DPDP;
                endcase
            end
            4'hb: begin
                case (h)
                    4'hc: begin kind = K_STORE; rsel = 2'd2; am = AM_DP; end
                    4'hd: begin kind = K_STORE; rsel = 2'd2; am = AM_DPX; end
                    4'he: begin kind = K_READ; rsel = 2'd2; am = AM_DP; fn = 3'd6; end
                    4'hf: begin kind = K_READ; rsel = 2'd2; am = AM_DPX; fn = 3'd6; end
                    default: begin kind = K_RMW; am = h[0] ? AM_DPX : AM_DP; end
                endcase
            end
            4'hc: begin
                case (h)
                    4'hc: begin kind = K_STORE; rsel = 2'd2; am = AM_ABS; end
                    4'he: begin kind = K_READ; rsel = 2'd2; am = AM_ABS; fn = 3'd6; end
                    default: if (!h[0] && h <= 4'ha) begin kind = K_RMW; am = AM_ABS; end
                endcase
            end
            4'hd: begin
                case (h)
                    4'h8: begin kind = K_IMM; rsel = 2'd2; fn = 3'd6; end
                    4'ha: begin kind = K_IMM; rsel = 2'd2; fn = 3'd3; end
                    4'hc: begin kind = K_IMM; rsel = 2'd1; fn = 3'd6; end
                    default: ;
                endcase
            end
            4'he: begin
                case (h)
                    4'h1: begin kind = K_READ; rsel = 2'd1; am = AM_ABS; fn = 3'd3; end
                    4'h3: begin kind = K_READ; rsel = 2'd1; am = AM_DP; fn = 3'd3; end
                    4'h5: begin kind = K_READ; rsel = 2'd2; am = AM_ABS; fn = 3'd3; end
                    4'h7: begin kind = K_READ; rsel = 2'd2; am = AM_DP; fn = 3'd3; end
                    default: ;
                endcase
            end
            default: ;
        endcase
    end

    logic [7:0] reg_val;
    always_comb begin
        case (rsel)
            2'd1: reg_val = x;
            2'd2: reg_val = y;
            default: reg_val = a;
        endcase
    end
    wire [7:0] idx = (am == AM_DPY || am == AM_ABY || am == AM_IDY) ? y : x;

    // Address-phase length (cycles after the opcode fetch).
    logic [3:0] alen;
    always_comb begin
        case (am)
            AM_DP, AM_IX: alen = 4'd1;
            AM_DPX, AM_DPY, AM_ABS: alen = 4'd2;
            AM_ABX, AM_ABY: alen = 4'd3;
            default: alen = 4'd4;
        endcase
    end

    // Branch condition for the x0 column (odd high nibble), BBS/BBC bit.
    logic cond;
    always_comb begin
        case (op[7:6])
            2'd0: cond = psw[FN];
            2'd1: cond = psw[FV];
            2'd2: cond = psw[FC];
            default: cond = psw[FZ];
        endcase
        if (!op[5]) cond = !cond;
    end

    // ---------------- Microcode ----------------
    always_comb begin
        logic [15:0] r16;
        logic [16:0] s17;
        logic [7:0] v8, p8;
        logic [3:0] d;
        logic last, take;
        n_pc = pc; n_a = a; n_x = x; n_y = y; n_sp = sp; n_psw = psw;
        n_op = op; n_ea = ea; n_t = t; n_dp = dp;
        n_halted = halted; n_resetting = resetting;
        n_step = step + 4'd1;
        addr_o = pc; data_o = 8'h00; rd_o = 1'b0; we_o = 1'b0;
        last = 1'b0;
        take = 1'b0;
        r16 = 16'h0; s17 = 17'h0; v8 = 8'h0; p8 = psw;
        d = step - alen;

        `define RD(ad)     begin addr_o = (ad); rd_o = 1'b1; end
        `define WR(ad, dv) begin addr_o = (ad); data_o = (dv); we_o = 1'b1; end
        `define OPND       begin addr_o = pc; rd_o = 1'b1; n_pc = pc + 16'd1; end
        `define PUSH(dv)   begin `WR({8'h01, sp}, dv) n_sp = sp - 8'd1; end
        `define POP        begin `RD({8'h01, sp + 8'd1}) n_sp = sp + 8'd1; end

        if (resetting) begin
            if (step == 4'd0) begin `RD(16'hfffe) n_t = data_i; end
            else begin
                `RD(16'hffff)
                n_pc = {data_i, t};
                last = 1'b1;
                n_resetting = 1'b0;
            end
        end else if (halted) begin
            // SLEEP / STOP: dummy read at PC, internal cycle, forever.
            if (!step[0]) `RD(pc)
            n_step = {3'b000, !step[0]};
        end else if (step == 4'd0) begin
            `OPND
            n_op = data_i;
        end else begin
            case (kind)
            // ------------- memory operand: read / store / modify -------------
            K_READ, K_STORE, K_RMW: begin
                if (step <= alen) begin
                    case (am)
                        AM_DP: begin `OPND n_dp = data_i; n_ea = dpa(pg, data_i); end
                        AM_DPX, AM_DPY:
                            if (step == 4'd1) begin `OPND n_dp = data_i; end
                            else n_ea = dpa(pg, dp + idx);
                        AM_ABS:
                            if (step == 4'd1) begin `OPND n_ea[7:0] = data_i; end
                            else begin `OPND n_ea[15:8] = data_i; end
                        AM_ABX, AM_ABY:
                            if (step == 4'd1) begin `OPND n_ea[7:0] = data_i; end
                            else if (step == 4'd2) begin `OPND n_ea[15:8] = data_i; end
                            else n_ea = ea + {8'h00, idx};
                        AM_IX: begin `RD(pc) n_ea = dpa(pg, x); end
                        AM_IDX:
                            case (step)
                                4'd1: begin `OPND n_dp = data_i; end
                                4'd2: ;
                                4'd3: begin `RD(dpa(pg, dp + x)) n_ea[7:0] = data_i; end
                                default: begin `RD(dpa(pg, dp + x + 8'd1)) n_ea[15:8] = data_i; end
                            endcase
                        default: // AM_IDY: the store form idles after the pointer
                            if (kind == K_STORE)
                                case (step)
                                    4'd1: begin `OPND n_dp = data_i; end
                                    4'd2: begin `RD(dpa(pg, dp)) n_ea[7:0] = data_i; end
                                    4'd3: begin `RD(dpa(pg, dp + 8'd1)) n_ea[15:8] = data_i; end
                                    default: n_ea = ea + {8'h00, y};
                                endcase
                            else
                                case (step)
                                    4'd1: begin `OPND n_dp = data_i; end
                                    4'd2: ;
                                    4'd3: begin `RD(dpa(pg, dp)) n_ea[7:0] = data_i; end
                                    default: begin
                                        `RD(dpa(pg, dp + 8'd1))
                                        n_ea = {data_i, ea[7:0]} + {8'h00, y};
                                    end
                                endcase
                    endcase
                end else begin
                    case (kind)
                        K_READ: begin
                            `RD(ea)
                            last = 1'b1;
                            {p8, v8} = alu(fn, reg_val, data_i, psw);
                            n_psw = p8;
                            if (fn != 3'd3)
                                case (rsel)
                                    2'd1: n_x = v8;
                                    2'd2: n_y = v8;
                                    default: n_a = v8;
                                endcase
                        end
                        K_STORE:
                            if (d == 4'd1) `RD(ea)
                            else begin `WR(ea, reg_val) last = 1'b1; end
                        default:
                            if (d == 4'd1) begin `RD(ea) n_t = data_i; end
                            else begin
                                {p8, v8} = rmw(fn, t, psw);
                                n_psw = p8;
                                `WR(ea, v8)
                                last = 1'b1;
                            end
                    endcase
                end
            end
            // ------------- immediate -------------
            K_IMM: begin
                `OPND
                last = 1'b1;
                {p8, v8} = alu(fn, reg_val, data_i, psw);
                n_psw = p8;
                if (fn != 3'd3)
                    case (rsel)
                        2'd1: n_x = v8;
                        2'd2: n_y = v8;
                        default: n_a = v8;
                    endcase
            end
            // ------------- op d,#imm -------------
            K_DPIMM:
                case (step)
                    4'd1: begin `OPND n_t = data_i; end
                    4'd2: begin `OPND n_ea = dpa(pg, data_i); end
                    4'd3: begin `RD(ea) n_dp = data_i; end
                    default: begin
                        {p8, v8} = alu(fn, dp, t, psw);
                        n_psw = p8;
                        if (fn != 3'd3) `WR(ea, v8)
                        last = 1'b1;
                    end
                endcase
            // ------------- op dd,ds -------------
            K_DPDP:
                case (step)
                    4'd1: begin `OPND n_ea = dpa(pg, data_i); end
                    4'd2: begin `RD(ea) n_t = data_i; end
                    4'd3: begin `OPND n_ea = dpa(pg, data_i); end
                    4'd4: begin `RD(ea) n_dp = data_i; end
                    default: begin
                        {p8, v8} = alu(fn, dp, t, psw);
                        n_psw = p8;
                        if (fn != 3'd3) `WR(ea, v8)
                        last = 1'b1;
                    end
                endcase
            // ------------- op (X),(Y) -------------
            K_XY:
                case (step)
                    4'd1: `RD(pc)
                    4'd2: begin `RD(dpa(pg, y)) n_t = data_i; end
                    4'd3: begin `RD(dpa(pg, x)) n_dp = data_i; end
                    default: begin
                        {p8, v8} = alu(fn, dp, t, psw);
                        n_psw = p8;
                        if (fn != 3'd3) `WR(dpa(pg, x), v8)
                        last = 1'b1;
                    end
                endcase
            // ------------- everything else -------------
            default: begin
                casez (op)
                // NOP, flag ops, register ops: one dummy read.
                8'h00, 8'h20, 8'h40, 8'h60, 8'h80, 8'he0,
                8'h1c, 8'h3c, 8'h5c, 8'h7c, 8'h9c, 8'hbc, 8'hdc, 8'hfc,
                8'h1d, 8'h3d, 8'h5d, 8'h7d, 8'h9d, 8'hbd, 8'hdd, 8'hfd: begin
                    `RD(pc)
                    last = 1'b1;
                    case (op)
                        8'h20: n_psw[FP] = 1'b0;
                        8'h40: n_psw[FP] = 1'b1;
                        8'h60: n_psw[FC] = 1'b0;
                        8'h80: n_psw[FC] = 1'b1;
                        8'he0: begin n_psw[FV] = 1'b0; n_psw[FH] = 1'b0; end
                        8'h1c: {n_psw, n_a} = rmw(3'd0, a, psw);
                        8'h3c: {n_psw, n_a} = rmw(3'd1, a, psw);
                        8'h5c: {n_psw, n_a} = rmw(3'd2, a, psw);
                        8'h7c: {n_psw, n_a} = rmw(3'd3, a, psw);
                        8'h9c: {n_psw, n_a} = rmw(3'd4, a, psw);
                        8'hbc: {n_psw, n_a} = rmw(3'd5, a, psw);
                        8'hdc: {n_psw, n_y} = rmw(3'd4, y, psw);
                        8'hfc: {n_psw, n_y} = rmw(3'd5, y, psw);
                        8'h1d: {n_psw, n_x} = rmw(3'd4, x, psw);
                        8'h3d: {n_psw, n_x} = rmw(3'd5, x, psw);
                        8'h5d: begin n_x = a; n_psw = nz(psw, a); end
                        8'h7d: begin n_a = x; n_psw = nz(psw, x); end
                        8'h9d: begin n_x = sp; n_psw = nz(psw, sp); end
                        8'hbd: n_sp = x;
                        8'hdd: begin n_a = y; n_psw = nz(psw, y); end
                        8'hfd: begin n_y = a; n_psw = nz(psw, a); end
                        default: ;
                    endcase
                end
                // EI DI NOTC DAA DAS: dummy read + internal cycle.
                8'ha0, 8'hc0, 8'hed, 8'hdf, 8'hbe:
                    if (step == 4'd1) `RD(pc)
                    else begin
                        last = 1'b1;
                        case (op)
                            8'ha0: n_psw[FI] = 1'b1;
                            8'hc0: n_psw[FI] = 1'b0;
                            8'hed: n_psw[FC] = !psw[FC];
                            8'hdf: begin
                                v8 = a;
                                if (psw[FC] || a > 8'h99) begin v8 = v8 + 8'h60; p8[FC] = 1'b1; end
                                if (psw[FH] || v8[3:0] > 4'h9) v8 = v8 + 8'h06;
                                n_a = v8; n_psw = nz(p8, v8);
                            end
                            default: begin
                                v8 = a;
                                if (!psw[FC] || a > 8'h99) begin v8 = v8 - 8'h60; p8[FC] = 1'b0; end
                                if (!psw[FH] || v8[3:0] > 4'h9) v8 = v8 - 8'h06;
                                n_a = v8; n_psw = nz(p8, v8);
                            end
                        endcase
                    end
                // XCN: dummy read + 3 internal cycles.
                8'h9f: begin
                    if (step == 4'd1) `RD(pc)
                    if (step == 4'd4) begin
                        last = 1'b1;
                        n_a = {a[3:0], a[7:4]};
                        n_psw = nz(psw, n_a);
                    end
                end
                // MUL YA: dummy read + 7 internal cycles.
                8'hcf: begin
                    if (step == 4'd1) `RD(pc)
                    if (step == 4'd8) begin
                        last = 1'b1;
                        r16 = {8'h00, y} * {8'h00, a};
                        n_a = r16[7:0]; n_y = r16[15:8];
                        n_psw = nz(psw, r16[15:8]);
                    end
                end
                // DIV YA,X: dummy read + 10 internal cycles.
                8'h9e: begin
                    if (step == 4'd1) `RD(pc)
                    if (step == 4'd11) begin
                        last = 1'b1;
                        p8[FH] = y[3:0] >= x[3:0];
                        p8[FV] = y >= x;
                        if ({1'b0, y} < {x, 1'b0}) begin
                            r16 = ya / {8'h00, x};
                            n_a = r16[7:0];
                            r16 = ya % {8'h00, x};
                            n_y = r16[7:0];
                        end else begin
                            s17 = {1'b0, ya} - {x, 9'h000};
                            r16 = 16'd255 - (s17[15:0] / (16'd256 - {8'h00, x}));
                            n_a = r16[7:0];
                            r16 = {8'h00, x} + (s17[15:0] % (16'd256 - {8'h00, x}));
                            n_y = r16[7:0];
                        end
                        n_psw = nz(p8, n_a);
                    end
                end
                // SLEEP / STOP.
                8'hef, 8'hff:
                    if (step == 4'd1) `RD(pc)
                    else begin n_halted = 1'b1; n_step = 4'd0; end
                // ---- branches ----
                8'b???1_0000, 8'h2f: begin
                    take = op == 8'h2f || cond;
                    case (step)
                        4'd1: begin
                            `OPND
                            n_ea = pc + 16'd1 + {{8{data_i[7]}}, data_i};
                            if (!take) last = 1'b1;
                        end
                        4'd2: ;
                        default: begin n_pc = ea; last = 1'b1; end
                    endcase
                end
                // BBS / BBC d.bit,rel
                8'b????_0011: begin
                    case (step)
                        4'd1: begin `OPND n_dp = data_i; end
                        4'd2: begin `RD(dpa(pg, dp)) n_t = data_i; end
                        4'd3: ;
                        4'd4: begin
                            `OPND
                            n_ea = pc + 16'd1 + {{8{data_i[7]}}, data_i};
                            if (t[op[7:5]] == op[4]) last = 1'b1;
                        end
                        4'd5: ;
                        default: begin n_pc = ea; last = 1'b1; end
                    endcase
                end
                // CBNE d,rel / CBNE d+X,rel
                8'h2e, 8'hde: begin
                    if (op == 8'h2e)
                        case (step)
                            4'd1: begin `OPND n_dp = data_i; end
                            4'd2: begin `RD(dpa(pg, dp)) n_t = data_i; end
                            4'd3: ;
                            4'd4: begin
                                `OPND
                                n_ea = pc + 16'd1 + {{8{data_i[7]}}, data_i};
                                if (t == a) last = 1'b1;
                            end
                            4'd5: ;
                            default: begin n_pc = ea; last = 1'b1; end
                        endcase
                    else
                        case (step)
                            4'd1: begin `OPND n_dp = data_i; end
                            4'd2: ;
                            4'd3: begin `RD(dpa(pg, dp + x)) n_t = data_i; end
                            4'd4: ;
                            4'd5: begin
                                `OPND
                                n_ea = pc + 16'd1 + {{8{data_i[7]}}, data_i};
                                if (t == a) last = 1'b1;
                            end
                            4'd6: ;
                            default: begin n_pc = ea; last = 1'b1; end
                        endcase
                end
                // DBNZ d,rel
                8'h6e:
                    case (step)
                        4'd1: begin `OPND n_dp = data_i; end
                        4'd2: begin `RD(dpa(pg, dp)) n_t = data_i - 8'd1; end
                        4'd3: `WR(dpa(pg, dp), t)
                        4'd4: begin
                            `OPND
                            n_ea = pc + 16'd1 + {{8{data_i[7]}}, data_i};
                            if (t == 8'h00) last = 1'b1;
                        end
                        4'd5: ;
                        default: begin n_pc = ea; last = 1'b1; end
                    endcase
                // DBNZ Y,rel
                8'hfe:
                    case (step)
                        4'd1: `RD(pc)
                        4'd2: n_y = y - 8'd1;
                        4'd3: begin
                            `OPND
                            n_ea = pc + 16'd1 + {{8{data_i[7]}}, data_i};
                            if (y == 8'h00) last = 1'b1;
                        end
                        4'd4: ;
                        default: begin n_pc = ea; last = 1'b1; end
                    endcase
                // SET1 / CLR1 d.bit
                8'b????_0010:
                    case (step)
                        4'd1: begin `OPND n_dp = data_i; end
                        4'd2: begin `RD(dpa(pg, dp)) n_t = data_i; end
                        default: begin
                            v8 = t;
                            v8[op[7:5]] = !op[4];
                            `WR(dpa(pg, dp), v8)
                            last = 1'b1;
                        end
                    endcase
                // OR1 AND1 EOR1 MOV1 NOT1 (13-bit address, bit number)
                8'h0a, 8'h2a, 8'h4a, 8'h6a, 8'h8a, 8'haa, 8'hca, 8'hea:
                    case (step)
                        4'd1: begin `OPND n_ea[7:0] = data_i; end
                        4'd2: begin `OPND n_ea[15:8] = data_i; end
                        4'd3: begin
                            `RD({3'b000, ea[12:0]})
                            n_t = data_i;
                            take = data_i[ea[15:13]];
                            case (op)
                                8'h4a: begin n_psw[FC] = psw[FC] & take; last = 1'b1; end
                                8'h6a: begin n_psw[FC] = psw[FC] & !take; last = 1'b1; end
                                8'haa: begin n_psw[FC] = take; last = 1'b1; end
                                default: ;
                            endcase
                        end
                        4'd4: begin
                            take = t[ea[15:13]];
                            case (op)
                                8'h0a: begin n_psw[FC] = psw[FC] | take; last = 1'b1; end
                                8'h2a: begin n_psw[FC] = psw[FC] | !take; last = 1'b1; end
                                8'h8a: begin n_psw[FC] = psw[FC] ^ take; last = 1'b1; end
                                8'hea: begin
                                    v8 = t;
                                    v8[ea[15:13]] = !take;
                                    `WR({3'b000, ea[12:0]}, v8)
                                    last = 1'b1;
                                end
                                default: ; // MOV1 m.b,C idles here
                            endcase
                        end
                        default: begin
                            v8 = t;
                            v8[ea[15:13]] = psw[FC];
                            `WR({3'b000, ea[12:0]}, v8)
                            last = 1'b1;
                        end
                    endcase
                // TSET1 / TCLR1 !a
                8'h0e, 8'h4e:
                    case (step)
                        4'd1: begin `OPND n_ea[7:0] = data_i; end
                        4'd2: begin `OPND n_ea[15:8] = data_i; end
                        4'd3: begin
                            `RD(ea)
                            n_t = data_i;
                            v8 = a - data_i;
                            n_psw = nz(psw, v8);
                        end
                        4'd4: `RD(ea)
                        default: begin
                            `WR(ea, op == 8'h0e ? (t | a) : (t & ~a))
                            last = 1'b1;
                        end
                    endcase
                // DECW / INCW d
                8'h1a, 8'h3a:
                    case (step)
                        4'd1: begin `OPND n_dp = data_i; end
                        4'd2: begin
                            `RD(dpa(pg, dp))
                            r16 = {8'h00, data_i} + (op == 8'h3a ? 16'h0001 : 16'hffff);
                            n_ea = r16;
                        end
                        4'd3: `WR(dpa(pg, dp), ea[7:0])
                        4'd4: begin
                            `RD(dpa(pg, dp + 8'd1))
                            n_ea = ea + {data_i, 8'h00};
                        end
                        default: begin
                            `WR(dpa(pg, dp + 8'd1), ea[15:8])
                            n_psw[FZ] = ea == 16'h0000;
                            n_psw[FN] = ea[15];
                            last = 1'b1;
                        end
                    endcase
                // CMPW / ADDW / SUBW / MOVW YA,d
                8'h5a, 8'h7a, 8'h9a, 8'hba:
                    case (step)
                        4'd1: begin `OPND n_dp = data_i; end
                        4'd2: begin `RD(dpa(pg, dp)) n_t = data_i; end
                        4'd3: begin
                            if (op == 8'h5a) begin
                                `RD(dpa(pg, dp + 8'd1))
                                s17 = {1'b0, ya} - {1'b0, data_i, t};
                                n_psw[FC] = !s17[16];
                                n_psw[FZ] = s17[15:0] == 16'h0;
                                n_psw[FN] = s17[15];
                                last = 1'b1;
                            end
                        end
                        default: begin
                            `RD(dpa(pg, dp + 8'd1))
                            last = 1'b1;
                            if (op == 8'hba) begin
                                n_a = t; n_y = data_i;
                                n_psw[FZ] = {data_i, t} == 16'h0;
                                n_psw[FN] = data_i[7];
                            end else begin
                                p8[FC] = op == 8'h9a;
                                {p8, v8} = alu(op == 8'h9a ? 3'd5 : 3'd4, a, t, p8);
                                n_a = v8;
                                {p8, v8} = alu(op == 8'h9a ? 3'd5 : 3'd4, y, data_i, p8);
                                n_y = v8;
                                p8[FZ] = {n_y, n_a} == 16'h0;
                                n_psw = p8;
                            end
                        end
                    endcase
                // MOVW d,YA
                8'hda:
                    case (step)
                        4'd1: begin `OPND n_dp = data_i; end
                        4'd2: `RD(dpa(pg, dp))
                        4'd3: `WR(dpa(pg, dp), a)
                        default: begin `WR(dpa(pg, dp + 8'd1), y) last = 1'b1; end
                    endcase
                // MOV d,#imm
                8'h8f:
                    case (step)
                        4'd1: begin `OPND n_t = data_i; end
                        4'd2: begin `OPND n_ea = dpa(pg, data_i); end
                        4'd3: `RD(ea)
                        default: begin `WR(ea, t) last = 1'b1; end
                    endcase
                // MOV dd,ds
                8'hfa:
                    case (step)
                        4'd1: begin `OPND n_ea = dpa(pg, data_i); end
                        4'd2: begin `RD(ea) n_t = data_i; end
                        4'd3: begin `OPND n_ea = dpa(pg, data_i); end
                        default: begin `WR(ea, t) last = 1'b1; end
                    endcase
                // MOV (X)+,A
                8'haf:
                    case (step)
                        4'd1: `RD(pc)
                        4'd2: ;
                        default: begin `WR(dpa(pg, x), a) n_x = x + 8'd1; last = 1'b1; end
                    endcase
                // MOV A,(X)+
                8'hbf:
                    case (step)
                        4'd1: `RD(pc)
                        4'd2: begin `RD(dpa(pg, x)) n_a = data_i; n_psw = nz(psw, data_i); end
                        default: begin n_x = x + 8'd1; last = 1'b1; end
                    endcase
                // PUSH PSW/A/X/Y
                8'h0d, 8'h2d, 8'h4d, 8'h6d:
                    case (step)
                        4'd1: `RD(pc)
                        4'd2: `PUSH(op == 8'h0d ? psw : (op == 8'h2d ? a : (op == 8'h4d ? x : y)))
                        default: last = 1'b1;
                    endcase
                // POP PSW/A/X/Y
                8'h8e, 8'hae, 8'hce, 8'hee:
                    case (step)
                        4'd1: `RD(pc)
                        4'd2: ;
                        default: begin
                            `POP
                            last = 1'b1;
                            case (op)
                                8'h8e: n_psw = data_i;
                                8'hae: n_a = data_i;
                                8'hce: n_x = data_i;
                                default: n_y = data_i;
                            endcase
                        end
                    endcase
                // JMP !a
                8'h5f:
                    if (step == 4'd1) begin `OPND n_ea[7:0] = data_i; end
                    else begin `RD(pc) n_pc = {data_i, ea[7:0]}; last = 1'b1; end
                // JMP [!a+X]
                8'h1f:
                    case (step)
                        4'd1: begin `OPND n_ea[7:0] = data_i; end
                        4'd2: begin `OPND n_ea[15:8] = data_i; end
                        4'd3: n_ea = ea + {8'h00, x};
                        4'd4: begin `RD(ea) n_t = data_i; end
                        default: begin `RD(ea + 16'd1) n_pc = {data_i, t}; last = 1'b1; end
                    endcase
                // CALL !a
                8'h3f:
                    case (step)
                        4'd1: begin `OPND n_ea[7:0] = data_i; end
                        4'd2: begin `OPND n_ea[15:8] = data_i; end
                        4'd3: ;
                        4'd4: `PUSH(pc[15:8])
                        4'd5: `PUSH(pc[7:0])
                        4'd6: ;
                        default: begin n_pc = ea; last = 1'b1; end
                    endcase
                // PCALL u
                8'h4f:
                    case (step)
                        4'd1: begin `OPND n_ea = {8'hff, data_i}; end
                        4'd2: ;
                        4'd3: `PUSH(pc[15:8])
                        4'd4: `PUSH(pc[7:0])
                        default: begin n_pc = ea; last = 1'b1; end
                    endcase
                // TCALL n
                8'b????_0001:
                    case (step)
                        4'd1: `RD(pc)
                        4'd2: ;
                        4'd3: `PUSH(pc[15:8])
                        4'd4: `PUSH(pc[7:0])
                        4'd5: ;
                        4'd6: begin `RD(16'hffde - {11'h000, op[7:4], 1'b0}) n_t = data_i; end
                        default: begin
                            `RD(16'hffdf - {11'h000, op[7:4], 1'b0})
                            n_pc = {data_i, t};
                            last = 1'b1;
                        end
                    endcase
                // BRK
                8'h0f:
                    case (step)
                        4'd1: `RD(pc)
                        4'd2: `PUSH(pc[15:8])
                        4'd3: `PUSH(pc[7:0])
                        4'd4: `PUSH(psw)
                        4'd5: ;
                        4'd6: begin `RD(16'hffde) n_t = data_i; end
                        default: begin
                            `RD(16'hffdf)
                            n_pc = {data_i, t};
                            n_psw[FB] = 1'b1;
                            n_psw[FI] = 1'b0;
                            last = 1'b1;
                        end
                    endcase
                // RET / RETI
                8'h6f, 8'h7f:
                    case (step)
                        4'd1: `RD(pc)
                        4'd2: ;
                        4'd3: begin
                            `POP
                            if (op == 8'h7f) n_psw = data_i; else n_t = data_i;
                        end
                        4'd4: begin
                            `POP
                            if (op == 8'h7f) n_t = data_i;
                            else begin n_pc = {data_i, t}; last = 1'b1; end
                        end
                        default: begin `POP n_pc = {data_i, t}; last = 1'b1; end
                    endcase
                default: last = 1'b1;
                endcase
            end
            endcase
        end
        if (last) n_step = 4'd0;
        `undef RD
        `undef WR
        `undef OPND
        `undef PUSH
        `undef POP
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            step <= 4'd0;
            resetting <= 1'b1;
            halted <= 1'b0;
        end else if (ce) begin
            pc <= n_pc; a <= n_a; x <= n_x; y <= n_y; sp <= n_sp; psw <= n_psw;
            op <= n_op; ea <= n_ea; t <= n_t; dp <= n_dp;
            step <= n_step; halted <= n_halted; resetting <= n_resetting;
        end
    end

    assign fetch_o = step == 4'd0 && !halted && !resetting;
    assign halted_o = halted;
    assign pc_o = pc;
    assign a_o = a;
    assign x_o = x;
    assign y_o = y;
    assign sp_o = sp;
    assign psw_o = psw;
endmodule
