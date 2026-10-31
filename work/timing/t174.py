import pymupdf
d = pymupdf.open("ds/74LS174.pdf")
print("pages", d.page_count)
for i,pg in enumerate(d[:2]): print("---",i+1,"---"); print(pg.get_text()[:800])
