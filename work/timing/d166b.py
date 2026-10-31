import pymupdf, re
d = pymupdf.open("ds/74LS166.pdf")
found=0
for i,p in enumerate(d):
    t = p.get_text()
    m = re.findall(r"SDLS\s?\d+[A-Z]?", t, re.I)
    if m: print("page", i+1, m); found+=1
print("pages scanned", d.page_count, "hits", found)
