`include "zilog_z80_defs.svh"

// Zilog Z80 byte ALU.
//
// Combinational; computes the result and the full flag byte including the two
// undocumented bits F5/F3. Flag rules follow the manufacturer manual for the
// documented bits and the z80.info flag-affection table plus the exerciser
// definition for F5/F3: the undocumented bits are copies of bits 5 and 3 of
// whatever byte the instruction's flag source is (normally the result, for
// BIT the tested byte, for indexed BIT the address high byte, which the
// caller supplies in b).
//
// Operations that preserve flags a caller must not clobber (INC/DEC preserve C,
// CPL preserves C and P/V, DAA consumes H/N/C) read them from f_in; the caller
// merges the returned byte with the preserved bits it needs.
module zilog_z80_alu
(
    input  alu_op_t    op,
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic       cin,
    input  logic [7:0] f_in,
    input  logic [2:0] bitnum,
    output logic [7:0] y,
    output logic [7:0] flags
);

  logic [8:0] wide;
  logic [4:0] nib;
  logic [7:0] res;
  logic [7:0] corr;
  logic       fc, fh, fv, fn, fz, fs, f5, f3;

  // Even-parity of the byte: P/V is set when the number of one bits is even.
  function automatic logic parity8(input logic [7:0] v);
    parity8 = ~(^v);
  endfunction

  always_comb begin
    // Every temporary gets a default so no path infers a latch.
    wide = 9'h000;
    nib  = 5'h00;
    corr = 8'h00;
    res  = a;
    fc   = f_in[FLAG_C];
    fh   = 1'b0;
    fv   = parity8(a);
    fn   = f_in[FLAG_N];
    fz   = (a == 8'h00);
    fs   = a[7];
    f5   = a[5];
    f3   = a[3];
    y    = a;

    case (op)
      ALU_ADD, ALU_ADC, ALU_SUB, ALU_SBC, ALU_CP: begin
        if (op == ALU_ADD || op == ALU_ADC) begin
          wide = {1'b0, a} + {1'b0, b} + cin;   // 9-bit: carry out
          res  = wide[7:0];
          fc   = wide[8];
          nib  = {1'b0, a[3:0]} + {1'b0, b[3:0]} + cin;
          fh   = nib[4];
          fv   = (a[7] == b[7]) && (res[7] != a[7]);
          fn   = 1'b0;
        end else begin
          wide = {1'b0, a} - {1'b0, b} - cin;   // 9-bit: borrow out
          res  = wide[7:0];
          fc   = wide[8];
          nib  = {1'b0, a[3:0]} - {1'b0, b[3:0]} - cin;
          fh   = nib[4];
          fv   = (a[7] != b[7]) && (res[7] != a[7]);
          fn   = 1'b1;
        end
        fz = (res == 8'h00);
        fs = res[7];
        // CP leaves the accumulator alone and copies F5/F3 from the operand.
        f5 = (op == ALU_CP) ? b[5] : res[5];
        f3 = (op == ALU_CP) ? b[3] : res[3];
        y  = (op == ALU_CP) ? a : res;
      end

      ALU_AND: begin
        res = a & b;
        fh  = 1'b1;
        fc  = 1'b0;
        fn  = 1'b0;
        fv  = parity8(res);
        fz  = (res == 8'h00);
        fs  = res[7];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_OR: begin
        res = a | b;
        fh  = 1'b0;
        fc  = 1'b0;
        fn  = 1'b0;
        fv  = parity8(res);
        fz  = (res == 8'h00);
        fs  = res[7];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_XOR: begin
        res = a ^ b;
        fh  = 1'b0;
        fc  = 1'b0;
        fn  = 1'b0;
        fv  = parity8(res);
        fz  = (res == 8'h00);
        fs  = res[7];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_INC: begin
        res = a + 8'h01;
        fc  = f_in[FLAG_C];          // preserved
        fh  = (a[3:0] == 4'hF);
        fv  = (a == 8'h7F);
        fn  = 1'b0;
        fz  = (res == 8'h00);
        fs  = res[7];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_DEC: begin
        res = a - 8'h01;
        fc  = f_in[FLAG_C];          // preserved
        fh  = (a[3:0] == 4'h0);
        fv  = (a == 8'h80);
        fn  = 1'b1;
        fz  = (res == 8'h00);
        fs  = res[7];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_RLC: begin
        res = {a[6:0], a[7]};
        fc  = a[7];
        fn  = 1'b0;
        fv  = parity8({a[6:0], a[7]});
        fz  = (res == 8'h00);
        fs  = res[7];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_RRC: begin
        res = {a[0], a[7:1]};
        fc  = a[0];
        fn  = 1'b0;
        fv  = parity8({a[0], a[7:1]});
        fz  = (res == 8'h00);
        fs  = res[7];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_RL: begin
        res = {a[6:0], cin};
        fc  = a[7];
        fn  = 1'b0;
        fv  = parity8({a[6:0], cin});
        fz  = (res == 8'h00);
        fs  = res[7];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_RR: begin
        res = {cin, a[7:1]};
        fc  = a[0];
        fn  = 1'b0;
        fv  = parity8({cin, a[7:1]});
        fz  = (res == 8'h00);
        fs  = res[7];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_SLA: begin
        res = {a[6:0], 1'b0};
        fc  = a[7];
        fn  = 1'b0;
        fv  = parity8({a[6:0], 1'b0});
        fz  = (res == 8'h00);
        fs  = res[7];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_SRA: begin
        res = {a[7], a[7:1]};
        fc  = a[0];
        fn  = 1'b0;
        fv  = parity8({a[7], a[7:1]});
        fz  = (res == 8'h00);
        fs  = res[7];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_SLL: begin
        // Undocumented shift-left-with-one (CB 30-37 in the published list).
        res = {a[6:0], 1'b1};
        fc  = a[7];
        fn  = 1'b0;
        fv  = parity8({a[6:0], 1'b1});
        fz  = (res == 8'h00);
        fs  = res[7];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_SRL: begin
        res = {1'b0, a[7:1]};
        fc  = a[0];
        fn  = 1'b0;
        fv  = parity8({1'b0, a[7:1]});
        fz  = (res == 8'h00);
        fs  = res[7];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_DAA: begin
        // Documented BCD correction: the low-nibble test decides the 0x06
        // correction, the high-nibble test decides 0x60 and forces C, and N
        // decides whether the correction is added or subtracted. H falls out
        // of the correction that was actually applied.
        fc = f_in[FLAG_C];
        if ((a[3:0] > 4'h9) || f_in[FLAG_H]) begin
          corr = corr + 8'h06;
        end
        if ((a > 8'h99) || f_in[FLAG_C]) begin
          corr = corr + 8'h60;
          fc   = 1'b1;
        end
        if (f_in[FLAG_N]) begin
          fh  = f_in[FLAG_H] && (a[3:0] < 4'h6);
          res = a - corr;
        end else begin
          fh  = (a[3:0] > 4'h9);
          res = a + corr;
        end
        fn = f_in[FLAG_N];
        fv = parity8(res);
        fz = (res == 8'h00);
        fs = res[7];
        f5 = res[5];
        f3 = res[3];
        y  = res;
      end

      ALU_CPL: begin
        res = ~a;
        fh  = 1'b1;
        fn  = 1'b1;
        // CPL preserves S, Z, P/V and C; only H and N are set.
        fc  = f_in[FLAG_C];
        fv  = f_in[FLAG_PV];
        fz  = f_in[FLAG_Z];
        fs  = f_in[FLAG_S];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_NEG: begin
        res = 8'h00 - a;
        fc  = (a != 8'h00);
        fh  = (a[3:0] != 4'h0);
        fv  = (a == 8'h80);
        fn  = 1'b1;
        fz  = (res == 8'h00);
        fs  = res[7];
        f5  = res[5];
        f3  = res[3];
        y   = res;
      end

      ALU_BIT: begin
        fh = 1'b1;
        fn = 1'b0;
        fz = ~a[bitnum];
        fs = (bitnum == 3'd7) ? a[7] : 1'b0;
        fv = ~a[bitnum];             // P/V mirrors Z for BIT
        fc = f_in[FLAG_C];           // preserved
        f5 = b[5];                   // caller supplies the flag source byte
        f3 = b[3];                   // (operand for r, WZ high for (HL))
        y  = a;
      end

      default: begin
        y = a;
      end
    endcase

    flags = {fs, fz, f5, fh, f3, fv, fn, fc};
  end

endmodule
