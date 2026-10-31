import pymupdf, glob, os, re
for f in sorted(glob.glob("ds/74LS*.pdf")):
    d = pymupdf.open(f)
    t = d[0].get_text() + d[1].get_text()
    doc = re.findall(r"(SDLS\d+[A-Z]?)", t)
    lines = [l.strip() for l in t.splitlines() if l.strip()]
    title = " / ".join(lines[:3])[:110]
    print(f"{os.path.basename(f):13s} doc={doc[0] if doc else '?':10s} {title}")
