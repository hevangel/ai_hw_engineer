// Intel 80386 instruction-format decoder.
//
// Purely combinational: parses prefixes, the one- or two-byte opcode, the
// ModR/M and SIB bytes, displacement and immediates from a 16-byte window
// that starts at CS:EIP. Formats follow Intel 386 DX Programmer's Reference
// Manual 230985-001, chapter 17.2 (instruction format) and appendix A
// (opcode map). The decoder does not read registers; it reports which
// registers form the effective address so the core can evaluate it with
// the values current at execution time.
module intel_80386_decode (
    input  logic [127:0] window_i,     // byte k at bits [8k+7:8k]
    input  logic         code32_i,     // CS default operand/address size (D bit)
    output logic [3:0]   prefix_len_o,
    output logic         seg_override_o,
    output logic [2:0]   seg_o,        // ES CS SS DS FS GS = 0..5
    output logic         opsize32_o,
    output logic         addrsize32_o,
    output logic         lock_o,
    output logic [1:0]   rep_o,        // 0 none, 2 REPNE (F2), 3 REP/REPE (F3)
    output logic         two_byte_o,
    output logic [7:0]   opcode_o,
    output logic         has_modrm_o,
    output logic [1:0]   mod_o,
    output logic [2:0]   reg_o,
    output logic [2:0]   rm_o,
    output logic         base_valid_o,
    output logic [2:0]   base_o,
    output logic         index_valid_o,
    output logic [2:0]   index_o,
    output logic [1:0]   scale_o,
    output logic [31:0]  disp_o,
    output logic         default_ss_o,
    output logic [31:0]  imm1_o,
    output logic [15:0]  imm2_o,
    output logic [4:0]   length_o,     // total instruction length in bytes
    output logic         too_long_o    // prefixes leave no room for an opcode
);
  logic [7:0] b [0:15];
  integer wk;
  always_comb for (wk = 0; wk < 16; wk = wk + 1) b[wk] = window_i[8*wk +: 8];

  function automatic logic modrm_table(input logic tb, input logic [7:0] op);
    logic r;
    if (!tb) begin
      casez (op)
        8'b00???0??: r = (op[2:0] < 3'd4);
        8'b0110001?: r = 1'b1;              // 62 BOUND, 63 ARPL
        8'h69, 8'h6B: r = 1'b1;
        8'b1000????: r = 1'b1;              // 80-8F
        8'hC0, 8'hC1: r = 1'b1;
        8'b110001??: r = 1'b1;              // C4-C7
        8'b110100??: r = 1'b1;              // D0-D3
        8'b11011???: r = 1'b1;              // D8-DF ESC
        8'hF6, 8'hF7, 8'hFE, 8'hFF: r = 1'b1;
        default: r = 1'b0;
      endcase
    end else begin
      casez (op)
        8'b000000??: r = 1'b1;              // 0F00-0F03
        8'b001000??: r = 1'b1;              // 0F20-0F23
        8'b001001?0: r = 1'b1;              // 0F24, 0F26 MOV TR
        8'b1001????: r = 1'b1;              // SETcc
        8'hA3, 8'hA4, 8'hA5, 8'hAB, 8'hAC, 8'hAD, 8'hAF: r = 1'b1;
        8'b1011001?, 8'b101101??: r = 1'b1; // B2-B7
        8'hBA, 8'hBB: r = 1'b1;
        8'b101111??: r = 1'b1;              // BC-BF
        default: r = 1'b0;
      endcase
    end
    modrm_table = r;
  endfunction

  // Immediate sizes: {second field bytes (0/1/2), first field bytes (0..4)}.
  /* verilator lint_off UNUSEDSIGNAL */
  function automatic logic [5:0] imm_table(input logic tb, input logic [7:0] op,
                                           input logic [2:0] reg_field,
                                           input logic o32, input logic a32);
    logic [2:0] first, second, osz, asz;
    osz = o32 ? 3'd4 : 3'd2;
    asz = a32 ? 3'd4 : 3'd2;
    first = 3'd0;
    second = 3'd0;
    if (!tb) begin
      casez (op)
        8'b00???100, 8'hA8, 8'b10110???, 8'h6A, 8'b0111????, 8'b111000??,
        8'hEB, 8'hCD, 8'b111001??, 8'hD4, 8'hD5, 8'hC0, 8'hC1, 8'h80,
        8'h82, 8'h83, 8'h6B, 8'hC6: first = 3'd1;
        8'b00???101, 8'hA9, 8'b10111???, 8'h68, 8'h69, 8'h81, 8'hC7,
        8'hE8, 8'hE9: first = osz;
        8'hF6: first = (reg_field[2:1] == 2'b00) ? 3'd1 : 3'd0;
        8'hF7: first = (reg_field[2:1] == 2'b00) ? osz : 3'd0;
        8'hC2, 8'hCA: first = 3'd2;
        8'hC8: begin first = 3'd2; second = 3'd1; end
        8'h9A, 8'hEA: begin first = osz; second = 3'd2; end
        8'b101000??: first = asz;
        default: first = 3'd0;
      endcase
    end else begin
      casez (op)
        8'b1000????: first = osz;
        8'hA4, 8'hAC, 8'hBA: first = 3'd1;
        default: first = 3'd0;
      endcase
    end
    imm_table = {second, first};
  endfunction
  /* verilator lint_on UNUSEDSIGNAL */

  function automatic logic [31:0] bytes_le(input logic [4:0] at, input logic [2:0] count);
    logic [31:0] v;
    integer k;
    v = 32'b0;
    for (k = 0; k < 4; k = k + 1)
      if (k < count && ({27'b0, at} + k) < 16) v[8*k +: 8] = b[{27'b0, at} + k];
    bytes_le = v;
  endfunction

  logic stop, o32, a32;
  logic [4:0] pos, ea_len, imm_at;
  logic [5:0] imms;
  logic [7:0] modrm, sib, op;
  logic [2:0] disp_size;
  logic [5:0] total;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] imm2_full;   // the second immediate field is at most 16 bits
  /* verilator lint_on UNUSEDSIGNAL */
  integer pk;

  always_comb begin

    prefix_len_o = 4'd0;
    seg_override_o = 1'b0;
    seg_o = 3'd3;
    o32 = code32_i;
    a32 = code32_i;
    lock_o = 1'b0;
    rep_o = 2'd0;
    stop = 1'b0;
    pos = 5'd0;
    for (pk = 0; pk < 15; pk = pk + 1) begin
      if (!stop) begin
        case (b[pk])
          8'h26: begin seg_override_o = 1'b1; seg_o = 3'd0; end
          8'h2E: begin seg_override_o = 1'b1; seg_o = 3'd1; end
          8'h36: begin seg_override_o = 1'b1; seg_o = 3'd2; end
          8'h3E: begin seg_override_o = 1'b1; seg_o = 3'd3; end
          8'h64: begin seg_override_o = 1'b1; seg_o = 3'd4; end
          8'h65: begin seg_override_o = 1'b1; seg_o = 3'd5; end
          8'h66: o32 = !code32_i;
          8'h67: a32 = !code32_i;
          8'hF0: lock_o = 1'b1;
          8'hF2: rep_o = 2'd2;
          8'hF3: rep_o = 2'd3;
          default: stop = 1'b1;
        endcase
        if (!stop) pos = pos + 5'd1;
      end
    end
    too_long_o = !stop;
    prefix_len_o = pos[3:0];
    opsize32_o = o32;
    addrsize32_o = a32;

    two_byte_o = (b[pos[3:0]] == 8'h0F);
    op = two_byte_o ? b[pos[3:0] + 4'd1] : b[pos[3:0]];
    opcode_o = op;
    pos = pos + (two_byte_o ? 5'd2 : 5'd1);

    has_modrm_o = modrm_table(two_byte_o, op);
    modrm = (pos < 5'd16) ? b[pos[3:0]] : 8'h00;
    sib = (pos < 5'd15) ? b[pos[3:0] + 4'd1] : 8'h00;
    mod_o = has_modrm_o ? modrm[7:6] : 2'b11;
    reg_o = modrm[5:3];
    rm_o = modrm[2:0];

    base_valid_o = 1'b0;
    base_o = 3'd0;
    index_valid_o = 1'b0;
    index_o = 3'd0;
    scale_o = 2'd0;
    default_ss_o = 1'b0;
    disp_size = 3'd0;
    ea_len = 5'd0;
    if (has_modrm_o) begin
      ea_len = 5'd1;
      if (mod_o != 2'b11) begin
        if (!a32) begin
          case (rm_o)
            3'd0: begin base_valid_o = 1; base_o = 3'd3; index_valid_o = 1; index_o = 3'd6; end
            3'd1: begin base_valid_o = 1; base_o = 3'd3; index_valid_o = 1; index_o = 3'd7; end
            3'd2: begin base_valid_o = 1; base_o = 3'd5; index_valid_o = 1; index_o = 3'd6; default_ss_o = 1; end
            3'd3: begin base_valid_o = 1; base_o = 3'd5; index_valid_o = 1; index_o = 3'd7; default_ss_o = 1; end
            3'd4: begin base_valid_o = 1; base_o = 3'd6; end
            3'd5: begin base_valid_o = 1; base_o = 3'd7; end
            3'd6: begin
              if (mod_o != 2'b00) begin base_valid_o = 1; base_o = 3'd5; default_ss_o = 1; end
            end
            default: begin base_valid_o = 1; base_o = 3'd3; end
          endcase
          disp_size = (mod_o == 2'b01) ? 3'd1 :
                      (mod_o == 2'b10 || (mod_o == 2'b00 && rm_o == 3'd6)) ? 3'd2 : 3'd0;
        end else begin
          if (rm_o == 3'd4) begin
            ea_len = 5'd2;
            scale_o = sib[7:6];
            index_o = sib[5:3];
            index_valid_o = (sib[5:3] != 3'd4);
            base_o = sib[2:0];
            base_valid_o = !(sib[2:0] == 3'd5 && mod_o == 2'b00);
            default_ss_o = base_valid_o && (sib[2:0] == 3'd4 || sib[2:0] == 3'd5);
            disp_size = (mod_o == 2'b01) ? 3'd1 :
                        (mod_o == 2'b10 || !base_valid_o) ? 3'd4 : 3'd0;
          end else begin
            base_o = rm_o;
            base_valid_o = !(rm_o == 3'd5 && mod_o == 2'b00);
            default_ss_o = base_valid_o && rm_o == 3'd5;
            disp_size = (mod_o == 2'b01) ? 3'd1 :
                        (mod_o == 2'b10 || !base_valid_o) ? 3'd4 : 3'd0;
          end
        end
      end
    end
    disp_o = bytes_le(pos + ea_len, disp_size);
    if (disp_size == 3'd1) disp_o = {{24{disp_o[7]}}, disp_o[7:0]};
    else if (disp_size == 3'd2) disp_o = {{16{disp_o[15]}}, disp_o[15:0]};

    imms = imm_table(two_byte_o, op, reg_o, o32, a32);
    imm_at = pos + ea_len + {2'b0, disp_size};
    imm1_o = bytes_le(imm_at, imms[2:0]);
    imm2_full = bytes_le(imm_at + {2'b0, imms[2:0]}, imms[5:3]);
    imm2_o = imm2_full[15:0];
    total = {1'b0, imm_at} + {3'b0, imms[2:0]} + {3'b0, imms[5:3]};
    length_o = (total > 6'd31) ? 5'd31 : total[4:0];
  end
endmodule
