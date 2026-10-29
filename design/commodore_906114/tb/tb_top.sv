// Dumps all 65,536 input words (MAME read_pla bit order, spec/spec.md) as
// one output byte per line: {romh,roml,io,grw,charom,kernal,basic,casram}.
module tb_top;
    logic [15:0] word;
    logic [7:0] pins;
    int fd;
    string path;
    commodore_906114 dut (
        .cas_i(word[0]), .loram_i(word[1]), .hiram_i(word[2]), .charen_i(word[3]),
        .va14_i(word[4]), .a15_i(word[5]), .a14_i(word[6]), .a13_i(word[7]),
        .a12_i(word[8]), .ba_i(word[9]), .aec_i(word[10]), .rw_i(word[11]),
        .exrom_i(word[12]), .game_i(word[13]), .va13_i(word[14]), .va12_i(word[15]),
        .casram_n_o(pins[0]), .basic_n_o(pins[1]), .kernal_n_o(pins[2]),
        .charom_n_o(pins[3]), .grw_n_o(pins[4]), .io_n_o(pins[5]),
        .roml_n_o(pins[6]), .romh_n_o(pins[7])
    );
    initial begin
        if (!$value$plusargs("out=%s", path)) $fatal(1, "missing +out=");
        fd = $fopen(path, "w");
        if (fd == 0) $fatal(1, "cannot open %s", path);
        for (int i = 0; i < 65536; i++) begin
            word = 16'(i);
            #1;
            if ($isunknown(pins)) $fatal(1, "unknown output at %04h", word);
            $fdisplay(fd, "%02h", pins);
        end
        $fclose(fd);
        $display("COMMODORE 906114 DUMP: 65536 input words");
        $finish;
    end
endmodule
