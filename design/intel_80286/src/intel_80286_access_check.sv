// Intel 210498-005 7.4 and 11.2.2; checks an existing ordinary cache.
// Load-time presence/privilege and instruction-level prechecks are external.
module intel_80286_access_check (
    input logic cache_valid_i, stack_i,
    input logic [4:1] access_i,
    input logic [15:0] limit_i, offset_i, last_delta_i,
    input logic [1:0] kind_i,
    output logic allow_o, fault_o,
    output logic [7:0] fault_vector_o,
    output logic [15:0] fault_error_o
);
    logic permission_valid, range_valid, expand_down;
    logic [16:0] last_byte;
    always_comb begin
        last_byte={1'b0,offset_i}+{1'b0,last_delta_i};
        expand_down=!access_i[3] && access_i[2];
        case (kind_i)
            0: permission_valid=!access_i[3] || access_i[1];
            1,3: permission_valid=!access_i[3] && access_i[1];
            2: permission_valid=access_i[3];
            default: permission_valid=0;
        endcase
        range_valid=expand_down ? (offset_i>limit_i && !last_byte[16]) :
            last_byte<={1'b0,limit_i};
        allow_o=cache_valid_i && access_i[4] && permission_valid && range_valid;
        fault_o=!allow_o;
        fault_vector_o=allow_o ? 8'd0 : (stack_i ? 8'd12 : 8'd13);
        fault_error_o=0;
    end
endmodule
