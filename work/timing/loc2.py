import glob, os, re
for f in sorted(glob.glob("ocr2/*.txt")):
    t = open(f, encoding="utf8").read()
    if re.search(r"witching\s*char", t, re.I):
        # only report pages whose table mentions 15 pF and 2 k
        print(os.path.basename(f), "|15pF:", "15 pF" in t or "15pF" in t)
