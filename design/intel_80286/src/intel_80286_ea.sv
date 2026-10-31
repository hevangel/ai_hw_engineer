// Intel 210498-005, table B-1/B-3: 16-bit effective addresses.
module intel_80286_ea (
    input logic [4:0] address_mode_i,
    input logic [15:0] bx_i, bp_i, si_i, di_i, displacement_i,
    output logic [15:0] offset_o,
    output logic stack_o,
    output logic [1:0] displacement_bytes_o
);
    logic [15:0] base;
    always_comb begin
        stack_o = 0;
        case (address_mode_i[2:0])
            0: base = bx_i + si_i;
            1: base = bx_i + di_i;
            2: begin base = bp_i + si_i; stack_o = 1; end
            3: begin base = bp_i + di_i; stack_o = 1; end
            4: base = si_i;
            5: base = di_i;
            6: begin base = address_mode_i[4:3] == 0 ? 16'h0000 : bp_i; stack_o = address_mode_i[4:3] != 0; end
            7: base = bx_i;
            default: base = 0;
        endcase
        displacement_bytes_o = 0;
        if (address_mode_i[4:3] == 1) displacement_bytes_o = 1;
        if (address_mode_i[4:3] == 2 || (address_mode_i[4:3] == 0 && address_mode_i[2:0] == 6)) displacement_bytes_o = 2;
        offset_o = base + displacement_i;
    end
endmodule
