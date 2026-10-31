import pypdf
r = pypdf.PdfReader("work/timing/pdf/TMS4116.pdf")
print("pages:", len(r.pages))
for i,p in enumerate(r.pages):
    t = p.extract_text() or ""
    if any(k in t for k in ("RAC","CAC","tRAS","Access Time","SPEED")):
        print("=== PAGE", i+1, "===")
        print(t[:3000])
