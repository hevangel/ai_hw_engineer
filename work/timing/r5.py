import pymupdf
d=pymupdf.open("work/timing/pdf/TMS4116.pdf")
for i in range(len(d)):
    pix=d[i].get_pixmap(dpi=170); fn=f"work/timing/pdf/tms4116_p{i+1}.png"; pix.save(fn)
print(len(d))
