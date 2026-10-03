// Included inside CPU under FORMAL. Manufacturer transaction-boundary contract.
`ifdef FORMAL
  logic past_valid = 0;
  logic [1:0] reset_cycles = 0;
  always_ff @(posedge clk) begin
    past_valid <= 1;
    if (reset_cycles < 2) begin assume (!rst_n); reset_cycles <= reset_cycles+1; end
    if (past_valid) begin
      assert (state <= FAULT);
      // Reachability invariant: every fault transition updates both together.
      assert (fault_o == (state == FAULT));
      if (hlda_o || fault_o || !rst_n) assert (!bus_req_o);
      if (retire_o) assert (state == BOUNDARY && !fault_o);
      if (bus_req_o && bus_io_o) begin
        assert (bus_addr_o[15:8] == bus_addr_o[7:0]);
        assert (bus_status_o == (bus_write_o ? 8'h10 : 8'h42));
      end
      if (bus_req_o && bus_intack_o) begin
        assert (!bus_write_o && !bus_io_o);
        assert (bus_status_o == 8'h23 || bus_status_o == 8'h2b || bus_status_o == 8'h02);
      end
      if (rst_n && $past(rst_n)) begin
        if ($past(bus_req_o && !bus_ready_i)) begin
          assert (bus_req_o);
          assert ({bus_addr_o,bus_wdata_o,bus_status_o,bus_write_o,bus_io_o,bus_intack_o} ==
              $past({bus_addr_o,bus_wdata_o,bus_status_o,bus_write_o,bus_io_o,bus_intack_o}));
          assert ({pc_o,sp_o,regs_o,flags_o} == $past({pc_o,sp_o,regs_o,flags_o}));
          assert (!retire_o);
        end
        if ($past(hlda_o)) begin
          assert ({pc_o,sp_o,regs_o,flags_o} == $past({pc_o,sp_o,regs_o,flags_o}));
          assert (!retire_o);
        end
        if ($past(fault_o)) assert (fault_o);
      end
      if ($past(!rst_n)) begin
        assert (pc == 0 && state == BOUNDARY && !inte_o && !hlda_o && !halted_o && !fault_o);
        assert ({sp_o,regs_o,flags_o} == $past({sp_o,regs_o,flags_o}));
      end
      cover (rst_n && bus_req_o && !bus_ready_i);
      cover (rst_n && bus_req_o && bus_write_o && !bus_io_o);
      cover (rst_n && bus_req_o && bus_io_o && bus_write_o);
      cover (rst_n && bus_req_o && bus_io_o && !bus_write_o);
      cover (rst_n && hlda_o);
      cover (rst_n && halted_o);
      cover (rst_n && bus_req_o && bus_intack_o);
      cover (rst_n && fault_o);
    end
  end
`endif
