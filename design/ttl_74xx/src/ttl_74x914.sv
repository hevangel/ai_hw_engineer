// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x914.md.
// ttl_74x914 - Hex inverter with Schmitt-trigger inputs, extended input voltage.
// Logically a hex inverter (same as 74x14); Schmitt-trigger hysteresis and
// extended input voltage tolerance are physical-only features.
module ttl_74x914 (
    input  logic [5:0] a,
    output logic [5:0] y
);
    assign y = ~a;
endmodule
