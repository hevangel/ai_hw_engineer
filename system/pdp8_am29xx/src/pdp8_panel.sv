// 1965 PDP-8 front panel, functional reconstruction.
//
// Keys: LOAD ADDRESS, EXAMINE, DEPOSIT, START, STOP, CONTINUE, STEP.
// One 12-bit switch register supplies the address, the deposit data and the
// OSR operand; the original machine has separate address and data switch rows,
// so this is a documented simplification.
//
// EXAMINE and DEPOSIT operate on the word addressed by PC and then advance PC,
// which is how the original panel walks a program into core.  Panel memory
// accesses are only meaningful while the processor is stopped; the CPU asserts
// no memory requests in its halt loop.
`timescale 1ns/1ps
module pdp8_panel (
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic [11:0] sw_i,
    input  logic        key_load_addr_i,
    input  logic        key_examine_i,
    input  logic        key_deposit_i,
    input  logic        key_start_i,
    input  logic        key_stop_i,
    input  logic        key_cont_i,
    input  logic        key_step_i,
    input  logic [11:0] pc_i,
    input  logic [11:0] mem_rdata_i,
    output logic        pc_we_o,
    output logic [11:0] pc_out_o,
    output logic        master_clear_o,
    output logic        run_set_o,
    output logic        stop_o,
    output logic        step_o,
    output logic [11:0] examine_addr_o,
    output logic        examine_re_o,
    output logic [11:0] deposit_addr_o,
    output logic [11:0] deposit_data_o,
    output logic        deposit_we_o,
    output logic [11:0] display_o,
    output logic        display_valid_o
);
  typedef enum logic [2:0] {
    IDLE       = 3'd0,
    EX_WAIT    = 3'd1,
    EX_LATCH   = 3'd2,
    DEP_WAIT   = 3'd3,
    START_WAIT = 3'd4
  } state_t;

  state_t state;

  // Key synchronisers and rising-edge detectors.
  logic [6:0] key_sync, key_prev;
  logic       load_edge, exam_edge, dep_edge, start_edge;
  logic       stop_edge, cont_edge, step_edge;

  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      key_sync <= 7'd0;
      key_prev <= 7'd0;
    end else begin
      key_sync <= {key_step_i, key_cont_i, key_stop_i, key_start_i,
                   key_deposit_i, key_examine_i, key_load_addr_i};
      key_prev <= key_sync;
    end
  end

  assign load_edge  = key_sync[0] & ~key_prev[0];
  assign exam_edge  = key_sync[1] & ~key_prev[1];
  assign dep_edge   = key_sync[2] & ~key_prev[2];
  assign start_edge = key_sync[3] & ~key_prev[3];
  assign stop_edge  = key_sync[4] & ~key_prev[4];
  assign cont_edge  = key_sync[5] & ~key_prev[5];
  assign step_edge  = key_sync[6] & ~key_prev[6];

  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      state           <= IDLE;
      pc_we_o         <= 1'b0;
      pc_out_o        <= 12'd0;
      master_clear_o  <= 1'b0;
      run_set_o       <= 1'b0;
      stop_o          <= 1'b0;
      step_o          <= 1'b0;
      examine_addr_o  <= 12'd0;
      examine_re_o    <= 1'b0;
      deposit_addr_o  <= 12'd0;
      deposit_data_o  <= 12'd0;
      deposit_we_o    <= 1'b0;
      display_o       <= 12'd0;
      display_valid_o <= 1'b0;
    end else begin
      pc_we_o        <= 1'b0;
      master_clear_o <= 1'b0;
      run_set_o      <= 1'b0;
      stop_o         <= 1'b0;
      step_o         <= 1'b0;
      examine_re_o   <= 1'b0;
      deposit_we_o   <= 1'b0;
      display_valid_o <= 1'b0;

      case (state)
        IDLE: begin
          if (load_edge) begin
            pc_out_o <= sw_i;
            pc_we_o  <= 1'b1;
          end else if (exam_edge) begin
            examine_addr_o <= pc_i;
            examine_re_o   <= 1'b1;
            state          <= EX_WAIT;
          end else if (dep_edge) begin
            deposit_addr_o <= pc_i;
            deposit_data_o <= sw_i;
            deposit_we_o   <= 1'b1;
            state          <= DEP_WAIT;
          end else if (start_edge) begin
            master_clear_o <= 1'b1;
            state          <= START_WAIT;
          end else if (cont_edge) begin
            run_set_o <= 1'b1;
          end else if (stop_edge) begin
            stop_o <= 1'b1;
          end else if (step_edge) begin
            step_o <= 1'b1;
          end
        end
        EX_WAIT: begin
          // The memory read registered at the end of this cycle is valid next.
          state <= EX_LATCH;
        end
        EX_LATCH: begin
          display_o       <= mem_rdata_i;
          display_valid_o <= 1'b1;
          pc_out_o        <= pc_i + 12'd1;
          pc_we_o         <= 1'b1;
          state           <= IDLE;
        end
        DEP_WAIT: begin
          pc_out_o <= pc_i + 12'd1;
          pc_we_o  <= 1'b1;
          state    <= IDLE;
        end
        START_WAIT: begin
          run_set_o <= 1'b1;
          state     <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule
