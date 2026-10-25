// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x582.md.
// ttl_74x582 - 4-bit BCD arithmetic logic unit.
// Supports add, subtract, and complement of two BCD digits with carry-in/out.
module ttl_74x582 (
    input  logic [3:0] a, b,
    input  logic       cin,    // BCD carry in
    input  logic       sub_n,  // 1=add, 0=subtract (nine's complement of b)
    output logic [3:0] s,
    output logic       cout
);
    logic [4:0] raw;
    logic [3:0] adj;
    logic [3:0] op;
    always_comb begin
        op   = sub_n ? b : (4'd9 - b);
        raw  = a + op + cin;
        adj  = raw[3:0] + 4'd6;
        cout = 0;
        s    = raw[3:0];
        if (raw >= 5'd10) begin
            cout = 1;
            s    = adj[3:0];
        end
    end
endmodule
