// Functional Intel 8008 core. See spec/spec.md for bus and timing scope.
//
// The sequencer computes the complete next state combinationally and commits
// every architectural element exactly once (review 2026-10-23: no blocking
// locals or side-effecting tasks inside the clocked block, and no element may
// receive two non-blocking assignments in one cycle).
module intel_8008 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ready,
    output logic [13:0] mem_addr,
    output logic        mem_read,
    output logic        mem_write,
    input  logic [7:0]  mem_data_i,
    output logic [7:0]  mem_data_o,
    output logic [4:0]  io_port,
    output logic        io_read,
    output logic        io_write,
    input  logic [7:0]  io_data_i,
    output logic [7:0]  io_data_o,
    input  logic        interrupt_i,
    input  logic [7:0]  interrupt_opcode,
    output logic        halted,
    output logic        retire,
    output logic [13:0] pc_debug,
    output logic [7:0]  a_debug,
    output logic [3:0]  flags_debug
);
    typedef enum logic [3:0] {FETCH, IMM, ADDR_LO, ADDR_HI,
                              MEM_R, MEM_W, IO_R, IO_W, HALTED} state_t;
    state_t state;
    logic [7:0] r [0:6]; // A B C D E H L
    logic [13:0] stack [0:7];
    logic [2:0] sp;
    logic [13:0] pc;
    logic [7:0] op;
    logic [7:0] addr_low;
    logic [7:0] immediate;
    logic carry, zero, sign, parity;
    logic [13:0] effective_addr;

    assign effective_addr = {r[5][5:0], r[6]};
    assign pc_debug = pc;
    assign a_debug = r[0];
    assign flags_debug = {carry, zero, sign, parity};
    assign halted = state == HALTED;

    always_comb begin
        mem_addr = pc;
        mem_read = 1'b0;
        mem_write = 1'b0;
        mem_data_o = r[0];
        io_port = op[5:1];
        io_read = 1'b0;
        io_write = 1'b0;
        io_data_o = r[0];
        case (state)
            FETCH, IMM, ADDR_LO, ADDR_HI: mem_read = 1'b1;
            MEM_R: begin mem_addr = effective_addr; mem_read = 1'b1; end
            MEM_W: begin
                mem_addr = effective_addr;
                mem_write = 1'b1;
                mem_data_o = op == 8'h3e ? immediate : r[op[2:0]];
            end
            IO_R: io_read = 1'b1;
            IO_W: io_write = 1'b1;
            default: ;
        endcase
    end

    function automatic logic flag_bit(input logic [1:0] which);
        case (which)
            2'd0: flag_bit = carry;
            2'd1: flag_bit = zero;
            2'd2: flag_bit = sign;
            default: flag_bit = parity;
        endcase
    endfunction

    // {zero, sign, parity} for a result byte. Carry is never touched here.
    function automatic logic [2:0] szp_bits(input logic [7:0] value);
        szp_bits = {value == 8'd0, value[7], ~^value};
    endfunction

    // {new_carry, new_zero, new_sign, new_parity, write_acc, new_acc}.
    // kind 7 is compare: flags only, the accumulator is unchanged.
    function automatic logic [12:0] alu_exec(input logic [2:0] kind,
                                             input logic [7:0] acc,
                                             input logic [7:0] value,
                                             input logic carry_in);
        logic [8:0] tmp;
        begin
            case (kind)
                3'd0: tmp = {1'b0, acc} + {1'b0, value};
                3'd1: tmp = {1'b0, acc} + {1'b0, value} + {8'd0, carry_in};
                3'd2: tmp = {1'b0, acc} - {1'b0, value};
                3'd3: tmp = {1'b0, acc} - {1'b0, value} - {8'd0, carry_in};
                3'd4: tmp = {1'b0, acc & value};
                3'd5: tmp = {1'b0, acc ^ value};
                3'd6: tmp = {1'b0, acc | value};
                default: tmp = {1'b0, acc} - {1'b0, value};
            endcase
            alu_exec[12] = (kind >= 3'd4 && kind <= 3'd6) ? 1'b0 : tmp[8];
            alu_exec[11:9] = szp_bits(tmp[7:0]);
            alu_exec[8] = kind != 3'd7;
            alu_exec[7:0] = tmp[7:0];
        end
    endfunction

    // ---- Next-state computation (one decision per architectural element) ----
    logic        fetch_now;
    logic [7:0]  code;
    logic [13:0] pc_adv;
    logic [12:0] alu_q;
    state_t      n_state;
    logic        n_retire;
    logic [13:0] n_pc;
    logic [2:0]  n_sp;
    logic [7:0]  n_op, n_addr_low, n_imm;
    logic        n_carry, n_zero, n_sign, n_parity;
    logic        r_we;
    logic [2:0]  r_waddr;
    logic [7:0]  r_wdata;
    logic        stk_we;
    logic [2:0]  stk_waddr;
    logic [13:0] stk_wdata;

    assign fetch_now = state == FETCH || (state == HALTED && interrupt_i);
    assign code = interrupt_i ? interrupt_opcode : mem_data_i;
    // An injected interrupt opcode occupies the un-advanced PC; a fetched
    // opcode advances it.
    assign pc_adv = interrupt_i ? pc : pc + 14'd1;

    always_comb begin
        alu_q = 13'd0;
        n_state = state;
        n_retire = 1'b0;
        n_pc = pc;
        n_sp = sp;
        n_op = op;
        n_addr_low = addr_low;
        n_imm = immediate;
        n_carry = carry;
        n_zero = zero;
        n_sign = sign;
        n_parity = parity;
        r_we = 1'b0;
        r_waddr = 3'd0;
        r_wdata = 8'd0;
        stk_we = 1'b0;
        stk_waddr = 3'd0;
        stk_wdata = 14'd0;
        if (ready) begin
            case (state)
                FETCH, HALTED: if (fetch_now) begin
                    n_op = code;
                    n_pc = pc_adv;
                    if (code == 8'hff || code == 8'h00 || code == 8'h01) begin
                        n_state = HALTED;
                        n_retire = 1'b1;
                    end else if (code[7:6] == 2'b11) begin
                        if (code[5:3] == 3'd7) begin          // LMr
                            n_state = MEM_W;
                        end else if (code[2:0] == 3'd7) begin // LdM
                            n_state = MEM_R;
                        end else begin                        // Lds
                            r_we = 1'b1;
                            r_waddr = code[5:3];
                            r_wdata = r[code[2:0]];
                            n_retire = 1'b1;
                            n_state = FETCH;
                        end
                    end else if (code[7:6] == 2'b10) begin
                        if (code[2:0] == 3'd7) begin          // ALU with M
                            n_state = MEM_R;
                        end else begin
                            alu_q = alu_exec(code[5:3], r[0], r[code[2:0]], carry);
                            n_carry = alu_q[12];
                            {n_zero, n_sign, n_parity} = alu_q[11:9];
                            if (alu_q[8]) begin
                                r_we = 1'b1;
                                r_waddr = 3'd0;
                                r_wdata = alu_q[7:0];
                            end
                            n_retire = 1'b1;
                            n_state = FETCH;
                        end
                    end else if ((code & 8'hc7) == 8'h06 ||
                                 (code & 8'hc7) == 8'h04) begin // LdI / immediate ALU
                        n_state = IMM;
                    end else if ((code & 8'hc7) == 8'h00 ||
                                 (code & 8'hc7) == 8'h01) begin // INR/DCR
                        if (code[5:3] != 3'd7) begin
                            // INR/DCR M (octal 070/071) is undefined; the spec
                            // models it as a NOP with no register or flag effect.
                            r_we = 1'b1;
                            r_waddr = code[5:3];
                            r_wdata = code[0] ? r[code[5:3]] - 8'd1
                                              : r[code[5:3]] + 8'd1;
                            {n_zero, n_sign, n_parity} = szp_bits(r_wdata);
                        end
                        n_retire = 1'b1;
                        n_state = FETCH;
                    end else if (code[7:6] == 2'b01 && !code[0]) begin // JMP/CAL
                        n_state = ADDR_LO;
                    end else if ((code & 8'hc7) == 8'h07) begin   // RET
                        n_sp = sp - 3'd1;
                        n_pc = stack[sp - 3'd1];
                        n_retire = 1'b1;
                        n_state = FETCH;
                    end else if ((code & 8'hc7) == 8'h03) begin   // RFc/RTc
                        // Manual: RFc is 000 C4C3 011, RTc is 001 C4C3 011;
                        // opcode bit 5 selects the true/false sense. (Review
                        // 2026-10-23: the previous mask fixed bit 5 to zero,
                        // so RTc decoded as a NOP.)
                        if (code[5] == flag_bit(code[4:3])) begin
                            n_sp = sp - 3'd1;
                            n_pc = stack[sp - 3'd1];
                        end
                        n_retire = 1'b1;
                        n_state = FETCH;
                    end else if ((code & 8'hc7) == 8'h05) begin   // RST
                        stk_we = 1'b1;
                        stk_waddr = sp;
                        stk_wdata = pc_adv;
                        n_sp = sp + 3'd1;
                        n_pc = {8'd0, code[5:3], 3'b000};
                        n_retire = 1'b1;
                        n_state = FETCH;
                    end else if (code[0]) begin                   // INP/OUT
                        n_state = code[5:4] == 2'b00 ? IO_R : IO_W;
                    end else begin
                        r_waddr = 3'd0;
                        case (code)
                            8'h02: begin                          // RLC
                                n_carry = r[0][7];
                                r_wdata = {r[0][6:0], r[0][7]};
                                r_we = 1'b1;
                            end
                            8'h0a: begin                          // RRC
                                n_carry = r[0][0];
                                r_wdata = {r[0][0], r[0][7:1]};
                                r_we = 1'b1;
                            end
                            8'h12: begin                          // RAL
                                n_carry = r[0][7];
                                r_wdata = {r[0][6:0], carry};
                                r_we = 1'b1;
                            end
                            8'h1a: begin                          // RAR
                                n_carry = r[0][0];
                                r_wdata = {carry, r[0][7:1]};
                                r_we = 1'b1;
                            end
                            default: ; // ASSUMPTION: undefined opcode is NOP.
                        endcase
                        n_retire = 1'b1;
                        n_state = FETCH;
                    end
                end
                IMM: begin
                    n_pc = pc + 14'd1;
                    n_state = FETCH;
                    if ((op & 8'hc7) == 8'h06) begin
                        if (op[5:3] == 3'd7) begin                // LMI
                            n_imm = mem_data_i;
                            n_state = MEM_W;
                        end else begin                            // LdI
                            r_we = 1'b1;
                            r_waddr = op[5:3];
                            r_wdata = mem_data_i;
                            n_retire = 1'b1;
                        end
                    end else begin                                // immediate ALU
                        alu_q = alu_exec(op[5:3], r[0], mem_data_i, carry);
                        n_carry = alu_q[12];
                        {n_zero, n_sign, n_parity} = alu_q[11:9];
                        if (alu_q[8]) begin
                            r_we = 1'b1;
                            r_waddr = 3'd0;
                            r_wdata = alu_q[7:0];
                        end
                        n_retire = 1'b1;
                    end
                end
                ADDR_LO: begin
                    n_addr_low = mem_data_i;
                    n_pc = pc + 14'd1;
                    n_state = ADDR_HI;
                end
                ADDR_HI: begin
                    n_pc = pc + 14'd1;
                    if (op[2] || (op[5] == flag_bit(op[4:3]))) begin
                        n_pc = {mem_data_i[5:0], addr_low};
                        if (op[1]) begin                          // CAL pushes
                            stk_we = 1'b1;
                            stk_waddr = sp;
                            stk_wdata = pc + 14'd1;
                            n_sp = sp + 3'd1;
                        end
                    end
                    n_state = FETCH;
                    n_retire = 1'b1;
                end
                MEM_R: begin
                    if (op[7:6] == 2'b11) begin                   // LdM
                        r_we = 1'b1;
                        r_waddr = op[5:3];
                        r_wdata = mem_data_i;
                    end else begin                                // ALU with M
                        alu_q = alu_exec(op[5:3], r[0], mem_data_i, carry);
                        n_carry = alu_q[12];
                        {n_zero, n_sign, n_parity} = alu_q[11:9];
                        if (alu_q[8]) begin
                            r_we = 1'b1;
                            r_waddr = 3'd0;
                            r_wdata = alu_q[7:0];
                        end
                    end
                    n_state = FETCH;
                    n_retire = 1'b1;
                end
                MEM_W: begin
                    n_state = FETCH;
                    n_retire = 1'b1;
                end
                IO_R: begin
                    r_we = 1'b1;
                    r_waddr = 3'd0;
                    r_wdata = io_data_i;
                    n_state = FETCH;
                    n_retire = 1'b1;
                end
                IO_W: begin
                    n_state = FETCH;
                    n_retire = 1'b1;
                end
                default: n_state = FETCH;
            endcase
        end
    end

    always_ff @(posedge clk) begin : sequencer
        if (!rst_n) begin
            state <= FETCH;
            pc <= 14'd0;
            sp <= 3'd0;
            op <= 8'd0;
            addr_low <= 8'd0;
            immediate <= 8'd0;
            carry <= 1'b0;
            zero <= 1'b0;
            sign <= 1'b0;
            parity <= 1'b0;
            retire <= 1'b0;
            for (int i = 0; i < 7; i++) r[i] <= 8'd0;
            for (int i = 0; i < 8; i++) stack[i] <= 14'd0;
        end else if (ready) begin
            state <= n_state;
            retire <= n_retire;
            pc <= n_pc;
            sp <= n_sp;
            op <= n_op;
            addr_low <= n_addr_low;
            immediate <= n_imm;
            carry <= n_carry;
            zero <= n_zero;
            sign <= n_sign;
            parity <= n_parity;
            if (r_we) r[r_waddr] <= r_wdata;
            if (stk_we) stack[stk_waddr] <= stk_wdata;
        end else begin
            retire <= 1'b0;
        end
    end

    `ifdef FORMAL
    // Shadow of the accepted instruction: latched at the opcode-accept cycle,
    // valid through retirement. The retire pulse always lands at least one
    // cycle after the accept (single-byte instructions retire on the cycle
    // after their accept), so f_* hold the instruction's base state while
    // pc/sp/flags already show the committed result.
    logic formal_past_valid = 1'b0;
    logic [13:0] f_pc;
    logic [2:0] f_sp;
    logic f_int;
    logic [13:0] f_target;
    logic [1:0] f_wake; // 1: interrupt accepted, 2: accepted from HALT
    always_ff @(posedge clk) begin
        formal_past_valid <= 1'b1;
        if (!formal_past_valid) assume(!rst_n);
        if (!rst_n) begin
            f_wake <= 2'd0;
        end else if (ready && fetch_now) begin
            f_pc <= pc;
            f_sp <= sp;
            f_int <= interrupt_i;
            f_wake <= state == HALTED ? 2'd2 : (interrupt_i ? 2'd1 : 2'd0);
        end else begin
            f_wake <= 2'd0;
        end
        if (rst_n && ready && state == ADDR_HI)
            f_target <= {mem_data_i[5:0], addr_low};
    end
    // PC after the opcode byte: injected opcodes occupy the un-advanced PC.
    logic [13:0] f_next;
    assign f_next = f_int ? f_pc : f_pc + 14'd1;

    // Spec opcode classes at the retire boundary.
    // 0: one byte, PC advances by one, SP unchanged (also HLT and INP/OUT).
    // 1: two bytes (LdI, immediate ALU, LMI): PC advances by two.
    // 2: return family or RST: PC/SP per the stack transfer.
    // 3: JMP/CAL: PC advances by three or jumps; CAL pushes when taken.
    function automatic logic [1:0] instr_class(input logic [7:0] c);
        if (c == 8'hff || c == 8'h00 || c == 8'h01)
            instr_class = 2'd0;
        else if (c[7:6] == 2'b11)
            instr_class = (c[5:3] == 3'd7 || c[2:0] == 3'd7) ? 2'd3 : 2'd0;
        else if (c[7:6] == 2'b10)
            instr_class = (c[2:0] == 3'd7) ? 2'd3 : 2'd0;
        else if ((c & 8'hc7) == 8'h06 || (c & 8'hc7) == 8'h04)
            instr_class = 2'd1;
        else if ((c & 8'hc7) == 8'h00 || (c & 8'hc7) == 8'h01)
            instr_class = 2'd0;
        else if (c[7:6] == 2'b01 && !c[0])
            instr_class = 2'd3;
        else if ((c & 8'hc7) == 8'h07 || (c & 8'hc7) == 8'h03 ||
                 (c & 8'hc7) == 8'h05)
            instr_class = 2'd2;
        else
            instr_class = 2'd0; // rotates, INP/OUT, undefined NOPs
    endfunction

    logic [55:0] regs_packed;
    assign regs_packed = {r[0], r[1], r[2], r[3], r[4], r[5], r[6]};

    always_ff @(posedge clk) begin
        if (rst_n) begin
            // Bus strobes: exactly one transaction kind at a time, and the
            // address/port selection matches the owning state.
            assert(!(mem_read && mem_write));
            assert(!(io_read && io_write));
            assert(!(mem_read && io_read));
            assert(!(mem_write && io_write));
            if (state == FETCH || state == IMM || state == ADDR_LO ||
                state == ADDR_HI) begin
                assert(mem_read);
                assert(mem_addr == pc);
            end else if (state == MEM_R) begin
                assert(mem_read && mem_addr == effective_addr);
            end else if (state == MEM_W) begin
                assert(mem_write && mem_addr == effective_addr);
                assert(mem_data_o == (op == 8'h3e ? immediate : r[op[2:0]]));
            end else if (state == IO_R) begin
                assert(io_read && io_port == op[5:1]);
            end else if (state == IO_W) begin
                assert(io_write && io_port == op[5:1]);
            end else begin
                assert(!mem_read && !mem_write && !io_read && !io_write);
            end
            // Register file writes stay in bounds by construction; the single
            // write port must name a defined register.
            if (r_we) assert(r_waddr <= 3'd6);
            // Ready freezes the whole architectural state.
            if (formal_past_valid && $past(rst_n) && !$past(ready)) begin
                assert(pc == $past(pc));
                assert(sp == $past(sp));
                assert(op == $past(op));
                assert(state == $past(state));
                assert(flags_debug == $past(flags_debug));
                assert(regs_packed == $past(regs_packed));
            end
            // Retirement contract, per opcode class. The retire pulse arrives
            // one cycle after the instruction's last execute state, so the
            // committed pc/sp/flags are already visible and the final cycle's
            // memory byte is $past(mem_data_i).
            if (retire) begin
                case (instr_class(op))
                    2'd0: begin
                        assert(pc == f_next);
                        assert(sp == f_sp);
                    end
                    2'd1: begin
                        assert(pc == f_next + 14'd1);
                        assert(sp == f_sp);
                    end
                    2'd2: begin
                        if ((op & 8'hc7) == 8'h05) begin // RST
                            assert(pc == {8'd0, op[5:3], 3'b000});
                            assert(sp == f_sp + 3'd1);
                            assert(stack[f_sp] == f_next);
                        end else if ((op & 8'hc7) == 8'h07) begin
                            // RET and its documented aliases pop unconditionally.
                            assert(pc == stack[f_sp - 3'd1]);
                            assert(sp == f_sp - 3'd1);
                        end else if (op[5] == flag_bit(op[4:3])) begin
                            assert(pc == stack[f_sp - 3'd1]);
                            assert(sp == f_sp - 3'd1);
                        end else begin
                            assert(pc == f_next);
                            assert(sp == f_sp);
                        end
                    end
                    default: begin // JMP/CAL or memory-cycle instruction
                        if ($past(state) == ADDR_HI) begin
                            if (op[2] || (op[5] == flag_bit(op[4:3]))) begin
                                assert(pc == f_target);
                                if (op[1]) begin // CAL taken
                                    assert(sp == f_sp + 3'd1);
                                    assert(stack[f_sp] == f_next + 14'd2);
                                end else begin
                                    assert(sp == f_sp);
                                end
                            end else begin
                                assert(pc == f_next + 14'd2);
                                assert(sp == f_sp);
                            end
                        end else begin // LdM/LMr/ALU-M retirement
                            assert(pc == f_next);
                            assert(sp == f_sp);
                        end
                    end
                endcase
                // F1: undefined INR/DCR M (octal 070/071) is a full NOP.
                if ((op & 8'hc7) == 8'h00 || (op & 8'hc7) == 8'h01) begin
                    if (op[5:3] == 3'd7) begin
                        assert(pc == f_next);
                        assert(flags_debug == $past(flags_debug));
                        assert(regs_packed == $past(regs_packed));
                    end
                end
            end
            `ifdef FORMAL_COVER
            if (state == FETCH && ready) begin
                cover(retire);
                cover(code == 8'h00);                              // HLT
                cover((code & 8'hc7) == 8'h00 && code[5:3] == 3'd7); // INR M NOP
                cover((code & 8'hc7) == 8'h01 && code[5:3] == 3'd7); // DCR M NOP
                cover((code & 8'hc7) == 8'h03 && code[5] == 1'b1);  // RTc
                cover((code & 8'hc7) == 8'h03 && code[5] == 1'b0);  // RFc
                cover(code[7:6] == 2'b01 && !code[0]);              // JMP/CAL
            end
            cover(mem_write);
            cover(io_write);
            if (retire && f_wake != 2'd0) begin
                cover(f_wake == 2'd2); // instruction injected from HALT
                cover((op & 8'hc7) == 8'h05); // RST under interrupt
            end
            `endif
        end
    end
    `endif
endmodule
