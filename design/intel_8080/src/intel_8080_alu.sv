`timescale 1ns/1ps
// Operation codes 0..7 follow the instruction ALU field; 8..15 are local.
module intel_8080_alu (
    input logic [3:0] kind_i,
    input logic [7:0] lhs_i, rhs_i, flags_i,
    output logic [7:0] value_o, flags_o
);
  logic [8:0] sum;
  logic [7:0] result, correction;
  logic update_szp;
  logic unused_reserved;
  assign unused_reserved = flags_i[5] ^ flags_i[3] ^ flags_i[1];
  always_comb begin
    sum = 0;
    result = lhs_i;
    correction = 0;
    update_szp = 0;
    // ASSUMPTION: PSW reserved bits, pinned external i8080_push_psw; spec ledger.
    flags_o = {flags_i[7:6],1'b0,flags_i[4],1'b0,flags_i[2],1'b1,flags_i[0]};
    case (kind_i)
      4'd0, 4'd1: begin // ADD, ADC
        sum = {1'b0,lhs_i} + {1'b0,rhs_i} + 9'(kind_i == 1 && flags_i[0]);
        result = sum[7:0];
        flags_o[0] = sum[8];
        flags_o[4] = lhs_i[4] ^ rhs_i[4] ^ result[4];
        update_szp = 1;
      end
      4'd2, 4'd3, 4'd7: begin // SUB, SBB, CMP
        sum = {1'b0,lhs_i} + {1'b0,~rhs_i} + 9'(kind_i != 3 || !flags_i[0]);
        result = sum[7:0];
        flags_o[0] = !sum[8];
        // ASSUMPTION: complemented-operand AC, external sub/cmp; spec ledger.
        flags_o[4] = !(lhs_i[4] ^ rhs_i[4] ^ result[4]);
        update_szp = 1;
      end
      4'd4: begin // Intel 8080/8085 programming manual 1-12: original operand bits.
        result = lhs_i & rhs_i;
        flags_o[0] = 0;
        flags_o[4] = lhs_i[3] | rhs_i[3];
        update_szp = 1;
      end
      4'd5, 4'd6: begin
        result = kind_i == 5 ? lhs_i ^ rhs_i : lhs_i | rhs_i;
        flags_o[0] = 0;
        flags_o[4] = 0;
        update_szp = 1;
      end
      4'd8: begin // INR, preserving CY
        result = lhs_i + 8'd1;
        flags_o[4] = &lhs_i[3:0];
        update_szp = 1;
      end
      4'd9: begin // DCR, preserving CY
        result = lhs_i - 8'd1;
        // ASSUMPTION: DCR AC inverse nibble borrow, external dcr; spec ledger.
        flags_o[4] = |lhs_i[3:0];
        update_szp = 1;
      end
      4'd10: begin // DAA, sequential decimal correction including low carry.
        if (flags_i[4] || lhs_i[3:0] > 9) correction = 8'h06;
        if (flags_i[0] || lhs_i > 8'h99) correction = correction | 8'h60;
        sum = {1'b0,lhs_i} + {1'b0,correction};
        result = sum[7:0];
        flags_o[0] = flags_i[0] || lhs_i > 8'h99;
        flags_o[4] = lhs_i[4] ^ correction[4] ^ result[4];
        update_szp = 1;
      end
      4'd11: begin result = {lhs_i[6:0],lhs_i[7]}; flags_o[0] = lhs_i[7]; end
      4'd12: begin result = {lhs_i[0],lhs_i[7:1]}; flags_o[0] = lhs_i[0]; end
      4'd13: begin result = {lhs_i[6:0],flags_i[0]}; flags_o[0] = lhs_i[7]; end
      4'd14: begin result = {flags_i[0],lhs_i[7:1]}; flags_o[0] = lhs_i[0]; end
      4'd15: result = ~lhs_i; // CMA preserves all five status flags.
      default: ;
    endcase
    if (update_szp) begin
      flags_o[7] = result[7];
      flags_o[6] = result == 0;
      flags_o[2] = ~^result;
    end
    value_o = kind_i == 7 ? lhs_i : result; // CMP leaves A unchanged.
  end
endmodule
