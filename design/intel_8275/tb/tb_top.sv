module tb_top;
    logic clk=0;
    initial forever #5 clk=~clk;
    logic rst_n=0, cclk_en=0, cs_n=1, rd_n=1, wr_n=1, a0=0;
    logic [7:0] db_in=0, db_out;
    logic db_oe, dack_n=1, lpen=0, drq, irq;
    logic [6:0] cc;
    logic [3:0] lc;
    logic [1:0] la, gpa;
    logic hrtc,vrtc,vsp,lten,rvv,hlgt;
    intel_8275 dut(.*);
    byte unsigned stream[0:8191];
    logic [3:0] graphics[0:47];
    integer stream_len=1, stream_pos=0, accepted=0, gap=0, stall=0;
    bit dma_auto=0, busy=0, prev_vrtc=0, random_stall=0, manual_dma=0;
    integer cols=1, nrows=1, lines=1, hr=2, vr=1, ul=0;
    integer rx=0, rr=0, rl=0, frames=0, observations=0, checks=0;
    integer mode=0, cursor_x=255, cursor_y=255, cursor_type=0;
    bit offset_mode=0, spaced=0, checking=0;
    integer frame_phase=0, seed=1;
    integer field_pattern=0;
    logic [31:0] rng=1;
    string vectors;
    bit verify_spacing=0, observed_drq=0;
    integer cclks=0, previous_request=0, spacing_acks=0, spacing_checks=0;
    integer requested_space=0, requested_burst=4;

    function automatic logic [31:0] next_random(input logic [31:0] value);
        logic [31:0] temp;
        temp=value^(value<<13); temp=temp^(temp>>17); return temp^(temp<<5);
    endfunction

    initial forever begin
        @(posedge clk);
        if (!rst_n) begin cclks=0; observed_drq=0; spacing_acks=0; end
        else begin
            if (cclk_en) cclks++;
            if (verify_spacing && drq && !observed_drq) begin
                if (spacing_acks%16!=0 && spacing_acks%requested_burst==0) begin
                    insist(cclks-previous_request>=requested_space,
                           "inter-burst spacing counted from DRQ");
                    insist(cclks-previous_request<=requested_space+1 || requested_space==0,
                           "inter-burst spacing does not add DACK latency");
                    spacing_checks++;
                end
                previous_request=cclks;
            end
            observed_drq=drq;
            if (verify_spacing && !dack_n && drq) spacing_acks++;
        end
    end

    // DMA controller BFM: only package pins, no DUT state inspection.
    initial forever begin
        @(negedge clk);
        if (!rst_n) begin
            dack_n=1; stream_pos=0; accepted=0; gap=0; prev_vrtc=0;
        end else begin
            if (vrtc && !prev_vrtc) stream_pos=0;
            prev_vrtc=vrtc;
            if (!manual_dma) begin
            if (!dack_n) begin
                dack_n=1; gap=stall;
                if (random_stall) begin rng=next_random(rng); gap=int'(rng[1:0]); end
            end
            else if (gap != 0) gap=gap-1;
            else if (drq && dma_auto && !busy) begin
                db_in=stream[stream_pos % stream_len];
                dack_n=0; stream_pos=stream_pos+1; accepted=accepted+1;
            end
            end
        end
    end

    task automatic insist(input bit condition, input string message);
        checks++;
        if (!condition) $fatal(1,"%s (x=%0d row=%0d line=%0d frame=%0d)",message,rx,rr,rl,frames);
    endtask
    task automatic reset_chip;
        busy=1; dma_auto=0; checking=0; random_stall=0; stall=0;
        verify_spacing=0; manual_dma=0;
        @(negedge clk); rst_n=0; cclk_en=0; cs_n=1; rd_n=1; wr_n=1; lpen=0;
        repeat(3) @(negedge clk);
        rst_n=1; rx=0; rr=0; rl=0; frames=0; frame_phase=0;
        cursor_x=255; cursor_y=255; cursor_type=0;
        cols=1; nrows=1; lines=1; hr=2; vr=1; ul=0; spaced=0; offset_mode=0;
        repeat(2) @(negedge clk); busy=0;
    endtask
    task automatic write_bus(input bit addr, input byte unsigned data, input integer hold=1);
        busy=1;
        @(negedge clk); a0=addr; db_in=data; cs_n=0; wr_n=0;
        repeat(hold) @(negedge clk);
        wr_n=1; cs_n=1; @(negedge clk); busy=0;
    endtask
    task automatic read_bus(input bit addr, output byte unsigned value, input integer hold=1);
        busy=1;
        @(negedge clk); a0=addr; cs_n=0; rd_n=0;
        #1; value=db_out; insist(db_oe,"CPU output enable");
        repeat(hold) @(negedge clk);
        rd_n=1; cs_n=1; @(negedge clk); busy=0;
    endtask

    task automatic check_cell;
        integer out_line, pos, region;
        logic [6:0] want_cc;
        logic [1:0] want_la, want_gpa;
        bit want_vsp, want_lten, want_rvv, want_hlgt;
        logic [3:0] vector;
        out_line=rl;
        if (rx>=cols) out_line=rl==lines-1 ? 0 : rl+1;
        if (offset_mode) out_line=out_line==0 ? lines-1 : out_line-1;
        insist(hrtc==(rx>=cols),"horizontal retrace");
        insist(vrtc==(rr>=nrows),"vertical retrace");
        insist(lc==4'(out_line),"line counter timing/offset");
        if (rx>=cols || rr>=nrows || (spaced && (rr%2)!=0))
            insist(vsp && !lten,"retrace/spaced row blanking");
        else if (frames>=2) begin
            pos=(spaced ? rr/2 : rr)*cols+rx;
            want_cc=7'((pos%95)+32); want_la=0; want_gpa=0;
            want_vsp=0; want_lten=0; want_rvv=0; want_hlgt=0;
            if (mode==1) begin
                want_cc=(rr==0 && rx==0) ? 7'h1d : 7'(65+pos);
                want_vsp=rr==0 && rx==0; want_gpa=3; want_rvv=1; want_hlgt=1;
                if (rr==0 && rx==0) begin want_gpa=0; want_rvv=0; want_hlgt=0; end
            end
            if (mode==2) begin
                want_cc=7'(65+pos); want_gpa=1; want_hlgt=1; want_lten=rl==ul;
            end
            if (mode==3) begin
                want_gpa=3; want_rvv=1;
                if (rx==0) begin
                    want_cc=7'h1c; want_vsp=1; want_gpa=0; want_rvv=0;
                end else begin
                    region=rl<ul ? 0 : (rl==ul ? 1 : 2);
                    vector=graphics[region*16+rx-1];
                    want_cc=7'h40+7'((rx-1)*4);
                    want_la=vector[3:2]; want_vsp=vector[1]; want_lten=vector[0];
                end
            end
            if (mode==4) begin
                want_cc=rx==0 ? 7'h22 : 7'h41;
                want_vsp=!frame_phase[4]; want_lten=rl==ul;
                if (rx==0) want_vsp=1; // visible blink + underline field code
            end
            if (mode==5) begin
                want_cc=rx==0 ? 7'h41 : 7'h70;
                want_vsp=rx!=0;
            end
            if (mode==6) begin
                want_cc=7'(65+rx); want_gpa=0; want_hlgt=0;
            end
            if (mode==7) begin
                want_cc=7'h41; want_vsp=rr!=0 || rl!=0 || rx!=0;
            end
            if (mode==8 || mode==9) begin
                want_cc=mode==8 && rx==0 ? 7'(field_pattern) : 7'(65+rx);
                if(mode==8 && rx==0) begin want_vsp=1; want_lten=0; end
                else begin
                    want_hlgt=bit'(field_pattern); want_gpa=2'(field_pattern>>2);
                    want_rvv=bit'(field_pattern>>4);
                    want_lten=bit'(field_pattern>>5) && rl==ul;
                    want_vsp=bit'(field_pattern>>1) && !frame_phase[4];
                end
            end
            if (mode==10) begin
                want_cc=rr==0 ? 7'h41 : 7'(67+rx);
                want_vsp=rr==0 && rx!=0;
            end
            if (cursor_x==rx && cursor_y==rr &&
                (cursor_type>=2 || !frame_phase[3])) begin
                if ((cursor_type%2)!=0) want_lten=want_lten || rl==ul;
                else want_rvv=!want_rvv;
            end
            if ((ul>=8 && (rl==0 || rl==lines-1)) ||
                (rx==0 && ((mode==1 && rr==0) || mode==3 || mode==4))) begin
                want_vsp=1; want_lten=0;
            end
            insist(vsp==want_vsp,"cell VSP");
            insist(lten==want_lten,"cell LTEN");
            // Suppressed cells have unspecified character output after EOR.
            if (!want_vsp || (mode!=5 && mode!=7 && mode!=10)) insist(cc==want_cc,"character code");
            insist(la==want_la,"graphics line attributes");
            insist(gpa==want_gpa,"general purpose attributes");
            insist(rvv==want_rvv,"reverse video/cursor");
            insist(hlgt==want_hlgt,"highlight");
            observations++;
        end
    endtask

    task automatic tick;
        @(negedge clk); cclk_en=1;
        #1;
        if (checking) check_cell();
        rx++;
        if (rx==cols+hr) begin
            rx=0; rl++;
            if (rl==lines) begin
                rl=0; rr++;
                if (rr==nrows) frame_phase=(frame_phase+1)%32;
                if (rr==nrows+vr) begin rr=0; frames++; end
            end
        end
        @(negedge clk); cclk_en=0;
        repeat(3) @(negedge clk);
    endtask
    task automatic run_frames(input integer count);
        byte unsigned ignored_status;
        repeat((cols+hr)*lines*(nrows+vr)*count) begin
            tick();
            // Cold start has no prefetched row; discard only that startup status.
            if (checking && frames==1 && rx==0 && rr==0 && rl==0)
                read_bus(1,ignored_status);
        end
    endtask
    task automatic configure(input integer width, height, scanlines, retrace,
                             retrace_rows, underline_pos, input bit offset_lc,
                             visible, double_space, input integer cursor=0,
                             dma_mode=3);
        byte unsigned status;
        reset_chip();
        cols=width; nrows=height; lines=scanlines; hr=retrace; vr=retrace_rows;
        ul=underline_pos; offset_mode=offset_lc; spaced=double_space; cursor_type=cursor;
        write_bus(1,0);
        write_bus(0,8'(width-1) | (double_space ? 8'h80 : 0),3);
        write_bus(0,8'(((retrace_rows-1)<<6)|(height-1)));
        write_bus(0,8'((underline_pos<<4)|(scanlines-1)));
        write_bus(0,8'((offset_lc ? 128 : 0)|(visible ? 64 : 0)|(cursor<<4)|(retrace/2-1)));
        read_bus(1,status); insist(status==0,"configuration status and held WR arity");
        write_bus(1,8'h20 | 8'(dma_mode));
        dma_auto=1; checking=1;
    endtask
    task automatic make_text;
        stream_len=cols*(spaced ? (nrows+1)/2 : nrows);
        for (integer i=0;i<stream_len;i++) stream[i]=8'((i%95)+32);
    endtask

    initial begin : suite
        byte unsigned status, value;
        integer before_count, width, height, scanlines, retrace, retrace_rows;
        if ($value$plusargs("seed=%d",seed)) begin end
        rng=32'(seed);
        if (!$value$plusargs("vectors=%s",vectors)) vectors="design/intel_8275/references/graphics_vectors.hex";
        $readmemh(vectors,graphics);
        reset_chip(); read_bus(1,status); insist(status==0,"hardware reset status");
        insist(vsp && !drq && !irq && !db_oe,"reset output state");
        write_bus(1,0); write_bus(0,7); write_bus(1,8'ha0);
        read_bus(1,status); insist(status==8'h48,"short parameter list");
        read_bus(1,status); insist(status==8'h40,"status flags cleared");
        write_bus(0,8'hff); read_bus(1,status); insist(status==8'h48,"extra parameter");
        write_bus(1,8'h80); read_bus(0,value); read_bus(1,status);
        insist(status[3],"wrong parameter direction");
        write_bus(1,0); write_bus(0,8'h7f); read_bus(1,status);
        insist(status[3],"undefined width clamps and signals IC");

        // Legal geometry sweeps include both capacity and timing extremes.
        mode=0;
        for (integer trial=0;trial<14;trial++) begin
            rng=next_random(rng); width=1+int'(rng[6:0])%80;
            rng=next_random(rng); height=1+int'(rng[2:0]);
            rng=next_random(rng); scanlines=2+int'(rng[3:0])%15;
            rng=next_random(rng); retrace=2*(1+int'(rng[3:0]));
            retrace_rows=1+trial%4;
            if (trial==0) begin width=1; height=1; scanlines=1; end
            if (trial==1) begin width=80; height=64; scanlines=16; end
            $display("geometry trial=%0d width=%0d rows=%0d lines=%0d",trial,width,height,scanlines);
            configure(width,height,scanlines,retrace,retrace_rows,7,
                      (trial%2)!=0,1,(trial%3)==0);
            make_text(); random_stall=scanlines>=4;
            run_frames(3); read_bus(1,status); insist(!status[1] && !status[0],"text DMA delivered on time");
        end

        // Visible attributes carry between rows and replay on each scanline.
        mode=1; configure(5,2,3,4,1,1,0,1,0); stream_len=10;
        for (integer i=0;i<10;i++) stream[i]=8'(65+i);
        stream[0]=8'h9d; run_frames(3);
        // Invisible attribute including a replacement in the last cell.
        mode=2; configure(5,2,3,4,1,1,1,0,0); stream_len=12;
        stream[0]=8'ha5; stream[1]=8'hc1;
        for (integer i=2;i<6;i++) stream[i]=8'(64+i);
        stream[6]=8'ha5; stream[7]=8'hc6;
        for (integer i=8;i<12;i++) stream[i]=8'(63+i);
        run_frames(3);
        // Last-cell invisible replacement must not terminate the burst early.
        mode=0; configure(1,1,2,4,1,0,0,0,0); checking=0;
        stream_len=2; stream[0]=8'h80; stream[1]=8'hc1;
        run_frames(2); insist(stream_pos==2,"last-cell replacement DMA count");
        insist(!vrtc && cc==7'h41 && !vsp,"replacement MSB discarded");

        mode=3; configure(12,1,3,4,1,1,0,1,0); stream_len=12; stream[0]=8'h9c;
        for (integer i=1;i<12;i++) stream[i]=8'hc0+8'((i-1)*4);
        run_frames(3);
        // Exhaustive combinations of the six field bits, both visibility modes.
        for(integer visibility=0;visibility<2;visibility++) begin
            for(integer pattern=0;pattern<64;pattern++) begin
                mode=visibility==1 ? 8 : 9; field_pattern=pattern;
                configure(2,1,3,4,1,1,0,visibility!=0,0);
                stream_len=visibility==1 ? 2 : 3;
                stream[0]=8'h80|8'(pattern);
                stream[1]=visibility==1 ? 8'h42 : 8'h41;
                stream[2]=8'h42; run_frames(3);
            end
        end
        // Exact frame divisors and four cursor forms.
        mode=4;
        for (integer form=0;form<4;form++) begin
            configure(3,1,3,4,1,1,0,1,0,form); stream_len=3;
            stream[0]=8'ha2; stream[1]=8'h41; stream[2]=8'h41;
            write_bus(1,8'h80); write_bus(0,1); write_bus(0,0);
            cursor_x=1; cursor_y=0; run_frames(35);
        end

        // Top/bottom suppression is independent of offset LC.
        mode=0; configure(4,2,12,2,1,10,1,1,0); make_text(); run_frames(3);
        // Status IRQ is at last row start and cleared only by a status read.
        mode=0; configure(4,2,3,4,1,1,0,1,0); make_text(); run_frames(2);
        read_bus(1,status); insist(status[5] && status[6] && !irq,"IRQ acknowledgement");
        write_bus(1,8'hc0); run_frames(1); insist(!irq,"disabled interrupt");
        write_bus(1,8'ha0); run_frames(1); insist(irq,"enabled interrupt");
        write_bus(1,8'h40); insist(vsp,"stop blanks display");
        checking=0; run_frames(1); read_bus(1,status); insist(status[6] && !status[2],"stop retains IE");

        // Light pen captures edge, not level; parameter reads do not acknowledge LP.
        reset_chip(); cols=1; nrows=1; lines=1; hr=2; vr=1;
        tick(); busy=1; @(negedge clk); lpen=1; repeat(3) @(negedge clk);
        write_bus(1,8'h60); read_bus(0,value,4); insist(value==1,"light pen column, held RD");
        read_bus(0,value); insist(value==0,"light pen row");
        read_bus(1,status); insist(status[4],"LP retained until status read");
        read_bus(1,status); insist(!status[4],"LP acknowledgement");
        @(negedge clk); lpen=0;

        // Preset requires two clocks, then freezes; release on a command.
        write_bus(1,8'he0);
        repeat(2) begin @(negedge clk); cclk_en=1; @(negedge clk); cclk_en=0; end
        insist(!hrtc && !vrtc && lc==0,"preset top left");
        repeat(8) begin @(negedge clk); cclk_en=1; @(negedge clk); cclk_en=0; end
        insist(!hrtc && !vrtc && lc==0,"preset remains held");
        write_bus(1,8'hc0); rx=0; rr=0; rl=0; tick(); insist(hrtc,"preset released to next character");

        // Deadline failure blanks a frame even after acknowledging DU; next VRTC recovers.
        mode=0; configure(8,2,2,2,1,1,0,1,0); make_text();
        checking=0; dma_auto=0; run_frames(2);
        read_bus(1,status); insist(status[1],"DMA underrun status");
        insist(vsp,"underrun blanking"); dma_auto=1; run_frames(2);
        read_bus(1,status); insist(!status[1],"underrun resumes after VRTC");
        insist(!vsp,"underrun recovered video");

        // Invisible FIFO wrap: the 17th entry overwrites the first.
        configure(18,1,4,4,1,1,0,0,0); checking=0; stream_len=36;
        for (integer i=0;i<18;i++) begin stream[2*i]=8'h80; stream[2*i+1]=8'(65+i); end
        run_frames(2); read_bus(1,status); insist(status[0],"FIFO overrun status");
        insist(cc==7'h51,"FIFO overwrote entry zero");

        // Stop codes, burst-boundary immediate stop versus one trailing dummy.
        for (integer code=0;code<2;code++) begin
            for (integer burst=0;burst<4;burst++) begin
                configure(8,1,4,4,1,1,0,1,0,0,burst); checking=0;
                stream_len=3; stream[0]=8'h41; stream[1]=code==0 ? 8'hf1 : 8'hf3; stream[2]=0;
                run_frames(2); insist(stream_pos==(burst<2 ? 2 : 3),"stop-code dummy count");
                read_bus(1,status); insist(!status[1],"stop-code is a complete row");
            end
        end
        // Every burst-space code; long rows provide enough time at 55 CCLK spacing.
        mode=0;
        for (integer spacing=0;spacing<8;spacing++) begin
            configure(16,1,16,32,4,7,0,1,0,0,spacing*4+2);
            requested_space=spacing==0 ? 0 : spacing*8-1;
            verify_spacing=1; make_text(); run_frames(3);
            read_bus(1,status); insist(!status[1],"burst spacing deadline");
        end
        // EOR without DMA stop: remaining bytes still fetched and blanked.
        mode=5; configure(4,1,3,4,1,1,0,1,0); stream_len=4;
        stream[0]=8'h41; stream[1]=8'hf0; stream[2]=8'h42; stream[3]=8'h43;
        run_frames(3); before_count=stream_pos; insist(before_count==4,"EOR keeps DMA");
        // EOS remains recognizable after EOR, and does not itself stop DMA.
        mode=7; configure(4,2,3,4,1,1,0,1,0); stream_len=8;
        for(integer i=0;i<8;i++) stream[i]=8'h41;
        stream[1]=8'hf0; stream[2]=8'hf2; run_frames(3);
        insist(stream_pos>=4,"EOS keeps DMA");
        mode=7; configure(4,2,3,4,1,1,0,1,0); stream_len=3;
        stream[0]=8'h41; stream[1]=8'hf3; stream[2]=0; run_frames(3);
        insist(stream_pos==3,"EOS-stop suppresses later-row DMA");
        mode=10; configure(4,2,3,4,1,1,0,1,0); stream_len=7;
        stream[0]=8'h41; stream[1]=8'hf1; stream[2]=0;
        for(integer i=3;i<7;i++) stream[i]=8'(64+i);
        run_frames(3);

        // A same-cycle CPU command wins over DACK. Held DACK is consumed once.
        configure(2,1,2,2,1,1,0,1,0); checking=0; dma_auto=0; manual_dma=1;
        repeat(8) tick(); insist(drq && vrtc,"manual DMA prefetch window");
        busy=1; @(negedge clk); cs_n=0; wr_n=0; a0=1; db_in=8'h40; dack_n=0;
        repeat(4) @(negedge clk); cs_n=1; wr_n=1;
        repeat(4) @(negedge clk); insist(drq,"CPU command suppressed colliding DMA");
        dack_n=1; @(negedge clk); write_bus(1,8'h23);
        busy=1; @(negedge clk); db_in=8'h41; dack_n=0;
        repeat(6) @(negedge clk); dack_n=1; repeat(3) @(negedge clk);
        insist(drq,"held DACK only accepted one byte");
        db_in=8'h42; dack_n=0; repeat(6) @(negedge clk);
        dack_n=1; repeat(3) @(negedge clk); insist(!drq,"two-byte row completed");
        busy=0; repeat(8) tick(); insist(cc==7'h41 && !vsp,"command/DMA arbitration preserves first byte");

        // The final byte may arrive on the exact row deadline without a false DU.
        configure(2,1,2,2,1,1,0,1,0); checking=0; dma_auto=0; manual_dma=1;
        repeat(8) tick(); busy=1;
        @(negedge clk); db_in=8'h41; dack_n=0;
        @(negedge clk); dack_n=1; repeat(3) @(negedge clk);
        repeat(7) tick(); // x=3, final scanline of the prefetch row
        @(negedge clk); db_in=8'h42; dack_n=0; cclk_en=1;
        @(negedge clk); dack_n=1; cclk_en=0; repeat(3) @(negedge clk);
        insist(!vrtc && cc==7'h41 && !vsp,"final-byte deadline displays completed row");
        read_bus(1,status); insist(!status[1],"no underrun on exact completion deadline");

        // A late ACK already exhausts burst spacing: no additional gap is inserted.
        configure(2,1,16,32,1,1,0,1,0,0,4); checking=0; dma_auto=0; manual_dma=1;
        repeat(34*16+20) tick(); insist(drq,"late-ACK request pending");
        busy=1; @(negedge clk); db_in=8'h41; dack_n=0;
        @(negedge clk); dack_n=1; repeat(3) @(negedge clk);
        insist(drq,"late ACK consumes spacing measured from request");

        // New LP event is retained when status is acknowledged in the same cycle.
        reset_chip(); busy=1; @(negedge clk); a0=1; cs_n=0; rd_n=0; lpen=1;
        @(negedge clk); cs_n=1; rd_n=1; lpen=0; @(negedge clk); busy=0;
        read_bus(1,status); insist(status[4],"new event wins concurrent status acknowledgement");
        insist(spacing_checks>=72,"all inter-burst spacing settings observed");
        $display("8275 PIN SUITE PASSED seed=%0d checks=%0d cells=%0d spacing=%0d",seed,checks,observations,spacing_checks);
        $finish;
    end
    initial begin #200000000; $fatal(1,"8275 suite watchdog"); end
endmodule
