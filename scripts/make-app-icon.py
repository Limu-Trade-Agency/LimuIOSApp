#!/usr/bin/env python3
"""Generate the App Store icon set from the Limu emblem.

The emblem ships as vector art (`LimuEmblem.imageset/limu-emblem.pdf`) on an
opaque white page. This renders it, keys out the page background while keeping
the white detail inside the mark, and writes the three 1024x1024 icons Xcode
expects: light (opaque), dark (transparent), tinted (grayscale + transparent).

Run from the repository root:

    python scripts/make-app-icon.py

Requires PyMuPDF and Pillow:  pip install pymupdf pillow
"""

from pathlib import Path

import pymupdf
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
EMBLEM_PDF = ROOT / "Limu Mobile/Assets.xcassets/LimuEmblem.imageset/limu-emblem.pdf"
ICON_SET = ROOT / "Limu Mobile/Assets.xcassets/AppIcon.appiconset"

SIZE = 1024
SCALE = 0.78          # artwork width as a fraction of the canvas
RENDER_WIDTH = 2048   # emblem render width before downsampling

CHARCOAL = (0x34, 0x3D, 0x46)   # emblem's dark ink
CREAM = (0xF5, 0xF0, 0xEC)      # LimuColors.cream
GRADIENT_TOP = (0xFF, 0xFE, 0xFD)
GRADIENT_BOTTOM = (0xF1, 0xE8, 0xDF)


def render_emblem() -> Image.Image:
    page = pymupdf.open(EMBLEM_PDF)[0]
    zoom = RENDER_WIDTH / page.rect.width
    pix = page.get_pixmap(matrix=pymupdf.Matrix(zoom, zoom))
    return Image.frombytes("RGB", (pix.width, pix.height), pix.samples)


def key_out_background(src: Image.Image) -> Image.Image:
    """Make the white page transparent without eating the mark's white detail."""
    width, height = src.size
    probe = src.copy()
    marker = (255, 0, 255)
    for corner in [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]:
        ImageDraw.floodfill(probe, corner, marker, thresh=60)

    background = Image.new("L", src.size, 0)
    background.putdata([255 if p == marker else 0 for p in probe.getdata()])
    # Grow the keyed region so the antialiased rim gets an alpha ramp rather
    # than a white halo against the icon background.
    background = background.filter(ImageFilter.MaxFilter(7))

    def alpha(pixel, keyed):
        if keyed < 128:
            return 255
        # Unpremultiply against white. Every shape in the mark is orange or
        # charcoal, both of which have a low minimum channel, so the minimum
        # tracks edge coverage closely enough.
        return max(0, min(255, int((255 - min(pixel[:3])) * 1.13)))

    mask = Image.new("L", src.size, 255)
    mask.putdata([alpha(p, k) for p, k in zip(src.getdata(), background.getdata())])

    emblem = src.copy()
    emblem.putalpha(mask)
    return emblem.crop(emblem.getbbox())


def place(mark: Image.Image, canvas: Image.Image) -> None:
    width = int(SIZE * SCALE)
    height = round(width * mark.height / mark.width)
    resized = mark.resize((width, height), Image.LANCZOS)
    canvas.paste(resized, ((SIZE - width) // 2, (SIZE - height) // 2), resized)


def light_icon(emblem: Image.Image) -> Image.Image:
    canvas = Image.new("RGB", (SIZE, SIZE))
    draw = ImageDraw.Draw(canvas)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        draw.line(
            [(0, y), (SIZE, y)],
            fill=tuple(round(a + (b - a) * t) for a, b in zip(GRADIENT_TOP, GRADIENT_BOTTOM)),
        )
    place(emblem, canvas)
    return canvas


def lighten_ink(emblem: Image.Image) -> Image.Image:
    """Recolour the charcoal ink to cream so it survives a dark background."""
    def swap(pixel):
        r, g, b, a = pixel
        if all(abs(c - t) < 60 for c, t in zip((r, g, b), CHARCOAL)):
            return CREAM + (a,)
        return pixel

    out = emblem.copy()
    out.putdata([swap(p) for p in out.getdata()])
    return out


def main() -> None:
    emblem = key_out_background(render_emblem())

    light_icon(emblem).save(ICON_SET / "AppIcon.png")

    dark_mark = lighten_ink(emblem)
    dark = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    place(dark_mark, dark)
    dark.save(ICON_SET / "AppIcon-Dark.png")

    grey = dark_mark.convert("LA").convert("RGBA")
    grey.putalpha(dark_mark.getchannel("A"))
    tinted = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    place(grey, tinted)
    tinted.save(ICON_SET / "AppIcon-Tinted.png")

    for name in ("AppIcon.png", "AppIcon-Dark.png", "AppIcon-Tinted.png"):
        with Image.open(ICON_SET / name) as img:
            print(f"{name}: {img.size[0]}x{img.size[1]} {img.mode}")


if __name__ == "__main__":
    main()
