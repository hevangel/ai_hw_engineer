from pdfminer.high_level import extract_text
for f in ["ds/74LS04.pdf","ds/74LS00.pdf"]:
    print("#####", f)
    t = extract_text(f)
    i = t.lower().find("switching characteristics")
    while i != -1:
        print("-----")
        print(t[max(0,i-300):i+900])
        i = t.lower().find("switching characteristics", i+1)
