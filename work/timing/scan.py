from pdfminer.high_level import extract_text
import glob, os, re
for f in sorted(glob.glob("ds/74LS*.pdf")):
    if os.path.basename(f)=="74LS195.pdf": continue
    hit=[]
    for pg in range(0, 60):
        try:
            t = extract_text(f, page_numbers=[pg])
        except Exception:
            break
        if not t: break
        if "switching characteristics" in t.lower():
            hit.append(pg+1)
    print(os.path.basename(f), "hits:", hit)
