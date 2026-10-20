"""Builds the page list's Heart crystal backdrop: textures in assets/settings/ and the glint and
spirit paths in config/crystalData.lua. Geometry comes from tools/crystalGeometry.js (the canvas
board "Crystal backdrop", variant A), in page list units (200 x 704) drawn at 2 px per unit.
Needs Node, Pillow and Google Chrome.

    python tools/crystalArt.py
"""
import json
import os
import subprocess
import tempfile

from PIL import Image, ImageChops, ImageDraw, ImageFilter

import settingsArt
from settingsArt import CHROME, ROOT, write_tga

SCALE = 2


def run_geometry():
    out = subprocess.run(['node', os.path.join(ROOT, 'tools', 'crystalGeometry.js')],
                         check=True, capture_output=True, text=True)
    return json.loads(out.stdout)


def render(svg, width, height):
    """svg: markup drawn from the page's top-left -> width x height RGBA screenshot."""
    html = '<html><body style="margin:0;background:transparent">{}</body></html>'.format(svg)
    tmp = tempfile.mkdtemp()
    page = os.path.join(tmp, 'layer.html')
    shot = os.path.join(tmp, 'layer.png')
    with open(page, 'w', encoding='utf-8') as f:
        f.write(html)
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--user-data-dir=' + os.path.join(tmp, 'profile'),
                    '--hide-scrollbars', '--force-device-scale-factor=1',
                    '--default-background-color=00000000', '--window-size={},{}'.format(width, height),
                    '--screenshot=' + shot, 'file:///' + page.replace('\\', '/')],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return Image.open(shot).convert('RGBA')


BODY_GRADIENT = ('<linearGradient id="body" x1="0" y1="0" x2=".35" y2="1">'
                 '<stop offset="0" stop-color="#C3D6E2" stop-opacity=".36"/>'
                 '<stop offset=".4" stop-color="#6E9CB4" stop-opacity=".16"/>'
                 '<stop offset="1" stop-color="#2A3C62" stop-opacity=".1"/></linearGradient>')


def back_svg(g):
    """Glow, stars, the whirlpool and its wisps: everything that stays still."""
    glow = g['glow']
    return ('<svg width="{w}" height="{h}" viewBox="0 0 200 704" xmlns="http://www.w3.org/2000/svg"><defs>'
            '<radialGradient id="glow"><stop offset="0" stop-color="#7FB8C8" stop-opacity=".26"/>'
            '<stop offset=".45" stop-color="#3E6F8E" stop-opacity=".1"/>'
            '<stop offset="1" stop-color="#0A1121" stop-opacity="0"/></radialGradient></defs>'
            '<circle cx="{gx}" cy="{gy}" r="{gr}" fill="url(#glow)"/>'
            '<path d="{stars}" fill="#CDE6F2" fill-opacity=".55"/>'
            '<path d="{wisps}" fill="none" stroke="#8FCFE2" stroke-opacity=".16" stroke-width=".7" stroke-linecap="round"/>'
            '<path d="{swirl}" fill="none" stroke="#6FD3E8" stroke-opacity=".14" stroke-width="3" stroke-linecap="round" style="filter:blur(2.5px)"/>'
            '<path d="{swirl}" fill="none" stroke="#A8DCEA" stroke-opacity=".26" stroke-width=".6" stroke-linecap="round"/>'
            '<path d="{eye}" fill="#CFF3FA" fill-opacity=".22" style="filter:blur(4px)"/>'
            '</svg>').format(w=200 * SCALE, h=704 * SCALE, gx=glow['x'], gy=glow['y'], gr=glow['r'], **g)


GEM_TOP, GEM_HEIGHT = 140, 512


def gem_svg(g):
    """The crystal and its two shards, which bob together; units GEM_TOP..GEM_TOP + GEM_HEIGHT."""
    return ('<svg width="{w}" height="{h}" viewBox="0 {top} 200 {height}" xmlns="http://www.w3.org/2000/svg">'
            '<defs>' + BODY_GRADIENT + '</defs>'
            '<path d="{shards}" fill="url(#body)" stroke="#CFF6FF" stroke-opacity=".4" stroke-width=".6" stroke-linejoin="round"/>'
            '<path d="{body}" fill="url(#body)" stroke="#C9DCEA" stroke-opacity=".38" stroke-width="1" stroke-linejoin="round"/>'
            '<path d="{facets}" fill="none" stroke="#DCE6EE" stroke-opacity=".2" stroke-width=".7"/>'
            '<path d="{hi}" fill="#FFFFFF" fill-opacity=".16"/>'
            '</svg>').format(w=200 * SCALE, h=GEM_HEIGHT * SCALE, top=GEM_TOP, height=GEM_HEIGHT, **g)


