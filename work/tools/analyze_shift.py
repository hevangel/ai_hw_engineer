"""Find the pixel alignment offset of the captured Monitor frame."""
import sys
sys.path.insert(0, "B:/ai_hw_engineer/system/apple_ii/scripts")
import check_video as cv

samples = [line.split(",") for line in (cv.WORK / "monitor_video.csv").read_text().splitlines()]
screen = (cv.WORK / "monitor_screen.hex").read_text().split()
flash = (cv.WORK / "monitor_flash.txt").read_text().strip() == "1"


def cell(row, column):
    index = (row % 8) * 128 + (row // 8) * 40 + column
    return int(screen[index], 16)


def expected(y):
    pixels = []
    for x in range(40):
        value = cell(y // 8, x)
        glyph = cv.FONT[(value % 64) * 8 + y % 8]
        inverted = not (value & 0x80 or value & 0x40 and flash)
        bits = [0] + [(glyph >> bit) & 1 for bit in range(4, -1, -1)] + [0]
        pixels.extend(str(int(bool(bit) ^ inverted)) for bit in bits for _ in range(2))
    return "".join(pixels)


for line in range(3):
    row = samples[line * 912:(line + 1) * 912]
    want = expected(line)
    for shift in range(-3, 4):
        obs = "".join(p[3] for p in row[14 + shift:574 + shift])
        if len(obs) != len(want):
            continue
        errors = sum(a != b for a, b in zip(obs, want))
        print(f"line {line} shift {shift:+d}: {errors} mismatches")

