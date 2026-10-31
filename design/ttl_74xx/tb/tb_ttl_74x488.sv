`timescale 1ns/1ps
module tb_ttl_74x488;
    logic talk_n, dir;
    logic [7:0] cpu_data, bus_data_in, cpu_data_out, bus_data_out;
    ttl_74x488 dut(.talk_n(talk_n), .dir(dir), .cpu_data(cpu_data), .bus_data_in(bus_data_in), .cpu_data_out(cpu_data_out), .bus_data_out(bus_data_out));
    int errors;
    initial begin
        errors = 0;
        bus_data_in = 0;
        talk_n=0; dir=1; cpu_data=8'hAA; #1;
        if (bus_data_out !== 8'hAA) errors++;
        dir=0; bus_data_in=8'h55; cpu_data=0; #1;
        if (cpu_data_out !== 8'h55) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x488: %0d errors", errors);
        $display("PASS: tb_ttl_74x488");
        $finish;
    end
endmodule
