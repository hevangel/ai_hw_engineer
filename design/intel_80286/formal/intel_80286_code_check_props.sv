// Independent reference: Intel Appendix B enumerated code types and ordered
// JMP/CALL checks; pinned 86Box corroborates privilege/RPL normalization.
`ifdef FORMAL
`default_nettype none
module intel_80286_code_check_props (
    input logic [15:0] selector, table_limit, ip_value,
    input logic [1:0] cpl,
    input logic ldt_valid, descriptor_valid, is_call, gate_call, stack_ok,
    input logic [47:0] descriptor
);
    logic needed, checked_result, valid_cache, special_result, fault;
    logic [15:0] offset, error, code_selector, limit_value;
    logic [7:0] vector, access_value, accessed_value;
    logic [23:0] base;
    integer unsigned sel, relative, rights, kind, privilege, requested;
    logic expected_needed, expected_done, expected_valid, expected_special, expected_fault, allowed;
    logic [7:0] expected_vector;
    logic [15:0] expected_error;
    intel_80286_code_check dut(.selector_i(selector),.table_limit_i(table_limit),.offset_i(ip_value),
        .cpl_i(cpl),.ldt_valid_i(ldt_valid),.descriptor_valid_i(descriptor_valid),
        .call_i(is_call),.gate_call_i(gate_call),.stack_ok_i(stack_ok),.descriptor_i(descriptor),
        .descriptor_offset_o(offset),.descriptor_needed_o(needed),.checked_o(checked_result),
        .cache_valid_o(valid_cache),.special_o(special_result),.fault_o(fault),
        .fault_vector_o(vector),.fault_error_o(error),.selector_o(code_selector),
        .base_o(base),.limit_o(limit_value),.access_o(access_value),.accessed_value_o(accessed_value));
    always_comb begin
        sel={16'h0,selector}; relative=(sel/8)*8; requested=sel%4;
        rights={24'h0,descriptor[47:40]}; kind=rights%32; privilege=(rights/32)%4;
        expected_needed=0; expected_done=1; expected_valid=0; expected_special=0;
        expected_fault=0; expected_vector=0; expected_error=0; allowed=0;
        if (sel/4==0) begin expected_fault=1; expected_vector=13; end
        else if (((sel/4)%2 && !ldt_valid) || relative+7>{16'h0,table_limit}) begin
            expected_fault=1; expected_vector=13; expected_error=16'((sel/4)*4);
        end else begin
            expected_needed=1; expected_done=descriptor_valid;
            if (descriptor_valid) begin
                case (kind)
                    24,25,26,27: allowed=gate_call ? privilege<={30'h0,cpl} :
                        requested<={30'h0,cpl} && privilege=={30'h0,cpl};
                    28,29,30,31: allowed=privilege<={30'h0,cpl};
                    default: allowed=0;
                endcase
                if (kind<16) expected_special=1;
                else if (!allowed) begin
                    expected_fault=1; expected_vector=13; expected_error=16'((sel/4)*4);
                end else if (rights<128) begin
                    expected_fault=1; expected_vector=11; expected_error=16'((sel/4)*4);
                end else if (is_call && !stack_ok) begin expected_fault=1; expected_vector=12; end
                else if ({16'h0,ip_value}>{16'h0,descriptor[15:0]}) begin expected_fault=1; expected_vector=13; end
                else expected_valid=1;
            end
        end
        assert(offset==16'(relative) && needed==expected_needed && checked_result==expected_done);
        assert(valid_cache==expected_valid && special_result==expected_special && fault==expected_fault);
        assert(vector==expected_vector && error==expected_error);
        if (expected_valid) begin
            assert(code_selector==16'((sel/4)*4+
                (gate_call && kind>=24 && kind<=27 ? privilege : {30'h0,cpl})));
            assert(base==24'(descriptor/65536) && limit_value==16'(descriptor%65536));
            assert(access_value==8'(rights) && accessed_value==8'(rights|1));
        end else assert(code_selector==0 && base==0 && limit_value==0 && access_value==0 && accessed_value==0);
        cover(valid_cache && requested>{30'h0,cpl} && privilege<{30'h0,cpl});
        cover(valid_cache && gate_call && kind>=24 && kind<=27 && privilege<{30'h0,cpl});
        cover(special_result && rights==4);
        cover(fault && vector==13 && rights==16);
        cover(fault && vector==11 && is_call && !stack_ok && ip_value>descriptor[15:0]);
        cover(fault && vector==12 && ip_value>descriptor[15:0]);
        cover(fault && vector==13 && error==0 && needed);
        cover(valid_cache && selector==7 && ldt_valid);
        cover(valid_cache && selector==16'hfff8 && table_limit==16'hffff);
    end
endmodule
`default_nettype wire
`endif
