import pymupdf
d=pymupdf.open("work/timing/pdf/8T97.pdf")
for i in range(len(d)):
    pix=d[i].get_pixmap(dpi=180); pix.save(f"work/timing/pdf/8t97_p{i+1}.png"); print(i+1,pix.width,pix.height)
