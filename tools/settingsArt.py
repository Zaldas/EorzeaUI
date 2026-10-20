"""Builds the settings window art in assets/settings/ as 32-bit bottom-up TGAs.

Icons and the corner sprig are the settings design's SVG paths, rendered white (tinted in game)
through headless Chrome; rounded-rect slices, glass, the glow and brush strokes are drawn with PIL.
Needs Pillow and Google Chrome.

    python tools/settingsArt.py
"""
import os
import random
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
    'navGeneral': ('M12 2.5 17.5 9.5 12 21.5 6.5 9.5ZM6.5 9.5h11M12 2.5 9.8 9.5 12 21.5 14.2 9.5Z', 'stroke', 1.6),
    'navLayout': ('M4 4h7v7H4zM13 4h7v4h-7zM13 10h7v10h-7zM4 13h7v7H4z', 'stroke', 1.6),
    'navParty': ('M9 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM3 20c0-3.3 2.7-6 6-6s6 2.7 6 6M16 5.5a3 3 0 0 1 0 5.5M18 14.5c1.8.8 3 2.8 3 5.5', 'stroke', 1.6),
    'navRaid': ('M6 3v18M6 4h12l-3 4 3 4H6M4 21h4', 'stroke', 1.6),
    'navIndicators': ('M9 3h6M8 5h8l1 3v8l-1 3H8l-1-3V8zM12 9v5M10 21h4M12 3v2', 'stroke', 1.6),
    'navColors': ('M20 3c-5 2-9 6-11 10l2.5 2.5C15.5 13.5 19 9 21 4zM8.5 13.5c-2.5 0-4 1.5-4 4 0 1.5-1 2.5-2 3 3 1 7 0 8-3', 'stroke', 1.6),
    'navFonts': ('M20 3C11 5 6 11 5 20M20 3c-1 6-5 10-11 12M9 10l3 3M3 21l2-2', 'stroke', 1.6),
    'navAbout': ('M12 2l10 10-10 10L2 12zM12 11v5M12 8h.01', 'stroke', 1.6),
    # Controls
    'reset': ('M4 12a8 8 0 1 0 2.5-5.8M4 4v5h5', 'stroke', 2),
}

# Rounded-rect slices: radius -> fill and 1px ring, sliced at the radius in game.
RADII = (3, 4, 6, 7, 8, 10)
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


def svg_cell(inner, view='0 0 24 24', cell=CELL):
    return ('<div style="width:{0}px;height:{0}px"><svg width="{0}" height="{0}" viewBox="{1}" '
            'xmlns="http://www.w3.org/2000/svg">{2}</svg></div>').format(cell, view, inner)


