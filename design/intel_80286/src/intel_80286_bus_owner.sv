// Exclusive functional-bus owner for CPU, descriptor and event transactions.
// A claim is accepted only while the CPU has no request. Descriptor/event
// ownership lasts through quiet engine cycles until release is safe.
// Claim inputs are levels held until their requester receives ownership; an
// event wins a simultaneous idle claim, then a waiting descriptor can acquire.
module intel_80286_bus_owner #(
    /* verilator lint_off UNUSEDPARAM */
    parameter bit FORMAL_PROPERTIES=1'b1,
    /* verilator lint_on UNUSEDPARAM */
    parameter int unsigned CONTEXT_WIDTH=32
) (
    input logic clk, rst_n,
    input logic cpu_req_i,
    input logic [23:0] cpu_addr_i,
    input logic cpu_write_i,
    input logic [7:0] cpu_wdata_i,
    input logic [CONTEXT_WIDTH-1:0] cpu_context_i,
    input logic descriptor_claim_i, descriptor_release_i, descriptor_req_i,
    input logic [23:0] descriptor_addr_i,
    input logic descriptor_write_i,
    input logic [7:0] descriptor_wdata_i,
    input logic [CONTEXT_WIDTH-1:0] descriptor_context_i,
    input logic event_claim_i, event_release_i, event_req_i,
    input logic [23:0] event_addr_i,
    input logic event_write_i,
    input logic [7:0] event_wdata_i,
    input logic [CONTEXT_WIDTH-1:0] event_context_i,
    input logic bus_ready_i,
    input logic [7:0] bus_rdata_i,
    output logic bus_req_o,
    output logic [23:0] bus_addr_o,
    output logic bus_write_o,
    output logic [7:0] bus_wdata_o,
    output logic [CONTEXT_WIDTH-1:0] bus_context_o,
    output logic cpu_grant_o, descriptor_grant_o, event_grant_o,
    output logic cpu_ready_o, descriptor_ready_o, event_ready_o,
    output logic [7:0] bus_rdata_o,
    output logic [1:0] owner_o
);
    localparam [1:0] CPU=0, DESCRIPTOR=1, EVENT=2;
    logic [1:0] owner;
    logic inflight;
    logic [23:0] held_addr;
    logic held_write;
    logic [7:0] held_wdata;
    logic [CONTEXT_WIDTH-1:0] held_context;
    logic held_req;
    logic selected_req;
    logic [23:0] selected_addr;
    logic selected_write;
    logic [7:0] selected_wdata;
    logic [CONTEXT_WIDTH-1:0] selected_context;

    assign owner_o=owner;
    assign cpu_grant_o=owner==CPU;
    assign descriptor_grant_o=owner==DESCRIPTOR;
    assign event_grant_o=owner==EVENT;
    assign bus_rdata_o=bus_rdata_i;

    always_comb begin
        selected_req=1'b0;
        selected_addr=24'd0;
        selected_write=1'b0;
        selected_wdata=8'd0;
        selected_context='0;
        case (owner)
            CPU: begin
                selected_req=cpu_req_i;
                selected_addr=cpu_addr_i;
                selected_write=cpu_write_i;
                selected_wdata=cpu_wdata_i;
                selected_context=cpu_context_i;
            end
            DESCRIPTOR: begin
                selected_req=descriptor_req_i;
                selected_addr=descriptor_addr_i;
                selected_write=descriptor_write_i;
                selected_wdata=descriptor_wdata_i;
                selected_context=descriptor_context_i;
            end
            EVENT: begin
                selected_req=event_req_i;
                selected_addr=event_addr_i;
                selected_write=event_write_i;
                selected_wdata=event_wdata_i;
                selected_context=event_context_i;
            end
            default: begin end
        endcase
        bus_req_o=rst_n && (inflight ? held_req : selected_req);
        bus_addr_o=inflight ? held_addr : selected_addr;
        bus_write_o=inflight ? held_write : selected_write;
        bus_wdata_o=inflight ? held_wdata : selected_wdata;
        bus_context_o=inflight ? held_context : selected_context;
        cpu_ready_o=rst_n && cpu_grant_o && bus_req_o && bus_ready_i;
        descriptor_ready_o=rst_n && descriptor_grant_o && bus_req_o && bus_ready_i;
        event_ready_o=rst_n && event_grant_o && bus_req_o && bus_ready_i;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            owner<=CPU;
            inflight<=0;
            held_req<=0;
            held_addr<=0;
            held_write<=0;
            held_wdata<=0;
            held_context<='0;
        end else begin
            if (inflight) begin
                if (bus_ready_i) begin
                    inflight<=0;
                    held_req<=0;
                end
            end else if (selected_req && !bus_ready_i) begin
                inflight<=1;
                held_req<=selected_req;
                held_addr<=selected_addr;
                held_write<=selected_write;
                held_wdata<=selected_wdata;
                held_context<=selected_context;
            end
            case (owner)
            CPU: begin
                if (!bus_req_o) begin
                    if (event_claim_i) owner<=EVENT;
                    else if (descriptor_claim_i) owner<=DESCRIPTOR;
                end
            end
            DESCRIPTOR: if (descriptor_release_i && (!bus_req_o || bus_ready_i)) owner<=CPU;
            EVENT: if (event_release_i && (!bus_req_o || bus_ready_i)) owner<=CPU;
            default: owner<=CPU;
            endcase
        end
    end

`ifdef FORMAL
    if (FORMAL_PROPERTIES) begin : formal_checks
        `include "intel_80286_bus_owner_props.sv"
    end
`endif
endmodule
