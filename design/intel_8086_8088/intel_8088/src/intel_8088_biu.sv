`timescale 1ns / 1ps
// Four-byte prefetch BIU and the native 8-bit-bus digital interface of the
// Intel 8088. Every bus cycle transfers one byte at its full byte address;
// a 16-bit EU transaction becomes two ascending byte cycles that complete
// as one transfer. Pin 34 carries SS0, the minimum-mode equivalent of the
// maximum-mode S0 status, in place of the 8086's BHE/S7, and the bus status
// pin carries the 8088's IO/M polarity.
module intel_8088_biu (
    input logic clk,
    rst_n,
    min_mode_i,
    ready_i,
    input logic [7:0] ad_i,
    input logic hold_i,
    input logic [1:0] rqgt_n_i,
    input logic eu_req_i,
    eu_write_i,
    eu_fetch_i,
    eu_first_i,
    eu_io_i,
    eu_intack_i,
    input logic [19:0] eu_addr_i,
    input logic [1:0] eu_be_i,
    eu_segment_i,
    input logic [15:0] eu_wdata_i,
    input logic flush_i, suspend_i, inhibit_i,
    lock_i,
    halted_i,
    if_i,
    input logic [15:0] cs_i,
    ip_i,
    output logic eu_ready_o,
    output logic [15:0] eu_rdata_o,
    output logic [7:0] ad_o,
    output logic ad_oe_o,
    output logic [7:0] high_address_o,
    output logic high_address_oe_o,
    output logic [3:0] address_status_o,
    output logic address_status_oe_o,
    sso_n_o,
    sso_oe_o,
    output logic rd_n_o,
    wr_n_o,
    io_m_o,
    dt_r_o,
    den_n_o,
    ale_o,
    inta_n_o,
    output logic control_oe_o,
    hlda_o,
    output logic [1:0] rqgt_n_o,
    rqgt_oe_o,
    output logic [2:0] status_o,
    phase_o,
    output logic [1:0] qs_o,
    output logic lock_n_o,
    arbitration_pending_o,
    output logic [2:0] queue_count_o
);
  typedef enum logic [2:0] {
    IDLE,
    T1,
    T2,
    T3,
    TW,
    T4
  } phase_t;
  phase_t phase;
  logic [7:0] queue[0:3];
  logic [1:0] head, tail;
  logic [2:0] count;
  logic [15:0] queue_cs, head_ip, fetch_ip;
  logic cycle_discard;
  logic [19:0] cycle_addr;
  logic [1:0] cycle_be, cycle_segment;
  logic [15:0] cycle_wdata, response_data;
  logic cycle_write, cycle_io, cycle_intack, cycle_prefetch, sampled_ready, cycle_grant_allowed;
  logic cycle_word, cycle_second, cycle_lane_high;
  logic queue_pop, prefetch_finish, data_phase, owned, lock_delayed;
  logic [1:0] pending, rqgt_previous, grant_pulse, release_delay;
  logic held, owner;
  logic request_hold, request_grant, release_request;
  integer index;
  function automatic logic [1:0] advance(input logic [1:0] pointer);
    advance = pointer == 2'd3 ? 2'd0 : pointer + 2'd1;
  endfunction
  function automatic logic [19:0] physical(input logic [15:0] base, offset_value);
    physical = {base, 4'b0} + {4'b0, offset_value};
  endfunction
  function automatic logic [15:0] capture_read();
    if (cycle_word && cycle_second) capture_read = {ad_i, response_data[7:0]};
    else if (!cycle_word && cycle_be == 2'b10 && !cycle_prefetch) capture_read = {ad_i, 8'b0};
    else capture_read = {8'b0, ad_i};
  endfunction
  // The byte lane this bus cycle carries within the EU transfer: the second
  // byte of a whole-word request or a high-lane byte request.
  assign cycle_lane_high = cycle_second || cycle_be == 2'b10 && !cycle_prefetch;
  assign queue_pop = eu_req_i && eu_fetch_i && count != 0 && !flush_i && eu_addr_i == (physical(
      queue_cs, head_ip
  ) & 20'hffffe) && eu_be_i == (head_ip[0] ? 2'b10 : 2'b01);
  assign prefetch_finish=phase==T4 && cycle_prefetch && !cycle_discard && !flush_i;
  assign eu_ready_o=rst_n && (queue_pop || phase==T4 && !cycle_prefetch && eu_req_i &&
      !eu_fetch_i && (!cycle_word || cycle_second));
  assign eu_rdata_o=eu_fetch_i ? (eu_be_i==2 ? {queue[head],8'b0}:{8'b0,queue[head]}) : response_data;
  assign request_hold = min_mode_i && hold_i;
  assign request_grant = !min_mode_i && (pending != 0 || ((rqgt_previous & ~rqgt_n_i) != 0));
  assign release_request=held && (min_mode_i ? !hold_i :
      (rqgt_previous[owner] && !rqgt_n_i[owner] && !grant_pulse[owner]));
  assign arbitration_pending_o = request_hold || request_grant || held || release_delay != 0;
  assign owned = rst_n && !held && release_delay == 0;
  assign data_phase = phase == T2 || phase == T3 || phase == TW;
  assign phase_o = phase;
  assign queue_count_o = count;
  assign hlda_o = min_mode_i && held;
  assign rqgt_n_o = ~grant_pulse;
  assign rqgt_oe_o = min_mode_i ? 2'b00 : grant_pulse;
  assign ad_o = phase == T1 ? cycle_addr[7:0] :
      cycle_lane_high ? cycle_wdata[15:8] : cycle_wdata[7:0];
  assign ad_oe_o = owned && !cycle_intack && (phase == T1 || (data_phase || phase == T4) && cycle_write);
  assign high_address_o = cycle_addr[15:8];
  assign high_address_oe_o = owned;
  assign address_status_o = phase == T1 ? cycle_addr[19:16] : {1'b0, if_i, cycle_segment};
  assign address_status_oe_o = owned;
  assign sso_n_o = !status_o[0];
  assign sso_oe_o = owned;
  assign control_oe_o = owned;
  assign rd_n_o = !(owned && data_phase && !cycle_write && !cycle_intack);
  assign wr_n_o = !(owned && min_mode_i && data_phase && cycle_write);
  assign io_m_o = cycle_io || cycle_intack;
  assign dt_r_o = cycle_write;
  assign den_n_o = !(owned && min_mode_i && (data_phase || phase == T4));
  assign ale_o = owned && min_mode_i && phase == T1;
  assign inta_n_o = !(owned && min_mode_i && data_phase && cycle_intack);
  assign lock_n_o = !(rst_n && !min_mode_i && lock_delayed);
  always_comb begin
    status_o = 3'b111;
    // The 8288 must see the active status through an extended cycle, until
    // READY permits the T3/Tw completion (Intel datasheet STATUS pin table).
    if (owned && (phase == T1 || phase == T2 || phase == T3 && !sampled_ready ||
                  phase == TW && !ready_i)) begin
      if (cycle_intack) status_o = 0;
      else if (cycle_io) status_o = cycle_write ? 3'b010 : 3'b001;
      else if (cycle_prefetch) status_o = 3'b100;
      else status_o = cycle_write ? 3'b110 : 3'b101;
    end else if (owned && phase == IDLE && halted_i) status_o = 3'b011;
  end
  always_ff @(posedge clk) begin
    qs_o <= 0;
    grant_pulse <= 0;
    lock_delayed <= lock_i;
    rqgt_previous <= rqgt_n_i;
    if (!rst_n) begin
      phase <= IDLE;
      head <= 0;
      tail <= 0;
      count <= 0;
      queue_cs <= 16'hffff;
      head_ip <= 0;
      fetch_ip <= 0;
      cycle_discard <= 0;
      cycle_addr <= 0;
      cycle_be <= 2'b01;
      cycle_word <= 0;
      cycle_second <= 0;
      cycle_segment <= 2;
      cycle_wdata <= 0;
      response_data <= 0;
      cycle_write <= 0;
      cycle_io <= 0;
      cycle_intack <= 0;
      cycle_prefetch <= 0;
      sampled_ready <= 0;
      cycle_grant_allowed <= 0;
      pending <= 0;
      rqgt_previous <= 3;
      held <= 0;
      owner <= 0;
      release_delay <= 0;
      lock_delayed <= 0;
      for (index = 0; index < 4; index = index + 1) queue[index] <= 0;
    end else begin
      if (!min_mode_i) begin
        for (index = 0; index < 2; index = index + 1)
        if(rqgt_previous[index] && !rqgt_n_i[index] && !grant_pulse[index] &&
             !(held && owner==1'(index)))
          pending[index] <= 1;
      end
      if (release_delay != 0) release_delay <= release_delay - 2'd1;
      if (release_request) begin
        held <= 0;
        release_delay <= 2;
      end
      if(!held && release_delay==0 && (phase==IDLE || phase==T4 && cycle_grant_allowed) &&
         !(phase==T4 && cycle_word && !cycle_second) &&
         !lock_i && !lock_delayed && !inhibit_i && (request_hold || request_grant)) begin
        held <= 1;
        if (!min_mode_i) begin
          if (pending[0] || rqgt_previous[0] && !rqgt_n_i[0]) begin
            owner <= 0;
            grant_pulse <= 1;
            pending[0] <= 0;
          end else begin
            owner <= 1;
            grant_pulse <= 2;
            pending[1] <= 0;
          end
        end
      end
      if (flush_i) begin
        queue_cs <= cs_i;
        head_ip <= ip_i;
        fetch_ip <= ip_i;
        head <= 0;
        tail <= 0;
        count <= 0;
        // Sticky for the entire bus cycle: a second redirect must not make
        // the response from an abandoned fetch valid again.
        cycle_discard <= 1;
        qs_o <= 2'b10;
      end else begin
        if (queue_pop) begin
          head <= advance(head);
          head_ip <= head_ip + 16'd1;
          qs_o <= eu_first_i ? 2'b01 : 2'b11;
        end
        if (prefetch_finish) begin
          queue[tail] <= response_data[7:0];
          tail <= advance(tail);
          fetch_ip <= fetch_ip + 16'd1;
        end
        if (queue_pop || prefetch_finish)
          count <= count + {2'b0, prefetch_finish} - {2'b0, queue_pop};
      end
      case (phase)
        IDLE:
        if(owned && ((!request_hold && !request_grant) || lock_i || lock_delayed || inhibit_i) && !flush_i) begin
          if (eu_req_i && !eu_fetch_i) begin
            cycle_addr <= eu_addr_i | {19'b0, eu_be_i == 2'b10 && !eu_intack_i};
            cycle_be <= eu_be_i;
            // Interrupt acknowledges are always single bus cycles: the
            // physical 8088 INTA sequence is exactly two cycles, so the
            // EU's whole-word dummy request must not split into two.
            cycle_word <= eu_be_i == 2'b11 && !eu_intack_i;
            cycle_second <= 0;
            cycle_segment <= eu_segment_i;
            cycle_wdata <= eu_wdata_i;
            cycle_write <= eu_write_i;
            cycle_io <= eu_io_i;
            cycle_intack <= eu_intack_i;
            cycle_prefetch <= 0;
            phase <= T1;
          end else if (count != 3'd4 && !halted_i && !suspend_i && !inhibit_i) begin
            // The 8088 BIU starts a byte fetch whenever the four-byte queue
            // has at least one free byte (the 8086 waits for two free bytes).
            cycle_addr <= physical(queue_cs, fetch_ip);
            cycle_be <= 2'b01;
            cycle_word <= 0;
            cycle_second <= 0;
            cycle_segment <= 2;
            cycle_wdata <= 0;
            cycle_write <= 0;
            cycle_io <= 0;
            cycle_intack <= 0;
            cycle_prefetch <= 1;
            cycle_discard <= 0;
            phase <= T1;
          end
        end
        T1: phase <= T2;
        T2: begin
          sampled_ready <= ready_i;
          cycle_grant_allowed <= request_hold || request_grant;
          phase <= T3;
        end
        T3:
        if (sampled_ready) begin
          response_data <= capture_read();
          phase <= T4;
        end else phase <= TW;
        TW:
        if (ready_i) begin
          response_data <= capture_read();
          phase <= T4;
        end
        T4:
        if (cycle_word && !cycle_second) begin
          // The high byte of an aligned word: a complete second bus cycle.
          cycle_second <= 1;
          cycle_addr <= cycle_addr ^ 20'h1;
          phase <= T1;
        end else phase <= IDLE;
        default: phase <= IDLE;
      endcase
    end
  end
`ifdef FORMAL
  logic past_valid = 0;
  // Independent monitor: any redirect abandons the active prefetch until it
  // finishes, even if several redirects occur while READY is held low.
  logic [1:0] redirects_during_fetch;
  always_ff @(posedge clk) begin
    past_valid <= 1;
    if (!rst_n || phase == IDLE) redirects_during_fetch <= 0;
    else if (cycle_prefetch && flush_i && redirects_during_fetch != 2)
      redirects_during_fetch <= redirects_during_fetch + 2'd1;
    if (!past_valid) assume (!rst_n);
    if (past_valid && rst_n && $past(rst_n)) begin
      assert (count <= 4 && head < 4 && tail < 4);
      if ($past(phase == TW && !ready_i)) begin
        assert (phase == TW);
        assert ($stable({cycle_addr, cycle_be, cycle_wdata, cycle_write, cycle_io,
                         cycle_intack, cycle_word, cycle_second}));
      end
      if (held || release_delay != 0) assert (!ad_oe_o && !high_address_oe_o &&
          !address_status_oe_o && !control_oe_o && !sso_oe_o);
      if (ad_oe_o && phase != T1) assert (cycle_write);
      if (cycle_intack) assert (!ad_oe_o);
      if (owned && phase == TW && !ready_i) assert (status_o != 3'b111);
      if ($past(inhibit_i && !held)) assert (!held);
      if (eu_ready_o && eu_fetch_i) assert (count != 0 && !flush_i);
      if (redirects_during_fetch != 0) assert (!prefetch_finish);
      assert (!(grant_pulse[0] && grant_pulse[1]));
      // A whole-word transfer runs its two byte cycles back to back; the bus
      // is never granted away between them.
      if ($past(phase == T4 && cycle_word && !cycle_second))
        assert (phase == T1 && cycle_second && cycle_addr == ($past(cycle_addr) ^ 20'h1));
    end
    cover (past_valid && phase == TW);
    cover (past_valid && count == 4);
    cover (past_valid && queue_pop && prefetch_finish);
    cover (past_valid && held);
    cover (past_valid && grant_pulse[0]);
    cover (past_valid && grant_pulse[1]);
    cover (past_valid && flush_i && cycle_prefetch && phase == T3);
    cover (past_valid && redirects_during_fetch == 2 && phase == T4 && !flush_i);
    cover (past_valid && cycle_word && cycle_second && phase == T4);
    cover (past_valid && owned && min_mode_i && status_o == 3'b101 && !sso_n_o);
    cover (past_valid && owned && min_mode_i && status_o == 3'b110 && sso_n_o);
    cover (past_valid && owned && cycle_io);
  end
`endif
endmodule
