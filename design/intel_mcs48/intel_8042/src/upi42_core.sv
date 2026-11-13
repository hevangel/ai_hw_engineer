// Intel UPI-42 (8042) processor core.
//
// Sources: Intel UPI-41A User's Manual 9800504-02B (Apr 1980), chapters 2-3,
// and the 8742 data sheet 290256-001 (Nov 1991) for the 2K ROM / 128-byte
// RAM sizes. Behavior the documents do not state is tagged ASSUMPTION Ux; the
// same tags appear in the reference model scripts/upi42_iss.py and in
// spec/spec.md.
//
// Timing: one machine cycle per clock with ce_i high. An instruction takes
// one or two machine cycles (manual Table 3-2); its architectural effects are
// applied at the end of its last cycle (ASSUMPTION U6). The host bus is
// sampled on every clock, independent of ce_i.
module upi42_core (
    input  logic        clk,
    input  logic        rst_n,      // synchronous, active low (RESET pin)
    input  logic        ce_i,       // machine-cycle enable

    // Program memory (combinational read)
    output logic [10:0] rom_addr_o,
    input  logic [7:0]  rom_data_i,

    // Host interface (data bus buffer, manual p.2-13)
    input  logic        cs_n_i,
    input  logic        rd_n_i,
    input  logic        wr_n_i,
    input  logic        a0_i,
    input  logic [7:0]  d_i,
    output logic [7:0]  d_o,
    output logic        d_oe_o,

    // Ports: quasi-bidirectional. *_o is the chip drive (1 = weak high),
    // *_i is the pin level after any external pull-down.
    output logic [7:0]  p1_o,
    input  logic [7:0]  p1_i,
    output logic [7:0]  p2_o,
    input  logic [7:0]  p2_i,
    input  logic        t0_i,
    input  logic        t1_i,

    // Retire/debug interface
    output logic        retire_o,
    output logic [10:0] retire_pc_o,
    output logic [7:0]  retire_op_o,
    output logic [1:0]  retire_kind_o,   // 0 insn, 1 IBF vector, 2 timer vector
    output logic        illegal_o,       // pulse with retire_o
    output logic [10:0] pc_o,
    output logic [7:0]  a_o,
    output logic [7:0]  psw_o,
    output logic [7:0]  sts_o,
    output logic [7:0]  t_o,
    output logic [7:0]  dbbin_o,
    output logic [7:0]  dbbout_o,
    output logic [15:0] misc_o           // see assignment below
);
    // ------------------------------------------------------------ state
    typedef enum logic [1:0] {S_FETCH, S_EXEC2, S_IRQ2} state_t;
    typedef enum logic [1:0] {TM_STOP, TM_TIMER, TM_COUNT} tmode_t;

    state_t      state;
    logic [7:0]  op_q;          // opcode held for the second cycle
    logic [10:0] pc_q;          // address of the instruction being executed
    logic        take_q;        // branch condition latched in cycle 1
    logic        vec7_q;        // vector selected in cycle 1 (0 = loc 3)

    logic [7:0]  ram [0:127];   // 128 x 8 (8742 data sheet)
    logic [7:0]  acc;
    logic [10:0] pc;
    logic        cy, ac, f0, bs;
    logic [2:0]  sp;
    logic        f1, ibf, obf;
    logic [3:0]  st_hi;
    logic [7:0]  dbbin, dbbout;
    logic [7:0]  p1, p2;
    logic [7:0]  tmr;
    logic [4:0]  pre;
    tmode_t      tmode;
    logic        tf, tie, tirq, ie, ibf_irq, in_irq, flags_en, dma_en;
    logic        t1_prev;

    // Host strobes (data sheet p.4: RD and WR act on their trailing edge)
    logic        wr_act, rd_act;
    logic        wr_a0_q, rd_a0_q;
    logic [7:0]  wr_d_q;

    // ------------------------------------------------------ PSW / regs
    logic [7:0]  psw;
    // ASSUMPTION U2: PSW bit 3 ("not used", manual p.2-7) reads as 1.
    assign psw = {cy, ac, f0, bs, 1'b1, sp};

    logic [6:0]  rbase;
    assign rbase = bs ? 7'd24 : 7'd0;

    // ---------------------------------------------------- decode helpers
    function automatic logic is_cond(input logic [7:0] o);
        case (o)
            8'hF6, 8'hE6, 8'hC6, 8'h96, 8'h36, 8'h26, 8'h56, 8'h46,
            8'hB6, 8'h76, 8'h16, 8'hD6, 8'h86: is_cond = 1'b1;
            default: is_cond = 1'b0;
        endcase
    endfunction

    /* verilator lint_off UNUSEDSIGNAL */
    function automatic logic is_expander(input logic [7:0] o);
        is_expander = (o[7:4] == 4'h0 || o[7:4] == 4'h3 || o[7:4] == 4'h8 ||
                       o[7:4] == 4'h9) && o[3:2] == 2'b11;
    endfunction
    /* verilator lint_on UNUSEDSIGNAL */

    function automatic logic needs_imm(input logic [7:0] o);
        case (o)
            8'h03, 8'h13, 8'h53, 8'h43, 8'hD3,   // ALU A,#data
            8'h99, 8'h9A, 8'h89, 8'h8A,          // ANL/ORL Pp,#data
            8'h23, 8'hB0, 8'hB1:                 // MOV A,# / MOV @Ri,#
                needs_imm = 1'b1;
            default:
                needs_imm = (o[3:0] == 4'h4) ||                    // JMP/CALL
                            (o[7:3] == 5'b10111) ||                // MOV Rr,#
                            (o[7:3] == 5'b11101) ||                // DJNZ
                            (o[3:0] == 4'h2 && o[4]) ||            // JBb
                            is_cond(o);
        endcase
    endfunction

    function automatic logic two_cycle(input logic [7:0] o);
        case (o)
            8'h09, 8'h0A, 8'h39, 8'h3A, 8'hA3, 8'hE3, 8'h83, 8'h93, 8'hB3:
                two_cycle = 1'b1;
            default:
                two_cycle = needs_imm(o) || is_expander(o);
        endcase
    endfunction

    // --------------------------------------------- execution operands
    logic        exec_now;      // instruction completes this ce cycle
    logic        irq_take;      // start an interrupt vector this cycle
    logic        irq_vec7;
    logic [7:0]  x_op;          // opcode being completed
    logic [7:0]  x_imm;         // second byte (valid when needs_imm)
    logic [10:0] x_pc;          // PC after all fetch bytes
    logic [2:0]  x_opage;       // page of the operand byte
    logic        x_take;        // branch condition from cycle 1
    logic [7:0]  fetch_op;

    assign fetch_op = rom_data_i;

    // Values read from RAM for the executing instruction.
    logic [2:0]  x_r;
    logic        x_ri;
    logic [7:0]  r_val, ind_val;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [7:0]  ri_ptr;        // bit 7 ignored (ASSUMPTION U3)
    /* verilator lint_on UNUSEDSIGNAL */
    logic [6:0]  r_addr, ind_addr;
    assign x_r      = x_op[2:0];
    assign x_ri     = x_op[0];
    assign r_addr   = rbase + {4'd0, x_r};
    assign r_val    = ram[r_addr];
    assign ri_ptr   = ram[rbase + {6'd0, x_ri}];
    // ASSUMPTION U3: @Ri uses pointer bits 0-6 for the 128-byte RAM.
    assign ind_addr = ri_ptr[6:0];
    assign ind_val  = ram[ind_addr];

    // Stack slots (manual Figure 2-7)
    logic [6:0]  push_lo, pop_lo;
    logic [2:0]  sp_dec;
    assign push_lo = 7'd8 + {3'd0, sp, 1'b0};
    assign sp_dec  = sp - 3'd1;
    assign pop_lo  = 7'd8 + {3'd0, sp_dec, 1'b0};

    // Branch condition (evaluated in the instruction's first cycle with the
    // state presented before the instruction, as in the reference model).
    function automatic logic cond_of(input logic [7:0] o);
        case (o)
            8'hF6: cond_of = cy;
            8'hE6: cond_of = !cy;
            8'hC6: cond_of = (acc == 8'd0);
            8'h96: cond_of = (acc != 8'd0);
            8'h36: cond_of = t0_i;
            8'h26: cond_of = !t0_i;
            8'h56: cond_of = t1_i;
            8'h46: cond_of = !t1_i;
            8'hB6: cond_of = f0;
            8'h76: cond_of = f1;
            8'h16: cond_of = tf;
            8'hD6: cond_of = !ibf;
            8'h86: cond_of = obf;
            default: cond_of = acc[o[7:5]];          // JBb
        endcase
    endfunction

    // ------------------------------------------------------- sequencing
    logic cnt_inc, cnt_ovf, tirq_avail;
    assign cnt_inc    = (state == S_FETCH) && (tmode == TM_COUNT) && t1_prev && !t1_i;
    assign cnt_ovf    = cnt_inc && (tmr == 8'hFF);
    assign tirq_avail = tirq || (cnt_ovf && tie);

    always_comb begin
        irq_take = 1'b0;
        irq_vec7 = 1'b0;
        exec_now = 1'b0;
        x_op     = fetch_op;
        x_imm    = rom_data_i;
        x_pc     = pc + 11'd1;          // ASSUMPTION U4: 11-bit wrap
        x_opage  = pc[10:8];
        x_take   = cond_of(fetch_op);
        rom_addr_o = pc;
        case (state)
            S_FETCH: begin
                if (!in_irq && ie && ibf_irq) begin
                    irq_take = 1'b1;
                end else if (!in_irq && tie && tirq_avail) begin
                    irq_take = 1'b1;
                    irq_vec7 = 1'b1;
                end else begin
                    exec_now = !two_cycle(fetch_op);
                end
            end
            S_EXEC2: begin
                x_op    = op_q;
                x_take  = take_q;
                x_opage = pc[10:8];
                x_pc    = needs_imm(op_q) ? pc + 11'd1 : pc;
                exec_now = 1'b1;
                // MOVP / JMPP read the page of the incremented PC (manual
                // p.3-20 note); MOVP3 reads page 3 (ASSUMPTION U10).
                if (op_q == 8'hA3 || op_q == 8'hB3)
                    rom_addr_o = {pc[10:8], acc};
                else if (op_q == 8'hE3)
                    rom_addr_o = {3'b011, acc};
            end
            default: ;
        endcase
    end

    // ------------------------------------------------------ host side
    // ASSUMPTION U13: a strobe's trailing edge is detected one clock after
    // CS/RD/WR deassert; the data and A0 present while the strobe was
    // active are used. A host write completing on the same clock as IN A,DBB
    // leaves IBF set.
    logic wr_now, rd_now, wr_end, rd_end;
    assign wr_now = !cs_n_i && !wr_n_i;
    assign rd_now = !cs_n_i && !rd_n_i;
    assign wr_end = wr_act && !wr_now;
    assign rd_end = rd_act && !rd_now;

    logic [7:0] sts;
    assign sts = {st_hi, f1, f0, ibf, obf};
    assign d_oe_o = rd_now;
    assign d_o    = a0_i ? sts : dbbout;

    // ---------------------------------------------------------- outputs
    assign p1_o = p1;
    // EN FLAGS: P24 = OBF gated by latch, P25 = /IBF gated by latch
    // (manual p.2-12, data sheet p.4).
    assign p2_o = flags_en ? {p2[7:6], p2[5] & !ibf, p2[4] & obf, p2[3:0]} : p2;

    assign pc_o     = pc;
    assign a_o      = acc;
    assign psw_o    = psw;
    assign sts_o    = sts;
    assign t_o      = tmr;
    assign dbbin_o  = dbbin;
    assign dbbout_o = dbbout;
    assign misc_o   = {1'b0, pre, tmode, tf, tie, tirq, ie, ibf_irq, in_irq,
                       flags_en, dma_en};

    // ------------------------------------------------- the update logic
    logic [7:0] alu_src;
    logic [8:0] add_sum;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [4:0] add_half;       // only the nibble carry is used
    /* verilator lint_on UNUSEDSIGNAL */
    logic       add_cin;

    always_comb begin
        // Source operand for the A-register ALU group
        if (x_op[3])
            alu_src = r_val;
        else if (x_op[3:0] == 4'h3)
            alu_src = x_imm;
        else
            alu_src = ind_val;
        add_cin  = (x_op[7:4] == 4'h7 || x_op == 8'h13) ? cy : 1'b0;
        add_sum  = {1'b0, acc} + {1'b0, alu_src} + {8'd0, add_cin};
        add_half = {1'b0, acc[3:0]} + {1'b0, alu_src[3:0]} + {4'd0, add_cin};
    end

    // Decimal adjust (manual p.3-10). ASSUMPTION U12: C is set by a carry
    // out of either addition and otherwise keeps its value.
    logic [8:0] da_1, da_2;
    logic [7:0] da_res;
    logic       da_cy;
    always_comb begin
        da_1 = {1'b0, acc};
        if (acc[3:0] > 4'd9 || ac)
            da_1 = {1'b0, acc} + 9'h006;
        da_2 = {1'b0, da_1[7:0]};
        if (da_1[7:4] > 4'd9 || cy)
            da_2 = {1'b0, da_1[7:0]} + 9'h060;
        da_res = da_2[7:0];
        da_cy  = cy | da_1[8] | da_2[8];
    end

    always_ff @(posedge clk) begin
        retire_o <= 1'b0;
        illegal_o <= 1'b0;
        if (!rst_n) begin
            // Manual p.2-12 and p.2-14; A, RAM and T are not reset.
            state    <= S_FETCH;
            pc       <= 11'd0;
            sp       <= 3'd0;
            bs       <= 1'b0;
            cy       <= 1'b0;
            ac       <= 1'b0;
            f0       <= 1'b0;
            f1       <= 1'b0;
            ibf      <= 1'b0;
            obf      <= 1'b0;
            st_hi    <= 4'd0;
            p1       <= 8'hFF;
            p2       <= 8'hFF;
            ie       <= 1'b0;
            tie      <= 1'b0;
            tirq     <= 1'b0;
            ibf_irq  <= 1'b0;
            in_irq   <= 1'b0;
            tmode    <= TM_STOP;
            tf       <= 1'b0;
            pre      <= 5'd0;
            flags_en <= 1'b0;   // ASSUMPTION U1
            dma_en   <= 1'b0;
            wr_act   <= 1'b0;
            rd_act   <= 1'b0;
            take_q   <= 1'b0;
            vec7_q   <= 1'b0;
            t1_prev  <= 1'b1;
        end else begin
            // ---- host strobes (every clock)
            wr_act <= wr_now;
            rd_act <= rd_now;
            if (wr_now) begin
                wr_d_q  <= d_i;
                wr_a0_q <= a0_i;
            end
            if (rd_now)
                rd_a0_q <= a0_i;

            if (ce_i) begin : machine_cycle
                logic [7:0] t_n;
                logic       tf_n, tirq_n;
                logic [4:0] pre_n;
                t_n    = tmr;
                tf_n   = tf;
                tirq_n = tirq;
                pre_n  = pre;

                // Counter input sampled at instruction start (ASSUMPTION U7)
                if (state == S_FETCH) begin
                    t1_prev <= t1_i;
                    if (cnt_inc) begin
                        t_n = tmr + 8'd1;
                        if (tmr == 8'hFF) begin
                            tf_n = 1'b1;
                            if (tie) tirq_n = 1'b1;
                        end
                    end
                end

                // Interrupt entry clears its request before the cycle ticks
                if (irq_take && irq_vec7)
                    tirq_n = 1'b0;

                // Timer prescaler: machine cycle / 32 (manual p.2-10)
                if (tmode == TM_TIMER) begin
                    pre_n = pre + 5'd1;
                    if (pre == 5'd31) begin
                        t_n = t_n + 8'd1;
                        if (t_n == 8'd0) begin
                            tf_n = 1'b1;
                            if (tie) tirq_n = 1'b1;
                        end
                    end
                end

                case (state)
                    S_FETCH: begin
                        pc_q <= pc;
                        if (irq_take) begin
                            vec7_q <= irq_vec7;
                            in_irq <= 1'b1;
                            if (!irq_vec7) ibf_irq <= 1'b0;
                            state <= S_IRQ2;
                        end else begin
                            op_q   <= fetch_op;
                            take_q <= cond_of(fetch_op);
                            pc     <= pc + 11'd1;
                            if (two_cycle(fetch_op))
                                state <= S_EXEC2;
                        end
                    end
                    S_EXEC2: begin
                        state <= S_FETCH;
                        if (needs_imm(op_q))
                            pc <= pc + 11'd1;
                    end
                    S_IRQ2: begin
                        // Forced CALL to 3 or 7 (manual p.2-11); 2 cycles
                        // in total (ASSUMPTION U8).
                        state <= S_FETCH;
                        ram[push_lo]        <= pc[7:0];
                        ram[push_lo + 7'd1] <= {psw[7:4], 1'b0, pc[10:8]};
                        sp       <= sp + 3'd1;
                        pc       <= vec7_q ? 11'd7 : 11'd3;
                        retire_o      <= 1'b1;
                        retire_pc_o   <= pc;
                        retire_op_o   <= 8'h00;
                        retire_kind_o <= vec7_q ? 2'd2 : 2'd1;
                    end
                    default: state <= S_FETCH;
                endcase

                if (exec_now) begin : execute
                    retire_o      <= 1'b1;
                    retire_pc_o   <= (state == S_FETCH) ? pc : pc_q;
                    retire_op_o   <= x_op;
                    retire_kind_o <= 2'd0;
                    casez (x_op)
                        // --- A-register ALU: ADD/ADDC/ANL/ORL/XRL
                        8'b0110_1???, 8'b0110_000?, 8'h03,
                        8'b0111_1???, 8'b0111_000?, 8'h13: begin
                            acc <= add_sum[7:0];
                            cy  <= add_sum[8];
                            ac  <= add_half[4];
                        end
                        8'b0101_1???, 8'b0101_000?, 8'h53: acc <= acc & alu_src;
                        8'b0100_1???, 8'b0100_000?, 8'h43: acc <= acc | alu_src;
                        8'b1101_1???, 8'b1101_000?, 8'hD3: acc <= acc ^ alu_src;
                        8'h17: acc <= acc + 8'd1;
                        8'h07: acc <= acc - 8'd1;
                        8'h27: acc <= 8'd0;
                        8'h37: acc <= ~acc;
                        8'h57: begin acc <= da_res; cy <= da_cy; end
                        8'h47: acc <= {acc[3:0], acc[7:4]};
                        8'hE7: acc <= {acc[6:0], acc[7]};
                        8'hF7: begin acc <= {acc[6:0], cy}; cy <= acc[7]; end
                        8'h77: acc <= {acc[0], acc[7:1]};
                        8'h67: begin acc <= {cy, acc[7:1]}; cy <= acc[0]; end
                        // --- input/output
                        8'h09: acc <= p1_i;
                        8'h0A: acc <= p2_i;
                        8'h39: p1 <= acc;
                        8'h3A: p2 <= acc;
                        // ASSUMPTION U9: ANL/ORL Pp,#data act on the latch
                        8'h99: p1 <= p1 & x_imm;
                        8'h9A: p2 <= p2 & x_imm;
                        8'h89: p1 <= p1 | x_imm;
                        8'h8A: p2 <= p2 | x_imm;
                        8'h22: begin acc <= dbbin; ibf <= 1'b0; end
                        8'h02: begin dbbout <= acc; obf <= 1'b1; end
                        8'h90: st_hi <= acc[7:4];
                        // --- data moves
                        8'b1111_1???: acc <= r_val;
                        8'b1111_000?: acc <= ind_val;
                        8'h23: acc <= x_imm;
                        8'b1010_1???: ram[r_addr] <= acc;
                        8'b1010_000?: ram[ind_addr] <= acc;
                        8'b1011_1???: ram[r_addr] <= x_imm;
                        8'b1011_000?: ram[ind_addr] <= x_imm;
                        8'hC7: acc <= psw;
                        8'hD7: begin
                            cy <= acc[7]; ac <= acc[6]; f0 <= acc[5];
                            bs <= acc[4]; sp <= acc[2:0];
                        end
                        8'b0010_1???: begin ram[r_addr] <= acc; acc <= r_val; end
                        8'b0010_000?: begin ram[ind_addr] <= acc; acc <= ind_val; end
                        8'b0011_000?: begin
                            ram[ind_addr] <= {ind_val[7:4], acc[3:0]};
                            acc <= {acc[7:4], ind_val[3:0]};
                        end
                        8'hA3, 8'hE3: acc <= rom_data_i;
                        // --- timer/counter (effects after the cycle ticks)
                        8'h42: acc <= t_n;
                        8'h62: t_n = acc;
                        8'h55: begin tmode <= TM_TIMER; pre_n = 5'd0; end
                        8'h45: tmode <= TM_COUNT;
                        8'h65: tmode <= TM_STOP;
                        8'h25: tie <= 1'b1;
                        8'h35: begin tie <= 1'b0; tirq_n = 1'b0; end
                        // --- control
                        8'hE5: dma_en <= 1'b1;
                        8'h05: ie <= 1'b1;
                        8'h15: ie <= 1'b0;
                        8'hF5: flags_en <= 1'b1;
                        8'hC5: bs <= 1'b0;
                        8'hD5: bs <= 1'b1;
                        8'h00: ;
                        // --- registers
                        8'b0001_1???: ram[r_addr] <= r_val + 8'd1;
                        8'b0001_000?: ram[ind_addr] <= ind_val + 8'd1;
                        8'b1100_1???: ram[r_addr] <= r_val - 8'd1;
                        // --- subroutine and jumps
                        8'b???1_0100: begin              // CALL
                            ram[push_lo]        <= x_pc[7:0];
                            ram[push_lo + 7'd1] <= {psw[7:4], 1'b0, x_pc[10:8]};
                            sp <= sp + 3'd1;
                            pc <= {x_op[7:5], x_imm};
                        end
                        8'b???0_0100: pc <= {x_op[7:5], x_imm};   // JMP
                        8'h83, 8'h93: begin              // RET / RETR
                            sp <= sp_dec;
                            pc <= {ram[pop_lo + 7'd1][2:0], ram[pop_lo]};
                            if (x_op[4]) begin
                                cy <= ram[pop_lo + 7'd1][7];
                                ac <= ram[pop_lo + 7'd1][6];
                                f0 <= ram[pop_lo + 7'd1][5];
                                bs <= ram[pop_lo + 7'd1][4];
                                in_irq <= 1'b0;
                            end
                        end
                        // --- flags
                        8'h97: cy <= 1'b0;
                        8'hA7: cy <= !cy;
                        8'h85: f0 <= 1'b0;
                        8'h95: f0 <= !f0;
                        8'hA5: f1 <= 1'b0;
                        8'hB5: f1 <= !f1;
                        // --- branches
                        8'hB3: pc <= {x_pc[10:8], rom_data_i};      // JMPP
                        8'b1110_1???: begin                          // DJNZ
                            ram[r_addr] <= r_val - 8'd1;
                            // ASSUMPTION U5: page of the operand byte
                            if (r_val != 8'd1)
                                pc <= {x_opage, x_imm};
                        end
                        8'b???1_0010: if (x_take) pc <= {x_opage, x_imm};  // JBb
                        8'hF6, 8'hE6, 8'hC6, 8'h96, 8'h36, 8'h26, 8'h56, 8'h46,
                        8'hB6, 8'h76, 8'hD6, 8'h86:
                            if (x_take) pc <= {x_opage, x_imm};
                        8'h16: begin                                   // JTF
                            tf_n = 1'b0;
                            if (x_take) pc <= {x_opage, x_imm};
                        end
                        default: begin
                            // 8243 expander instructions and opcodes not in
                            // Table 3-2 (ASSUMPTION U11): no effect.
                            illegal_o <= 1'b1;
                        end
                    endcase
                end

                tmr  <= t_n;
                tf   <= tf_n;
                tirq <= tirq_n;
                pre  <= pre_n;
            end

            // ---- host strobe completion (after the core so that it wins)
            if (wr_end) begin
                dbbin   <= wr_d_q;
                ibf     <= 1'b1;
                f1      <= wr_a0_q;
                ibf_irq <= 1'b1;
            end
            if (rd_end && !rd_a0_q)
                obf <= 1'b0;
        end
    end

`ifdef FORMAL
    // Properties hold for any program (rom_data_i is unconstrained) and
    // any host/pin activity.
    logic f_past_valid = 1'b0;
    logic [1:0] f_ce_since_retire = 2'd0;
    always_ff @(posedge clk) begin
        f_past_valid <= 1'b1;
        if (!rst_n || retire_o)
            f_ce_since_retire <= 2'd0;
        else if (ce_i && f_ce_since_retire != 2'd3)
            f_ce_since_retire <= f_ce_since_retire + 2'd1;
    end

    always_comb begin
        if (!f_past_valid)
            assume (!rst_n);
    end

    always_ff @(posedge clk) begin
        if (f_past_valid && $past(rst_n) && rst_n) begin
            // The sequencer only uses its three states.
            assert (state != 2'd3);
            // Every instruction or vector retires within two machine
            // cycles (manual Table 3-2: 1 or 2 cycles).
            assert (f_ce_since_retire <= 2'd2);
            // A vector cycle is always inside an interrupt.
            if (state == S_IRQ2) assert (in_irq);
            // Single-level interrupts: none is taken while one is active.
            if (irq_take) assert (!in_irq);
            // Interrupt priority: IBF before timer (manual p.2-10).
            if (irq_take && ie && ibf_irq) assert (!irq_vec7);
            // Retire pulses only follow a machine cycle.
            if (retire_o) assert ($past(ce_i));
            // A completed host write always leaves IBF set (U13).
            if ($past(wr_end)) assert (ibf);
            // The timer prescaler only runs in timer mode.
            if ($past(tmode) != TM_TIMER &&
                !($past(ce_i) && $past(exec_now) && $past(x_op) == 8'h55))
                assert (pre == $past(pre));
        end
    end

    always_ff @(posedge clk) begin
        if (f_past_valid && $past(rst_n) && rst_n) begin
            cover (retire_o && retire_kind_o == 2'd1);          // IBF vector
            cover (retire_o && retire_kind_o == 2'd2);          // timer vector
            cover (retire_o && retire_op_o == 8'h93 && !in_irq); // RETR
            // Stack wrap by a CALL (manual p.2-7)
            cover ($past(ce_i) && $past(exec_now) && $past(x_op[4:0]) == 5'b10100
                   && $past(sp) == 3'd7 && sp == 3'd0);
            cover (obf && $past(!obf));                         // OUT DBB
        end
    end
`endif
endmodule
