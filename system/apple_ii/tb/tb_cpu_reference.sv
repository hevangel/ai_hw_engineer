// Startup/reset regression for the optional external VPI solver.
`timescale 1ns/1ps
module tb_cpu_reference;
    integer pins=0, sample=0;
    bit low_seen=0, high_seen=0, fetch_seen=0;
    initial begin
        for (int cycle=0; cycle<80; cycle++) begin
            for (int phase=0; phase<2; phase++) begin
                case (pins[15:0])
                    16'hfffc: sample='h59;
                    16'hfffd: sample='hff;
                    default: sample='hea;
                endcase
                pins=$apple_ii_cpu_step(phase, int'(cycle>=8), 1, 1, 1, 0, sample);
                if (cycle>=8 && pins[24]) begin
                    if (pins[15:0]=='hfffc) low_seen=1;
                    if (pins[15:0]=='hfffd) high_seen=1;
                    if (low_seen && high_seen && pins[25] && !fetch_seen) begin
                        if (pins[15:0]!==16'hff59) $fatal(1,"Reference first fetch %h",pins[15:0]);
                        fetch_seen=1;
                    end
                end
                #1;
            end
        end
        if (!low_seen || !high_seen || !fetch_seen) $fatal(1,"Reference reset/fetch missing");
        $display("PASS independent CPU reference startup, reset vector and exact first fetch");
        $finish;
    end
endmodule
