from pathlib import Path
src = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\work\probe\tb_boot_off.sv').read_text()
n = src.count('#25;')
src = src.replace('#25;', '#50;')
Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\work\probe\tb_boot_off50.sv').write_text(src, newline='\r\n')
print('replaced', n, 'wait offsets with 50 ns')
