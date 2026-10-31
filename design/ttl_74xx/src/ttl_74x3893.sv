// ASSUMPTION: see spec/chips/ttl_74x3893.md. Externally resolved powered
// logic; released I/O lines read high only through the bus bias; reduced
// swing, series diode, power-up glitch suppression and timing omitted.
//
// ttl_74x3893 - quad Futurebus backplane transceiver (3-state + open
// collector). The TTL data inputs are NANDed with DE: I/O pin n sinks its
// line exactly when de=1 and d_in[n]=1, and is released otherwise (the bus
// carries inverted data). The inverting TTL receivers R0..R3 are three-stated
// by the common active-low RE pin (re_n): r_out = ~io_in while re_n=0.
// Driver (DE) and receiver (RE) controls are fully independent.
module ttl_74x3893 (
    input  logic [3:0] d_in,     // D0..D3 TTL data inputs
    input  logic       de,       // Data Enable, active high
    input  logic       re_n,     // Receive Enable (RE pin), active low
    input  logic [3:0] io_in,    // I/O0..I/O3 resolved bus levels
    output logic [3:0] io_out,   // always zero; open-collector state is io_drive
    output logic [3:0] io_drive, // per-pin sink flags: 1 = sinking line low
    output logic [3:0] r_out,
    output logic       r_drive
);
    always_comb begin
        io_out   = '0;
        io_drive = '0;
        if (de)
            io_drive = d_in;     // NAND(D, DE): sink iff d_in bit is 1
        r_drive = !re_n;
        r_out   = '0;
        if (!re_n)
            r_out = ~io_in;
    end
endmodule
