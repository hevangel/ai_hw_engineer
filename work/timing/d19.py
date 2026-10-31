import pypdf,warnings,re
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/signetics_1977_memory.pdf")
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    if "9316" in t:
        for m in re.finditer("9316",t):
            print(f"p{i+1}: ..."+t[max(0,m.start()-120):m.end()+120].replace("\n"," ")+"...")
