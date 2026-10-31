"""Capture the Monitor frame on the video sample clock (CRLF file)."""
from pathlib import Path

path = Path("system/apple_ii/tb/tb_rev0_boot.sv")
text = path.read_text()

old_block = """    localparam real VIDEO_SAMPLE_NS=50.0;
    localparam real SCAN_SAMPLE_NS=60.0;
    // Delayed continuous assignments start as X everywhere, so the netlist gets
    // a static settle window before the real oscillator starts. Silicon has no
    // equivalent X state; this only removes a time-zero artifact.
    initial begin #2000; forever #34.921 osc=~osc; end
    initial forever begin
        @(posedge dut.board.B10.p3); #(VIDEO_SAMPLE_NS);
        if(capture) begin
            if(dut.flash !== captured_flash) $fatal(1,"Flash phase changed during Monitor frame");
            $fdisplay(video_file,"%0.3f,%0d,%0d,%b,%b,%h",$realtime,h,v,video,video_sync,latched);
            pixel_samples++;
        end
    end
"""
new_block = """    localparam real VIDEO_SAMPLE_NS=50.0;
    // Delayed continuous assignments start as X everywhere, so the netlist gets
    // a static settle window before the real oscillator starts. Silicon has no
    // equivalent X state; this only removes a time-zero artifact.
    initial begin #2000; forever #34.921 osc=~osc; end
"""
assert text.count(old_block) == 1
text = text.replace(old_block, new_block)

old_frame = """        wait(polls>=poll_target);
        do begin @(posedge dut.board.D14.p2); #(SCAN_SAMPLE_NS); end while(h!==6'd24 || v!==9'h100);
        captured_flash=dut.flash;
        if($isunknown(captured_flash)) $fatal(1,"Unknown flash phase");
        screen_file=$fopen("work/monitor_screen.hex","w");
        flash_file=$fopen("work/monitor_flash.txt","w");
        video_file=$fopen("work/monitor_video.csv","w");
        if(!screen_file || !flash_file || !video_file) $fatal(1,"Cannot open Monitor frame files");
        for(int i=0;i<1024;i++) $fdisplay(screen_file,"%02h",screen[i]);
        $fdisplay(flash_file,"%b",captured_flash);
        $fclose(screen_file); $fclose(flash_file);
        capture=1;
        @(posedge dut.board.D14.p2); #(SCAN_SAMPLE_NS);
        do begin @(posedge dut.board.D14.p2); #(SCAN_SAMPLE_NS); end while(h!==6'd24 || v!==9'h100);
        capture=0; $fclose(video_file);
        if(pixel_samples!=238944) $fatal(1,"Incomplete Monitor frame: %0d samples",pixel_samples);
        $display("CAPTURE historical Monitor video: %0d master-clock samples",pixel_samples);"""
new_frame = """        wait(polls>=poll_target);
        // The video sample clock defines sample 0. Deriving the start from the
        // scan-counter load pulse ties the frame to a hand-tuned delay and
        // shifts the raster when package delays change.
        do begin @(posedge dut.board.B10.p3); #(VIDEO_SAMPLE_NS); end while(h!==6'd24 || v!==9'h100);
        captured_flash=dut.flash;
        if($isunknown(captured_flash)) $fatal(1,"Unknown flash phase");
        screen_file=$fopen("work/monitor_screen.hex","w");
        flash_file=$fopen("work/monitor_flash.txt","w");
        video_file=$fopen("work/monitor_video.csv","w");
        if(!screen_file || !flash_file || !video_file) $fatal(1,"Cannot open Monitor frame files");
        for(int i=0;i<1024;i++) $fdisplay(screen_file,"%02h",screen[i]);
        $fdisplay(flash_file,"%b",captured_flash);
        $fclose(screen_file); $fclose(flash_file);
        capture=1; pixel_samples=0;
        forever begin
            if(dut.flash !== captured_flash) $fatal(1,"Flash phase changed during Monitor frame");
            $fdisplay(video_file,"%0.3f,%0d,%0d,%b,%b,%h",$realtime,h,v,video,video_sync,latched);
            pixel_samples++;
            if(pixel_samples==238944) break;
            @(posedge dut.board.B10.p3); #(VIDEO_SAMPLE_NS);
        end
        capture=0; $fclose(video_file);
        if(pixel_samples!=238944) $fatal(1,"Incomplete Monitor frame: %0d samples",pixel_samples);
        $display("CAPTURE historical Monitor video: %0d master-clock samples",pixel_samples);"""
assert text.count(old_frame) == 1
text = text.replace(old_frame, new_frame)

path.write_text(text, newline="\r\n")
print("patched", path)
