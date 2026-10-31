from pdfminer.high_level import extract_text
from pdfminer.layout import LAParams
t = extract_text("cand/74LS195_74LS195.pdf", page_numbers=[3], laparams=LAParams(char_margin=0.8, line_margin=0.2))
i = t.find("AC CHARACTER")
print(t[i:i+1200])
