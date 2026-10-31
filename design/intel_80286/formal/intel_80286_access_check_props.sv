// Primary type lists plus pinned 86Box limit_low/limit_high interval reference.
`ifdef FORMAL
`default_nettype none
module intel_80286_access_check_props (
    input logic usable, ss,
    input logic [4:0] rights,
    input logic [15:0] limit_value, start_offset, displacement,
    input logic [1:0] operation
);
    logic allow_result, fault;
    logic [7:0] vector;
    logic [15:0] error;
    integer unsigned low_bound, high_bound, first_byte, final_byte, kind;
    logic permitted, expected;
    intel_80286_access_check dut(.cache_valid_i(usable),.stack_i(ss),.access_i(rights[4:1]),
        .limit_i(limit_value),.offset_i(start_offset),.last_delta_i(displacement),.kind_i(operation),
        .allow_o(allow_result),.fault_o(fault),.fault_vector_o(vector),.fault_error_o(error));
    always_comb begin
        kind={27'h0,rights}; first_byte={16'h0,start_offset};
        final_byte=first_byte+{16'h0,displacement};
        low_bound=0; high_bound={16'h0,limit_value}; permitted=0;
        if (kind>=20 && kind<=23) begin low_bound={16'h0,limit_value}+1; high_bound=65535; end
        case (operation)
            0: case (kind)
                16,17,18,19,20,21,22,23,26,27,30,31: permitted=1;
                default: permitted=0;
            endcase
            1,3: case (kind)
                18,19,22,23: permitted=1;
                default: permitted=0;
            endcase
            2: case (kind)
                24,25,26,27,28,29,30,31: permitted=1;
                default: permitted=0;
            endcase
            default: permitted=0;
        endcase
        expected=usable && permitted && first_byte>=low_bound && final_byte<=high_bound;
        assert(allow_result==expected && fault==!expected);
        assert(error==0 && vector==(expected ? 8'd0 : (ss ? 8'd12 : 8'd13)));
        cover(allow_result && rights==20 && start_offset==65535 && displacement==0 && limit_value==65534);
        cover(fault && rights==20 && limit_value==65535 && usable);
        cover(allow_result && rights==16 && start_offset==0 && displacement==65535 && limit_value==65535);
        cover(allow_result && rights==28 && operation==2 && start_offset<=limit_value);
        cover(fault && rights==26 && operation==1 && usable && final_byte<=high_bound);
        cover(fault && rights==24 && operation==0 && usable && final_byte<=high_bound);
        cover(fault && usable && permitted && final_byte>65535);
        cover(fault && !usable && ss);
    end
endmodule
`default_nettype wire
`endif
