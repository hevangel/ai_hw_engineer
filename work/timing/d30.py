import pypdf,warnings,re
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/ns_iface_1983.pdf")
for i in [577,1023,1024,20,6]:
    t=r.pages[i].extract_text() or ""
    print(f"===== PAGE {i+1} =====")
    idx=t.find("8T97")
    print(t[max(0,idx-400):idx+400] if idx>=0 else t[:600])
