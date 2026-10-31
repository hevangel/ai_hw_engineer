// Reference from pinned 86Box x86seg.c loadseg_2386 type lists/decision order,
// not from RTL. Byte layout independently pinned to PCjs segx86.js.
`ifdef FORMAL
module intel_80286_segment_check_props (
    input logic [15:0] selector, table_limit,
    input logic [1:0] cpl,
    input logic stack_target, ldt_valid, descriptor_valid,
    input logic [47:0] descriptor
);
    logic needed, checked_result, valid_cache, fault;
    logic [15:0] offset, error, limit_value;
    logic [7:0] vector, access_value, accessed_value;
    logic [23:0] base;
    integer unsigned sel, relative, rights, kind, privilege, requested;
    logic expected_needed, expected_done, expected_valid, expected_fault, allowed;
    logic [7:0] expected_vector;
    logic [15:0] expected_error;
    intel_80286_segment_check dut(.selector_i(selector),.table_limit_i(table_limit),.cpl_i(cpl),
        .stack_i(stack_target),.ldt_valid_i(ldt_valid),.descriptor_valid_i(descriptor_valid),
        .descriptor_i(descriptor),.descriptor_offset_o(offset),.descriptor_needed_o(needed),
        .checked_o(checked_result),.cache_valid_o(valid_cache),.fault_o(fault),
        .fault_vector_o(vector),.fault_error_o(error),.base_o(base),.limit_o(limit_value),
        .access_o(access_value),.accessed_value_o(accessed_value));
    always_comb begin
        sel={16'h0,selector}; relative=(sel/8)*8; requested=sel%4;
        rights={24'h0,descriptor[47:40]}; kind=rights%32; privilege=(rights/32)%4;
        expected_needed=0; expected_done=1; expected_valid=0; expected_fault=0;
        expected_vector=0; expected_error=0; allowed=0;
        if (sel/4==0) begin
            if (stack_target) begin expected_fault=1; expected_vector=13; end
        end else if (((sel/4)%2 && !ldt_valid) || relative+7>{16'h0,table_limit}) begin
            expected_fault=1; expected_vector=13; expected_error=16'((sel/4)*4);
        end else begin
            expected_needed=1; expected_done=descriptor_valid;
            if (descriptor_valid) begin
                // This enumeration is the independent artifact's accepted
                // descriptor list, rather than the implementation's bit tests.
                if (stack_target) begin
                    case (kind)
                        18,19,22,23: allowed=requested=={30'h0,cpl} && privilege=={30'h0,cpl};
                        default: allowed=0;
                    endcase
                end else begin
                    case (kind)
                        16,17,18,19,20,21,22,23,26,27:
                            allowed=requested<=privilege && {30'h0,cpl}<=privilege;
                        30,31: allowed=1;
                        default: allowed=0;
                    endcase
                end
                if (!allowed) begin expected_fault=1; expected_vector=13; end
                else if (rights<128) begin expected_fault=1; expected_vector=stack_target ? 12 : 11; end
                else expected_valid=1;
                if (expected_fault) expected_error=16'((sel/4)*4);
            end
        end
        assert(offset==16'(relative));
        assert(needed==expected_needed && checked_result==expected_done);
        assert(valid_cache==expected_valid && fault==expected_fault);
        assert(vector==expected_vector && error==expected_error);
        if (expected_valid) begin
            assert(base==24'(descriptor/65536));
            assert(limit_value==16'(descriptor%65536));
            assert(access_value==8'(rights) && accessed_value==8'(rights|1));
        end else assert(base==0 && limit_value==0 && access_value==0 && accessed_value==0);
        cover(valid_cache && selector[2] && selector[15:3]==0);
        cover(checked_result && !needed && !fault && selector==3);
        cover(fault && vector==12);
        cover(fault && vector==11);
        cover(valid_cache && kind==30 && privilege<requested && privilege<{30'h0,cpl});
        cover(valid_cache && selector==16'hfff8 && table_limit==16'hffff);
    end
endmodule
`endif
