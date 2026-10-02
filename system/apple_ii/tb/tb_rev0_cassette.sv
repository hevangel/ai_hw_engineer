`timescale 1ns/1ps
module tb_rev0_cassette;
    logic osc=0, reset_n=0, key_strobe=0;
    logic [6:0] key_data=0;
    tri [15:0] address;
    tri [7:0] data;
    tri phi0, rw, sync, tape_out;
    real cassette_voltage=0.0;
    wire real jack_voltage;
    logic jack_valid;
    integer unknown_reads, polls=0, instructions=0, phase=0;
    integer edge_file, input_file, edges=0, received=0, verified=0, polarity=1;
    longint cpu_cycles=0;
    logic entered=0, wrote_routine=0, read_routine=0;
    logic vector_low=0, vector_high=0, reset_fetch=0;
    logic [7:0] expected [0:6];
    logic [15:0] recent_pc [0:31];
    logic [7:0] recent_opcode [0:31];
    apple_ii_rev0_reference #(
        .ROM_D0("work/cassette_D0.hex"),.ROM_D8("work/rom_D8.hex"),
        .ROM_E0("work/rom_E0.hex"),.ROM_E8("work/rom_E8.hex"),
        .ROM_F0("work/rom_F0.hex"),.ROM_F8("work/rom_F8.hex"),.CHAR_ROM("work/char_2513.hex")
    ) dut (
        .master_oscillator(osc),.reset_n(reset_n),.keyboard_data(key_data),
        .keyboard_strobe(key_strobe),.buttons(3'b0),
        .paddle0_ohms(75000.0),.paddle1_ohms(75000.0),.paddle2_ohms(75000.0),.paddle3_ohms(75000.0),
        .cassette_voltage(cassette_voltage),.cpu_address(address),.cpu_data(data),
        .cpu_rw(rw),.cpu_sync(sync),.cpu_phi0(phi0),.unknown_read_samples(unknown_reads),
        .video_data(),.composite_sync(),.speaker(),.cassette_out(tape_out),.annunciators(),
        .cassette_jack_voltage(jack_voltage),.cassette_jack_valid(jack_valid)
    );
    initial forever #34.921 osc=~osc;
    initial begin
        if($value$plusargs("POLARITY=%d",polarity)) begin end
        if(polarity!=1 && polarity!=-1) $fatal(1,"Invalid tape polarity");
        $readmemh("work/cassette_expected.hex",expected);
        edge_file=$fopen("work/cassette_edges.csv","w");
        input_file=$fopen("work/cassette_input.csv","w");
        if(!edge_file || !input_file) $fatal(1,"Cannot open cassette captures");
        // ASSUMPTION: selected startup states for unresettable TTL packages.
        dut.board.B1.q=0; dut.board.C2.q=0;
        dut.board.D11.q=0; dut.board.D12.q=0; dut.board.D13.q=0; dut.board.D14.q=0;
        dut.board.B10.q1=0; dut.board.B10.n1=1;
        // J13 cassette flip-flop has no reset; exercise both possible states.
        dut.board.J13.q1=(polarity<0); dut.board.J13.n1=(polarity>0);
        #20000; reset_n=1;
        #450000000; $fatal(1,"Cassette historical byte-routine timeout; phase=%0d received=%0d",phase,received);
    end
    task automatic key(input logic [6:0] value,input bit await_poll=1);
        @(negedge phi0); #100;
        key_data=value; key_strobe=1;
        #1200; key_strobe=0;
        wait(dut.board.B10.q1===1'b0);
        @(negedge phi0);
        if(await_poll) wait(address===16'hc000 && rw===1'b1);
    endtask
    initial begin
        wait(polls>=8);
        key("D"); key("0"); key("0"); key("0"); key("G"); key(7'h0d,0);
        wait(phase==5);
        if(!reset_fetch || !entered || !wrote_routine || !read_routine || received!=7 || verified!=7 || edges!=112)
            $fatal(1,"Incomplete cassette exercise: entry=%b write=%b read=%b bytes=%0d edges=%0d",
                entered,wrote_routine,read_routine,received,edges);
        $fclose(edge_file); $fclose(input_file);
        $display("PASS historical cassette byte routines; polarity=%0d bytes=%0d DRAM readbacks=%0d edges=%0d instructions=%0d unknown read samples=%0d",
            polarity,received,verified,edges,instructions,unknown_reads);
        $finish;
    end
    // Independent analog stimulus from the published bit format, not loopback.
    initial begin
        wait(phase==3);
        cassette_voltage=polarity*0.6;
        wait(phase==4);
        for(int byte_index=0;byte_index<7;byte_index++)
            for(int bit_index=7;bit_index>=0;bit_index--)
                for(int half=0;half<2;half++) begin
                    if(expected[byte_index][bit_index]) #500000; else #250000;
                    cassette_voltage= -cassette_voltage;
                    $fdisplay(input_file,"%0.3f,%0.6f",$realtime,cassette_voltage);
                end
    end
    initial forever begin
        @(tape_out);
        if(phase==1) begin
            #1; // Allow the resistive output observation to settle after J13.
            if($isunknown(tape_out)) $fatal(1,"Unknown physical cassette output");
            if(!jack_valid) $fatal(1,"Invalid cassette jack observation");
            $fdisplay(edge_file,"%0.3f,%b,%0d,%0.9f",$realtime,tape_out,cpu_cycles,jack_voltage);
            edges++;
        end
    end
    always_ff @(negedge phi0) begin
        cpu_cycles<=cpu_cycles+1;
        if(reset_n && rw && address==16'hfffc) begin
            if(data!==8'h59) $fatal(1,"Incorrect reset vector low");
            vector_low<=1;
        end
        if(reset_n && rw && address==16'hfffd && vector_low) begin
            if(data!==8'hff) $fatal(1,"Incorrect reset vector high");
            vector_high<=1;
        end
        if(reset_n && sync && vector_high) begin
            instructions<=instructions+1;
            recent_pc[instructions%32]=address; recent_opcode[instructions%32]=data;
            if($isunknown(data)) begin
                for(int i=0;i<32;i++) $display("recent %h %h",recent_pc[(instructions+1+i)%32],recent_opcode[(instructions+1+i)%32]);
                $fatal(1,"Unknown opcode at %h phase=%0d polls=%0d",address,phase,polls);
            end
            if(!reset_fetch) begin
                if(address!==16'hff59 || data!==8'h20) $fatal(1,"Incorrect exact reset fetch %h/%h",address,data);
                reset_fetch<=1;
            end
            if(address==16'hd000) begin
                if(data!==8'h78) $fatal(1,"Incorrect exact exerciser entry");
                entered<=1;
            end
            if(entered && address==16'hfeed) wrote_routine<=1;
            if(entered && address==16'hfcec) read_routine<=1;
        end
        if(reset_n && rw && address==16'hc000) polls<=polls+1;
        if(entered && !rw && address==16'h02f0) begin
            if($isunknown(data) || data!==phase+1) $fatal(1,"Invalid phase marker %h after %0d",data,phase);
            phase<=int'(data);
        end
        if(entered && !rw && address>=16'h0220 && address<=16'h0226) begin
            if(address!==16'h0220+received || data!==expected[received])
                $fatal(1,"Cassette input byte %0d at %h: expected %h got %h",received,address,expected[received],data);
            received<=received+1;
        end
        if(entered && !rw && address>=16'h0240 && address<=16'h0246) begin
            if(address!==16'h0240+verified || data!==expected[verified])
                $fatal(1,"Cassette DRAM readback byte %0d: expected %h got %h",verified,expected[verified],data);
            verified<=verified+1;
        end
    end
    initial begin
        #100000;
        if(!reset_fetch) $fatal(1,"Physical reset vector sequence was not completed");
    end
endmodule
