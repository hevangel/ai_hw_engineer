// Included inside commodore_906114 under FORMAL. Combinational decoder:
// every property is checked over all 2^16 input words at depth 1.
logic [5:0] sel;
assign sel = ~{basic_n_o, kernal_n_o, charom_n_o, io_n_o, roml_n_o, romh_n_o};

always_comb begin
    // At most one ROM/I/O chip select, and never together with DRAM.
    assert ($onehot0(sel));
    if (sel != 0) assert (casram_n_o);
    // CAS idle keeps DRAM and the color-RAM strobe idle.
    if (cas_i) assert (casram_n_o && grw_n_o);
    // VIC cycles only see DRAM, character ROM or Ultimax ROMH.
    if (aec_i) assert (basic_n_o && kernal_n_o && io_n_o && roml_n_o && grw_n_o);
    // Internal ROMs are read-only: CPU writes fall through to DRAM. VIC
    // terms ignore R/W, which the board leaves pulled up in VIC cycles.
    if (!rw_i && !aec_i) assert (basic_n_o && kernal_n_o && charom_n_o);
    if (!rw_i && !aec_i && !cas_i && !(exrom_i && !game_i) && !dio) assert (!casram_n_o);
    // Without a cartridge the map is the 64K RAM + BASIC/KERNAL/CHAROM/I/O set.
    if (exrom_i && game_i) assert (roml_n_o && romh_n_o);
    // Color RAM strobe implies a CPU write cycle in $D000-$DFFF.
    if (!grw_n_o) assert (!rw_i && !aec_i && dio);
    // I/O reads need BA high.
    if (!io_n_o && rw_i) assert (ba_i);

    cover (!basic_n_o);
    cover (!kernal_n_o);
    cover (!charom_n_o && !aec_i);
    cover (!charom_n_o && aec_i);
    cover (!io_n_o && rw_i);
    cover (!io_n_o && !rw_i);
    cover (!roml_n_o);
    cover (!romh_n_o && aec_i);
    cover (!romh_n_o && !aec_i);
    cover (!grw_n_o);
    cover (!casram_n_o && aec_i);
    cover (casram_n_o && sel == 0 && !cas_i);  // Ultimax hole
end
