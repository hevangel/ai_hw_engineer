`ifndef APPLE_II_CPU_MODULE
`define APPLE_II_CPU_MODULE apple_ii_rev0_reference
`endif
`timescale 1ns/1ps
module tb_rev0_basic;
    logic osc=0, reset_n=0;
    tri [15:0] address;
    tri [7:0] data;
    tri phi0, rw, sync;
    tri video, video_sync;
    integer unknown_reads;
    integer instructions=0;
    integer polls=0;
    logic [6:0] key_data=0;
    logic key_strobe=0;
    logic vector_low=0, vector_high=0, reset_fetch=0;
    `APPLE_II_CPU_MODULE #(
        .ROM_D0("work/rom_D0.hex"),.ROM_D8("work/rom_D8.hex"),
        .ROM_E0("work/rom_E0.hex"),.ROM_E8("work/rom_E8.hex"),
        .ROM_F0("work/rom_F0.hex"),.ROM_F8("work/rom_F8.hex"),.CHAR_ROM("work/char_2513.hex")
    ) dut (
        .master_oscillator(osc),.reset_n(reset_n),.keyboard_data(key_data),
        .keyboard_strobe(key_strobe),.buttons(3'b0),
        .paddle0_ohms(75000.0),.paddle1_ohms(75000.0),.paddle2_ohms(75000.0),.paddle3_ohms(75000.0),
        .cassette_voltage(0.0),.cpu_address(address),.cpu_data(data),
        .cpu_rw(rw),.cpu_sync(sync),.cpu_phi0(phi0),.unknown_read_samples(unknown_reads),
        .video_data(video),.composite_sync(video_sync),.speaker(),.cassette_out(),.annunciators()
    );
    initial forever #34.921 osc=~osc;
    initial begin
        // ASSUMPTION: selected power-up state for unresettable TTL packages.
        dut.board.B1.q=0; dut.board.C2.q=0;
        dut.board.D11.q=0; dut.board.D12.q=0; dut.board.D13.q=0; dut.board.D14.q=0;
        // Keyboard strobe latch has no power-on reset; emulate a cleared latch.
        dut.board.B10.q1=0; dut.board.B10.n1=1;
        // Select a known state for the unresettable speaker flip-flop.
        dut.board.J13.q0=0; dut.board.J13.n0=1;
        #20000; reset_n=1;
        #3000000000;
        $fatal(1,"BASIC timeout PC=%h bus=%h polls=%d strobe=%b",dut.H7.core.pc_o,address,polls,dut.board.B10.q1);
    end
    task automatic key(input logic [6:0] value);
        @(negedge phi0); #100;
        key_data=value; key_strobe=1;
        #1200; key_strobe=0;
        wait(dut.board.B10.q1===1'b0);
        // The next input is sent only once the Monitor polls again.
        @(negedge phi0);
        wait(address===16'hc000 && rw===1'b1);
    endtask
    int printed_file;
    initial printed_file=$fopen("work/basic_output.txt","w");
    int sound_accesses=0, speaker_edges=0, sound_before, edges_before;
    logic previous_speaker;
    always_ff @(dut.board.J13.p5) if(reset_n && !$isunknown(dut.board.J13.p5)) speaker_edges++;
    logic sum_written=0, pixel_written=0, sum_read=0, pixel_read=0;
    task automatic line(input string value);
        for(int i=0;i<value.len();i++) key(value[i]);
        key(7'h0d);
    endtask
    initial begin
        wait(polls>=8);
        key(7'h1b); key("@");
        // Original Monitor CTRL-B then RETURN starts Integer BASIC cold.
        key(7'h02); key(7'h0d);
        line("NEW");
        line("10 S=0");
        line("20 FOR I=1 TO 10:S=S+I:NEXT I");
        line("30 POKE 768,S");
        line("40 PRINT \"SUM=\";S");
        line("50 END");
        line("RUN");
        wait(sum_written);
        line("GR");
        line("COLOR=9");
        line("PLOT 3,4");
        line("POKE 769,SCRN(3,4)");
        wait(pixel_written);
        sound_before=sound_accesses; edges_before=speaker_edges;
        previous_speaker=dut.board.J13.p5;
        if($isunknown(previous_speaker)) $fatal(1,"Speaker latch is unresolved before BASIC PEEK");
        line("Z=PEEK(-16336)");
        if(sound_accesses!=sound_before+1 || speaker_edges!=edges_before+1 ||
           dut.board.J13.p5!==~previous_speaker)
            $fatal(1,"BASIC PEEK must cause exactly one real J13 speaker toggle");
        line("TEXT");
        line("CALL -151");
        line("300.301");
        wait(sum_read && pixel_read);
        if(sound_accesses<1) $fatal(1,"BASIC PEEK speaker access missing");
        if(!reset_fetch) $fatal(1,"Exact reset vector/fetch missing");
        $fclose(printed_file);
        $display("PASS original Integer BASIC physical keyboard/program FOR-NEXT, arithmetic, POKE, PRINT, lores PLOT/SCRN, one isolated speaker toggle and Monitor readback; instructions=%0d unknown reads=%0d",instructions,unknown_reads);
        $finish;
    end
    always_ff @(negedge phi0) begin
        if(reset_n && sync && address==16'hfded)
            $fwrite(printed_file,"%c",dut.H7.core.a_o & 8'h7f);
        if(reset_n && address==16'hc030) sound_accesses<=sound_accesses+1;
        if(reset_n && !rw && address==16'h0300 && data==8'd55) sum_written<=1;
        if(reset_n && !rw && address==16'h0301 && data==8'd9) pixel_written<=1;
        if(sum_written && pixel_written && rw && address==16'h0300) begin
            if(data!==8'd55) $fatal(1,"BASIC sum DRAM readback %h",data);
            sum_read<=1;
        end
        if(sum_written && pixel_written && rw && address==16'h0301) begin
            if(data!==8'd9) $fatal(1,"BASIC lores DRAM readback %h",data);
            pixel_read<=1;
        end
        if(reset_n && sync) begin
            instructions<=instructions+1;
            if($isunknown(data)) $fatal(1,"Unresolved opcode at %h",address);
            if(vector_high && !reset_fetch) begin
                if(address!==16'hff59 || data!==8'h20) $fatal(1,"exact reset fetch %h/%h",address,data);
                reset_fetch<=1;
            end
        end
        if(reset_n && rw && address==16'hfffc) begin
            if(data!==8'h59) $fatal(1,"reset vector low");
            vector_low<=1;
        end
        if(reset_n && rw && address==16'hfffd && vector_low) begin
            if(data!==8'hff) $fatal(1,"reset vector high");
            vector_high<=1;
        end
        if(reset_n && rw && address==16'hc000) begin
            polls<=polls+1;
        end
    end
endmodule
