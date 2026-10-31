import pymupdf
d=pymupdf.open("work/timing/pdf/signetics_1977_memory.pdf")
pix=d[251].get_pixmap(dpi=200); pix.save("work/timing/pdf/sig2616_p252.png"); print(pix.width,pix.height)
