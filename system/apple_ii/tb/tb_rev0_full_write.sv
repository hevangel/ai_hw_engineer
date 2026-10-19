`ifndef APPLE_II_CPU_MODULE
`define APPLE_II_CPU_MODULE apple_ii_rev0_reference
`endif
`timescale 1ns/1ps
module tb_rev0_full_write;
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
        dut.board.J13.q1=0; dut.board.J13.n1=1;
        #20000; reset_n=1;
        #30000000000;
        $fatal(1,"Full WRITE timeout PC=%h bus=%h polls=%d strobe=%b",dut.H7.core.pc_o,address,polls,dut.board.B10.q1);
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
    logic started=0;
    int cpu_cycles=0, edges=0, edge_file;
    initial edge_file=$fopen("work/full_cassette_board.csv","w");
    task automatic line(input string value);
        for(int i=0;i<value.len();i++) key(value[i]);
        key(7'h0d);
    endtask
    initial begin
        wait(polls>=8);
        key(7'h1b); key("@");
        line("2FD:00 FF 55 AA A5 5A");
        line("2FD.302W");
        if(!started || edges!=16499 || !reset_fetch)
            $fatal(1,"Incomplete full physical WRITE: %0d edges",edges);
        $fclose(edge_file);
        $display("PASS full physical original Monitor WRITE, unmodified leader and inclusive page-crossing payload; edges=%0d unknown reads=%0d",edges,unknown_reads);
        $finish;
    end
    initial forever begin
        @(dut.cassette_out);
        if(started) begin
            #1;
            if($isunknown(dut.cassette_out) || !dut.cassette_jack_valid)
                $fatal(1,"Unresolved physical cassette output");
            $fdisplay(edge_file,"%0.3f,%b,%0d,%0.9f",$realtime,
                dut.cassette_out,cpu_cycles,dut.cassette_jack_voltage);
            edges++;
        end
    end
    always_ff @(negedge phi0) begin
        cpu_cycles<=cpu_cycles+1;
        if(reset_n && rw && address==16'hc000) polls<=polls+1;
        if(reset_n && sync) begin
            if($isunknown(data)) $fatal(1,"Unknown physical opcode %h",address);
            if(address==16'hfecd) started<=1;
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
