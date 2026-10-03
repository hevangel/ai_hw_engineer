`ifndef APPLE_II_CPU_MODULE
`define APPLE_II_CPU_MODULE apple_ii_rev0_reference
`endif
`timescale 1ns/1ps
module tb_rev0_full_read;
    logic osc=0, reset_n=0;
    real cassette_input=0.0;
    int polarity=1, bad_checksum=0;
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
        .cassette_voltage(cassette_input),.cpu_address(address),.cpu_data(data),
        .cpu_rw(rw),.cpu_sync(sync),.cpu_phi0(phi0),.unknown_read_samples(unknown_reads),
        .video_data(video),.composite_sync(video_sync),.speaker(),.cassette_out(),.annunciators()
    );
    initial forever #34.921 osc=~osc;
    initial begin
        if($value$plusargs("POLARITY=%d",polarity)) begin end
        if($value$plusargs("BADCHECK=%d",bad_checksum)) begin end
        if((polarity!=1 && polarity!=-1) || (bad_checksum!=0 && bad_checksum!=1))
            $fatal(1,"Invalid tape stimulus settings");
        // ASSUMPTION: selected power-up state for unresettable TTL packages.
        dut.board.B1.q=0; dut.board.C2.q=0;
        dut.board.D11.q=0; dut.board.D12.q=0; dut.board.D13.q=0; dut.board.D14.q=0;
        // Keyboard strobe latch has no power-on reset; emulate a cleared latch.
        dut.board.B10.q1=0; dut.board.B10.n1=1;
        dut.board.J13.q1=0; dut.board.J13.n1=1;
        #20000; reset_n=1;
        #30000000000;
        $fatal(1,"Full READ timeout PC=%h bus=%h polls=%d strobe=%b",dut.H7.core.pc_o,address,polls,dut.board.B10.q1);
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
    logic started=0, completed=0;
    logic [7:0] expected[0:6];
    initial begin
        expected[0]=8'h00; expected[1]=8'hff; expected[2]=8'h55;
        expected[3]=8'haa; expected[4]=8'ha5; expected[5]=8'h5a; expected[6]=8'h00;
    end
    int received=0, verified=0, bells=0, printed_file;
    initial printed_file=$fopen("work/full_read_output.txt","w");
    task automatic line(input string value);
        for(int i=0;i<value.len();i++) key(value[i]);
        key(7'h0d);
    endtask
    initial begin
        wait(polls>=8);
        key(7'h1b); key("@");
        line("2FD:3C 3C 3C 3C 3C 3C");
        line("2FD.302R");
        if(!started || received!=6 || bells==0 || !reset_fetch)
            $fatal(1,"Incomplete full physical READ received=%0d bells=%0d",received,bells);
        completed=1;
        line("2FD.302");
        if(verified!=6) $fatal(1,"Missing physical DRAM readback %0d",verified);
        $fclose(printed_file);
        $display("PASS full physical original Monitor READ polarity=%0d bad_checksum=%0d payload=%0d readback=%0d unknown reads=%0d",polarity,bad_checksum,received,verified,unknown_reads);
        $finish;
    end
    // Independent published tape format at the physical Cap10 input.
    initial begin
        wait(started);
        cassette_input=polarity*0.6;
        repeat(12000) begin #650000; cassette_input=-cassette_input; end
        #200000; cassette_input=-cassette_input;
        #250000; cassette_input=-cassette_input;
        for(int byte_index=0;byte_index<7;byte_index++)
            for(int bit_index=7;bit_index>=0;bit_index--)
                for(int half=0;half<2;half++) begin
                    if((expected[byte_index] ^ (byte_index==6 ? 8'(bad_checksum) : 8'h00)) & (8'h01<<bit_index))
                        #500000; else #250000;
                    cassette_input=-cassette_input;
                end
    end
    always_ff @(negedge phi0) begin
        if(reset_n && rw && address==16'hc000) polls<=polls+1;
        if(started && address==16'hc030) bells<=bells+1;
        if(started && !rw && address>=16'h02fd && address<=16'h0302) begin
            if(received>=6 || address!==16'h02fd+received || data!==expected[received])
                $fatal(1,"Physical READ byte at %h got %h",address,data);
            received<=received+1;
        end
        if(completed && rw && address>=16'h02fd && address<=16'h0302) begin
            if(verified>=6 || address!==16'h02fd+verified || data!==expected[verified])
                $fatal(1,"Physical READ readback at %h got %h",address,data);
            verified<=verified+1;
        end
        if(reset_n && sync) begin
            if($isunknown(data)) $fatal(1,"Unknown physical opcode %h",address);
            if(address==16'hfded) $fwrite(printed_file,"%c",dut.H7.core.a_o & 8'h7f);
            if(address==16'hfefd) started<=1;
            if(vector_high && !reset_fetch) begin
                if(address!==16'hff59 || data!==8'h20) $fatal(1,"Exact reset fetch");
                reset_fetch<=1;
            end
        end
        if(reset_n && rw && address==16'hfffc) begin
            if(data!==8'h59) $fatal(1,"Reset low");
            vector_low<=1;
        end
        if(reset_n && rw && address==16'hfffd && vector_low) begin
            if(data!==8'hff) $fatal(1,"Reset high");
            vector_high<=1;
        end
    end
endmodule
