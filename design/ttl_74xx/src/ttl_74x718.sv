// Source-backed MC4018-equivalent 74LS718 digital function.
// CONFORMANCE LIMITS: Keep preset stable throughout the PE-low preload pulse.
// Source does not specify transparent tracking within that pulse. The source
// documents MR_n and PE_n low together for zero entry; MR-alone priority is
// unspecified, so MR_n priority here is an implementation assumption. Gate is
// a separate input; tie it to clock for the documented single-stage phase.
// See spec/chips/ttl_74x718.md for the available source table and limits.
module ttl_74x718 (
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

    assign bus = (q == 4'd0) && !external_bus_low;
    assign automatic_load = mr_n && pe_n && (q == 4'd0) &&
                            !gate && !external_bus_low;

    always_ff @(posedge clock or negedge mr_n or negedge pe_n or posedge automatic_load) begin
        if (!mr_n) begin
            q <= 4'd0;
        end else if (!pe_n) begin
            q <= preset;
        end else if (automatic_load) begin
            q <= preset;
        end else begin
            q <= q - 4'd1;
        end
    end
endmodule
