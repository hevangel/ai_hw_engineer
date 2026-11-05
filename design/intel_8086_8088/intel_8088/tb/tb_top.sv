`timescale 1ns / 1ps
module tb_top;
  import uvm_pkg::*;
  import intel_8088_uvm_pkg::*;
  intel_8088_if vif ();
  intel_8088_chip dut (
      .clk(vif.clk),
      .reset_i(vif.reset),
      .min_mode_i(vif.min_mode),
      .ready_i(vif.ready),
      .intr_i(vif.intr),
      .nmi_i(vif.nmi),
      .test_n_i(vif.test_n),
      .hold_i(vif.hold),
      .rqgt_n_i(vif.rqgt_n),
      .ad_i(vif.ad_in),
      .ad_o(vif.ad_out),
      .ad_oe_o(vif.ad_oe),
      .high_address_o(vif.high_address),
      .high_address_oe_o(vif.high_address_oe),
      .address_status_o(vif.address_status),
      .address_status_oe_o(vif.address_status_oe),
      .sso_n_o(vif.sso_n),
      .sso_oe_o(vif.sso_oe),
      .rd_n_o(vif.rd_n),
      .wr_n_o(vif.wr_n),
      .io_m_o(vif.io_m),
      .dt_r_o(vif.dt_r),
      .den_n_o(vif.den_n),
      .ale_o(vif.ale),
      .inta_n_o(vif.inta_n),
      .control_oe_o(vif.control_oe),
      .hlda_o(vif.hlda),
      .rqgt_n_o(vif.rqgt_n_o),
      .rqgt_oe_o(vif.rqgt_oe),
      .status_o(vif.status),
      .phase_o(vif.phase),
      .qs_o(vif.qs),
      .lock_n_o(vif.lock_n),
      .halted_o(vif.halted),
      .fault_o(vif.fault),
      .retire_o(vif.retire),
      .regs_o(vif.regs),
      .segs_o(vif.segs),
      .ip_o(vif.ip),
      .flags_o(vif.flags),
      .queue_count_o(vif.queue_count)
  );
  initial begin
    uvm_config_db#(virtual intel_8088_if)::set(null, "uvm_test_top.driver", "vif", vif);
    run_test("intel_8088_control_test");
  end
  initial begin
    forever #5 vif.clk = ~vif.clk;
  end
  initial begin
    #1000000;
    $fatal(1, "8088 UVM watchdog");
  end
endmodule
