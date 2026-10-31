import pymupdf, glob, os, re
for f in sorted(glob.glob("cand/*.pdf")):
    d = pymupdf.open(f); t = "".join(p.get_text() for p in d)
    if "tPLH" not in t: print("#####", os.path.basename(f), "NO tPLH"); continue
    i = t.find("tPLH")
    print("#####", os.path.basename(f))
    print(t[max(0,i-700):i+400].replace("\n"," ~ "))
    print()
