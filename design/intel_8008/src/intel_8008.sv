// Functional Intel 8008 core. See spec/spec.md for bus and timing scope.
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

    function automatic logic flag_selected(input logic [1:0] which);
        case (which)
            2'd0: flag_selected = carry;
            2'd1: flag_selected = zero;
            2'd2: flag_selected = sign;
            default: flag_selected = parity;
        endcase
    endfunction

    task automatic set_szp(input logic [7:0] value);
        begin
            zero <= value == 8'd0;
            sign <= value[7];
            parity <= ~^value;
        end
    endtask

    task automatic execute_alu(input logic [2:0] kind, input logic [7:0] value);
        logic [8:0] tmp;
        begin
            tmp = 9'd0;
            case (kind)
                3'd0: tmp = {1'b0, r[0]} + {1'b0, value};
                3'd1: tmp = {1'b0, r[0]} + {1'b0, value} + {8'd0, carry};
                3'd2: tmp = {1'b0, r[0]} - {1'b0, value};
                3'd3: tmp = {1'b0, r[0]} - {1'b0, value} - {8'd0, carry};
                3'd4: tmp = {1'b0, r[0] & value};
                3'd5: tmp = {1'b0, r[0] ^ value};
                3'd6: tmp = {1'b0, r[0] | value};
                default: tmp = {1'b0, r[0]} - {1'b0, value};
            endcase
            carry <= (kind >= 3'd4 && kind <= 3'd6) ? 1'b0 : tmp[8];
            set_szp(tmp[7:0]);
            if (kind != 3'd7) r[0] <= tmp[7:0];
        end
    endtask

    always_ff @(posedge clk) begin : sequencer
        logic [7:0] code;
        logic [7:0] tmp8;
        integer i;
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
            for (i = 0; i < 7; i = i + 1) r[i] <= 8'd0;
            for (i = 0; i < 8; i = i + 1) stack[i] <= 14'd0;
        end else begin
            retire <= 1'b0;
            if (ready) begin
                case (state)
                    FETCH, HALTED: begin
                        if (state == FETCH || interrupt_i) begin
                            code = interrupt_i ? interrupt_opcode : mem_data_i;
                            op <= code;
                            if (!interrupt_i) pc <= pc + 14'd1;
                            if (code == 8'hff || code == 8'h00 || code == 8'h01) begin
                                state <= HALTED;
                                retire <= 1'b1;
                            end else if (code[7:6] == 2'b11) begin
                                if (code[5:3] == 3'd7) state <= MEM_W;
                                else if (code[2:0] == 3'd7) state <= MEM_R;
                                else begin
                                    r[code[5:3]] <= r[code[2:0]];
                                    retire <= 1'b1;
                                    state <= FETCH;
                                end
                            end else if (code[7:6] == 2'b10) begin
                                if (code[2:0] == 3'd7) state <= MEM_R;
                                else begin
                                    execute_alu(code[5:3], r[code[2:0]]);
                                    retire <= 1'b1;
                                    state <= FETCH;
                                end
                            end else if ((code & 8'hc7) == 8'h06 ||
                                         (code & 8'hc7) == 8'h04) begin
                                state <= IMM;
                            end else if ((code & 8'hc7) == 8'h00 ||
                                         (code & 8'hc7) == 8'h01) begin
                                tmp8 = code[0] ? r[code[5:3]] - 8'd1 : r[code[5:3]] + 8'd1;
                                r[code[5:3]] <= tmp8;
                                set_szp(tmp8);
                                retire <= 1'b1;
                                state <= FETCH;
                            end else if (code[7:6] == 2'b01 && !code[0]) begin
                                state <= ADDR_LO;
                            end else if ((code & 8'hc7) == 8'h07) begin
                                sp <= sp - 3'd1;
                                pc <= stack[sp - 3'd1];
                                retire <= 1'b1;
                                state <= FETCH;
                            end else if ((code & 8'he7) == 8'h03) begin
                                if (code[5] == flag_selected(code[4:3])) begin
                                    sp <= sp - 3'd1;
                                    pc <= stack[sp - 3'd1];
                                end
                                retire <= 1'b1;
                                state <= FETCH;
                            end else if ((code & 8'hc7) == 8'h05) begin
                                stack[sp] <= interrupt_i ? pc : pc + 14'd1;
                                sp <= sp + 3'd1;
                                pc <= {8'd0, code[5:3], 3'b000};
                                retire <= 1'b1;
                                state <= FETCH;
                            end else if ((code & 8'hc1) == 8'h41) begin
                                state <= code[5:4] == 2'b00 ? IO_R : IO_W;
                            end else begin
                                case (code)
                                    8'h02: begin carry <= r[0][7]; r[0] <= {r[0][6:0], r[0][7]}; end
                                    8'h0a: begin carry <= r[0][0]; r[0] <= {r[0][0], r[0][7:1]}; end
                                    8'h12: begin carry <= r[0][7]; r[0] <= {r[0][6:0], carry}; end
                                    8'h1a: begin carry <= r[0][0]; r[0] <= {carry, r[0][7:1]}; end
                                    default: ; // ASSUMPTION: undefined opcode is NOP.
                                endcase
                                retire <= 1'b1;
                                state <= FETCH;
                            end
                        end
                    end
                    IMM: begin
                        pc <= pc + 14'd1;
                        if ((op & 8'hc7) == 8'h06) begin
                            if (op[5:3] == 3'd7) begin immediate <= mem_data_i; state <= MEM_W; end
                            else begin r[op[5:3]] <= mem_data_i; state <= FETCH; retire <= 1'b1; end
                        end else begin
                            execute_alu(op[5:3], mem_data_i);
                            state <= FETCH;
                            retire <= 1'b1;
                        end
                    end
                    ADDR_LO: begin
                        addr_low <= mem_data_i;
                        pc <= pc + 14'd1;
                        state <= ADDR_HI;
                    end
                    ADDR_HI: begin
                        pc <= pc + 14'd1;
                        if (op[2] || (op[5] == flag_selected(op[4:3]))) begin
                            if (op[1]) begin
                                stack[sp] <= pc + 14'd1;
                                sp <= sp + 3'd1;
                            end
                            pc <= {mem_data_i[5:0], addr_low};
                        end
                        state <= FETCH;
                        retire <= 1'b1;
                    end
                    MEM_R: begin
                        if (op[7:6] == 2'b11) r[op[5:3]] <= mem_data_i;
                        else execute_alu(op[5:3], mem_data_i);
                        state <= FETCH;
                        retire <= 1'b1;
                    end
                    MEM_W: begin state <= FETCH; retire <= 1'b1; end
                    IO_R: begin r[0] <= io_data_i; state <= FETCH; retire <= 1'b1; end
                    IO_W: begin state <= FETCH; retire <= 1'b1; end
                    default: state <= FETCH;
                endcase
            end
        end
    end

    `ifdef FORMAL
    logic formal_past_valid = 1'b0;
    always_ff @(posedge clk) begin
        formal_past_valid <= 1'b1;
        if (!formal_past_valid) assume(!rst_n);
        if (rst_n) begin
            assert(!(mem_read && mem_write));
            assert(!(io_read && io_write));
            assert(!(mem_read && io_read));
            assert(!(mem_write && io_write));
        end
        if (formal_past_valid && $past(rst_n) && !$past(ready)) begin
            assert(pc == $past(pc));
            assert(sp == $past(sp));
            assert(r[0] == $past(r[0]));
            assert(flags_debug == $past(flags_debug));
        end
        `ifdef FORMAL_COVER
        if (rst_n) begin
            cover(retire);
            cover(mem_write);
            cover(io_write);
        end
        `endif
    end
    `endif
endmodule
