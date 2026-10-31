import pypdf,warnings,re
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/ns_interface_1979.pdf")
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    for m in re.finditer(r"8T9\d", t):
        print(f"p{i+1}: "+t[max(0,m.start()-100):m.end()+100].replace("\n"," "))
