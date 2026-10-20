// Geometry of the settings top bar's hex texture (canvas board "Top bar hex texture", Mosaic with
// Larger cells), in the plane's units (1400 x 300) before its tilt. Prints JSON for
// tools/hexBarArt.py.

const S3 = Math.sqrt(3);
const R = 18;
const f2 = (n) => Math.round(n * 100) / 100;

function hex(cx, cy, r) {
    let d = '';
    for (let k = 0; k < 6; k++) {
        const a = (60 * k - 90) * Math.PI / 180;
        d += (k ? 'L' : 'M') + f2(cx + r * Math.cos(a)) + ' ' + f2(cy + r * Math.sin(a));
    }
    return d + 'Z';
}

function rng(seed) {
    let a = seed;
    return () => {
        a |= 0; a = a + 0x6D2B79F5 | 0;
        let t = Math.imul(a ^ a >>> 15, 1 | a);
        t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
        return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
}

// One pattern tile of pointy-top hexes, each with an inner rim.
function tile(r) {
    const hw = S3 * r, ri = r * .74;
    return {
        hw: f2(hw), th: f2(3 * r),
        cells: [hex(0, 0, r), hex(hw, 0, r), hex(hw / 2, 1.5 * r, r), hex(0, 3 * r, r), hex(hw, 3 * r, r)],
        inner: hex(0, 0, ri) + hex(hw, 0, ri) + hex(hw / 2, 1.5 * r, ri) + hex(0, 3 * r, ri) + hex(hw, 3 * r, ri),
    };
}

// Glyphs on a 24-unit square, absolute M/L/C/Q/Z only, so every number pair is a point.
const RELICS = [
    { o: 'M19 3C12 4 7 9 6 17C11 16 17 11 19 3Z', d: 'M6 17L4.5 21M17 5L8 15' },
    { o: 'M12 3C14.2 3 16 4.8 16 7C16 9.2 14.2 11 12 11C9.8 11 8 9.2 8 7C8 4.8 9.8 3 12 3Z', d: 'M12 11C12 14 11 17 12 21M10 5.5C10.5 4.8 11.2 4.4 12 4.4' },
    { o: 'M12 4C16.4 4 20 7.6 20 12C20 16.4 16.4 20 12 20C7.6 20 4 16.4 4 12C4 7.6 7.6 4 12 4Z', d: 'M8 12C8 9.8 9.8 8 12 8M9 15C11 16.5 14 16 15.5 13.5M8.5 7.5C9.5 6.6 10.6 6.2 11.8 6.2' },
    { o: 'M11 2L13 2L14 15L10 15ZM7 15L17 15L17 16.5L7 16.5ZM11 16.5L13 16.5L13 21L11 21Z', d: 'M12 3.5L12 14' },
    { o: 'M12 2L16 14L20 16C20 18 4 18 4 16L8 14Z', d: 'M8 14C10 15 14 15 16 14M13 7L10.5 9' },
    { o: 'M10 3L14 3L14 8C17 9 19 11.5 19 14.5C19 18.4 15.9 21 12 21C8.1 21 5 18.4 5 14.5C5 11.5 7 9 10 8Z', d: 'M9 3L15 3M6.5 14L17.5 14' },
    { o: 'M12 4C16.4 4 20 7.6 20 12C20 16.4 16.4 20 12 20C7.6 20 4 16.4 4 12C4 7.6 7.6 4 12 4Z', d: 'M12 7L12 17M14.5 9C13.5 8 10 8 10 10C10 12 14.5 11.5 14.5 14C14.5 16 11 16 9.5 15' },
    { o: 'M4 10C4 7 8 6 13 6C18 6 21 8 21 10C21 12 18 14 13 14C8 14 4 13 4 10ZM9 16L16 16L15 19L10 19Z', d: 'M10 14L10 16M15 14L15 16M2 10L4 10M21 10L23 9M8 10L18 10' },
    { o: 'M12 3C13.7 3 15 4.3 15 6C15 7.7 13.7 9 12 9C10.3 9 9 7.7 9 6C9 4.3 10.3 3 12 3ZM11.3 9L12.7 9L12.7 21L11.3 21Z', d: 'M9 7.5L7 9M15 7.5L17 9' },
    { o: 'M12 2L17 9L12 22L7 9Z', d: 'M7 9L17 9M12 2L10 9L12 22L14 9' },
];
const ELEMENTS = [
    'M12 3C13 7 17 8 17 13C17 16 14.8 18 12 18C9.2 18 7 16 7 13C7 10 9 9 9 7C10 8 10 10 12 10C12 7 11 5 12 3Z',
    'M12 3L12 21M4.2 7.5L19.8 16.5M4.2 16.5L19.8 7.5M10 5L12 3L14 5M10 19L12 21L14 19',
    'M13 3L6 13L11 13L10 21L17 11L12 11Z',
    'M3 9L14 9C16 9 17 7.5 17 6C17 4.5 15.5 3.5 14 4M3 14L18 14C20 14 21 15.5 21 17C21 18.5 19.5 19.5 18 19M3 19L10 19',
    'M3 19L9 9L12 14L15 11L21 19Z',
    'M12 3C15 8 18 11 18 15C18 18.3 15.3 21 12 21C8.7 21 6 18.3 6 15C6 11 9 8 12 3Z',
    'M12 8C14.2 8 16 9.8 16 12C16 14.2 14.2 16 12 16C9.8 16 8 14.2 8 12C8 9.8 9.8 8 12 8ZM12 2L12 5M12 19L12 22M2 12L5 12M19 12L22 12M5 5L7 7M17 17L19 19M5 19L7 17M17 7L19 5',
    'M15 3C10 3 6 7 6 12C6 17 10 21 15 21C17 21 19 20 20 19C16 18.5 13 15.5 13 12C13 8.5 16 5.5 20 5C19 4 17 3 15 3Z',
];
const CRYSTALS = [
    'M12 2L17 9L12 22L7 9ZM7 9L17 9M12 2L10 9L12 22L14 9',
    'M12 2Q12 12 22 12Q12 12 12 22Q12 12 2 12Q12 12 12 2Z',
    'M8 21L6 12L9 6L12 12L10 21ZM12 21L13 9L16 3L19 9L17 21Z',
    'M12 4C16.4 4 20 7.6 20 12C20 16.4 16.4 20 12 20C7.6 20 4 16.4 4 12C4 7.6 7.6 4 12 4ZM8.5 9C9 7.5 10.2 6.6 11.5 6.4',
    'M5 9L8 4L16 4L19 9L12 20ZM5 9L19 9M8 4L10 9L12 20L14 9L16 4',
];

// Moves a 24-unit glyph onto a cell centred at (cx, cy), size s across.
function place(d, cx, cy, s) {
    const k = s / 24;
    let odd = true;
    return d.replace(/-?\d+(\.\d+)?/g, (n) => {
        const v = parseFloat(n), out = odd ? f2(cx + (v - 12) * k) : f2(cy + (v - 12) * k);
        odd = !odd;
        return String(out);
    });
}

// About half the cells the bar shows carry a faint glyph; two in five of those light in one of
// five staggered groups.
function mosaic(r, seed) {
    const hw = S3 * r, rnd = rng(seed);
    const out = { rest: { line: '', fill: '', etch: '' }, groups: [] };
    for (let k = 0; k < 5; k++) out.groups.push({ cells: '', line: '', fill: '', etch: '' });
    const pool = [];
    RELICS.forEach((it) => { pool.push({ o: it.o, d: it.d, filled: true }); pool.push({ o: it.o, d: it.d, filled: false }); });
    ELEMENTS.concat(CRYSTALS).forEach((o) => pool.push({ o, d: '', filled: false }));
    const rowMin = Math.ceil(96 / (1.5 * r)), rowMax = Math.floor(200 / (1.5 * r));
    let n = 0;
    for (let row = rowMin; row <= rowMax; row++) {
        for (let col = Math.floor(160 / hw); col <= Math.floor(800 / hw); col++) {
            if (rnd() >= .5) continue;
            const cx = col * hw + (row % 2) * hw / 2, cy = row * 1.5 * r, it = pool[Math.floor(rnd() * pool.length)], s = r * 1.05;
            const o = place(it.o, cx, cy, s), d = it.d ? place(it.d, cx, cy, s) : '';
            if (it.filled) { out.rest.fill += o; out.rest.etch += d; } else out.rest.line += o + d;
            if (rnd() < .4) {
                const group = out.groups[n++ % 5];
                group.cells += hex(cx, cy, r) + hex(cx, cy, r * .74);
                if (it.filled) { group.fill += o; group.etch += d; } else group.line += o + d;
            }
        }
    }
    return out;
}

process.stdout.write(JSON.stringify(Object.assign({ tile: tile(R) }, mosaic(R, 5))));
