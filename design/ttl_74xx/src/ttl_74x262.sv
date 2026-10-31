// Read-only mask/PROM function. No runtime write path or programming waveform.
// INIT_FILE supplies the selected mask/fuse image; DEFAULT_WORD is a blank image,
// not a claim about any historical factory mask. See spec/chips/ttl_74x262.md.
module ttl_74x262 #(parameter INIT_FILE="", parameter logic [44:0] DEFAULT_WORD='0)
(
    input logic [6:0] addr,
    input logic cs_n,
    output logic [44:0] drive_en,
    output logic [44:0] data_out
);
    logic [44:0] mem[0:127];
    initial begin
        for(integer i=0;i<128;i=i+1) mem[i]=DEFAULT_WORD;
        if(INIT_FILE!="") $readmemh(INIT_FILE,mem);
    end
    assign data_out=cs_n ? '0 : mem[addr];
    assign drive_en={45{~cs_n}};
endmodule
