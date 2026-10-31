import pypdf,warnings,re
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/ns_interface_1979.pdf")
for i in [2,9,12,123]:
    t=r.pages[i].extract_text() or ""
    print(f"== P{i+1} ==")
    for l in t.splitlines():
        if "8T9" in l or "8T2" in l or "8T" in l:
            print("  ",l.strip()[:120])
