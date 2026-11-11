// Formal transport proof for the Am9512 stack, status and bus interface.
// The FPU is replaced by formal/model_fpu.sv, so numerical results are free;
// this proof checks the documented stack movement and handshake behavior.
`include "documented_stack.svh"

logic formal_past = 1'b0;
logic formal_finish = 1'b0;
logic [127:0] formal_stack = 128'd0;
logic [7:0] formal_status = 8'd0;

initial assume(reset_i);

always_comb begin
    formal_finish = (state == ST_WAIT && unit_done);
    formal_stack = documented_stack(command_q[6:0], stack_q, s_result, d_result);
    formal_status = documented_status(command_q[6:0], stack_q, s_status, d_status);
end

always_ff @(posedge clk_i) begin
    formal_past <= 1'b1;
    if (!formal_past)
        assume(reset_i);
    assume(rd_n_i || wr_n_i);

    if (formal_past) begin
        assert(status_q[0] == 1'b0);
        assert(status_q[4] == 1'b0);
        assert(state == ST_IDLE || state == ST_WAIT);
        assert(!(state == ST_WAIT) || status_q[7]);
        assert(!(state == ST_IDLE) || !status_q[7]);
        assert(!end_o || state == ST_IDLE);
        assert(!end_o || !status_q[7]);
        assert(data_oe_o == (!cs_n_i && !rd_n_i));
        assert(pause_n_o == !(!cs_n_i && ((rd_n_i && wr_n_i) ||
                                          (active && !cycle_done))));

        if ($past(reset_i)) begin
            assert(state == ST_IDLE);
            assert(stack_q == {128{1'b0}});
            assert(status_q == 8'h00);
            assert(!cycle_done);
            assert(!end_pending);
            assert(!service_pending);
            assert(!err_q);
        end else if ($past(formal_finish)) begin
            assert(state == ST_IDLE);
            assert(completion_pulse);
            assert(stack_q == documented_stack($past(command_q[6:0]),
                                               $past(stack_q),
                                               $past(s_result), $past(d_result)));
            assert(status_q == documented_status($past(command_q[6:0]),
                                                 $past(stack_q),
                                                 $past(s_status), $past(d_status)));
            assert(service_pending == ($past(command_q[7]) && $past(svack_n_i)));
        end else begin
            // Data accesses and command issue are covered by the directed
            // simulation vectors; the transport proof checks completed commands.
        end

        cover(state == ST_WAIT);
        cover(formal_finish && command_q[6:0] == AMD_AM9512_OP_SADD);
        cover(formal_finish && command_q[6:0] == AMD_AM9512_OP_DDIV);
        cover(!status_q[7] && status_q[3]);
        cover(!status_q[7] && status_q[2]);
        cover(!status_q[7] && status_q[1]);
        cover(svreq_o);
        cover(end_o);
        cover(reset_i && state == ST_WAIT);
    end
end