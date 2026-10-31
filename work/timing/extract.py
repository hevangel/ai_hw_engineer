import pymupdf, re, sys
p = sys.argv[1]
d = pymupdf.open(p)
print("pages", d.page_count)
for i, pg in enumerate(d):
    t = pg.get_text()
    if "switching characteristics" in t.lower():
        print("=== page", i+1, "===")
        print(t[:2500])
