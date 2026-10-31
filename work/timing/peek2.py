import glob, os, re
for f in sorted(glob.glob("ocr2/*_p*.txt")):
    lines = open(f, encoding="utf8").read().splitlines()
    hits = [i for i,l in enumerate(lines) if re.search(r"witching", l, re.I)]
    if not hits: continue
    hdr = " ".join(l for l in lines[:3])
    print("=====", os.path.basename(f), "| HDR:", hdr[:70])
    for i in hits:
        print("   ", " || ".join(lines[i:i+7])[:300])
