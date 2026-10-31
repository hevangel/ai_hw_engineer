// One bit of Intel 286 group-2 shifting. Count masking is done by the core.
module intel_80286_shift (
    input logic [2:0] operation_i,
    input logic wide_i, carry_i,
    input logic [15:0] value_i,
    output logic [15:0] value_o,
    output logic carry_o, overflow_o
);
    logic msb;
    always_comb begin
        msb = wide_i ? value_i[15] : value_i[7];
        carry_o = operation_i[0] ? value_i[0] : msb;
        value_o = value_i;
        case (operation_i)
            0: value_o = {value_i[14:0],msb};
            1: value_o = wide_i ? {value_i[0],value_i[15:1]} : {8'h00,value_i[0],value_i[7:1]};
            2: value_o = {value_i[14:0],carry_i};
            3: value_o = wide_i ? {carry_i,value_i[15:1]} : {8'h00,carry_i,value_i[7:1]};
            4: value_o = {value_i[14:0],1'b0};
            5: value_o = wide_i ? {1'b0,value_i[15:1]} : {8'h00,1'b0,value_i[7:1]};
            7: value_o = wide_i ? {msb,value_i[15:1]} : {8'h00,msb,value_i[7:1]};
            default: begin end // /6 is rejected by decode.
        endcase
        if (!wide_i) value_o[15:8] = 0;
        if (!operation_i[0]) overflow_o = (wide_i ? value_o[15] : value_o[7]) ^ carry_o;
        else if (operation_i == 5) overflow_o = msb;
        else if (operation_i == 7) overflow_o = 0;
        else overflow_o = wide_i ? (value_o[15]^value_o[14]) : (value_o[7]^value_o[6]);
    end
endmodule
