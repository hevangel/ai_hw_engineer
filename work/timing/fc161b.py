import pymupdf
d = pymupdf.open("fc161.pdf")
for i,p in enumerate(d):
    t = p.get_text()
    if "Switching Characteristics" in t or "SWITCHING" in t.upper():
        j = t.find("Switching Characteristics")
        print("=== page", i+1, "===")
        print(t[j:j+1800].replace("\n"," | "))
