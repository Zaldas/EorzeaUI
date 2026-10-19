"""Builds the settings window art in assets/settings/ as 32-bit bottom-up TGAs.

Icons are the settings design's 24x24 SVG paths, rendered white (tinted in game) through headless
Chrome; rounded-rect slices and discs are drawn with PIL. Needs Pillow and Google Chrome.

    python tools/settingsArt.py
"""
import os
import struct
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'settings')
# Chrome writes the screenshot before it exits; Edge returns first and writes it later.
CHROME = r'C:\Program Files\Google\Chrome\Application\chrome.exe'
CELL = 64

# name: (path, 'stroke' | 'fill', stroke width in viewBox units)
ICONS = {
    # Page list
    'navGeneral': ('M4 6h9M17 6h3M15 4v4M4 12h3M11 12h9M9 10v4M4 18h11M19 18h1M17 16v4', 'stroke', 1.6),
    'navLayout': ('M4 4h7v7H4zM13 4h7v4h-7zM13 10h7v10h-7zM4 13h7v7H4z', 'stroke', 1.6),
    'navTarget': ('M12 3v4M12 17v4M3 12h4M17 12h4M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8z', 'stroke', 1.6),
    'navParty': ('M9 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM3 20c0-3.3 2.7-6 6-6s6 2.7 6 6M16 5.5a3 3 0 0 1 0 5.5M18 14.5c1.8.8 3 2.8 3 5.5', 'stroke', 1.6),
    'navRaid': ('M4 4h4v4H4zM10 4h4v4h-4zM16 4h4v4h-4zM4 10h4v4H4zM10 10h4v4h-4zM16 10h4v4h-4zM4 16h4v4H4zM10 16h4v4h-4zM16 16h4v4h-4z', 'stroke', 1.6),
    'navIndicators': ('M12 3l9 9-9 9-9-9zM12 8v5M12 16h.01', 'stroke', 1.6),
    'navColors': ('M12 3a9 9 0 1 0 0 18c1 0 1.6-.8 1.6-1.6 0-1-.8-1.4-.8-2.4 0-1 .8-1.6 1.8-1.6H17a4 4 0 0 0 4-4C21 6.7 17 3 12 3zM7.5 11.5h.01M10 7.5h.01M15 7.5h.01', 'stroke', 1.6),
    'navFonts': ('M4 19 10 5h1.5l6 14M6.5 14h8.5M17 19h4', 'stroke', 1.6),
    'navAbout': ('M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 11v6M12 7.5h.01', 'stroke', 1.6),
    # Controls
    'search': ('M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-3.5-3.5', 'stroke', 2),
    'close': ('M6 6l12 12M18 6 6 18', 'stroke', 2),
    'move': ('M12 3v18M3 12h18M12 3l-3 3M12 3l3 3M12 21l-3-3M12 21l3-3M3 12l3-3M3 12l3 3M21 12l-3-3M21 12l-3 3', 'stroke', 2),
    'reset': ('M4 12a8 8 0 1 0 2.5-5.8M4 4v5h5', 'stroke', 2),
    'chevron': ('M7 10l5 5 5-5', 'stroke', 1.8),
    'diamond': ('M12 2l10 10-10 10-10-10z', 'stroke', 2.6),
}

POINTER = '<path d="M1 0l10 6-10 6 2.5-6z" fill="#fff"/>'

# Rounded-rect slices: radius -> fill and 1px ring, sliced at the radius in game.
RADII = (3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 15)
SLICE_SIZE = 32


def write_tga(image, name):
    image = image.convert('RGBA')
    w, h = image.size
    header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x08)
    pixels = image.load()
    rows = []
    for y in range(h - 1, -1, -1):
        row = bytearray()
        for x in range(w):
            r, g, b, a = pixels[x, y]
            row += bytes((b, g, r, a))
        rows.append(bytes(row))
    with open(os.path.join(OUT, name + '.tga'), 'wb') as f:
        f.write(header + b''.join(rows))


def svg_cell(inner, view='0 0 24 24'):
    return ('<div style="width:{0}px;height:{0}px"><svg width="{0}" height="{0}" viewBox="{1}" '
            'xmlns="http://www.w3.org/2000/svg">{2}</svg></div>').format(CELL, view, inner)


def render_svgs(cells):
    """cells: list of (name, svg markup) -> {name: 64x64 RGBA image}."""
    cols = 8
    rows = (len(cells) + cols - 1) // cols
    html = ('<html><body style="margin:0;background:transparent">'
            '<div style="display:grid;grid-template-columns:repeat({0},{1}px)">{2}</div></body></html>').format(
        cols, CELL, ''.join(markup for _, markup in cells))
    tmp = tempfile.mkdtemp()
    page = os.path.join(tmp, 'icons.html')
    shot = os.path.join(tmp, 'icons.png')
    with open(page, 'w', encoding='utf-8') as f:
        f.write(html)
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--user-data-dir=' + os.path.join(tmp, 'profile'),
                    '--hide-scrollbars', '--force-device-scale-factor=1',
                    '--default-background-color=00000000', '--window-size={},{}'.format(cols * CELL, rows * CELL),
                    '--screenshot=' + shot, 'file:///' + page.replace('\\', '/')],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    sheet = Image.open(shot).convert('RGBA')
    out = {}
    for i, (name, _) in enumerate(cells):
        x, y = (i % cols) * CELL, (i // cols) * CELL
        out[name] = sheet.crop((x, y, x + CELL, y + CELL))
    return out


def rounded(size, radius, inset=0, scale=8):
    """Antialiased white rounded rect mask of size x size, inset px from each edge."""
    big = Image.new('L', (size * scale, size * scale), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (inset * scale, inset * scale, (size - inset) * scale - 1, (size - inset) * scale - 1),
        radius=max(0, radius - inset) * scale, fill=255)
    return big.resize((size, size), Image.LANCZOS)


def white(mask):
    image = Image.new('RGBA', mask.size, (255, 255, 255, 0))
    image.putalpha(mask)
    return image


def main():
    os.makedirs(OUT, exist_ok=True)
    cells = []
    for name, (path, mode, width) in ICONS.items():
        if mode == 'fill':
            inner = '<path d="{}" fill="#fff"/>'.format(path)
        else:
            inner = ('<path d="{}" fill="none" stroke="#fff" stroke-width="{}" stroke-linecap="round" '
                     'stroke-linejoin="round"/>').format(path, width)
        cells.append((name, svg_cell(inner)))
    cells.append(('pointer', svg_cell(POINTER, '0 -0.5 12 13')))
    for name, image in render_svgs(cells).items():
        write_tga(image, name)

    for radius in RADII:
        outer = rounded(SLICE_SIZE, radius)
        inner = rounded(SLICE_SIZE, radius, inset=1)
        ring = Image.composite(Image.new('L', outer.size, 0), outer, inner)
        write_tga(white(outer), 'fill{}'.format(radius))
        write_tga(white(ring), 'ring{}'.format(radius))

    disc = rounded(64, 32)
    write_tga(white(disc), 'disc')
    glow = Image.new('L', (64, 64), 0)
    ImageDraw.Draw(glow).ellipse((16, 16, 47, 47), fill=255)
    write_tga(white(glow.filter(ImageFilter.GaussianBlur(7))), 'glow')
    print('wrote', len(os.listdir(OUT)), 'files to', OUT)


if __name__ == '__main__':
    sys.exit(main())
