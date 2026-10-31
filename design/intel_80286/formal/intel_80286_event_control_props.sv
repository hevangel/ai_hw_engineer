// Temporal contracts from Intel 210498-005 sections 9.2/9.5 and A8,
// not an instruction reference model. All transaction inputs are arbitrary.
module intel_80286_event_control_props (
    input logic clk, rst_n,
    input logic boundary, inhibit, step_request, interrupts_enabled, intr, nmi, iret,
    input logic shutdown, shutdown_nmi_enable,
    input logic ack_ready, event_ready,
    input logic [7:0] ack_vector
);
    logic ack, valid, pending, blocked;
    logic [7:0] vector;
    logic past_valid=0;
    logic selected, was_nmi, waiting_ack;
    logic [7:0] claimed_vector;
    logic nmi_history, remembered;
    logic saw_blocked_edge, saw_ack_stall, saw_delivery_stall;
    intel_80286_event_control dut(.clk(clk),.rst_n(rst_n),.boundary_i(boundary),
        .inhibit_i(inhibit),.step_i(step_request),.if_i(interrupts_enabled),
        .intr_i(intr),.nmi_i(nmi),.iret_i(iret),.ack_ready_i(ack_ready),
        .shutdown_i(shutdown),.shutdown_nmi_enable_i(shutdown_nmi_enable),
        .ack_vector_i(ack_vector),.ack_req_o(ack),.event_valid_o(valid),
        .event_vector_o(vector),.event_ready_i(event_ready),
        .nmi_pending_o(pending),.nmi_blocked_o(blocked));
    // Independent protocol monitor: selection, acknowledgement and delivery
    // are tracked without accessing the DUT state encoding or internal signals.
    always_ff @(posedge clk) begin
        past_valid<=1;
        if (!past_valid) assume(!rst_n);
        if (!rst_n) begin
            selected<=0; was_nmi<=0; waiting_ack<=0; claimed_vector<=0;
            nmi_history<=0; remembered<=0;
            saw_blocked_edge<=0; saw_ack_stall<=0; saw_delivery_stall<=0;
        end else begin
            nmi_history<=nmi;
            if (nmi && !nmi_history) remembered<=1;
            if (shutdown && !shutdown_nmi_enable) remembered<=0;
            if (iret) was_nmi<=0;
            if (!selected) begin
                if (shutdown) begin
                    if (shutdown_nmi_enable &&
                        (remembered || (nmi && !nmi_history))) begin
                        selected<=1; claimed_vector<=2; was_nmi<=1; remembered<=0;
                    end
                end else if (boundary && !inhibit) begin
                    if (step_request) begin selected<=1; claimed_vector<=1; end
                    else if ((!was_nmi || iret) && (remembered || (nmi && !nmi_history))) begin
                        selected<=1; claimed_vector<=2; was_nmi<=1; remembered<=0;
                    end else if (intr && interrupts_enabled) begin selected<=1; waiting_ack<=1; end
                end
            end
            if (ack && ack_ready) begin waiting_ack<=0; claimed_vector<=ack_vector; end
            if (valid && event_ready) selected<=0;
            if (blocked && nmi && !nmi_history) saw_blocked_edge<=1;
            if (ack && !ack_ready) saw_ack_stall<=1;
            if (valid && !event_ready) saw_delivery_stall<=1;
        end
        if (past_valid) begin
            assert(!(ack && valid));
            if (!rst_n) assert(!ack && !valid);
            if (rst_n) begin
                assert(!waiting_ack || selected);
                assert(ack==(selected && waiting_ack));
                assert(valid==(selected && !waiting_ack));
                assert(blocked==was_nmi && pending==remembered);
                if (valid) assert(vector==claimed_vector);
            end
            if ($past(rst_n)) assert(nmi_history==$past(nmi));
            else assert(!nmi_history);
            if (!$past(rst_n)) assert(!pending && !blocked);
            if (rst_n && $past(rst_n && ack && !ack_ready)) assert(ack);
            if (rst_n && $past(rst_n && valid && !event_ready)) begin
                assert(valid); assert(vector==$past(vector));
            end
            cover(rst_n && valid && vector==2 && saw_blocked_edge && blocked);
            cover(rst_n && valid && saw_ack_stall && saw_delivery_stall);
            cover(rst_n && valid && vector==1 && pending);
            cover(rst_n && ack && pending);
            cover(rst_n && shutdown && shutdown_nmi_enable && valid &&
                  vector==2 && blocked);
            cover(!rst_n && $past(ack));
            cover(!rst_n && $past(valid));
        end
    end
endmodule
