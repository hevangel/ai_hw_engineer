`ifndef APPLE_II_CPU_MODULE
`define APPLE_II_CPU_MODULE apple_ii_rev0_reference
`endif
`timescale 1ns/1ps
module tb_front_panel;
    logic osc=0, reset_n=0;
    tri [15:0] address;
    tri [7:0] data;
    tri phi0, rw, sync;
    tri video, video_sync;
    integer unknown_reads;
    logic [6:0] key_data=0;
    logic key_strobe=0;
    apple_ii_rev0_authored #(
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
        #20000; reset_n=1;

    end
    tri [5:0] h={dut.board.D13.p13,dut.board.D13.p14,dut.board.D14.p11,
                 dut.board.D14.p12,dut.board.D14.p13,dut.board.D14.p14};
    tri [8:0] v={dut.board.D11.p11,dut.board.D11.p12,dut.board.D11.p13,dut.board.D11.p14,
                 dut.board.D12.p11,dut.board.D12.p12,dut.board.D12.p13,dut.board.D12.p14,dut.board.D13.p11};
    logic [107519:0] pixels='x;
    int position=0, frame_line, sample;
    bit capture=0, boundary=0;
    initial forever begin
        @(posedge dut.board.B10.p3); #10;
        if(!boundary && h===6'd24 && v===9'h100) begin capture=1; position=0; end
        boundary=(h===6'd24 && v===9'h100);
        if(capture) begin
            frame_line=position/912; sample=position%912;
            if(frame_line<192 && sample>=14 && sample<574)
                pixels[frame_line*560+sample-14]=video;
            position++;
            if(position==238944) begin
                $a2_frame(pixels); capture=0;
                $display("Front panel frame at %0t, unknown CPU reads=%0d",$time,unknown_reads);
            end
        end
    end
    initial begin : keyboard_input
        integer event_code;
        wait(reset_n);
        forever begin
            @(negedge phi0); #100;
            if(address===16'hc000 && rw===1'b1) begin
                event_code=$a2_key();
                if(event_code & 32'h100) begin
                    key_data=7'(event_code); key_strobe=1;
                    #1200; key_strobe=0;
                    wait(dut.board.B10.q1===1'b0);
                end
            end
        end
    end
    // The operator RES key must work during cassette/firmware execution,
    // independently of C000 polling. Host-control sampling is at most 64
    // CPU clocks apart; no internal package state is reset here.
    initial begin : reset_input
        wait(reset_n);
        forever begin
            repeat(64) @(negedge phi0);
            if($a2_reset()) begin reset_n=0; #20000; reset_n=1; end
        end
    end
endmodule
