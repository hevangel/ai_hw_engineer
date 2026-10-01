`timescale 1ns/1ps
module tb_rev0_boot;
    logic osc=0, reset_n=0;
    tri [15:0] address;
    tri [7:0] data;
    tri phi0, rw, sync;
    integer unknown_reads;
    integer instructions=0;
    integer polls=0;
    logic [6:0] key_data=0;
    logic key_strobe=0;
    logic wrote_first=0, wrote_second=0, read_first=0, read_second=0;
    logic vector_low=0, vector_high=0, reset_fetch=0;
    apple_ii_rev0_reference #(
        .ROM_D0("work/rom_D0.hex"),.ROM_D8("work/rom_D8.hex"),
        .ROM_E0("work/rom_E0.hex"),.ROM_E8("work/rom_E8.hex"),
        .ROM_F0("work/rom_F0.hex"),.ROM_F8("work/rom_F8.hex"),.CHAR_ROM("work/char_2513.hex")
    ) dut (
        .master_oscillator(osc),.reset_n(reset_n),.keyboard_data(key_data),
        .keyboard_strobe(key_strobe),.buttons(3'b0),
        .paddle0_ohms(75000.0),.paddle1_ohms(75000.0),.paddle2_ohms(75000.0),.paddle3_ohms(75000.0),
        .cassette_voltage(0.0),.cpu_address(address),.cpu_data(data),
        .cpu_rw(rw),.cpu_sync(sync),.cpu_phi0(phi0),.unknown_read_samples(unknown_reads),
        .video_data(),.composite_sync(),.speaker(),.cassette_out(),.annunciators()
    );
    initial forever #34.921 osc=~osc;
    initial begin
        // ASSUMPTION: selected power-up state for unresettable TTL packages.
        dut.board.B1.q=0; dut.board.C2.q=0;
        dut.board.D11.q=0; dut.board.D12.q=0; dut.board.D13.q=0; dut.board.D14.q=0;
        // Keyboard strobe latch has no power-on reset; emulate a cleared latch.
        dut.board.B10.q1=0; dut.board.B10.n1=1;
        #20000; reset_n=1;
        #250000000;
        $fatal(1,"Historical monitor command/verification timed out");
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
    initial begin
        wait(polls>=8);
        // Authentic Monitor syntax: deposit two bytes, then examine them.
        key("3"); key("0"); key("0"); key(":"); key("A"); key("5");
        key(" "); key("5"); key("A"); key(7'h0d);
        wait(wrote_first && wrote_second);
        key("3"); key("0"); key("0"); key("."); key("3"); key("0"); key("1"); key(7'h0d);
        wait(read_first && read_second);
        if(!reset_fetch) $fatal(1,"reset vector/fetch sequence not observed");
        $display("PASS historical Monitor keyboard deposit/examine through chip wiring; instructions=%0d unknown read samples=%0d",instructions,unknown_reads);
        $finish;
    end
    always_ff @(negedge phi0) begin
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
        if(reset_n && !rw && address==16'h0300 && data==8'ha5) wrote_first<=1;
        if(reset_n && !rw && address==16'h0301 && data==8'h5a) wrote_second<=1;
        if(wrote_first && wrote_second && rw && address==16'h0300) begin
            if(data!==8'ha5) $fatal(1,"Monitor examine 0300 %h",data);
            read_first<=1;
        end
        if(wrote_first && wrote_second && rw && address==16'h0301) begin
            if(data!==8'h5a) $fatal(1,"Monitor examine 0301 %h",data);
            read_second<=1;
        end
    end
endmodule
