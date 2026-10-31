from pathlib import Path
p = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\report\final_report.md')
t = p.read_text()
i = t.index('<<<<<<< HEAD')
j = t.index('=======', i)
k = t.index('>>>>>>> c60f191', j)
ours = t[i + len('<<<<<<< HEAD'):j]
theirs = t[j + len('======='):k]
p2 = theirs[theirs.index('## DRAM refresh'):]
merged = ours.rstrip('\r\n') + '\r\n\r\n' + p2.lstrip('\r\n')
p.write_text(t[:i] + merged + t[t.index('\n', k) + 1:], newline='\r\n')
print('report conflict resolved: main paragraph kept, P2 section appended')
