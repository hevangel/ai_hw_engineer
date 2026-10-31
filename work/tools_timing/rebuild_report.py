from pathlib import Path
main = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\report\final_report.md').read_text()
p2 = Path(r'C:\Users\hevan\AppData\Local\Temp\p2.md').read_text()
p2 = p2.replace('\r\n', '\n').strip('\n')
merged = main.rstrip('\r\n') + '\r\n\r\n' + p2.replace('\n', '\r\n') + '\r\n'
Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\report\final_report.md').write_text(merged, newline='')
print('report rebuilt: main content + P2 section')
