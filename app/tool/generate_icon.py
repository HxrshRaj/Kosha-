"""Generates the Kosha app icon: a purple rounded-square with a white
coin-and-uptrend mark, plus a foreground-only version for Android adaptive
icons. Run once; output feeds flutter_launcher_icons.
"""
from PIL import Image, ImageDraw

SIZE = 1024
PRIMARY = (108, 99, 255, 255)  # #6C63FF, matches AppColors.primary
WHITE = (255, 255, 255, 255)

def rounded_square(size, radius_ratio, fill):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    radius = int(size * radius_ratio)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=fill)
    return img

def draw_mark(draw, cx, cy, scale):
    # A coin (circle) with a simple upward trend line through it — reads as
    # "money that's growing", legible at small launcher sizes.
    r = int(140 * scale)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=WHITE, width=int(26 * scale))

    # Rupee-esque mark inside the coin: two horizontal bars + diagonal leg.
    bar_w = int(120 * scale)
    bar_h = int(20 * scale)
    x0 = cx - bar_w // 2
    y0 = cy - int(70 * scale)
    draw.rectangle([x0, y0, x0 + bar_w, y0 + bar_h], fill=WHITE)
    draw.rectangle([x0, y0 + int(45 * scale), x0 + bar_w, y0 + int(45 * scale) + bar_h], fill=WHITE)
    draw.line([x0 + int(20 * scale), y0, x0 + int(90 * scale), cy + int(80 * scale)], fill=WHITE, width=int(20 * scale))

    # Small uptrend line + dot breaking out of the coin, upper-right.
    trend_start = (cx + int(70 * scale), cy + int(10 * scale))
    trend_mid = (cx + int(150 * scale), cy - int(60 * scale))
    trend_end = (cx + int(210 * scale), cy - int(120 * scale))
    draw.line([trend_start, trend_mid, trend_end], fill=WHITE, width=int(16 * scale), joint="curve")
    dot_r = int(18 * scale)
    draw.ellipse([trend_end[0] - dot_r, trend_end[1] - dot_r, trend_end[0] + dot_r, trend_end[1] + dot_r], fill=WHITE)

# Full icon (background + mark) — used for iOS / legacy Android.
full = rounded_square(SIZE, 0.22, PRIMARY)
draw_full = ImageDraw.Draw(full)
draw_mark(draw_full, SIZE // 2, SIZE // 2, scale=1.0)
full.save("assets/icon/icon.png")

# Adaptive icon foreground (transparent background, mark only, inset so it
# survives Android's adaptive-icon mask cropping).
fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw_fg = ImageDraw.Draw(fg)
draw_mark(draw_fg, SIZE // 2, SIZE // 2, scale=0.72)
fg.save("assets/icon/icon_foreground.png")

# Adaptive icon background (solid brand color).
bg = Image.new("RGBA", (SIZE, SIZE), PRIMARY)
bg.save("assets/icon/icon_background.png")

print("Wrote assets/icon/icon.png, icon_foreground.png, icon_background.png")
