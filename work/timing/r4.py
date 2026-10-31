import pymupdf
d=pymupdf.open("work/timing/pdf/apple_ii_redbook.pdf")
for pno in [155,152,158]:
    pix=d[pno].get_pixmap(dpi=200); fn=f"work/timing/pdf/redbook_p{pno+1}.png"; pix.save(fn); print(fn,pix.width,pix.height)
