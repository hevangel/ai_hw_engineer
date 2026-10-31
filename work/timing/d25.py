import pypdf,warnings
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/apple_ii_redbook.pdf")
for i in range(150,162):
    t=r.pages[i].extract_text() or ""
    first=[l for l in t.splitlines() if l.strip()][:6]
    print(i+1, "|", " / ".join(first)[:160])
