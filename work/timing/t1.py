from pdfminer.high_level import extract_text
t = extract_text("ds/74LS02.pdf", page_numbers=[4,5,6])
print(repr(t[:1200]))
