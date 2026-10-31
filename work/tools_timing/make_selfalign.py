"""Build a self-aligned boot TB candidate from the current testbench.

The frame now starts on the (h,v) state the sampler itself observes, instead of
waiting on a different clock with a fixed delay, so the capture aligns the same
way at legacy, typical and maximum package delays.
"""
from pathlib import Path

SRC = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\tb\tb_rev0_boot.sv')
OUT = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\work\probe\tb_boot_selfalign.sv')

src = SRC.read_text()

old_sampler = """    initial forever begin
        @(posedge dut.board.B10.p3); #10;
        if(capture) begin
            if(dut.flash !== captured_flash) $fatal(1,"Flash phase changed during Monitor frame");
            $fdisplay(video_file,"%0.3f,%0d,%0d,%b,%b,%h",$realtime,h,v,video,video_sync,latched);
            pixel_samples++;
        end
    end
"""
new_sampler = """    // One sample per dot, taken after the counters and the serial output have
    // settled: 50 ns is past the 40 ns worst-case clock-to-Q of the 74LS74s and
    // still inside the 69.842 ns dot. The frame starts on the state this sampler
    // observes, so alignment does not depend on a fixed offset.
    logic frame_armed=0, frame_done=0;
    task automatic emit_sample;
        if(dut.flash !== captured_flash) $fatal(1,"Flash phase changed during Monitor frame");
        $fdisplay(video_file,"%0.3f,%0d,%0d,%b,%b,%h",$realtime,h,v,video,video_sync,latched);
        pixel_samples++;
    endtask
    initial forever begin
        @(posedge dut.board.B10.p3); #50;
        if(capture) begin
            emit_sample();
            if(pixel_samples==238944) begin capture=0; $fclose(video_file); frame_done=1; end
        end
        else if(frame_armed && h===6'd24 && v===9'h100) begin
            int screen_file, flash_file;
            captured_flash=dut.flash;
            if($isunknown(captured_flash)) $fatal(1,"Unknown flash phase");
            screen_file=$fopen("work/monitor_screen.hex","w");
            flash_file=$fopen("work/monitor_flash.txt","w");
            video_file=$fopen("work/monitor_video.csv","w");
            if(!screen_file || !flash_file || !video_file) $fatal(1,"Cannot open Monitor frame files");
            for(int i=0;i<1024;i++) $fdisplay(screen_file,"%02h",screen[i]);
            $fdisplay(flash_file,"%b",captured_flash);
            $fclose(screen_file); $fclose(flash_file);
            pixel_samples=0; capture=1;
            emit_sample();
        end
    end
"""

old_task = """    task automatic monitor_frame;
        int screen_file, flash_file, poll_target;
        poll_target=polls+8;
        wait(polls>=poll_target);
        do begin @(posedge dut.board.D14.p2); #25; end while(h!==6'd24 || v!==9'h100);
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
        @(posedge dut.board.D14.p2); #25;
        do begin @(posedge dut.board.D14.p2); #25; end while(h!==6'd24 || v!==9'h100);
        capture=0; $fclose(video_file);
        if(pixel_samples!=238944) $fatal(1,"Incomplete Monitor frame: %0d samples",pixel_samples);
        $display("CAPTURE historical Monitor video: %0d master-clock samples",pixel_samples);
    endtask
"""
new_task = """    task automatic monitor_frame;
        int poll_target;
        poll_target=polls+8;
        wait(polls>=poll_target);
        frame_armed=1;
        wait(frame_done);
        if(pixel_samples!=238944) $fatal(1,"Incomplete Monitor frame: %0d samples",pixel_samples);
        $display("CAPTURE historical Monitor video: %0d master-clock samples",pixel_samples);
    endtask
"""

for old, new, name in ((old_sampler, new_sampler, 'sampler'), (old_task, new_task, 'task')):
    assert src.count(old) == 1, f'{name}: {src.count(old)}'
    src = src.replace(old, new)

OUT.write_text(src, newline='\r\n')
print('self-aligned candidate written:', OUT)
