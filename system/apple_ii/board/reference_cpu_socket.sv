// Independent simulation reference only; see DEPENDENCIES.md.
`timescale 1ns/1ps
module reference_cpu_socket (
    input logic phi0, reset_n, irq_n, nmi_n, rdy,
    output logic [15:0] address,
    inout tri [7:0] data,
    output logic rw, sync, phi1, phi2,
    output integer unknown_read_samples,
    input logic so
);
    logic [31:0] pins;
    integer sample;
    initial unknown_read_samples=0;
    assign data = rw ? 8'bz : pins[23:16];
    assign address=pins[15:0];
    assign rw=pins[24];
    assign sync=pins[25];
    assign phi1=pins[26];
    assign phi2=pins[27];
    always_ff @(posedge phi0 or negedge phi0) begin
        // ASSUMPTION: unresolved input bits sample high at this two-state
        // transistor-solver boundary. Count these samples; never claim their
        // electrical values are validated. Dummy/reset reads can be unknown.
        sample=0;
        for(int i=0;i<8;i++) if(data[i] !== 1'b0) sample=sample | (1<<i);
        if(!phi0 && rw && reset_n && $isunknown(data))
            unknown_read_samples <= unknown_read_samples+1;
        pins <= $apple_ii_cpu_step(int'(phi0),int'(reset_n),int'(irq_n),
                                  int'(nmi_n),int'(rdy),int'(so),sample);
    end
endmodule
