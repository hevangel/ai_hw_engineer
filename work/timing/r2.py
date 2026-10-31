import pymupdf
d=pymupdf.open("work/timing/pdf/signetics_1977_memory.pdf")
p=d[259]
pix=p.get_pixmap(dpi=200); pix.save("work/timing/pdf/sig2513_p260.png"); print(pix.width,pix.height)
