// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x885.md.
// ttl_74x885 - 8-bit magnitude comparator with P-input latch and cascade.
//
// Per SN74AS885 datasheet (SDAS236A): unsigned ("Logical") or two's
// complement ("Arithmetic") comparison selectable by l_a_n. The P-port
// has a transparent latch enabled while ple is high. When P equals Q the
// chip propagates the cascade inputs through to the cascade outputs;
// otherwise it drives them based on the magnitude comparison.
module ttl_74x885 (
    input  logic       l_a_n,
    input  logic       ple,
    input  logic       p_gt_qin,
    input  logic       p_lt_qin,
    input  logic [7:0] p,
    input  logic [7:0] q,
    output logic       p_gt_qout,
    output logic       p_lt_qout
);
    logic [7:0] p_lat;
    logic eq, gt_u, lt_u, gt_s, lt_s;

    always_latch begin
        if (ple) p_lat = p;
    end

    assign eq   = (p_lat == q);
    assign gt_u = (p_lat > q);
    assign lt_u = (p_lat < q);
    assign gt_s = ($signed(p_lat) > $signed(q));
    assign lt_s = ($signed(p_lat) < $signed(q));

    always_comb begin
        if (eq) begin
            p_gt_qout = p_gt_qin;
            p_lt_qout = p_lt_qin;
        end else if (l_a_n) begin
            p_gt_qout = gt_u;
            p_lt_qout = lt_u;
        end else begin
            p_gt_qout = gt_s;
            p_lt_qout = lt_s;
        end
    end
endmodule
