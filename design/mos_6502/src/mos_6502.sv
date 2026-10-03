module mos_6502 (
    input  logic        clk,
    input  logic        rst_n,
    output logic [15:0] bus_addr,
    input  logic [7:0]  bus_data_i,
    output logic [7:0]  bus_data_o,
    output logic        bus_we,
    output logic        fetch_o,
    output logic        fault_o,
    output logic [15:0] pc_o,
    output logic [7:0]  status_o,
    output logic [7:0]  x_o,
    output logic [7:0]  y_o
);
    typedef enum logic [3:0] {
        RESET_LO, RESET_HI, FETCH, IMM, ABS_LO, ABS_HI, WRITE, FAULT,
        ZP, READ, REL
    } state_t;
    state_t state;
    logic [15:0] pc;
    logic [15:0] target;
    logic [7:0] a, x, y, p, opcode;
    logic [7:0] low_byte;
    logic branch_taken;

    always_comb begin
        case (opcode[7:6])
            2'b00: branch_taken = p[7] == opcode[5];
            2'b01: branch_taken = p[6] == opcode[5];
            2'b10: branch_taken = p[0] == opcode[5];
            2'b11: branch_taken = p[1] == opcode[5];
            default: branch_taken = 1'b0;
        endcase
    end

    assign pc_o = pc;
    assign status_o = p;
    assign x_o = x;
    assign y_o = y;
    assign fetch_o = (state == FETCH);
    assign fault_o = (state == FAULT);
    assign bus_data_o = a;
    assign bus_we = (state == WRITE);

    always_comb begin
        case (state)
            RESET_LO: bus_addr = 16'hfffc;
            RESET_HI: bus_addr = 16'hfffd;
            WRITE, READ: bus_addr = target;
            default:  bus_addr = pc;
        endcase
    end

    // ASSUMPTION: This early slice uses a combinational read bus. NMOS 6502
    // dummy reads and exact phi2 timing are deferred and must be checked
    // against the MOS hardware manual before Apple II software sign-off.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= RESET_LO;
            pc <= 16'h0000;
            target <= 16'h0000;
            low_byte <= 8'h00;
            opcode <= 8'h00;
            a <= 8'h00;
            x <= 8'h00;
            y <= 8'h00;
            p <= 8'h24;
        end else begin
            case (state)
                RESET_LO: begin
                    low_byte <= bus_data_i;
                    state <= RESET_HI;
                end
                RESET_HI: begin
                    pc <= {bus_data_i, low_byte};
                    state <= FETCH;
                end
                FETCH: begin
                    opcode <= bus_data_i;
                    case (bus_data_i)
                        8'hea: begin // NOP
                            pc <= pc + 16'd1;
                        end
                        8'ha9, 8'ha2, 8'ha0: begin // LDA/LDX/LDY #imm
                            pc <= pc + 16'd1;
                            state <= IMM;
                        end
                        8'h8d, 8'h4c, 8'had, 8'hae, 8'hac, 8'h2c: begin
                            pc <= pc + 16'd1;
                            state <= ABS_LO;
                        end
                        8'ha5, 8'ha6, 8'ha4, 8'h24: begin
                            pc <= pc + 16'd1;
                            state <= ZP;
                        end
                        8'h10, 8'h30, 8'h50, 8'h70,
                        8'h90, 8'hb0, 8'hd0, 8'hf0: begin
                            pc <= pc + 16'd1;
                            state <= REL;
                        end
                        8'h18, 8'h38, 8'h58, 8'h78, 8'hb8,
                        8'hd8, 8'hf8: begin
                            pc <= pc + 16'd1;
                            case (bus_data_i)
                                8'h18: p[0] <= 1'b0;
                                8'h38: p[0] <= 1'b1;
                                8'h58: p[2] <= 1'b0;
                                8'h78: p[2] <= 1'b1;
                                8'hb8: p[6] <= 1'b0;
                                8'hd8: p[3] <= 1'b0;
                                8'hf8: p[3] <= 1'b1;
                                default: begin end
                            endcase
                        end
                        default: state <= FAULT;
                    endcase
                end
                IMM, READ: begin
                    case (opcode)
                        8'ha9, 8'ha5, 8'had: a <= bus_data_i;
                        8'ha2, 8'ha6, 8'hae: x <= bus_data_i;
                        8'ha0, 8'ha4, 8'hac: y <= bus_data_i;
                        8'h24, 8'h2c: p[6] <= bus_data_i[6];
                        default: state <= FAULT;
                    endcase
                    p[1] <= (opcode == 8'h24 || opcode == 8'h2c)
                            ? ((a & bus_data_i) == 8'h00)
                            : (bus_data_i == 8'h00);
                    p[7] <= bus_data_i[7];         // N
                    if (state == IMM) pc <= pc + 16'd1;
                    state <= FETCH;
                end
                ABS_LO: begin
                    low_byte <= bus_data_i;
                    pc <= pc + 16'd1;
                    state <= ABS_HI;
                end
                ABS_HI: begin
                    if (opcode == 8'h4c) begin
                        pc <= {bus_data_i, low_byte};
                        state <= FETCH;
                    end else begin
                        target <= {bus_data_i, low_byte};
                        pc <= pc + 16'd1;
                        state <= (opcode == 8'h8d) ? WRITE : READ;
                    end
                end
                ZP: begin
                    target <= {8'h00, bus_data_i};
                    pc <= pc + 16'd1;
                    state <= READ;
                end
                REL: begin
                    pc <= pc + 16'd1 + (branch_taken
                        ? {{8{bus_data_i[7]}}, bus_data_i} : 16'd0);
                    state <= FETCH;
                end
                WRITE: state <= FETCH;
                FAULT: state <= FAULT;
                default: state <= FAULT;
            endcase
        end
    end
endmodule
