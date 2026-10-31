// Ordinary protected DS/ES/SS loads; Intel 210498-005 7.3/7.4.
// No bus transaction or cache commit occurs inside this combinational unit.
module intel_80286_segment_check (
    input logic [15:0] selector_i, table_limit_i,
    input logic [1:0] cpl_i,
    input logic stack_i, ldt_valid_i, descriptor_valid_i,
    input logic [47:0] descriptor_i,
    output logic [15:0] descriptor_offset_o,
    output logic descriptor_needed_o, checked_o, cache_valid_o, fault_o,
    output logic [7:0] fault_vector_o,
    output logic [15:0] fault_error_o,
    output logic [23:0] base_o,
    output logic [15:0] limit_o,
    output logic [7:0] access_o, accessed_value_o,
    // Classification-only bits: {S, executable, writable}; never a cache value.
    output logic [2:0] descriptor_class_o
);
    logic null_selector, table_valid, type_valid, privilege_valid;
    logic [7:0] access_byte;
    logic [1:0] dpl, rpl;
    logic [16:0] descriptor_last;
    always_comb begin
        descriptor_offset_o={selector_i[15:3],3'b000};
        descriptor_last={1'b0,descriptor_offset_o}+17'd7;
        null_selector=selector_i[15:2]==0;
        table_valid=(!selector_i[2] || ldt_valid_i) &&
                    descriptor_last<={1'b0,table_limit_i};
        access_byte=descriptor_i[47:40]; dpl=access_byte[6:5]; rpl=selector_i[1:0];
        descriptor_class_o=descriptor_valid_i ?
            {access_byte[4],access_byte[3],access_byte[1]} : 3'd0;
        if (stack_i) begin
            type_valid=access_byte[4] && !access_byte[3] && access_byte[1];
            privilege_valid=rpl==cpl_i && dpl==cpl_i;
        end else begin
            type_valid=access_byte[4] && (!access_byte[3] || access_byte[1]);
            privilege_valid=(access_byte[3] && access_byte[2]) || (rpl<=dpl && cpl_i<=dpl);
        end
        descriptor_needed_o=!null_selector && table_valid;
        checked_o=!descriptor_needed_o || descriptor_valid_i;
        cache_valid_o=0; fault_o=0; fault_vector_o=0; fault_error_o=0;
        base_o=0; limit_o=0; access_o=0; accessed_value_o=0;
        if (null_selector) begin
            if (stack_i) begin fault_o=1; fault_vector_o=13; end
        end else if (!table_valid) begin
            fault_o=1; fault_vector_o=13; fault_error_o={selector_i[15:2],2'b00};
        end else if (descriptor_valid_i) begin
            if (!type_valid || !privilege_valid) begin
                fault_o=1; fault_vector_o=13; fault_error_o={selector_i[15:2],2'b00};
            end else if (!access_byte[7]) begin
                fault_o=1; fault_vector_o=stack_i ? 8'd12 : 8'd11;
                fault_error_o={selector_i[15:2],2'b00};
            end else begin
                cache_valid_o=1; base_o=descriptor_i[39:16]; limit_o=descriptor_i[15:0];
                access_o=access_byte; accessed_value_o=access_byte|8'h01;
            end
        end
    end
endmodule
