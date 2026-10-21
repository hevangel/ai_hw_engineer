// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x748.md.
// ttl_74x748 - 8-to-3 priority encoder (glitch-less).
//
// Logically identical to 74x148: active-low inputs, active-low encoded outputs,
// EI/GS/EO. The SN74LS748 is a "glitch-less" variant — the steady-state truth
// table is the same; the difference (clean output during input transitions) is
// a timing/structural improvement not captured in functional RTL.
module ttl_74x748 (
    input  logic [7:0] i_n,
    input  logic       ei_n,
    output logic [2:0] y_n,
    output logic       gs_n,
    output logic       eo_n
);
    logic [2:0] code;
    logic       any_active;
    always_comb begin
        any_active = !ei_n && (i_n != 8'hFF);
        casez (i_n)
            8'b0???????: code = 3'd7;
            8'b10??????: code = 3'd6;
            8'b110?????: code = 3'd5;
            8'b1110????: code = 3'd4;
            8'b11110???: code = 3'd3;
            8'b111110??: code = 3'd2;
            8'b1111110?: code = 3'd1;
            8'b11111110: code = 3'd0;
            default:     code = 3'd0;
        endcase
        if (!ei_n && any_active) begin
            y_n  = ~code;
            gs_n = 1'b0;
            eo_n = 1'b1;
        end else if (!ei_n) begin
            y_n  = 3'b111;
            gs_n = 1'b1;
            eo_n = 1'b0;
        end else begin
            y_n  = 3'b111;
            gs_n = 1'b1;
            eo_n = 1'b1;
        end
    end
endmodule
