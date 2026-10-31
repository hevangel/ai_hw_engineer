import pypdf,warnings,re
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/apple_ii_redbook.pdf")
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    if re.search(r"PARTS?\s*LIST|PART NUMBER|341-", t, re.I):
        print("PAGE",i+1, [l for l in t.splitlines() if re.search(r"PARTS?\s*LIST|PART NUMBER|341-",l,re.I)][:5])
