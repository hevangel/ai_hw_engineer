// Independent primary type lists/intervals and explicit packed-role reference.
`ifdef FORMAL
`default_nettype none
module intel_80286_cached_reference_props (
    input logic [95:0] bases,
    input logic [63:0] limits,
    input logic [31:0] rights,
    input logic [3:0] usable,
    input logic [1:0] role, kind,
    input logic [15:0] offset_value, displacement,
    input logic trusted
);
    logic allowed, fault;
    logic [7:0] vector_value;
    logic [15:0] error_value;
    logic [23:0] physical, base_value;
    logic [15:0] limit_value;
    logic [7:0] access_value;
    logic valid_value, expected, permission;
    integer unsigned first_byte, final_byte, low_bound, high_bound, descriptor_type;
    logic [31:0] physical_sum;
    intel_80286_cached_reference dut(.bases_i(bases),.limits_i(limits),.access_i(rights),
        .usable_i(usable),.role_i(role),.kind_i(kind),.offset_i(offset_value),
        .last_delta_i(displacement),.trusted_cs_i(trusted),.allow_o(allowed),
        .fault_o(fault),.fault_vector_o(vector_value),.fault_error_o(error_value),
        .physical_o(physical));
    always_comb begin
        case (role)
            0: begin base_value=bases[23:0]; limit_value=limits[15:0]; access_value=rights[7:0]; valid_value=usable[0]; end
            1: begin base_value=bases[47:24]; limit_value=limits[31:16]; access_value=rights[15:8]; valid_value=usable[1]; end
            2: begin base_value=bases[71:48]; limit_value=limits[47:32]; access_value=rights[23:16]; valid_value=usable[2]; end
            3: begin base_value=bases[95:72]; limit_value=limits[63:48]; access_value=rights[31:24]; valid_value=usable[3]; end
            default: begin base_value=0; limit_value=0; access_value=0; valid_value=0; end
        endcase
        descriptor_type={27'h0,access_value[4:0]};
        first_byte={16'h0,offset_value}; final_byte=first_byte+{16'h0,displacement};
        low_bound=0; high_bound={16'h0,limit_value}; permission=0;
        if (descriptor_type>=20 && descriptor_type<=23) begin
            low_bound={16'h0,limit_value}+1; high_bound=65535;
        end
        case (kind)
            0: case (descriptor_type)
                16,17,18,19,20,21,22,23,26,27,30,31: permission=1;
                default: permission=0;
            endcase
            1,3: case (descriptor_type)
                18,19,22,23: permission=1;
                default: permission=0;
            endcase
            2: permission=descriptor_type>=24 && descriptor_type<=31;
            default: permission=0;
        endcase
        expected=valid_value && permission && first_byte>=low_bound && final_byte<=high_bound;
        if (trusted && role==1 && kind==2)
            expected=valid_value && final_byte<={16'h0,limit_value};
        physical_sum={8'h0,base_value}+first_byte;
        assert(allowed==expected && fault==!expected);
        assert(vector_value==(expected ? 8'd0 : (role==2 ? 8'd12 : 8'd13)) && error_value==0);
        assert(physical==(expected ? physical_sum[23:0] : 24'd0));
        cover(allowed && trusted && role==1 && kind==2 && access_value==8'h93);
        cover(fault && !trusted && role==1 && kind==2 && access_value==8'h93 && valid_value);
        cover(fault && trusted && role==1 && kind==1 && access_value==8'h9b && valid_value);
        cover(fault && trusted && role==1 && kind==2 && !valid_value);
        cover(fault && role==2 && bases[23:0]==bases[71:48] && usable[0] && !usable[2]);
        cover(allowed && base_value==24'hffffff && offset_value==16'd1 && physical==0);
        cover(fault && trusted && role==1 && kind==2 && final_byte>65535 && valid_value);
        cover(allowed && role==3 && descriptor_type==22 && first_byte>low_bound);
    end
endmodule
`default_nettype wire
`endif
