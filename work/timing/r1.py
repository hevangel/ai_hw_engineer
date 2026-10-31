import pymupdf
d=pymupdf.open("work/timing/pdf/MK4116-2_3.pdf")
p=d[2]
pix=p.get_pixmap(dpi=220)
pix.save("work/timing/pdf/mk4116_p3.png")
print(pix.width,pix.height)
