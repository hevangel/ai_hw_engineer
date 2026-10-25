// Intel 210498-005 Appendix B ordinary JMP/CALL checks, in documented order.
// System descriptors are deferred to the required gate/TSS resolver.
module intel_80286_code_check (
    input logic [15:0] selector_i, table_limit_i, offset_i,
    input logic [1:0] cpl_i,
    input logic ldt_valid_i, descriptor_valid_i, call_i, stack_ok_i,
    input logic [47:0] descriptor_i,
    output logic [15:0] descriptor_offset_o,
    output logic descriptor_needed_o, checked_o, cache_valid_o, special_o, fault_o,
    output logic [7:0] fault_vector_o,
    output logic [15:0] fault_error_o, selector_o, limit_o,
    output logic [23:0] base_o,
    output logic [7:0] access_o, accessed_value_o
);
    logic null_selector, table_valid, privilege_valid;
    logic [7:0] rights;
    logic [16:0] last_byte;
    always_comb begin
        descriptor_offset_o={selector_i[15:3],3'b000};
        last_byte={1'b0,descriptor_offset_o}+17'd7;
        null_selector=selector_i[15:2]==0;
        table_valid=(!selector_i[2] || ldt_valid_i) && last_byte<={1'b0,table_limit_i};
        rights=descriptor_i[47:40];
        privilege_valid=rights[2] ? rights[6:5]<=cpl_i :
            (rights[6:5]==cpl_i && selector_i[1:0]<=cpl_i);
        descriptor_needed_o=!null_selector && table_valid;
        checked_o=!descriptor_needed_o || descriptor_valid_i;
        cache_valid_o=0; special_o=0; fault_o=0; fault_vector_o=0; fault_error_o=0;
        selector_o=0; base_o=0; limit_o=0; access_o=0; accessed_value_o=0;
        if (null_selector) begin fault_o=1; fault_vector_o=13; end
        else if (!table_valid) begin
            fault_o=1; fault_vector_o=13; fault_error_o={selector_i[15:2],2'b00};
        end else if (descriptor_valid_i) begin
            if (!rights[4]) special_o=1;
            else if (!rights[3] || !privilege_valid) begin
                fault_o=1; fault_vector_o=13; fault_error_o={selector_i[15:2],2'b00};
            end else if (!rights[7]) begin
                fault_o=1; fault_vector_o=11; fault_error_o={selector_i[15:2],2'b00};
            end else if (call_i && !stack_ok_i) begin fault_o=1; fault_vector_o=12; end
            else if (offset_i>descriptor_i[15:0]) begin fault_o=1; fault_vector_o=13; end
            else begin
                cache_valid_o=1; selector_o={selector_i[15:2],cpl_i};
                base_o=descriptor_i[39:16]; limit_o=descriptor_i[15:0];
                access_o=rights; accessed_value_o=rights|8'h01;
            end
        end
    end
endmodule
