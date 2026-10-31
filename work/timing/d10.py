import pypdf,warnings,re
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/gayler_circuit_description.pdf")
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    for m in re.finditer(r"4116", t):
        s=max(0,m.start()-260); e=min(len(t),m.end()+260)
        print(f"--- p{i+1}: ..."+t[s:e].replace("\n"," ")+"...")
