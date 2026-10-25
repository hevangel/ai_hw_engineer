// Intel 210498-005 Appendix B: implicit byte/word MUL, IMUL, DIV and IDIV.
// Multiplication is combinational; division performs one restoring bit per cycle.
module intel_80286_muldiv (
    input logic clk, rst_n, start_i, wide_i,
    input logic [1:0] operation_i,
    input logic [15:0] ax_i, dx_i, operand_i, flags_i,
    output logic done_o, fault_o, busy_o,
    output logic [15:0] ax_o, dx_o, flags_o
);
    logic busy, wide, signed_divide, negative_quotient, negative_remainder;
    logic [5:0] bits_left;
    logic [31:0] numerator;
    logic [30:0] quotient;
    logic [15:0] denominator;
    logic [15:0] remainder;
    logic [16:0] trial;
    logic [15:0] next_remainder;
    logic [31:0] next_quotient, dividend, magnitude;
    logic [15:0] corrected_quotient;
    logic [15:0] divisor, divisor_magnitude, corrected_remainder;
    logic dividend_negative, divisor_negative, quotient_fits;
    logic [31:0] product;
    logic product_overflow;
    assign busy_o=busy;
    always_comb begin
        dividend = wide_i ? {dx_i,ax_i} : {16'h0,ax_i};
        divisor = wide_i ? operand_i : {8'h0,operand_i[7:0]};
        dividend_negative = operation_i[0] && (wide_i ? dividend[31] : dividend[15]);
        divisor_negative = operation_i[0] && (wide_i ? divisor[15] : divisor[7]);
        magnitude = dividend_negative ? (wide_i ? -dividend : {16'h0,(16'h0-ax_i)}) : dividend;
        divisor_magnitude = divisor_negative ? (wide_i ? -divisor : {8'h0,(8'h0-operand_i[7:0])}) : divisor;
        if (operation_i[0]) begin
            if (wide_i) product = 32'($signed(ax_i) * $signed(operand_i));
            else product = 32'($signed(ax_i[7:0]) * $signed(operand_i[7:0]));
        end else product = wide_i ? (32'(ax_i)*32'(operand_i)) : (32'(ax_i[7:0])*32'(operand_i[7:0]));
        if (operation_i[0]) product_overflow = wide_i ? product[31:16]!={16{product[15]}} : product[15:8]!={8{product[7]}};
        else product_overflow = wide_i ? product[31:16]!=0 : product[15:8]!=0;
        trial = {remainder[15:0],numerator[31]};
        next_remainder = 16'(trial >= {1'b0,denominator} ? trial-{1'b0,denominator} : trial);
        next_quotient = {quotient,trial >= {1'b0,denominator}};
        corrected_quotient = negative_quotient ? (16'h0-next_quotient[15:0]) : next_quotient[15:0];
        corrected_remainder = negative_remainder ? (16'h0-next_remainder[15:0]) : next_remainder[15:0];
        if (signed_divide)
            quotient_fits = next_quotient <= (wide ? (negative_quotient ? 32'h8000 : 32'h7fff) : (negative_quotient ? 32'h80 : 32'h7f));
        else quotient_fits = next_quotient <= (wide ? 32'hffff : 32'hff);
    end
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            done_o<=0; fault_o<=0; busy<=0; wide<=0; signed_divide<=0;
            negative_quotient<=0; negative_remainder<=0; bits_left<=0;
            numerator<=0; quotient<=0; denominator<=0; remainder<=0;
            ax_o<=0; dx_o<=0; flags_o<=0;
        end else begin
            done_o<=0;
            if (start_i && !busy) begin
                fault_o<=0; ax_o<=ax_i; dx_o<=dx_i; flags_o<=flags_i;
                if (!operation_i[1]) begin
                    ax_o<=product[15:0];
                    if (wide_i) dx_o<=product[31:16];
                    // ASSUMPTION: A3. Preserve manufacturer-undefined multiply flags.
                    flags_o[0]<=product_overflow; flags_o[11]<=product_overflow;
                    done_o<=1;
                end else if (divisor==0) begin fault_o<=1; done_o<=1; end
                else begin
                    busy<=1; wide<=wide_i; signed_divide<=operation_i[0];
                    negative_quotient<=dividend_negative^divisor_negative;
                    negative_remainder<=dividend_negative;
                    numerator<=wide_i ? magnitude : {magnitude[15:0],16'h0};
                    denominator<=divisor_magnitude; quotient<=0; remainder<=0;
                    bits_left<=wide_i ? 32 : 16;
                end
            end else if (busy) begin
                numerator<={numerator[30:0],1'b0}; quotient<=next_quotient[30:0];
                remainder<=next_remainder[15:0]; bits_left<=bits_left-6'd1;
                if (bits_left==1) begin
                    busy<=0; done_o<=1; fault_o<=!quotient_fits;
                    if (quotient_fits) begin
                        ax_o<=wide ? corrected_quotient[15:0] : {corrected_remainder[7:0],corrected_quotient[7:0]};
                        if (wide) dx_o<=corrected_remainder;
                    end
                end
            end
        end
    end
`ifdef FORMAL
    `include "intel_80286_muldiv_props.sv"
`endif
endmodule
