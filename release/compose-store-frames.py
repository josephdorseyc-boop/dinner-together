#!/usr/bin/env python3
"""Compose App Store screenshot frames from the store-assets run output.

    python3 release/compose-store-frames.py <store-assets-dir> <out-dir>

<store-assets-dir> is a checkout of the `store-assets` branch (or the
downloaded artifact): screenshots/<device>/*.png (static seeded states on
iPhone 17 Pro Max / iPad Pro 13-inch) and ui-screenshots/<device>/*.png
(the UI-test attachments). Output: <out-dir>/<device>/NN-<slug>.png at the
exact pixel sizes App Store Connect accepts for 6.9-inch iPhone (1320×2868)
and 13-inch iPad (2064×2752), each a real simulator render with a caption
band above it — nothing painted over the UI.

The six-frame story and captions are Agent 2's (A2_APPSTORE_HANDOFF.md §5).
"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFont

SIZES = {"iphone": (1320, 2868), "ipad": (2064, 2752)}
FONT_BOLD = "/usr/share/fonts/opentype/inter/InterDisplay-SemiBold.otf"
FONT_REG = "/usr/share/fonts/opentype/inter/Inter-Regular.otf"
CREAM, INK, MUTED, TOMATO = (250, 246, 237), (48, 43, 37), (110, 103, 94), (168, 56, 39)

# (slug, caption, subcaption, candidates in order of preference: ("static"|"ui", name-prefix))
STORY = [
    ("pick-dinner", "Pick dinner. Pick a time.",
     "Every dish gets its place in one timeline.",
     [("static", "tonight-steak-light"), ("ui", "09-tonight-top")]),
    ("know-what-to-do", "Know what to do now.",
     "The next thing that needs you is always at the top.",
     [("static", "on-schedule-light")]),
    ("running-late", "Running late? Review the plan.",
     "See the new estimate next to the time you chose. Nothing moves on its own.",
     [("ui", "01-review-sheet"), ("static", "late-prep-light")]),
    ("check-the-food", "A timer ends. You check the food.",
     "The app never decides a step is done for you.",
     [("static", "expired-timer-light")]),
    ("nine-dinners", "Nine dinners to choose from.",
     "Four of them meat-free. Your own recipes, our timing.",
     [("ui", "09-tonight-menus"), ("static", "tonight-steak-light")]),
    ("after-dark", "A calmer counter, even after dark.",
     "Dark Mode, large readable times, iPad two-column layout.",
     [("static", "on-schedule-dark"), ("static", "late-prep-dark")]),
]


def find(root, device, kind, prefix):
    folder = "screenshots" if kind == "static" else "ui-screenshots"
    hits = sorted(glob.glob(os.path.join(root, folder, device, prefix + "*.png")))
    return hits[0] if hits else None


def fit_text(draw, text, font_path, max_width, start, minimum):
    size = start
    while size > minimum:
        font = ImageFont.truetype(font_path, size)
        if draw.textlength(text, font=font) <= max_width:
            return font
        size -= 4
    return ImageFont.truetype(font_path, minimum)


def rounded(im, radius):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width - 1, im.height - 1], radius=radius, fill=255)
    out = Image.new("RGB", im.size, CREAM)
    out.paste(im, mask=mask)
    return out


def compose(src, W, H, caption, sub):
    canvas = Image.new("RGB", (W, H), CREAM)
    d = ImageDraw.Draw(canvas)
    margin = int(W * 0.07)
    band = int(H * 0.19)
    title = fit_text(d, caption, FONT_BOLD, W - 2 * margin, int(W * 0.066), int(W * 0.04))
    subf = fit_text(d, sub, FONT_REG, W - 2 * margin, int(W * 0.032), int(W * 0.022))
    y = int(H * 0.055)
    d.text((margin, y), caption, font=title, fill=INK)
    y += int(title.size * 1.35)
    d.text((margin, y), sub, font=subf, fill=MUTED)
    # the render, scaled to fit below the band, corner-rounded, with a thin tomato hairline
    shot = Image.open(src).convert("RGB")
    avail_w, avail_h = W - 2 * margin, H - band - int(H * 0.03)
    scale = min(avail_w / shot.width, avail_h / shot.height)
    shot = shot.resize((int(shot.width * scale), int(shot.height * scale)), Image.LANCZOS)
    shot = rounded(shot, int(W * 0.035))
    x = (W - shot.width) // 2
    y = band
    d.rounded_rectangle([x - 3, y - 3, x + shot.width + 2, y + shot.height + 2], radius=int(W * 0.035) + 3,
                        outline=(214, 205, 188), width=3)
    canvas.paste(shot, (x, y))
    return canvas


def main(argv):
    if len(argv) != 3:
        print(__doc__); return 2
    root, out = argv[1], argv[2]
    made, missing = [], []
    for device, (W, H) in SIZES.items():
        os.makedirs(os.path.join(out, device), exist_ok=True)
        for i, (slug, caption, sub, candidates) in enumerate(STORY, 1):
            src = next((p for k, pre in candidates if (p := find(root, device, k, pre))), None)
            if not src:
                missing.append(f"{device}/{slug}: none of {[c[1] for c in candidates]}"); continue
            frame = compose(src, W, H, caption, sub)
            path = os.path.join(out, device, f"{i:02d}-{slug}.png")
            frame.save(path, optimize=True)
            made.append(f"{device}/{i:02d}-{slug}.png  <- {os.path.relpath(src, root)}  {W}x{H}")
    print("\n".join(made))
    if missing:
        print("MISSING:\n  " + "\n  ".join(missing))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
