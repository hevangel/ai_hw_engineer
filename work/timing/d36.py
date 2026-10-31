import pypdf,warnings,re
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/apple_ii_ref_manual.pdf")
print("pages",len(r.pages))
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    for m in re.finditer(r"4116|nanosecond|ns\b", t):
        s=t[max(0,m.start()-90):m.end()+90].replace("\n"," ")
        if "4116" in s or "nanosec" in s.lower():
            print(f"p{i+1}: ...{s}...")
