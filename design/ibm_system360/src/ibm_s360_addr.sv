// IBM System/360 storage-address generation.
//
// A22-6821-7 "Address Generation", pp. 13-14:
//   - the base address (general register named by B) and the index (general
//     register named by X) are treated as unsigned 24-bit integers;
//   - the displacement is an unsigned 12-bit integer;
//   - the three are added as 24-bit binary numbers, ignoring overflow;
//   - a zero B or X field means the corresponding component is absent, even
//     when general register 0 holds a nonzero value.
// Only the low-order 24 bits of a general register participate; the top eight
// bits are ignored here and are zeroed when an address is loaded into a
// register by LOAD ADDRESS (p. 65).

`timescale 1ns/1ps

`ifndef IBM_S360_ADDR_SV
`define IBM_S360_ADDR_SV

// The high-order eight bits of the base and index inputs are intentionally not
// part of the address.
/* verilator lint_off UNUSEDSIGNAL */
module ibm_s360_addr (
    input  logic [3:0]  b_field,
    input  logic [3:0]  x_field,
    input  logic [31:0] b_val,
    input  logic [31:0] x_val,
    input  logic [11:0] disp,
    output logic [23:0] addr
);

  logic [23:0] base_term;
  logic [23:0] index_term;

  // Only the low-order 24 bits of a general register are part of the address;
  // the top eight bits are ignored by design (A22-6821-7 p. 13).
  assign base_term  = (b_field == 4'd0) ? 24'd0 : b_val[23:0];
  assign index_term = (x_field == 4'd0) ? 24'd0 : x_val[23:0];

  // 24-bit addition: any carry beyond bit 23 is discarded.
  assign addr = base_term + index_term + {12'd0, disp};

`ifdef FORMAL
  // A zero field contributes nothing, whatever the register holds.
  always_comb begin
    if (b_field == 4'd0) begin
      assert (addr == (index_term + {12'd0, disp}));
    end
    if (x_field == 4'd0) begin
      assert (addr == (base_term + {12'd0, disp}));
    end
    if ((b_field == 4'd0) && (x_field == 4'd0)) begin
      assert (addr == {12'd0, disp});
    end
  end
`endif

endmodule

/* verilator lint_on UNUSEDSIGNAL */

`endif
