import pypdf
r=pypdf.PdfReader("work/timing/pdf/MK4116-2_3.pdf")
for i in [0,1,2,3]:
    print(f"===== PAGE {i+1} =====")
    print(r.pages[i].extract_text())
