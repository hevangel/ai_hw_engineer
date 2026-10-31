// 74x370: image-backed read-only 512 x 4 storage.
// ASSUMPTION: normalized positive-data interface; map native enables externally.
module ttl_74x370 #(parameter INIT_FILE = "") (
    input logic [8:0] addr,
    input logic cs_n,
    output logic [3:0] data_out,
    output logic drive
);
    logic [3:0] mem [0:511];
    initial begin
        for (integer i=0; i<512; i=i+1) mem[i]='1;
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end
    assign drive = !cs_n;
    assign data_out = cs_n ? '0 : mem[addr];
endmodule
