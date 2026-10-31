import pymupdf
d = pymupdf.open("fc161.pdf"); t = "".join(p.get_text() for p in d)
print("pages", d.page_count, "chars", len(t))
i = t.find("tPLH")
print(t[max(0,i-800):i+500].replace("\n"," ~ "))
