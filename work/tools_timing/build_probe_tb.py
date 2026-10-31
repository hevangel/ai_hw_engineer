"""Build the offset-parameterized boot TB for the capture-point experiment."""
from pathlib import Path

SRC = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\tb\tb_rev0_boot.sv')
OUT = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\work\probe\tb_boot_off.sv')

src = SRC.read_text()
old = """    initial forever begin
        @(posedge dut.board.B10.p3); #10;
        if(capture) begin
            if(dut.flash !== captured_flash) $fatal(1,"Flash phase changed during Monitor frame");
            $fdisplay(video_file,"%0.3f,%0d,%0d,%b,%b,%h",$realtime,h,v,video,video_sync,latched);
            pixel_samples++;
        end
    end
"""
new = """    initial begin
        int off = 10;
        void'($value$plusargs("off=%d", off));
        forever begin
            @(posedge dut.board.B10.p3); #(off);
            if(capture) begin
                if(dut.flash !== captured_flash) $fatal(1,"Flash phase changed during Monitor frame");
                $fdisplay(video_file,"%0.3f,%0d,%0d,%b,%b,%h",$realtime,h,v,video,video_sync,latched);
                pixel_samples++;
            end
        end
    end
"""
assert src.count(old) == 1, src.count(old)
OUT.write_text(src.replace(old, new), newline='\r\n')
print('probe TB rebuilt:', OUT)
