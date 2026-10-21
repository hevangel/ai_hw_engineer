// Source-backed MC4016-equivalent 74LS716 digital function.
// CONFORMANCE LIMITS: Keep preset stable throughout the PE-low preload pulse.
// Source does not specify transparent tracking within that pulse. The source
// documents MR_n and PE_n low together for zero entry; MR-alone priority is
// unspecified, so MR_n priority here is an implementation assumption. Gate is
// a separate input; tie it to clock for the documented single-stage phase.
// See spec/chips/ttl_74x716.md for the available source table and limits.
module ttl_74x716 (
    input  logic       clock,
    input  logic       gate,
    input  logic       mr_n,
    input  logic       pe_n,
    input  logic [3:0] preset,
    input  logic       external_bus_low,
    output logic [3:0] q,
    output logic       bus
);
    logic automatic_load;
    logic [3:0] normalized_preset;

    always_comb begin
        if (preset > 4'd9) begin
            normalized_preset = {1'b0, preset[2:0]};
        end else begin
            normalized_preset = preset;
        end
    end

    assign bus = (q == 4'd0) && !external_bus_low;
    assign automatic_load = mr_n && pe_n && (q == 4'd0) &&
                            !gate && !external_bus_low;

    always_ff @(posedge clock or negedge mr_n or negedge pe_n or posedge automatic_load) begin
        if (!mr_n) begin
            q <= 4'd0;
        end else if (!pe_n) begin
            q <= normalized_preset;
        end else if (automatic_load) begin
            q <= normalized_preset;
        end else if (q == 4'd0) begin
            q <= 4'd9;
        end else begin
            q <= q - 4'd1;
        end
    end
endmodule
