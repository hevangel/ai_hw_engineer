import glob, os, re
parts = sorted({os.path.basename(f).split("_p")[0] for f in glob.glob("ocr2/74LS*_p*.txt")})
for p in parts:
    best=None
    for f in sorted(glob.glob(f"ocr2/{p}_p*.txt")):
        t = open(f, encoding="utf8").read()
        hasls = ("SN74LS" in t.replace(" ","")) or ("74LS" in t and "SN54LS" in t.replace(" ",""))
        if re.search(r"witching", t, re.I) and ("15 pF" in t or "15pF" in t):
            if hasls: best=os.path.basename(f)
    print(p, best)
