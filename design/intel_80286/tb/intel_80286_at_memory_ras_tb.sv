module intel_80286_at_memory_ras_tb;
    logic memr_n, memw_n, ras;
    intel_80286_at_memory_ras dut (.memr_n_i(memr_n), .memw_n_i(memw_n), .ras_trigger_o(ras));
    initial begin
        memr_n=1; memw_n=1; #1; assert(!ras) else $fatal(1,"idle asserted RAS trigger");
        memr_n=0; #1; assert(ras) else $fatal(1,"read did not trigger RAS");
        memr_n=1; memw_n=0; #1; assert(ras) else $fatal(1,"write did not trigger RAS");
        memr_n=0; #1; assert(ras) else $fatal(1,"concurrent asserted strobes lost RAS");
        memr_n=1; memw_n=1; #1; assert(!ras) else $fatal(1,"trigger did not clear");
        $display("PASS: IBM AT memory-read/write RAS trigger truth table");
        $finish;
    end
endmodule
