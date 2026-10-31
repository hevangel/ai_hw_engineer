import pymupdf
d = pymupdf.open("alt_74LS195.pdf")
for i in range(min(4,d.page_count)):
    print("--- p",i+1,"---"); print(repr(d[i].get_text()[:500]))
