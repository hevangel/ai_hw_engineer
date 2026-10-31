import pymupdf, re
d = pymupdf.open("ds/74LS166.pdf")
print("meta", d.metadata.get("title"), "|", d.metadata.get("subject"))
for i,p in enumerate(d[:6]):
    t = p.get_text()
    m = re.findall(r"SDLS\s?\d+[A-Z]?", t, re.I)
    if m: print("page", i+1, m)
