module address_formal(input logic clk);
`ifdef FORMAL
    (* anyconst *) logic [15:0] a;
    (* anyconst *) logic bank1;
    logic [7:0] row_bits,column_bits;
    logic [15:0] physical;
    // Independent source: TRM Table 7-9 plus D000 bank-1 -> physical C000.
    assign row_bits={a[8:7],a[5:0]};
    assign column_bits={a[15:13],a[12]^(bank1&&a[15:12]==4'hd),a[11:10],a[6],a[9]};
    apple_iie_address dut(.row_address(row_bits),.column_address(column_bits),.physical_address(physical));
    always_ff @(posedge clk) begin
        assert(physical == ((bank1&&a[15:12]==4'hd)?(a^16'h1000):a));
        cover(bank1&&a==16'hd123&&physical==16'hc123);
        cover(!bank1&&a==16'hd123&&physical==16'hd123);
        cover(a==16'hffff&&physical==16'hffff);
    end
`endif
endmodule
