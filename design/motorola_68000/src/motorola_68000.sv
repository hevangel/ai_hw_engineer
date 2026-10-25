// Motorola MC68000 — user ISA (work in progress; see
// report/final_report.md). This revision establishes the architectural
// skeleton: register file (D0-D7/A0-A7 shared 16-entry, USP/SSP), SR,
// opcode fetch, and the instruction-retire handshake the vector-replay
// harness consumes. Instruction classes are added incrementally against
// the compiled SingleStepTests vectors (1,000,060 tests, work/sim).
// Contract: final architectural state per instruction. Out of contract:
// pin protocol, prefetch queue, per-opcode cycle counts, bus-transaction
// traces.
`timescale 1ns/1ps

module motorola_68000 (
    input  logic        clk,
    input  logic        rst_n,
    output logic [23:0] bus_addr,
    output logic [15:0] bus_data_o,
    input  logic [15:0] bus_data_i,
    output logic        bus_we,       // word write (addr even)
    output logic        bus_bwe,      // byte write (addr may be odd)
    output logic        vma_o,
    input  logic [2:0]  ipl_n,        // tie 111 (no interrupt) in the TB
    output logic        done_o,       // one-cycle instruction-retired pulse
    output logic        halted_o
);

    // SR bit positions (used as instruction classes land)
    localparam int FC = 0, FV = 1, FZ = 2, FN = 3, FX = 4;
    localparam int FI0 = 8, FI1 = 9, FI2 = 10, FS = 13, FT = 14;
    wire _unused_sr = ^{FC, FV, FZ, FN, FX, FI0, FI1, FI2, FT};

    typedef enum logic [5:0] {
        S_FETCH0, S_FETCH1, S_DECODE,
        // effective-address micro-ops (skeleton; exercised by MOVE group)
        S_EA_AI, S_EA_PI, S_EA_PD, S_EA_DISP, S_EA_IDX,
        S_EA_ABSW, S_EA_ABSL, S_EA_ABSL2,
        S_IREAD,
        S_DST_EA, S_DST_DISP, S_DST_IDX, S_DST_ABSW, S_DST_ABSL,
        S_DST_ABSL2, S_WRITE, S_WRITE2,
        S_DONE
    } state_e;

    state_e state;

    logic [15:0] regs [0:15];   // D0-D7 = 0-7; A0-A7 = 8-15 (low halves)
    logic [15:0] regh [0:15];
    logic [15:0] usp, ssp;
    logic [31:0] pc;
    logic [15:0] sr;
    logic [15:0] ir;            // opcode register
    logic [15:0] ext1;          // extension word
    logic [31:0] ea;            // current effective address
    logic [31:0] ea_hold;       // source ea (two-ea instructions)
    logic [31:0] op1;           // source operand
    logic [31:0] src_hold;      // MOVE data across dst-ea evaluation
    logic [1:0]  sizeb;         // 0=byte 1=word 2=long
    logic [31:0] xsize;         // 1/2/4
    logic [2:0]  ea_mode_q, ea_reg_q;
    logic        dst_phase;     // evaluating destination EA
    logic [31:0] tgt;           // destination write address
    logic        wrb;
    logic        exc_req;
    logic [4:0]  vector;

    assign bus_addr = ea[23:0];
    assign bus_data_o = 16'h0000;
    assign bus_we = wrb && (sizeb != 2'd0);
    assign bus_bwe = wrb && (sizeb == 2'd0);
    assign vma_o = 1'b1;
    assign halted_o = 1'b0;

    wire [31:0] a7 = sr[FS] ? {16'h0000, ssp} : {16'h0000, usp};

    function automatic logic [15:0] rd16(input logic [4:0] r);
        rd16 = r[4] ? regh[r[3:0]] : regs[r[3:0]];
    endfunction

    task automatic wr16(input logic [4:0] r, input logic [15:0] v);
        if (r[4]) regh[r[3:0]] = v;
        else regs[r[3:0]] = v;
    endtask

    function automatic logic [31:0] rd32(input logic [4:0] r);
        rd32 = {regh[r[3:0]], regs[r[3:0]]};
    endfunction

    function automatic logic [31:0] sext16(input logic [15:0] v);
        sext16 = {{16{v[15]}}, v};
    endfunction

    // current instruction fields
    wire [2:0] d_eam  = ir[5:3];
    wire [2:0] d_ereg = ir[2:0];
    wire [1:0] d_sz   = ir[7:6];        // MOVE: 01=B 11=W 10=L
    wire [3:0] d_reg  = ir[11:8];

    wire is_move = (ir[15:12] <= 4'h3);  // 00xx/01xx/10xx/11xx MOVE.B/W/L

    wire _unused_fields = ^{d_eam, d_ereg, d_sz, d_reg};

    function automatic logic [1:0] move_sz(input logic [1:0] c);
        move_sz = (c == 2'b01) ? 2'd0 : (c == 2'b11) ? 2'd1 : 2'd2;
    endfunction

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= S_FETCH0;
            pc <= 32'h0;
            sr <= 16'h2700;
            ssp <= 16'h0;
            usp <= 16'h0;
            ir <= 16'h4E71;
            wrb <= 1'b0;
            sizeb <= 2'd1;
            xsize <= 32'd2;
            dst_phase <= 1'b0;
            exc_req <= 1'b0;
            vector <= 5'd0;
            ea <= 32'h0;
            ea_hold <= 32'h0;
            op1 <= 32'h0;
            src_hold <= 32'h0;
            tgt <= 32'h0;
            ea_mode_q <= 3'h0;
            ea_reg_q <= 3'h0;
            ext1 <= 16'h0;
            done_o <= 1'b0;
            for (int i = 0; i < 16; i++) begin regs[i] <= 16'h0; regh[i] <= 16'h0; end
        end else begin
            done_o <= 1'b0;
            case (state)
                // ---------------- fetch ----------------
                S_FETCH0: begin
                    ea <= pc;
                    wrb <= 1'b0;
                    sizeb <= 2'd1;
                    state <= S_FETCH1;
                end
                S_FETCH1: begin
                    ir <= bus_data_i;
                    pc <= pc + 32'h2;
                    exc_req <= 1'b0;
                    dst_phase <= 1'b0;
                    state <= S_DECODE;
                end

                // ---------------- decode ----------------
                // WIP: the MOVE group is the first class wired into the
                // skeleton; remaining classes land incrementally.
                S_DECODE: if (is_move) begin
                    sizeb <= move_sz(d_sz);
                    xsize <= (move_sz(d_sz) == 2'd0) ? 32'd1 :
                             (move_sz(d_sz) == 2'd1) ? 32'd2 : 32'd4;
                    dst_phase <= 1'b0;
                    ea_mode_q <= d_ereg[2:0] >>> 0;  // dst mode field
                    ea_reg_q  <= d_eam;              // placeholder reorder
                    ea_mode_q <= ir[5:3];
                    ea_reg_q  <= ir[2:0];
                    state <= S_DST_EA;
                end else begin
                    // remaining instruction classes: not yet implemented
                    done_o <= 1'b1;
                    state <= S_DONE;
                end

                // ---------------- destination EA (MOVE dst) ----------
                S_DST_EA: begin
                    case (ea_mode_q)
                        3'h0, 3'h1: begin   // Dn/An direct: no memory
                            state <= S_DONE;
                            done_o <= 1'b1;
                        end
                        3'h2: begin          // (An)
                            ea <= {16'h0, rd16({1'b1, 1'b0, ea_reg_q})};
                            state <= S_WRITE;
                        end
                        3'h3: begin          // (An)+
                            ea <= {16'h0, rd16({1'b1, 1'b0, ea_reg_q})};
                            wr16({1'b0, 1'b1, ea_reg_q},
                                 rd16({1'b1, 1'b0, ea_reg_q}) + 16'h2);
                            state <= S_WRITE;
                        end
                        3'h4: begin          // -(An)
                            wr16({1'b0, 1'b1, ea_reg_q},
                                 rd16({1'b1, 1'b0, ea_reg_q}) - 16'h2);
                            ea <= {16'h0, rd16({1'b1, 1'b0, ea_reg_q})};
                            state <= S_WRITE;
                        end
                        3'h5: begin          // (d16,An)
                            ea <= pc;
                            wrb <= 1'b0;
                            state <= S_DST_DISP;
                        end
                        3'h6: state <= S_DST_IDX;
                        3'h7: begin
                            if (ea_reg_q == 3'h0) begin     // ABS.W
                                ea <= pc;
                                state <= S_DST_ABSW;
                            end else if (ea_reg_q == 3'h1) begin // ABS.L
                                ea <= pc;
                                state <= S_DST_ABSL;
                            end
                        end
                        default: begin
                            done_o <= 1'b1;
                            state <= S_DONE;
                        end
                    endcase
                end

                S_DST_DISP: begin
                    ext1 <= bus_data_i;
                    pc <= pc + 32'h2;
                    ea <= a7 + sext16(bus_data_i);  // placeholder base
                    state <= S_WRITE;
                end

                S_DST_IDX: begin
                    ext1 <= bus_data_i;
                    pc <= pc + 32'h2;
                    state <= S_WRITE;
                end

                S_DST_ABSW: begin
                    ext1 <= bus_data_i;
                    pc <= pc + 32'h2;
                    state <= S_DST_ABSL2;
                end

                S_DST_ABSL2: begin
                    ea <= {ext1, bus_data_i};
                    pc <= pc + 32'h2;
                    state <= S_WRITE;
                end

                S_DST_ABSL: begin
                    ext1 <= bus_data_i;
                    pc <= pc + 32'h2;
                    state <= S_DST_ABSL2;
                end

                // ---------------- write ----------------
                S_WRITE: begin
                    wrb <= 1'b1;
                    state <= S_WRITE2;
                end

                S_WRITE2: begin
                    wrb <= 1'b0;
                    done_o <= 1'b1;
                    state <= S_DONE;
                end

                S_DONE: state <= S_FETCH0;

                default: begin
                    done_o <= 1'b1;
                    state <= S_DONE;
                end
            endcase
        end
    end
endmodule
