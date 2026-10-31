import glob, re, os
for p in ["74LS194","74LS32","74LS51","74LS74","74LS86","74LS161","74LS257","74LS259","74LS283","74LS251"]:
    for f in sorted(glob.glob(f"ocr2/{p}_p*.txt")):
        lines=open(f,encoding="utf8").read().splitlines()
        hits=[i for i,l in enumerate(lines) if re.search(r"witching",l,re.I)]
        if not hits: continue
        print("=====",os.path.basename(f),"|",lines[0][:60])
        for i in hits[:1]: print("   "," || ".join(lines[i:i+9])[:330])
