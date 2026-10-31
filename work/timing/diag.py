import pymupdf, glob, os
for p in sorted(glob.glob("ds/74LS*.pdf")):
    d = pymupdf.open(p)
    chars = sum(len(pg.get_text()) for pg in d)
    imgs = sum(len(pg.get_images()) for pg in d)
    print(f"{os.path.basename(p):14s} pages={d.page_count:2d} chars={chars:7d} imgs={imgs:3d}")