def render_svgs(cells, cell=CELL):
    """cells: list of (name, svg markup) -> {name: cell x cell RGBA image}."""
    cols = 8
    rows = (len(cells) + cols - 1) // cols
    html = ('<html><body style="margin:0;background:transparent">'
            '<div style="display:grid;grid-template-columns:repeat({0},{1}px)">{2}</div></body></html>').format(
        cols, cell, ''.join(markup for _, markup in cells))
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
        x, y = (i % cols) * cell, (i // cols) * cell
        out[name] = sheet.crop((x, y, x + cell, y + cell))
    return out


# The Sprig corner flourish (canvas "Corner flourishes"): lines that overshoot the corner and meet
# in a curl. The window corner sits at (0, 0); the texture spans -24..104 so the overshoot fits.
SPRIG_STROKE = 'M-16 -5H86M-5 -16V50M-5 -5C-5 -14 6 -17 9 -10C11 -5 6 -3 4 -6'
SPRIG_HAIR = 'M30 -9H70M-9 20V40'
SPRIG_DOTS = 'M88.2 -5a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0ZM-6.8 54a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0Z'
SPRIG_SIZE = 128
SPRIG_ORIGIN = 24


def sprig_svg():
    """White sprig with a baked black drop shadow, so one vertex tint colours only the lines."""
    lines = ('<path d="{0}" fill="none" stroke="{3}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
             '<path d="{1}" fill="none" stroke="{3}" stroke-width=".8" stroke-opacity=".8" stroke-linecap="round"/>'
             '<path d="{2}" fill="{3}"/>')
    shadow = '<g transform="translate(0 1)" opacity=".85">' + lines.format(SPRIG_STROKE, SPRIG_HAIR, SPRIG_DOTS, '#000') + '</g>'
    return shadow + lines.format(SPRIG_STROKE, SPRIG_HAIR, SPRIG_DOTS, '#fff')


def glass(size, radius):
    """Glass 9-slice: a bright glossy top half over a darker bottom half, with a top highlight line.
    RGB carries the shading and alpha the translucency, so one vertex tint sets the hue."""
    mask = rounded(size, radius)
    image = Image.new('RGBA', (size, size))
    pixels = image.load()
    for y in range(size):
        t = y / (size - 1)
        if t < 0.47:
            shade, alpha = 255 - 30 * (t / 0.47), 0.30 - 0.14 * (t / 0.47)
        elif t < 0.53:
            k = (t - 0.47) / 0.06
            shade, alpha = 225 - 135 * k, 0.16 + 0.18 * k
        else:
            k = (t - 0.53) / 0.47
            shade, alpha = 90 + 50 * k, 0.34 + 0.06 * k
        if y == 1:
            shade, alpha = 255, 0.45
        for x in range(size):
            a = int(alpha * mask.getpixel((x, y)))
            pixels[x, y] = (int(shade), int(shade), int(shade), a)
    return image


def reset_cap(scale=8):
    """The closed end of the section reset's C: the right half of a 32px circle as a 1px ring and
    as a fill, 16x32. In game the open side continues as stretched, fading lines and fill."""
    size = 32 * scale
    ring = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(ring)
    draw.ellipse((0, 0, size - 1, size - 1), fill=255)
    draw.ellipse((scale, scale, size - 1 - scale, size - 1 - scale), fill=0)
    disc = Image.new('L', (size, size), 0)
    ImageDraw.Draw(disc).ellipse((0, 0, size - 1, size - 1), fill=255)
    half = (size // 2, 0, size, size)
    ring = ring.crop(half).resize((16, 32), Image.LANCZOS)
    disc = disc.crop(half).resize((16, 32), Image.LANCZOS)
    return white(ring), white(disc)


def noise(rng, n, scale, octaves=3):
    """Smooth 1D noise of length n, roughly in -1.5..1.5."""
    total = [0.0] * n
    amp, size = 1.0, float(scale)
    for _ in range(octaves):
        points = [rng.gauss(0, 1) for _ in range(int(n / size) + 3)]
        for i in range(n):
            x = i / size
            j = int(x)
            t = x - j
            t = t * t * (3 - 2 * t)
            total[i] += amp * (points[j] * (1 - t) + points[j + 1] * t)
        amp *= 0.5
        size = max(2.0, size / 2)
    return total


def brush(seed, ss=4):
    """A white painted stroke, 256x64: alpha is the paint, RGB carries darker bristle streaks so a
    vertex tint keeps the texture. Thick loaded start, curved body, dry-brush tail."""
    w, h = 256 * ss, 64 * ss
    rng = random.Random(seed)
    img = Image.new('RGBA', (w, h), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    top_n, bot_n = noise(rng, w, 70 * ss), noise(rng, w, 70 * ss)
    top_j, bot_j = noise(rng, w, 3 * ss, 2), noise(rng, w, 3 * ss, 2)
    bend = rng.uniform(-3, 3) * ss
    top, bottom = [], []
    for x in range(w):
        t = x / w
        half = h * (0.34 - 0.10 * t)
        centre = h * 0.5 + bend * (4 * t * (1 - t)) * 2
        top.append(centre - half + top_n[x] * 2.5 * ss + top_j[x] * 1.8 * ss)
        bottom.append(centre + half + bot_n[x] * 2.5 * ss + bot_j[x] * 1.8 * ss)
    start_n = noise(rng, h, 6 * ss, 2)
    end_n = noise(rng, h, 2 * ss, 1)
    streak_n = noise(rng, h, 5 * ss, 2)
    body_end = w * (0.74 + 0.08 * rng.random())
    for y in range(h):
        dy = (y - h * 0.5) / (h * 0.5)
        start = 4 * ss + dy * dy * 14 * ss + abs(start_n[y]) * 4 * ss
        end = body_end + abs(end_n[y]) * 24 * ss
        if rng.random() < 0.08:
            end = end + rng.random() * 46 * ss
        end = min(w - 3 * ss, end)
        shade = 0.86 + 0.14 * max(0.0, min(1.0, streak_n[y] * 0.5 + 0.5))
        x = start
        while x < end:
            tail = max(0.0, (x - body_end) / (end - body_end + 1))
            seg = rng.uniform(30, 160) * ss * (1 - 0.8 * tail)
            x2 = min(end, x + seg, w - 1)
            inside = [xx for xx in range(int(x), int(x2), ss) if top[xx] < y < bottom[xx]]
            if inside:
                level = int(255 * shade * (1 - 0.12 * tail))
                draw.line([(inside[0], y), (min(int(x2), inside[-1] + ss), y)], fill=(level, level, level, 255))
            x = x2 + (rng.uniform(2, 14) * ss * tail if tail > 0 else 0)
    return img.resize((256, 64), Image.LANCZOS)


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
    for name, image in render_svgs(cells).items():
        write_tga(image, name)

    for radius in RADII:
        outer = rounded(SLICE_SIZE, radius)
        inner = rounded(SLICE_SIZE, radius, inset=1)
        ring = Image.composite(Image.new('L', outer.size, 0), outer, inner)
        write_tga(white(outer), 'fill{}'.format(radius))
        write_tga(white(ring), 'ring{}'.format(radius))

    glow = Image.new('L', (64, 64), 0)
    ImageDraw.Draw(glow).ellipse((16, 16, 47, 47), fill=255)
    write_tga(white(glow.filter(ImageFilter.GaussianBlur(7))), 'glow')

    write_tga(glass(SLICE_SIZE, 8), 'glass8')
    cap_ring, cap_fill = reset_cap()
    write_tga(cap_ring, 'resetCapRing')
    write_tga(cap_fill, 'resetCapFill')
    view = '{0} {0} {1} {1}'.format(-SPRIG_ORIGIN, SPRIG_SIZE)
    write_tga(render_svgs([('sprig', svg_cell(sprig_svg(), view, SPRIG_SIZE))], SPRIG_SIZE)['sprig'], 'sprig')
    for i, seed in enumerate((7, 21, 42), 1):
        write_tga(brush(seed), 'brush{}'.format(i))
    print('wrote', len(os.listdir(OUT)), 'files to', OUT)


if __name__ == '__main__':
    sys.exit(main())
