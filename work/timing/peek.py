import glob, os, re
files = ["74LS138_p4","74LS139_p3","74LS139_p4","74LS151_p4","74LS153_p5","74LS166_p5","74LS174_p4","74LS175_p4","74LS194_p6","74LS20_p3","74LS251_p6"]
for n in files:
    t = open(f"ocr2/{n}.txt", encoding="utf8").read().splitlines()
    idx = [i for i,l in enumerate(t) if re.search(r"witching", l, re.I)]
    print("=====", n, "hits", idx)
    for i in idx[:1]:
        print("\n".join(t[i:i+10]))
