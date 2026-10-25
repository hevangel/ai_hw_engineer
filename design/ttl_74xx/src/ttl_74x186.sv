// Read-only mask/PROM function. No runtime write path or programming waveform.
// INIT_FILE supplies the selected mask/fuse image; DEFAULT_WORD is a blank image,
// not a claim about any historical factory mask. See spec/chips/ttl_74x186.md.
module ttl_74x186 #(parameter INIT_FILE="", parameter logic [7:0] DEFAULT_WORD='0)
(
    input logic [5:0] addr,
    output logic [7:0] data
);
    logic [7:0] mem[0:63];
    initial begin
        for(integer i=0;i<64;i=i+1) mem[i]=DEFAULT_WORD;
        if(INIT_FILE!="") $readmemh(INIT_FILE,mem);
    end
    assign data=mem[addr];
endmodule
