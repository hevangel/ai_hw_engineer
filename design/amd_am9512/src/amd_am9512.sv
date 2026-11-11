`timescale 1ns/1ps
// Am9512 stack-oriented floating-point processor.
// Functional reconstruction of the 1980 AMD Am9512 datasheet.  See spec/spec.md
// for the clock-sampled interface, format and assumption ledger.
module amd_am9512 (
    input  logic clk_i,
    input  logic reset_i,
    input  logic cs_n_i,
    input  logic rd_n_i,
    input  logic wr_n_i,
    input  logic cd_i,
    input  logic eack_n_i,
    input  logic svack_n_i,
    input  logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic data_oe_o,
    output logic pause_n_o,
    output logic end_o,
    output logic err_o,
    output logic svreq_o
);
`include "amd_am9512_commands.svh"

    localparam logic [2:0] ST_IDLE = 3'd0;
    localparam logic [2:0] ST_WAIT = 3'd1;

    logic [2:0] state;
    logic [127:0] stack_q;
    logic [7:0] command_q;
    logic [7:0] status_q;
    logic [7:0] read_latch;
    logic cycle_done;
    logic end_pending;
    logic completion_pulse;
    logic service_pending;
    logic err_q;

    logic active, status_read;
    logic write_cycle;
    logic unit_start, unit_done;
    logic s_start, d_start, s_done, d_done;
    logic s_busy, d_busy;
    logic [31:0] s_result;
    logic [63:0] d_result;
    logic [4:0] s_status, d_status;

    assign active = !cs_n_i && (rd_n_i ^ wr_n_i);
    assign write_cycle = active && !wr_n_i;
    assign status_read = active && !rd_n_i && cd_i;

    assign data_oe_o = !cs_n_i && !rd_n_i;
    assign data_o = read_latch;
    assign pause_n_o = !(!cs_n_i && ((rd_n_i && wr_n_i) ||
                                     (active && !cycle_done)));
    // ASSUMPTION: sampled EACK.  A tied-LOW EACK produces the documented
    // one-clock completion pulse through completion_pulse.
    assign end_o = (end_pending && eack_n_i) || (completion_pulse && clk_i);
    assign err_o = err_q;
    assign svreq_o = service_pending && svack_n_i;

    assign unit_start = (state == ST_IDLE) && write_cycle && cd_i &&
                        !cycle_done && !s_busy && !d_busy;
    assign s_start = unit_start && is_single_arith(data_i[6:0]);
    assign d_start = unit_start && is_double_arith(data_i[6:0]);
    assign unit_done = s_done || d_done;

    function automatic logic is_single_arith(input logic [6:0] op);
        begin
            is_single_arith = (op == AMD_AM9512_OP_SADD) ||
                              (op == AMD_AM9512_OP_SSUB) ||
                              (op == AMD_AM9512_OP_SMUL) ||
                              (op == AMD_AM9512_OP_SDIV);
        end
    endfunction

    function automatic logic is_double_arith(input logic [6:0] op);
        begin
            is_double_arith = (op == AMD_AM9512_OP_DADD) ||
                              (op == AMD_AM9512_OP_DSUB) ||
                              (op == AMD_AM9512_OP_DMUL) ||
                              (op == AMD_AM9512_OP_DDIV);
        end
    endfunction

    function automatic logic [7:0] status_from_flags(input logic [4:0] flags);
        // flags = {S,Z,U,V,D}; status = {busy,S,Z,0,D,U,V,0}
        begin
            status_from_flags = {1'b0, flags[4], flags[3], 1'b0,
                                 flags[0], flags[2], flags[1], 1'b0};
        end
    endfunction

    function automatic logic [7:0] status_from_sign_zero(input logic sign,
                                                         input logic zero);
        begin
            status_from_sign_zero = {1'b0, sign, zero, 1'b0,
                                     1'b0, 1'b0, 1'b0, 1'b0};
        end
    endfunction

    function automatic logic [127:0] data_op_stack(input logic [6:0] op);
        logic [31:0] tos;
        logic [63:0] dtos;
        begin
            tos = stack_q[127:96];
            dtos = stack_q[127:64];
            case (op)
                AMD_AM9512_OP_CLR: data_op_stack = stack_q;
                AMD_AM9512_OP_CHSS: begin
                    if (tos[30:23] == 8'd0)
                        data_op_stack = {32'd0, stack_q[95:0]};
                    else
                        data_op_stack = {tos ^ 32'h8000_0000, stack_q[95:0]};
                end
                AMD_AM9512_OP_CHSD: begin
                    if (dtos[62:52] == 11'd0)
                        data_op_stack = {64'd0, stack_q[63:0]};
                    else
                        data_op_stack = {dtos ^ 64'h8000_0000_0000_0000,
                                         stack_q[63:0]};
                end
                AMD_AM9512_OP_PTOS: begin
                    if (tos[30:23] == 8'd0)
                        data_op_stack = {32'd0, tos, stack_q[95:32]};
                    else
                        data_op_stack = {tos, tos, stack_q[95:32]};
                end
                AMD_AM9512_OP_PTOD: data_op_stack = {dtos, dtos};
                AMD_AM9512_OP_POPS: data_op_stack = {stack_q[95:0], stack_q[127:96]};
                AMD_AM9512_OP_POPD: data_op_stack = {stack_q[63:0], stack_q[127:64]};
                AMD_AM9512_OP_XCHS: data_op_stack = {stack_q[95:64], stack_q[127:96],
                                                     stack_q[63:0]};
                default: data_op_stack = stack_q;
            endcase
        end
    endfunction

    function automatic logic [7:0] data_op_status(input logic [6:0] op);
        logic sign;
        logic zero;
        begin
            case (op)
                AMD_AM9512_OP_CLR: data_op_status = 8'h00;
                AMD_AM9512_OP_CHSS: begin
                    zero = (stack_q[126:119] == 8'd0);
                    sign = zero ? 1'b0 : ~stack_q[127];
                    data_op_status = status_from_sign_zero(sign, zero);
                end
                AMD_AM9512_OP_CHSD: begin
                    zero = (stack_q[126:116] == 11'd0);
                    sign = zero ? 1'b0 : ~stack_q[127];
                    data_op_status = status_from_sign_zero(sign, zero);
                end
                AMD_AM9512_OP_PTOS: begin
                    zero = (stack_q[126:119] == 8'd0);
                    sign = zero ? 1'b0 : stack_q[127];
                    data_op_status = status_from_sign_zero(sign, zero);
                end
                AMD_AM9512_OP_PTOD: begin
                    zero = (stack_q[126:116] == 11'd0);
                    sign = zero ? 1'b0 : stack_q[127];
                    data_op_status = status_from_sign_zero(sign, zero);
                end
                AMD_AM9512_OP_POPS: begin
                    zero = (stack_q[94:87] == 8'd0);
                    sign = zero ? 1'b0 : stack_q[95];
                    data_op_status = status_from_sign_zero(sign, zero);
                end
                AMD_AM9512_OP_POPD: begin
                    zero = (stack_q[62:52] == 11'd0);
                    sign = zero ? 1'b0 : stack_q[63];
                    data_op_status = status_from_sign_zero(sign, zero);
                end
                AMD_AM9512_OP_XCHS: begin
                    zero = (stack_q[94:87] == 8'd0);
                    sign = zero ? 1'b0 : stack_q[95];
                    data_op_status = status_from_sign_zero(sign, zero);
                end
                default: data_op_status = 8'h00;
            endcase
        end
    endfunction

    function automatic logic [1:0] op_from_command(input logic [6:0] op);
        begin
            case (op)
                AMD_AM9512_OP_SADD, AMD_AM9512_OP_DADD: op_from_command = 2'd0;
                AMD_AM9512_OP_SSUB, AMD_AM9512_OP_DSUB: op_from_command = 2'd1;
                AMD_AM9512_OP_SMUL, AMD_AM9512_OP_DMUL: op_from_command = 2'd2;
                AMD_AM9512_OP_SDIV, AMD_AM9512_OP_DDIV: op_from_command = 2'd3;
                default: op_from_command = 2'd0;
            endcase
        end
    endfunction

    task automatic finish(input logic svreq,
                          input logic [127:0] new_stack,
                          input logic [7:0] new_status);
        begin
            stack_q <= new_stack;
            status_q <= new_status;
            state <= ST_IDLE;
            completion_pulse <= 1'b1;
            end_pending <= 1'b1;
            service_pending <= svreq && svack_n_i;
            if (new_status[3:1] != 3'b000)
                err_q <= 1'b1;
        end
    endtask

    amd_am9512_fpu #(
        .MANT_W(24), .EXP_W(8), .BIAS(127)
    ) single_unit (
        .clk_i(clk_i), .reset_i(reset_i), .start_i(s_start),
        .op_i(op_from_command(data_i[6:0])),
        .a_i(stack_q[127:96]), .b_i(stack_q[95:64]),
        .done_o(s_done), .busy_o(s_busy), .result_o(s_result), .status_o(s_status)
    );

    amd_am9512_fpu #(
        .MANT_W(53), .EXP_W(11), .BIAS(1023)
    ) double_unit (
        .clk_i(clk_i), .reset_i(reset_i), .start_i(d_start),
        .op_i(op_from_command(data_i[6:0])),
        .a_i(stack_q[127:64]), .b_i(stack_q[63:0]),
        .done_o(d_done), .busy_o(d_busy), .result_o(d_result), .status_o(d_status)
    );

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            state <= ST_IDLE;
            stack_q <= {128{1'b0}};
            command_q <= 8'h00;
            status_q <= 8'h00;
            read_latch <= 8'h00;
            cycle_done <= 1'b0;
            end_pending <= 1'b0;
            completion_pulse <= 1'b0;
            service_pending <= 1'b0;
            err_q <= 1'b0;
        end else begin
            completion_pulse <= 1'b0;
            if (!eack_n_i)
                end_pending <= 1'b0;
            if (!svack_n_i)
                service_pending <= 1'b0;

            if (state == ST_WAIT && unit_done) begin
                if (is_single_arith(command_q[6:0]))
                    finish(command_q[7],
                           {s_result, stack_q[63:0], 32'd0},
                           status_from_flags(s_status));
                else
                    finish(command_q[7],
                           {d_result, 64'd0},
                           status_from_flags(d_status));
            end else if (active && !cycle_done) begin
                end_pending <= 1'b0;
                if (status_read) begin
                    cycle_done <= 1'b1;
                    read_latch <= status_q;
                    err_q <= 1'b0;
                end else if (state == ST_IDLE) begin
                    cycle_done <= 1'b1;
                    if (!rd_n_i) begin
                        // data read
                        read_latch <= stack_q[127:120];
                        stack_q <= {stack_q[119:0], stack_q[127:120]};
                    end else if (!wr_n_i) begin
                        if (cd_i) begin
                            command_q <= data_i;
                            if (is_single_arith(data_i[6:0]) ||
                                is_double_arith(data_i[6:0])) begin
                                state <= ST_WAIT;
                                status_q <= {1'b1, 7'b0};
                            end else begin
                                finish(data_i[7], data_op_stack(data_i[6:0]),
                                       data_op_status(data_i[6:0]));
                            end
                        end else begin
                            // data write
                            stack_q <= {data_i, stack_q[127:8]};
                        end
                    end
                end else if (!cd_i && (!rd_n_i || !wr_n_i)) begin
                    // Data reads and writes are allowed while a command runs.
                    cycle_done <= 1'b1;
                    if (!rd_n_i) begin
                        read_latch <= stack_q[127:120];
                        stack_q <= {stack_q[119:0], stack_q[127:120]};
                    end else begin
                        stack_q <= {data_i, stack_q[127:8]};
                    end
                end
            end else if (!active) begin
                cycle_done <= 1'b0;
            end
        end
    end

`ifdef FORMAL
`include "amd_am9512_props.sv"
`endif

endmodule