# The motes tile repeats every MOTE_TILE units; 256 x 1024 px covers 200 x 800 units.
MOTE_TILE = 800
MOTE_SCALE = 256 / 200


def motes_image(motes):
    ss = 4
    w, h = 256 * ss, 1024 * ss
    mask = Image.new('L', (w, h), 0)
    draw = ImageDraw.Draw(mask)
    for m in motes:
        y = m['y'] % MOTE_TILE
        for wrap in (-MOTE_TILE, 0, MOTE_TILE):
            cx, cy, r = m['x'] * MOTE_SCALE * ss, (y + wrap) * MOTE_SCALE * ss, m['r'] * MOTE_SCALE * ss
            draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=140)
    mask = mask.resize((256, 1024), Image.LANCZOS)
    image = Image.new('RGBA', (256, 1024), (0xDD, 0xF8, 0xFF, 0))
    image.putalpha(mask)
    return image


def glint_image():
    """A white four-point star, 64 px across its points."""
    return render('<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">'
                  '<path d="M32 1Q32 32 63 32Q32 32 32 63Q32 32 1 32Q32 32 32 1Z" fill="#FFFFFF"/></svg>', 64, 64)


def spirit_image():
    """A white glow with a bright core, 64 px."""
    ss = 4
    size = 64 * ss
    halo = Image.new('L', (size, size), 0)
    ImageDraw.Draw(halo).ellipse((size * .3, size * .3, size * .7, size * .7), fill=150)
    halo = halo.filter(ImageFilter.GaussianBlur(size * .09))
    core = Image.new('L', (size, size), 0)
    ImageDraw.Draw(core).ellipse((size * .44, size * .44, size * .56, size * .56), fill=255)
    core = core.filter(ImageFilter.GaussianBlur(size * .015))
    alpha = ImageChops.lighter(halo, core)
    alpha = alpha.resize((64, 64), Image.LANCZOS)
    image = Image.new('RGBA', (64, 64), (255, 255, 255, 0))
    image.putalpha(alpha)
    return image


def pad(image, width, height):
    canvas = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    canvas.paste(image.crop((0, 0, min(image.width, width), min(image.height, height))), (0, 0))
    return canvas


def lua_data(g):
    lines = ['-- Generated by tools/crystalArt.py from tools/crystalGeometry.js; do not edit.',
             '-- Page list units (200 x 704) from the top-left.', '',
             'local _, EUI = ...', '', 'EUI.CrystalData = {']
    lines.append('    glints = {')
    for glint in g['glints']:
        lines.append('        {{ {}, {}, {}, {} }},'.format(glint['x'], glint['y'], glint['r'], 'true' if glint['late'] else 'false'))
    lines.append('    },')
    lines.append('    orbits = {')
    for orbit in g['orbits']:
        points = orbit['points'][::2]
        if points[-1] != orbit['points'][-1]:
            points.append(orbit['points'][-1])
        lines.append('        {{ period = {}, reverse = {}, points = {{'.format(orbit['period'], 'true' if orbit['reverse'] else 'false'))
        for i in range(0, len(points), 8):
            lines.append('            ' + ' '.join('{{ {}, {} }},'.format(x, y) for x, y in points[i:i + 8]))
        lines.append('        } },')
    lines.append('    },')
    lines.append('}')
    with open(os.path.join(ROOT, 'config', 'crystalData.lua'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


def main():
    g = run_geometry()
    os.makedirs(settingsArt.OUT, exist_ok=True)
    write_tga(pad(render(back_svg(g), 512, 2048), 512, 2048), 'crystalBack')
    write_tga(pad(render(gem_svg(g), 512, 1024), 512, 1024), 'crystalGem')
    write_tga(motes_image(g['motes']), 'crystalMotes')
    write_tga(glint_image(), 'crystalGlint')
    write_tga(spirit_image(), 'crystalSpirit')
    lua_data(g)
    print('wrote crystal textures and config/crystalData.lua')


if __name__ == '__main__':
    main()
