"""Builds the settings top bar's hex texture in assets/settings/: the tilted grid with its resting
glyphs (hexBarBase) and the five groups of cells that light in turn (hexBarLit1..5). Geometry
comes from tools/hexBarGeometry.js (the canvas board "Top bar hex texture", Mosaic); each layer is
the bar's left 620 x 48 units, where the fade ends, drawn at 2 px per unit with the tilt and fade
baked in. Needs Node, Pillow and Google Chrome.

    python tools/hexBarArt.py
"""
import json
import os
import subprocess
import tempfile

from PIL import Image

import settingsArt
from settingsArt import CHROME, ROOT, write_tga

WIDTH, HEIGHT, SCALE = 620, 48, 2
TEXTURE_SIZE = (2048, 128)

STYLE = """
body{margin:0;background:transparent}
.bar{position:relative;width:620px;height:48px;overflow:hidden;
  -webkit-mask-image:linear-gradient(90deg,#000 0%,rgba(0,0,0,.75) 45.16%,rgba(0,0,0,0) 100%)}
.plane{position:absolute;left:-180px;top:-126px;width:1400px;height:300px;transform-origin:700px 150px;
  transform:perspective(700px) rotateX(30deg) rotateZ(10deg)}
.plane svg{position:absolute;left:0;top:0}
.glyph{fill:none;stroke:#E8FBFF;stroke-width:1.1;stroke-linecap:round;stroke-linejoin:round}
.glyphF{fill:#E8FBFF;fill-opacity:.6;stroke:#F4FDFF;stroke-width:.6;stroke-linejoin:round}
.glyphE{fill:none;stroke:#0E2A3A;stroke-opacity:.75;stroke-width:.9;stroke-linecap:round;stroke-linejoin:round}
"""

DEFS = ('<linearGradient id="cg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#BFE8F5" stop-opacity=".18"/>'
        '<stop offset=".55" stop-color="#6FD3E8" stop-opacity=".04"/><stop offset="1" stop-color="#02050C" stop-opacity=".26"/></linearGradient>'
        '<linearGradient id="lg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9FE9F8" stop-opacity=".55"/>'
        '<stop offset="1" stop-color="#2C7487" stop-opacity=".2"/></linearGradient>')


def page(inner):
    return ('<html><head><style>{}</style></head><body><div class="bar"><div class="plane">'
            '<svg width="1400" height="300" viewBox="0 0 1400 300" xmlns="http://www.w3.org/2000/svg">'
            '<defs>{}</defs>{}</svg></div></div></body></html>').format(STYLE, DEFS, inner)


def base_layer(g):
    tile = g['tile']
    cells = ''.join('<path d="{}" fill="url(#cg)" stroke="#9FD8EA" stroke-opacity=".32" stroke-width=".8"/>'.format(d)
                    for d in tile['cells'])
    pattern = ('<pattern id="p" width="{hw}" height="{th}" patternUnits="userSpaceOnUse">{cells}'
               '<path d="{inner}" fill="none" stroke="#9FD8EA" stroke-opacity=".14" stroke-width=".6"/></pattern>').format(
        hw=tile['hw'], th=tile['th'], cells=cells, inner=tile['inner'])
    rest = g['rest']
    return ('<defs>{}</defs><rect x="0" y="0" width="1400" height="300" fill="url(#p)"/>'
            '<g opacity=".22"><path class="glyph" d="{}"/><path class="glyphF" d="{}"/><path class="glyphE" d="{}"/></g>').format(
        pattern, rest['line'], rest['fill'], rest['etch'])


def lit_layer(group):
    return ('<path d="{}" fill="url(#lg)" stroke="#CFF6FF" stroke-opacity=".7" stroke-width=".9"/>'
            '<path class="glyph" d="{}"/><path class="glyphF" d="{}"/><path class="glyphE" d="{}"/>').format(
        group['cells'], group['line'], group['fill'], group['etch'])


def render(html):
    tmp = tempfile.mkdtemp()
    path = os.path.join(tmp, 'layer.html')
    shot = os.path.join(tmp, 'layer.png')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(html)
    # A roomier window than the bar: headless Chrome keeps a minimum window height.
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--user-data-dir=' + os.path.join(tmp, 'profile'),
                    '--hide-scrollbars', '--force-device-scale-factor={}'.format(SCALE),
                    '--default-background-color=00000000', '--window-size=640,240',
                    '--screenshot=' + shot, 'file:///' + path.replace('\\', '/')],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    image = Image.open(shot).convert('RGBA').crop((0, 0, WIDTH * SCALE, HEIGHT * SCALE))
    canvas = Image.new('RGBA', TEXTURE_SIZE, (0, 0, 0, 0))
    canvas.paste(image, (0, 0))
    return canvas


def main():
    out = subprocess.run(['node', os.path.join(ROOT, 'tools', 'hexBarGeometry.js')],
                         check=True, capture_output=True, text=True)
    g = json.loads(out.stdout)
    os.makedirs(settingsArt.OUT, exist_ok=True)
    write_tga(render(page(base_layer(g))), 'hexBarBase')
    for i, group in enumerate(g['groups']):
        write_tga(render(page(lit_layer(group))), 'hexBarLit{}'.format(i + 1))
    print('wrote hexBarBase and hexBarLit1..{}'.format(len(g['groups'])))


if __name__ == '__main__':
    main()
