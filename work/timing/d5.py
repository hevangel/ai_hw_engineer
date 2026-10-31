import pypdf
r=pypdf.PdfReader("work/timing/pdf/MK4116-2_3.pdf")
t=r.pages[2].extract_text(extraction_mode="layout")
print(t)
