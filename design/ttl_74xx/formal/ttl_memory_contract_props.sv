`ifdef FORMAL
module ttl_memory_contract(input logic clk);
    (* anyconst *) logic [3:0] watched_address;
    (* anyseq *) logic [3:0] addr,data_in;
    (* anyseq *) logic cs_n,we_n;
    logic known=0;
    logic [3:0] expected;
    wire [3:0] data_out_n,drive_en;
    ttl_74x189 dut(.*);
    always_ff @(posedge clk) begin
        if(!cs_n && !we_n && addr==watched_address) begin
            known<=1;expected<=data_in;
        end
        if(known && !cs_n && addr==watched_address) assert(data_out_n==~expected);
        assert(drive_en=={4{!cs_n && we_n}});
        cover(known && !cs_n && we_n && addr==watched_address && data_out_n!=0);
    end
endmodule
`endif
