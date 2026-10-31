from pathlib import Path
p = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\work\probe\tb_video_probe.sv')
t = p.read_text()
decl = """    tri [5:0] h={dut.board.D13.p13,dut.board.D13.p14,dut.board.D14.p11,
                 dut.board.D14.p12,dut.board.D14.p13,dut.board.D14.p14};
    tri [8:0] v={dut.board.D11.p11,dut.board.D11.p12,dut.board.D11.p13,dut.board.D11.p14,
                 dut.board.D12.p11,dut.board.D12.p12,dut.board.D12.p13,dut.board.D12.p14,dut.board.D13.p11};
"""
assert t.count(decl) == 1
t = t.replace(decl, "")
anchor = "    );\n    initial begin #2000"
assert t.count(anchor) == 1
t = t.replace(anchor, "    );\n" + decl + "    initial begin #2000")
p.write_text(t, newline='\r\n')
print('declarations moved after the instance')
