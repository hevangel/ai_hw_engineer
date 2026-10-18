// Controller proof uses a documented reduced instruction alphabet. Numerical
// instructions are verified independently in simulation, not in this proof.
module intel_8087_props(input logic clk);
    (* anyseq *) logic rst_n,valid,ready,waiting;
`ifdef COVER_STACK
    wire [2:0] instruction=1;
`elsif COVER_BUS
    wire [2:0] instruction=6;
`else
    (* anyseq *) logic [2:0] instruction;
`endif
    (* anyseq *) logic [19:0] address;
    (* anyseq *) logic [7:0] data;
    logic [7:0] opcode,modrm;
    logic cmd_ready,mem_valid,mem_write,busy,irq,done,unsupported;
    logic [19:0] mem_address;
    logic [7:0] mem_data;
    logic [15:0] cw,sw,tags;
    logic [639:0] registers;
    always_comb begin
        opcode=8'hd9;modrm=8'he8;
        case(instruction)
            0:modrm=8'he8;
            1:modrm=8'he8;
            2:modrm=8'hee;
            3:modrm=8'hf7;
            4:modrm=8'hf6;
            5:modrm=8'he8;
            6:modrm=8'h38;
            7:modrm=8'hd0;
        endcase
    end
    intel_8087 dut(.clk(clk),.rst_n(rst_n),.cmd_valid_i(valid),.cmd_ready_o(cmd_ready),
        .opcode_i(opcode),.modrm_i(modrm),.address_i(address),.instruction_i(address),.cpu_wait_i(waiting),
        .mem_valid_o(mem_valid),.mem_write_o(mem_write),.mem_address_o(mem_address),.mem_wdata_o(mem_data),
        .mem_ready_i(ready),.mem_rdata_i(data),.busy_o(busy),.int_o(irq),.done_o(done),.unsupported_o(unsupported),
        .control_o(cw),.status_o(sw),.tags_o(tags),.registers_o(registers));
endmodule
