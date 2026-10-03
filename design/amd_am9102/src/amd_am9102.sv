`timescale 1ns/1ps
// AMD 1974 Data Book 5-61..5-66: asynchronous 1024x1 retained-power RAM.
module amd_am9102 (
    input  logic [9:0] a_i,
    input  logic cs_n_i, we_n_i, din_i,
    input  logic standby_i, // supply-mode metadata, not a physical signal pin
    output logic dout_o, dout_oe_o, output_valid_o
);
  logic [31:0] column_data;
  // A 32x32 cell array, as in the manufacturer's block diagram (5-61).
  // Banking avoids both quadratic latch lowering and 1024 event processes.
  for (genvar column = 0; column < 32; column++) begin : columns
    logic mem [0:31]; // No reset or specified power-up contents.
    always_latch begin
      if (!standby_i && !cs_n_i && !we_n_i && a_i[9:5] == 5'(column))
        mem[a_i[4:0]] = din_i;
    end
    assign column_data[column] = mem[a_i[4:0]];
  end
  always_comb begin
    output_valid_o = !standby_i || cs_n_i;
    // Selected standby is unspecified; OE=0 is only a masked representative.
    dout_oe_o = !standby_i && !cs_n_i;
    dout_o = 1'bx;
    if (dout_oe_o) begin
      if (!we_n_i) dout_o = din_i; // 5-64: output follows DIN during write.
      else dout_o = column_data[a_i[9:5]];
    end
  end
endmodule
