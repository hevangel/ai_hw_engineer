`timescale 1ns/1ps
`ifdef FORMAL
module amd_am3101_props (
    input logic [3:0] a_i, d_i,
    input logic cs_n_i, we_n_i
);
  (* anyconst *) logic [3:0] watch_address;
  logic [3:0] q;
  logic output_valid;
  logic [3:0] watched_data;
  logic written = 0;
  logic unrelated_write = 0;
  amd_am3101 dut (
      .a_i(a_i), .cs_n_i(cs_n_i), .we_n_i(we_n_i), .d_i(d_i),
      .q_n_o(q), .output_valid_o(output_valid)
  );
  always_ff @($global_clock) begin
    if (!cs_n_i && !we_n_i && a_i == watch_address) begin
      watched_data <= d_i;
      written <= 1;
    end
    if (written && !cs_n_i && !we_n_i && a_i != watch_address)
      unrelated_write <= 1;
    assert (output_valid == !(cs_n_i && !we_n_i));
    if (cs_n_i && we_n_i) assert (q == 4'hf);
    if (!cs_n_i && !we_n_i) assert (q == ~d_i);
    if (written && !cs_n_i && we_n_i && a_i == watch_address) begin
      assert (q == ~watched_data);
      cover (watched_data == 4'ha && q == 4'h5);
      cover (unrelated_write && watched_data == 4'h3 && q == 4'hc);
    end
    cover (cs_n_i && !we_n_i && !output_valid);
  end
endmodule
`endif
