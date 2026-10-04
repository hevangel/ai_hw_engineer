`timescale 1ns/1ps
`ifdef FORMAL
module amd_am9102_props (
    input logic [9:0] a_i,
    input logic cs_n_i, we_n_i, din_i, standby_i
);
  (* anyconst *) logic [9:0] watch_address;
  logic dout, oe, valid;
  logic watched_data;
  logic written = 0;
  logic unrelated_write = 0;
  logic was_standby = 0;
  amd_am9102 dut (.a_i(a_i), .cs_n_i(cs_n_i), .we_n_i(we_n_i),
      .din_i(din_i), .standby_i(standby_i), .dout_o(dout),
      .dout_oe_o(oe), .output_valid_o(valid));
  always_ff @($global_clock) begin
    // Independent one-cell history from manufacturer's write/retention rules.
    if (!standby_i && !cs_n_i && !we_n_i && a_i == watch_address) begin
      watched_data <= din_i;
      written <= 1;
    end
    if (written && !standby_i && !cs_n_i && !we_n_i && a_i != watch_address)
      unrelated_write <= 1;
    if (written && standby_i && cs_n_i) was_standby <= 1;
    assert (valid == (!standby_i || cs_n_i));
    if (!standby_i) begin
      assert (oe == !cs_n_i);
      if (!cs_n_i && !we_n_i) assert (dout == din_i);
      if (written && !cs_n_i && we_n_i && a_i == watch_address) begin
        assert (dout == watched_data);
        cover (!dout);
        cover (dout);
        cover (unrelated_write && dout);
        cover (was_standby && !dout);
      end
    end
    if (standby_i && cs_n_i) assert (!oe);
    cover (standby_i && !cs_n_i && !valid);
  end
endmodule
`endif
