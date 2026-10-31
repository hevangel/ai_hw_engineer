import pymupdf, glob, os
for f in sorted(glob.glob("cand/*.pdf")):
    try:
        d = pymupdf.open(f); t = "".join(p.get_text() for p in d)
        print(f"{os.path.basename(f):22s} pages={d.page_count:2d} chars={len(t):6d} tPLH={'tPLH' in t} SW={'witching' in t}")
    except Exception as e:
        print(f"{os.path.basename(f):22s} ERR {e}")
