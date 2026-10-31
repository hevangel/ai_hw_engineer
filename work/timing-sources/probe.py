import pymupdf, sys, os, glob

for p in sorted(glob.glob(r"work/timing/ds/*.pdf")):
    d = pymupdf.open(p)
    tot = 0
    hits = []
    for i, pg in enumerate(d):
        t = pg.get_text()
        tot += len(t.strip())
        if "switching characteristics" in t.lower():
            hits.append(i + 1)
    print(f"{os.path.basename(p):20s} pages={d.page_count:3d} textchars={tot:7d} swc_pages={hits}")
