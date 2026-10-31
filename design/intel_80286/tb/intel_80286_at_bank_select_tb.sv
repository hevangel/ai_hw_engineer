module intel_80286_at_bank_select_tb;
    logic [6:0] address;
    logic refresh, ram_n, hlda, ale, cs16_n;
    logic [7:0] prom;
    logic [8:0] index;
    logic [3:0] ras;
    logic [1:0] cas_n;
    logic lmeg_n, fsys16, f16, rom_n;
    intel_80286_at_bank_select dut (
        .a23_a17_i(address), .refresh_i(refresh), .ram_select_n_i(ram_n),
        .hlda_i(hlda), .ale_i(ale), .mem_cs16_n_i(cs16_n), .prom_data_i(prom),
        .prom_address_o(index), .ram_ras_select_o(ras), .ram_cas_select_n_o(cas_n),
        .lmeg_cs_n_o(lmeg_n), .fsys16_o(fsys16), .f16_o(f16), .cs_rom_n_o(rom_n)
    );
    initial begin
        address=0; refresh=0; ram_n=0; hlda=0; ale=1; cs16_n=1; prom=0; #1;
        for (int n=0;n<512;n++) begin
            {ram_n,refresh,address}=9'(n); #1;
            assert(index==9'(n)) else $fatal(1,"PROM address wiring mismatch");
        end
        for (int n=0;n<512;n++) begin
            {cs16_n,prom}=9'(n); #1;
            assert(f16==!(prom[4] && prom[5] && prom[7] && cs16_n));
            assert(rom_n==prom[7]);
            assert({fsys16,lmeg_n,cas_n,ras}=={f16,prom[6:0]});
        end
        ale=0; #1; prom=8'h00; cs16_n=0; #1;
        assert({fsys16,lmeg_n,cas_n,ras}=={1'b0,7'h7f})
            else $fatal(1,"closed latch did not preserve bank selection");
        hlda=1; #1;
        assert({fsys16,lmeg_n,cas_n,ras}==8'h80)
            else $fatal(1,"HLDA did not open bank latch");
        hlda=0; prom=8'h7f; #1;
        assert({fsys16,lmeg_n,cas_n,ras}==8'h80)
            else $fatal(1,"bank latch did not hold after HLDA");
        $display("PASS: IBM AT PROM wiring and transparent bank-select latch with synthetic data");
        $finish;
    end
endmodule
