import pymupdf
d = pymupdf.open("sy_74LS00.pdf")
print(d[0].get_text()[:600])
print("==== p2 ====")
print(d[1].get_text()[:1200])
