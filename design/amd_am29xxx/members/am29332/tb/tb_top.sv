// Am29332 lockstep testbench wrapper: flat pin-level interface for the
// C++ vector driver (see tb_am29332_driver.cpp for the vector format).
module tb_top (
  input  logic        cp_i,
  input  logic        hold_i,
  input  logic        borow_i,
  input  logic        macro_i,
  input  logic        mlink_i,
  input  logic        mcin_i,
  input  logic        rs_i,
  input  logic        slave_i,
  input  logic        oey_n_i,
  input  logic [31:0] da_i,
  input  logic [31:0] db_i,
  input  logic [3:0]  pa_i,
  input  logic [3:0]  pb_i,
  input  logic [8:0]  instr_i,
  input  logic [5:0]  p_i,
  input  logic [4:0]  w_i,
  input  logic [31:0] y_ext_i,
  input  logic [3:0]  py_ext_i,
  input  logic [4:0]  cznvl_ext_i,
  input  logic        perr_ext_i,
  output logic [31:0] y_o,
  output logic        y_oe_o,
  output logic [3:0]  py_o,
  output logic [4:0]  cznvl_o,
  output logic        perr_o,
  output logic        mserr_o
);

  amd_am29332 dut (.*);

  // power-up state for simulation (the model's defined init; the driver
  // exercises LDSTAT bring-up explicitly in the curated rows)
  initial begin
    dut.status_q = 32'h0;
    dut.q_q = 32'h0;
  end
endmodule
