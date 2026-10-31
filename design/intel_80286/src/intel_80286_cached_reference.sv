// Cache selection, permission/range check and functional physical address.
// ASSUMPTION: A14. Retained real CS fetch uses its trusted role and normal
// limit, not its data-like raw reset attributes; see cached_reference.md.
module intel_80286_cached_reference (
    input logic [95:0] bases_i,
    input logic [63:0] limits_i,
    input logic [31:0] access_i,
    input logic [3:0] usable_i,
    input logic [1:0] role_i, kind_i,
    input logic [15:0] offset_i, last_delta_i,
    input logic trusted_cs_i,
    output logic allow_o, fault_o,
    output logic [7:0] fault_vector_o,
    output logic [15:0] fault_error_o,
    output logic [23:0] physical_o
);
    logic [23:0] selected_base;
    logic [15:0] selected_limit;
    logic [4:1] selected_access;
    logic ordinary_allow, ordinary_fault;
    logic [7:0] ordinary_vector;
    logic [15:0] ordinary_error;
    logic [16:0] final_byte;
    // Presence/DPL were checked on load; A cannot change access permissions.
    logic unused_load_attributes;
    assign unused_load_attributes=^{access_i[31:29],access_i[24],access_i[23:21],access_i[16],
                                   access_i[15:13],access_i[8],access_i[7:5],access_i[0]};
    // Explicit complete selections avoid out-of-range padding X in AIG export
    // of variable shifts over the non-power-of-two 96-bit base bank.
    always_comb begin
        case (role_i)
            0: begin selected_base=bases_i[23:0]; selected_limit=limits_i[15:0]; selected_access=access_i[4:1]; end
            1: begin selected_base=bases_i[47:24]; selected_limit=limits_i[31:16]; selected_access=access_i[12:9]; end
            2: begin selected_base=bases_i[71:48]; selected_limit=limits_i[47:32]; selected_access=access_i[20:17]; end
            3: begin selected_base=bases_i[95:72]; selected_limit=limits_i[63:48]; selected_access=access_i[28:25]; end
            default: begin selected_base=0; selected_limit=0; selected_access=0; end
        endcase
    end
    intel_80286_access_check permissions(
        .cache_valid_i(usable_i[role_i]),.stack_i(role_i==2),
        .access_i(selected_access),.limit_i(selected_limit),
        .offset_i(offset_i),.last_delta_i(last_delta_i),.kind_i(kind_i),
        .allow_o(ordinary_allow),.fault_o(ordinary_fault),
        .fault_vector_o(ordinary_vector),.fault_error_o(ordinary_error));
    always_comb begin
        final_byte={1'b0,offset_i}+{1'b0,last_delta_i};
        allow_o=ordinary_allow; fault_o=ordinary_fault;
        fault_vector_o=ordinary_vector; fault_error_o=ordinary_error;
        if (trusted_cs_i && role_i==1 && kind_i==2) begin
            allow_o=usable_i[1] && final_byte<={1'b0,selected_limit};
            fault_o=!allow_o;
            fault_vector_o=allow_o ? 8'd0 : 8'd13;
            fault_error_o=0;
        end
        physical_o=allow_o ? selected_base+{8'h0,offset_i} : 24'd0;
    end
endmodule
