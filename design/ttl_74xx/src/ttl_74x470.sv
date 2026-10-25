// 74x470: image-backed read-only 256 x 8 storage.
// ASSUMPTION: normalized positive-data interface; map native enables externally.
module ttl_74x470 #(parameter INIT_FILE = "") (
    input logic [7:0] addr,
    input logic cs_n,
    output logic [7:0] data_out,
    output logic drive
);
    logic [7:0] mem [0:255];
    initial begin
        for (integer i=0; i<256; i=i+1) mem[i]='1;
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end
    assign drive = !cs_n;
    assign data_out = cs_n ? '0 : mem[addr];
endmodule
