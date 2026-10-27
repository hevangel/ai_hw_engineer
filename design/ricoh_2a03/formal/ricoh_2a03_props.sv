    // Included inside ricoh_2a03 under FORMAL (the core's own properties
    // are included by mos_6502_native and checked in the same proof).
    logic f_2a03_valid = 0;
    always_ff @(posedge clk) begin
        f_2a03_valid <= 1;
        // The core assumes reset in the first cycle; registers are
        // consistent from the second cycle on.
        if (f_2a03_valid) begin
        // DMA owns the bus only while the core is held off with RDY.
        if (dma_owns) assert(!core_rdy);
        // DMA writes only to OAMDATA; the core never drives a write then.
        if (dma_owns && we_o) assert(addr_o == 16'h2004);
        // Strobes follow decoded read cycles exactly.
        assert(oe1_n_o == !(!we_o && addr_o == 16'h4016));
        assert(oe2_n_o == !(!we_o && addr_o == 16'h4017));
        // $4015 reads are served internally, never from the board.
        if (cpu_cycle && !core_we && core_addr == 16'h4015) assert(!ext_rd_o);
        // APU phase alternates every cycle.
        if (f_2a03_valid && rst_n && $past(rst_n)) assert(apu_phase != $past(apu_phase));
        // A DMA bus cycle starts only after a halt cycle in which the core read.
        if (f_2a03_valid && rst_n && $past(rst_n) && dma_owns && !$past(dma_owns))
            assert(!$past(core_we) && !$past(core_rdy));
        assert(dmc_o <= 7'd127);
        if (dmc_done) assert(dma_owns && !we_o && !apu_phase);

        end
        cover(f_2a03_valid && rst_n && dma_owns && we_o);          // OAM put
        cover(f_2a03_valid && rst_n && dmc_done);                  // DMC get
        cover(f_2a03_valid && rst_n && !core_rdy && core_we);      // write proceeds under RDY
        cover(f_2a03_valid && rst_n && status_rd);                 // $4015 read
        cover(f_2a03_valid && rst_n && !oe1_n_o);                  // controller strobe
        cover(f_2a03_valid && rst_n && dma_owns && dma_repeat);    // alignment/dummy
    end
