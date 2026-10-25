// Functional event selection; Intel 210498-005 sections 9.2 and 9.5.
// Caller qualifies architectural boundaries, instruction exceptions and TF.
// ASSUMPTION: A8. Atomic functional selection/ack, synchronized NMI level;
// native INTA timing and CPU boundary semantics require separate validation.
module intel_80286_event_control (
    input logic clk, rst_n,
    input logic boundary_i, inhibit_i, step_i, if_i, intr_i, nmi_i, iret_i,
    input logic ack_ready_i,
    input logic [7:0] ack_vector_i,
    output logic ack_req_o,
    output logic event_valid_o,
    output logic [7:0] event_vector_o,
    input logic event_ready_i,
    output logic nmi_pending_o, nmi_blocked_o
);
    localparam [1:0] IDLE=0, ACKNOWLEDGE=1, DELIVER=2;
    logic [1:0] state;
    logic nmi_previous, nmi_edge, select_nmi;
    assign nmi_edge = nmi_i && !nmi_previous;
    assign select_nmi = state==IDLE && boundary_i && !inhibit_i && !step_i &&
                        (!nmi_blocked_o || iret_i) && (nmi_pending_o || nmi_edge);
    assign ack_req_o = rst_n && state==ACKNOWLEDGE;
    assign event_valid_o = rst_n && state==DELIVER;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state<=IDLE; nmi_previous<=0; nmi_pending_o<=0;
            nmi_blocked_o<=0; event_vector_o<=0;
        end else begin
            nmi_previous<=nmi_i;
            if (nmi_edge) nmi_pending_o<=1;
            if (iret_i) nmi_blocked_o<=0;
            if (select_nmi) begin nmi_pending_o<=0; nmi_blocked_o<=1; end
            case (state)
                IDLE: if (boundary_i && !inhibit_i) begin
                    if (step_i) begin event_vector_o<=1; state<=DELIVER; end
                    else if (select_nmi) begin event_vector_o<=2; state<=DELIVER; end
                    else if (intr_i && if_i) state<=ACKNOWLEDGE;
                end
                ACKNOWLEDGE: if (ack_ready_i) begin
                    event_vector_o<=ack_vector_i; state<=DELIVER;
                end
                DELIVER: if (event_ready_i) state<=IDLE;
                default: state<=IDLE;
            endcase
        end
    end
`ifdef FORMAL
    logic past_valid=0;
    always_ff @(posedge clk) begin
        past_valid<=1;
        if (!past_valid) assume(!rst_n);
        if (past_valid) begin
            assert(state<=DELIVER);
            if ($past(rst_n)) assert(nmi_previous==$past(nmi_i));
            else assert(!nmi_previous);
        end
    end
`endif
endmodule
