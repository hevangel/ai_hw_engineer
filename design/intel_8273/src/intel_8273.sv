`timescale 1ns/1ps
// Intel 8273 common-clock functional core; pin/timing adaptations in spec/spec.md.
module intel_8273 (
    input logic clk, rst_n,
    input logic cs_n, rd_n, wr_n,
    input logic [1:0] addr,
    input logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic data_oe,
    input logic tx_dack_n, rx_dack_n,
    output logic tx_drq, rx_drq, tx_int, rx_int,
    input logic tx_tick, rx_tick, tx_sample_tick, clk32_tick, rxd,
    output logic txd, dpll_tick,
    input logic cts_n, cd_n,
    input logic [2:0] port_a,
    output logic [3:0] port_b,
    output logic rts_n, flag_det_n
);
    logic reset_hold_q, old_rd_q,old_wr_q,core_rst_n;
    logic read_bus,write_bus,read_edge,write_edge,cpu_read,cpu_write;
    logic tx_put,rx_get,tx_result_get,rx_result_get;
    logic [7:0] mode_q,serial_q,port_q,command_q,param_q[0:2];
    logic [2:0] needed_q,index_q;
    logic non_dma_q,delay_q,delay_select_q,immediate_full_q;
    logic [7:0] immediate_q;
    logic tx_start_q,tx_abort_q,tx_busy,tx_take,tx_done;
    logic [1:0] tx_abort_kind_q;
    logic [7:0] tx_code,tx_buffer_q,tx_address_q,tx_control_q;
    logic [15:0] tx_length_q,tx_left_q;
    logic tx_full_q,tx_transparent_q,tx_loop_q,tx_pending_q;
    logic [7:0] tx_results_q[0:1];
    logic [1:0] tx_count_q;
    logic tx_head_q,tx_tail_q,tx_publish,tx_pop;
    logic [7:0] tx_publish_code;
    logic rx_enable_q,rx_restart_q,rx_selective_q,rx_loop_q;
    logic [7:0] match1_q,match2_q,rx_buffer_q;
    logic [15:0] rx_limit_q,rx_count_bytes_q;
    logic rx_full_q,rx_valid,rx_done,rx_flag,rx_eop,rx_idle;
    logic [7:0] rx_byte,rx_code,rx_address,rx_control;
    logic [15:0] rx_length;
    logic [7:0] rx_results_q[0:4];
    logic [2:0] rx_count_q,rx_head_q;
    logic rx_pending_q;
    logic [7:0] rx_saved_code_q,rx_saved_address_q,rx_saved_control_q;
    logic [15:0] rx_saved_length_q;
    logic serial_out,rx_line,receive_tick,loop_prev_q,loop_delay_q;
    logic tx_need,rx_need;
    assign core_rst_n=rst_n && !reset_hold_q;
    assign read_bus=rst_n && !rd_n && wr_n;
    assign write_bus=rst_n && !wr_n && rd_n;
    assign read_edge=read_bus && old_rd_q;
    assign write_edge=write_bus && old_wr_q;
    assign cpu_read=read_edge && !cs_n && tx_dack_n && rx_dack_n;
    assign cpu_write=write_edge && !cs_n && tx_dack_n && rx_dack_n;
    assign tx_put=write_edge && !tx_dack_n && rx_dack_n && tx_need;
    assign rx_get=read_edge && !rx_dack_n && tx_dack_n && rx_full_q;
    assign tx_result_get=cpu_read && addr==2 && tx_count_q!=0;
    assign rx_result_get=cpu_read && addr==3 && rx_count_q!=0;
    assign tx_need=core_rst_n && tx_busy && tx_left_q!=0 && !tx_full_q;
    assign rx_need=core_rst_n && rx_full_q;
    assign tx_drq=tx_need && tx_dack_n && !non_dma_q;
    assign rx_drq=rx_need && rx_dack_n && !non_dma_q;
    assign tx_int=core_rst_n && (tx_count_q!=0 || (non_dma_q && tx_need));
    assign rx_int=core_rst_n && (rx_count_q!=0 || (non_dma_q && rx_need));
    assign port_b=port_q[4:1];
    assign rts_n=port_q[0] && !tx_busy && !tx_pending_q;
    assign flag_det_n=port_q[5];
    assign txd=delay_select_q ? loop_delay_q : serial_out;
    assign rx_line=serial_q[2] ? txd : rxd;
    assign receive_tick=serial_q[1] ? tx_sample_tick : rx_tick;
    assign tx_pop=tx_result_get;
    assign tx_publish=tx_done || (tx_put && tx_left_q==1 && mode_q[3]);
    assign tx_publish_code=tx_done ? tx_code : 8'h0c;
    always_comb begin
        data_o=0; data_oe=0;
        if (core_rst_n && read_bus) begin
            if (!rx_dack_n && tx_dack_n) begin
                data_o=rx_buffer_q; data_oe=1;
            end else if (!cs_n && tx_dack_n && rx_dack_n) begin
                case(addr)
                    0: begin
                        data_o={needed_q!=0,2'b00,immediate_full_q,
                                rx_int,tx_int,rx_count_q!=0,tx_count_q!=0};
                        data_oe=1;
                    end
                    1: if (immediate_full_q) begin data_o=immediate_q; data_oe=1; end
                    2: if (tx_count_q!=0) begin data_o=tx_results_q[tx_head_q]; data_oe=1; end
                    3: if (rx_count_q!=0) begin data_o=rx_results_q[rx_head_q]; data_oe=1; end
                endcase
            end
        end
    end
    always_ff @(posedge clk) begin
        if (!rst_n) begin reset_hold_q<=0; old_rd_q<=1; old_wr_q<=1; end
        else begin
            old_rd_q<=rd_n; old_wr_q<=wr_n;
            if (cpu_write && addr==2) reset_hold_q<=data_i[0];
        end
    end
    intel_8273_tx transmitter (
        .clk(clk),.rst_n(core_rst_n),.tick(tx_tick),.start(tx_start_q),
        .abort_req(tx_abort_q),.cts_n(cts_n),.buffered(mode_q[2]),
        .abort_kind(tx_abort_kind_q),
        .transparent(tx_transparent_q),.nrzi(serial_q[0]),.pre_sync(mode_q[1]),
        .flag_stream(mode_q[0]),.length(tx_length_q),.address(tx_address_q),
        .control(tx_control_q),.data(tx_buffer_q),.data_valid(tx_full_q),
        .take(tx_take),.busy(tx_busy),.txd(serial_out),.done(tx_done),.result(tx_code)
    );
    intel_8273_rx receiver (
        .clk(clk),.rst_n(core_rst_n),.tick(receive_tick),.enable(rx_enable_q),
        .restart(rx_restart_q),.rxd(rx_line),.nrzi(serial_q[0]),.hdlc(mode_q[5]),
        .buffered(mode_q[2]),.selective(rx_selective_q),.eop_mode(mode_q[4]),
        .match1(match1_q),.match2(match2_q),.data_valid(rx_valid),.data(rx_byte),
        .frame_done(rx_done),.result(rx_code),.address(rx_address),.control(rx_control),
        .length(rx_length),.flag_seen(rx_flag),.eop_seen(rx_eop),.idle_seen(rx_idle)
    );
    intel_8273_dpll recovery (.clk(clk),.rst_n(core_rst_n),.tick32(clk32_tick),
        .rxd(rx_line),.sample_tick(dpll_tick));

    // ASSUMPTION A6: a second unread result disables receive with overrun 0B.
`define RX_RESULT(code_value,length_value) begin \
        rx_results_q[0] <= (rx_count_q!=0 && !(rx_result_get && rx_count_q==1)) ? 8'heb : (code_value); \
        rx_results_q[1] <= 8'(length_value); \
        rx_results_q[2] <= 8'((length_value) >> 8); \
        rx_results_q[3] <= rx_address; rx_results_q[4] <= rx_control; \
        rx_head_q<=0; rx_count_q<=mode_q[2] ? 3'd5 : 3'd3; \
        if (rx_count_q!=0 && !(rx_result_get && rx_count_q==1)) rx_enable_q<=0; \
    end
    always_ff @(posedge clk) begin
        if (!core_rst_n) begin
            mode_q<=0; serial_q<=0; port_q<=8'h3f; command_q<=0;
            for (int i=0;i<3;i++) param_q[i]<=0;
            needed_q<=0; index_q<=0; non_dma_q<=0; delay_q<=0; delay_select_q<=0;
            immediate_full_q<=0; immediate_q<=0;
            tx_start_q<=0; tx_abort_q<=0; tx_abort_kind_q<=0; tx_buffer_q<=0;
            tx_address_q<=0; tx_control_q<=0; tx_length_q<=0; tx_left_q<=0;
            tx_full_q<=0; tx_transparent_q<=0; tx_loop_q<=0; tx_pending_q<=0;
            tx_count_q<=0; tx_head_q<=0; tx_tail_q<=0;
            tx_results_q[0]<=0; tx_results_q[1]<=0;
            rx_enable_q<=0; rx_restart_q<=0; rx_selective_q<=0; rx_loop_q<=0;
            match1_q<=0; match2_q<=0; rx_buffer_q<=0; rx_limit_q<=0;
            rx_count_bytes_q<=0; rx_full_q<=0; rx_count_q<=0; rx_head_q<=0;
            rx_pending_q<=0; rx_saved_code_q<=0; rx_saved_length_q<=0;
            rx_saved_address_q<=0; rx_saved_control_q<=0;
            for (int i=0;i<5;i++) rx_results_q[i]<=0;
            loop_prev_q<=1; loop_delay_q<=1;
        end else begin
            tx_start_q<=0; tx_abort_q<=0; rx_restart_q<=0;
            // Change relay ownership on a serial edge, preserving the final
            // transmitted flag bit until the receive sampling edge has passed.
            if (!delay_q || tx_busy) delay_select_q<=0;
            else if (tx_tick || receive_tick) delay_select_q<=1;
            if (receive_tick) begin loop_prev_q<=rx_line; loop_delay_q<=loop_prev_q; end
            if (tx_take) tx_full_q<=0;
            if (tx_put) begin
                tx_buffer_q<=data_i; tx_full_q<=1; tx_left_q<=tx_left_q-1'b1;
            end
            if (tx_pop) tx_head_q<=~tx_head_q;
            if (tx_publish && (tx_count_q<2 || tx_pop)) begin
                tx_results_q[tx_tail_q]<=tx_publish_code; tx_tail_q<=~tx_tail_q;
            end
            case ({tx_publish && (tx_count_q<2 || tx_pop),tx_pop})
                2'b10: tx_count_q<=tx_count_q+1'b1;
                2'b01: tx_count_q<=tx_count_q-1'b1;
                default: begin end
            endcase
            if (tx_done) begin
                tx_full_q<=0; tx_left_q<=0;
                if (tx_loop_q) begin delay_q<=1; mode_q[0]<=0; end
            end
            if (tx_pending_q && (rx_eop || mode_q[0])) begin
                tx_start_q<=1; tx_pending_q<=0; delay_q<=0;
            end
            if (rx_flag) port_q[5]<=0;
            else if (receive_tick) port_q[5]<=1;
            if (rx_get) rx_full_q<=0;
            if (rx_result_get) begin rx_count_q<=rx_count_q-1'b1; rx_head_q<=rx_head_q+1'b1; end
            // Publish successful/CRC frame results after the last data request
            // has been serviced, keeping non-DMA INT/IRA interpretation clear.
            if (rx_pending_q && (!rx_full_q || rx_get)) begin
                `RX_RESULT(rx_saved_code_q,rx_saved_length_q)
                rx_results_q[3]<=rx_saved_address_q; rx_results_q[4]<=rx_saved_control_q;
                rx_pending_q<=0;
            end
            if (rx_enable_q) begin
                if (cd_n) begin
                    rx_enable_q<=0;
                    `RX_RESULT(8'hea,rx_count_bytes_q)
                end else if (rx_valid) begin
                    if (rx_full_q && !rx_get) begin
                        rx_enable_q<=0;
                        `RX_RESULT(8'he8,rx_count_bytes_q)
                    end else if (rx_count_bytes_q>=rx_limit_q) begin
                        rx_enable_q<=0;
                        `RX_RESULT(8'he9,rx_count_bytes_q)
                    end else begin
                        rx_buffer_q<=rx_byte; rx_full_q<=1;
                        rx_count_bytes_q<=rx_count_bytes_q+1'b1;
                    end
                end
                if (rx_done && !cd_n && !(rx_valid &&
                    ((rx_full_q && !rx_get) || rx_count_bytes_q>=rx_limit_q))) begin
                    if (rx_pending_q) begin
                        `RX_RESULT(8'heb,rx_length)
                        rx_enable_q<=0; rx_pending_q<=0;
                    end else if ((rx_code[4:0]<=3 || rx_code[4:0]==7) &&
                                 ((rx_full_q && !rx_get) || rx_valid)) begin
                        rx_pending_q<=1; rx_saved_code_q<=rx_code;
                        rx_saved_length_q<=rx_length; rx_saved_address_q<=rx_address;
                        rx_saved_control_q<=rx_control;
                    end else begin
                        `RX_RESULT(rx_code,rx_length)
                    end
                    rx_count_bytes_q<=0;
                    // ASSUMPTION A7: retain Rx after abort per Intel figure 11;
                    // General Receive note 8 disagrees (see specification).
                    if (rx_idle || rx_code[4:0]==6) rx_enable_q<=0;
                end
                if (rx_loop_q && rx_eop) begin delay_q<=0; mode_q[0]<=1; rx_enable_q<=0; end
            end
            if (cpu_read && addr==1) immediate_full_q<=0;
            if (cpu_write && addr==0 && needed_q==0) begin
                command_q<=data_i; index_q<=0;
                case(data_i)
                    8'ha4,8'h64,8'h97,8'h57,8'h91,8'h51,
                    8'ha0,8'h60,8'ha3,8'h63: needed_q<=1;
                    8'hc0: needed_q<=2;
                    8'hc1,8'hc2: needed_q<=4;
                    // ASSUMPTION A1: no next-frame queue while Tx is active.
                    8'hc8,8'hca: if (!tx_busy && !tx_pending_q) needed_q<=mode_q[2] ? 3'd4 : 3'd2;
                    8'hc9: if (!tx_busy && !tx_pending_q) needed_q<=2;
                    8'hc5: rx_enable_q<=0;
                    8'hcc,8'hce,8'hcd: begin
                        tx_abort_kind_q<=data_i==8'hce ? 2'd1 : data_i==8'hcd ? 2'd2 : 2'd0;
                        if (tx_busy) tx_abort_q<=1;
                        if (tx_pending_q) begin tx_pending_q<=0; tx_left_q<=0; end
                        if (data_i==8'hce) delay_q<=1;
                    end
                    8'h22: begin immediate_q<={3'd0,port_a,cd_n,cts_n}; immediate_full_q<=1; end
                    8'h23: begin immediate_q<={2'd0,port_q[5:1],rts_n}; immediate_full_q<=1; end
                    default: begin end
                endcase
            end
            if (cpu_write && addr==1 && needed_q!=0) begin
                if (index_q<3) param_q[index_q[1:0]]<=data_i;
                index_q<=index_q+1'b1;
                if (index_q+1'b1==needed_q) begin
                    needed_q<=0; index_q<=0;
                    case(command_q)
                        8'ha4: delay_q<=delay_q | data_i[7];
                        8'h64: delay_q<=delay_q & data_i[7];
                        8'h97: non_dma_q<=non_dma_q | data_i[0];
                        8'h57: non_dma_q<=non_dma_q & data_i[0];
                        8'h91: mode_q<=mode_q | (data_i & 8'h3f);
                        8'h51: mode_q<=mode_q & (data_i | 8'hc0);
                        8'ha0: serial_q<=serial_q | (data_i & 8'h07);
                        8'h60: serial_q<=serial_q & (data_i | 8'hf8);
                        8'ha3: port_q<=port_q | (data_i & 8'h3f);
                        8'h63: port_q<=port_q & (data_i | 8'hc0);
                        8'hc0,8'hc1,8'hc2: begin
                            rx_limit_q<=command_q==8'hc0 ? {data_i,param_q[0]} : {param_q[1],param_q[0]};
                            match1_q<=param_q[2]; match2_q<=data_i;
                            rx_selective_q<=command_q!=8'hc0; rx_loop_q<=command_q==8'hc2;
                            rx_enable_q<=1; rx_restart_q<=1; rx_full_q<=0; rx_count_bytes_q<=0;
                            rx_pending_q<=0;
                        end
                        8'hc8,8'hca,8'hc9: begin
                            // ASSUMPTION A3: count zero is zero, not 65536.
                            tx_length_q<=needed_q==4 ? {param_q[1],param_q[0]} : {data_i,param_q[0]};
                            tx_left_q<=needed_q==4 ? {param_q[1],param_q[0]} : {data_i,param_q[0]};
                            tx_address_q<=param_q[2]; tx_control_q<=data_i; tx_full_q<=0;
                            tx_transparent_q<=command_q==8'hc9; tx_loop_q<=command_q==8'hca;
                            if (command_q==8'hca && !mode_q[0]) tx_pending_q<=1;
                            else begin tx_start_q<=1; delay_q<=0; end
                        end
                        default: begin end
                    endcase
                end
            end
        end
    end
`undef RX_RESULT
`ifdef FORMAL
    `include "intel_8273_props.sv"
`endif
endmodule
