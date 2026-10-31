import pymupdf, glob, os
for f in glob.glob("sy_*.pdf"):
    d = pymupdf.open(f)
    txt = "".join(p.get_text() for p in d)
    print(f, "pages", d.page_count, "chars", len(txt), "| hasAC:", "AC CHARACTERISTICS" in txt.upper())
