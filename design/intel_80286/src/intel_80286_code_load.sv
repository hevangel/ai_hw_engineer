// Ordinary CS load transaction; architectural CS/IP and CALL commit are external.
// ASSUMPTION: A13. Validate before the functional accessed-byte write; A11 byte
// scheduling/modulo-24 addressing applies. See code_load_transaction.md.
module intel_80286_code_load (
    input logic clk, rst_n, start_i,
    input logic [15:0] selector_i, offset_i, gdt_limit_i, ldt_limit_i,
    input logic [23:0] gdt_base_i, ldt_base_i,
    input logic [1:0] cpl_i,
    input logic call_i, gate_call_i, stack_ok_i, ldt_valid_i,
    output logic busy_o, done_o,
    output logic bus_req_o, bus_write_o,
    output logic [23:0] bus_addr_o,
    output logic [7:0] bus_wdata_o,
    input logic bus_ready_i,
    input logic [7:0] bus_rdata_i,
    output logic fault_o, cache_valid_o, special_o,
    output logic [7:0] fault_vector_o, access_o,
    output logic [15:0] fault_error_o, selector_o, limit_o,
    output logic [15:0] request_selector_o, request_offset_o,
    output logic [23:0] base_o,
    output logic [47:0] special_descriptor_o,
    output logic [15:0] special_tail_o
);
    localparam [2:0] IDLE=0, PRECHECK=1, READ_DESCRIPTOR=2, VALIDATE=3, WRITE_ACCESSED=4;
    logic [2:0] state, byte_index;
    logic [15:0] saved_selector, saved_offset, saved_table_limit;
    logic [23:0] saved_table_base, descriptor_address;
    logic [1:0] saved_cpl;
    logic saved_call, saved_gate_call, saved_stack_ok, saved_ldt_valid;
    logic [47:0] descriptor;
    logic [15:0] descriptor_tail;
    logic check_needed, check_done, check_valid, check_special, check_fault;
    logic [15:0] check_offset, check_error, check_selector, check_limit;
    logic [7:0] check_vector, check_access, check_accessed;
    logic [23:0] check_base;

    intel_80286_code_check check_code(.selector_i(saved_selector),.offset_i(saved_offset),.cpl_i(saved_cpl),
        .call_i(saved_call),.gate_call_i(saved_gate_call),.stack_ok_i(saved_stack_ok),
        .ldt_valid_i(saved_ldt_valid),.table_limit_i(saved_table_limit),
        .descriptor_valid_i(state==VALIDATE || state==WRITE_ACCESSED),.descriptor_i(descriptor),
        .descriptor_offset_o(check_offset),.descriptor_needed_o(check_needed),.checked_o(check_done),
        .cache_valid_o(check_valid),.special_o(check_special),.fault_o(check_fault),.fault_vector_o(check_vector),
        .fault_error_o(check_error),.selector_o(check_selector),.base_o(check_base),.limit_o(check_limit),
        .access_o(check_access),.accessed_value_o(check_accessed));

    assign busy_o=state!=IDLE;
    assign bus_req_o=rst_n && (state==READ_DESCRIPTOR || state==WRITE_ACCESSED);
    assign bus_write_o=state==WRITE_ACCESSED;
    assign bus_addr_o=descriptor_address+(state==WRITE_ACCESSED ? 24'd5 : {21'h0,byte_index});
    assign bus_wdata_o=check_accessed;
    task automatic complete_load;
        done_o<=1; state<=IDLE;
        request_selector_o<=saved_selector; request_offset_o<=saved_offset;
        selector_o<=check_selector; fault_o<=check_fault; special_o<=check_special;
        fault_vector_o<=check_vector; fault_error_o<=check_error;
        cache_valid_o<=check_valid; base_o<=check_base; limit_o<=check_limit; access_o<=check_access;
        special_descriptor_o<=check_special ? descriptor : 48'h0;
        special_tail_o<=check_special ? descriptor_tail : 16'h0;
    endtask
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state<=IDLE; byte_index<=0; descriptor<=0; descriptor_tail<=0; descriptor_address<=0;
            saved_selector<=0; saved_offset<=0; saved_table_base<=0; saved_table_limit<=0;
            saved_cpl<=0; saved_call<=0; saved_gate_call<=0; saved_stack_ok<=0; saved_ldt_valid<=0;
            done_o<=0; fault_o<=0; fault_vector_o<=0; fault_error_o<=0;
            cache_valid_o<=0; special_o<=0; selector_o<=0; base_o<=0; limit_o<=0; access_o<=0;
            request_selector_o<=0; request_offset_o<=0; special_descriptor_o<=0; special_tail_o<=0;
        end else begin
            done_o<=0;
            case (state)
                IDLE: if (start_i) begin
                    saved_selector<=selector_i; saved_offset<=offset_i; saved_cpl<=cpl_i;
                    saved_call<=call_i; saved_gate_call<=gate_call_i;
                    saved_stack_ok<=stack_ok_i; saved_ldt_valid<=ldt_valid_i;
                    saved_table_base<=selector_i[2] ? ldt_base_i : gdt_base_i;
                    saved_table_limit<=selector_i[2] ? ldt_limit_i : gdt_limit_i;
                    descriptor<=0; descriptor_tail<=0; byte_index<=0; state<=PRECHECK;
                end
                PRECHECK: if (check_done) complete_load();
                          else if (check_needed) begin
                              descriptor_address<=saved_table_base+{8'h0,check_offset};
                              state<=READ_DESCRIPTOR;
                          end
                READ_DESCRIPTOR: if (bus_ready_i) begin
                    if (byte_index<6) descriptor[byte_index*8 +: 8]<=bus_rdata_i;
                    else descriptor_tail[(byte_index-6)*8 +: 8]<=bus_rdata_i;
                    if (byte_index==7) state<=VALIDATE;
                    else byte_index<=byte_index+3'd1;
                end
                VALIDATE: if (check_fault || check_special) complete_load();
                          else if (check_valid) state<=WRITE_ACCESSED;
                WRITE_ACCESSED: if (bus_ready_i) complete_load();
                default: state<=IDLE;
            endcase
        end
    end
`ifdef FORMAL
    `include "intel_80286_code_load_props.sv"
`endif
endmodule
