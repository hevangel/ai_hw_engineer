"""Show observed vs expected Monitor pixels for one line."""
import sys
sys.path.insert(0, "B:/ai_hw_engineer/system/apple_ii/scripts")
import check_video as cv

samples = [line.split(",") for line in (cv.WORK / "monitor_video.csv").read_text().splitlines()]
screen = (cv.WORK / "monitor_screen.hex").read_text().split()
flash = (cv.WORK / "monitor_flash.txt").read_text().strip() == "1"


def cell(row, column):
    return int(screen[(row % 8) * 128 + (row // 8) * 40 + column], 16)


def expected(y):
    pixels = []
    for x in range(40):
        value = cell(y // 8, x)
        glyph = cv.FONT[(value % 64) * 8 + y % 8]
        inverted = not (value & 0x80 or value & 0x40 and flash)
        bits = [0] + [(glyph >> bit) & 1 for bit in range(4, -1, -1)] + [0]
        pixels.extend(str(int(bool(bit) ^ inverted)) for bit in bits for _ in range(2))
    return "".join(pixels)


for line in (0, 1):
    row = samples[line * 912:(line + 1) * 912]
    obs = "".join(p[3] for p in row[14:574])
    want = expected(line)
    print(f"line {line}")
    for start in range(0, 560, 70):
        print(" obs", obs[start:start + 70])
        print(" exp", want[start:start + 70])
