"""Replace the unsupported break statement in the capture loop."""
from pathlib import Path

p = Path("system/apple_ii/tb/tb_rev0_boot.sv")
t = p.read_text()
old = """        forever begin
            if(dut.flash !== captured_flash) $fatal(1,"Flash phase changed during Monitor frame");
            $fdisplay(video_file,"%0.3f,%0d,%0d,%b,%b,%h",$realtime,h,v,video,video_sync,latched);
            pixel_samples++;
            if(pixel_samples==238944) break;
            @(posedge dut.board.B10.p3); #(VIDEO_SAMPLE_NS);
        end"""
new = """        while(pixel_samples<238944) begin
            if(dut.flash !== captured_flash) $fatal(1,"Flash phase changed during Monitor frame");
            $fdisplay(video_file,"%0.3f,%0d,%0d,%b,%b,%h",$realtime,h,v,video,video_sync,latched);
            pixel_samples++;
            if(pixel_samples<238944) begin
                @(posedge dut.board.B10.p3); #(VIDEO_SAMPLE_NS);
            end
        end"""
assert t.count(old) == 1, t.count(old)
p.write_text(t.replace(old, new), newline="\r\n")
print("ok")
