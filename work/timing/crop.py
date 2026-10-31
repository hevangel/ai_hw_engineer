import pymupdf, glob, os
os.makedirs("crops", exist_ok=True)
for f in sorted(glob.glob("cand/*.pdf")):
    part = os.path.basename(f).split("_")[0]
    d = pymupdf.open(f)
    for pi in range(d.page_count):
        rects = d[pi].search_for("tPLH")
        if not rects: continue
        r = rects[0]
        h = d[pi].rect.height; w = d[pi].rect.width
        y0 = max(0, r.y0-170); y1 = min(h, r.y1+200)
        clip = pymupdf.Rect(0, y0, w, y1)
        pix = d[pi].get_pixmap(dpi=300, clip=clip)
        out = f"crops/{part}_p{pi+1}.png"
        pix.save(out)
        print(out, pix.width, pix.height)
        break
