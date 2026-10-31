import pypdf,warnings,re
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/mos_2316.pdf")
print("pages",len(r.pages))
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    if re.search(r"tACC|Address Access", t):
        print("== PAGE",i+1,"==")
        idx=t.find("Address Access")
        print(t[max(0,idx-500):idx+900])
