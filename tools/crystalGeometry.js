// Geometry of the page list's Heart crystal backdrop (canvas board "Crystal backdrop", variant A),
// in page list units (200 x 704). Prints JSON for tools/crystalArt.py.

const f1 = (n) => Math.round(n * 10) / 10;
const P = (x, y) => f1(x) + ' ' + f1(y);
const star4 = (x, y, r) => 'M' + P(x, y - r) + 'Q' + P(x, y) + ' ' + P(x + r, y) + 'Q' + P(x, y) + ' ' + P(x, y + r)
    + 'Q' + P(x, y) + ' ' + P(x - r, y) + 'Q' + P(x, y) + ' ' + P(x, y - r) + 'Z';

function rng(seed) {
    let a = seed;
    return () => {
        a |= 0; a = a + 0x6D2B79F5 | 0;
        let t = Math.imul(a ^ a >>> 15, 1 | a);
        t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
        return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
}

function crystal(cx, ty, h, w) {
    const T = [cx, ty], UL = [cx - w / 2, ty + .36 * h], UR = [cx + w / 2, ty + .33 * h], LL = [cx - w * .4, ty + .66 * h],
        LR = [cx + w * .43, ty + .63 * h], B = [cx + w * .02, ty + h], F1 = [cx - w * .09, ty + .37 * h],
        F2 = [cx - w * .06, ty + .65 * h], Q = [cx + w * .2, ty + .5 * h];
    const L = (...ps) => ps.map((p, i) => (i ? 'L' : 'M') + P(p[0], p[1])).join('');
    return {
        body: L(T, UR, LR, B, LL, UL) + 'Z',
        facets: L(T, F1, F2, B) + L(UL, F1, UR) + L(LL, F2, LR) + L(F1, Q, F2) + L(UR, Q, LR) + L(T, [cx + w * .22, ty + .2 * h], UR),
        hi: L(T, F1, [cx - w * .32, ty + .3 * h]) + 'Z' + L([cx - w * .2, ty + .45 * h], [cx - w * .1, ty + .42 * h], [cx - w * .15, ty + .6 * h]) + 'Z',
    };
}

function whirlPoints(fx, fy, r0, turns, ph, flat) {
    const T = turns * Math.PI * 2, k = Math.log(r0 / 2.5) / T, pts = [];
    for (let i = 0; i <= 110; i++) {
        const t = T * i / 110, r = r0 * Math.exp(-k * t), a = t + ph;
        pts.push([f1(fx + r * Math.cos(a) * (.34 + Math.pow(r / 150, 2.2) * .85)), f1(fy + r * Math.sin(a) * flat * .6 - r * 1.05)]);
    }
    return pts;
}
const toPath = (pts) => pts.map((p, i) => (i ? 'L' : 'M') + P(p[0], p[1])).join('');

const FX = 104, FY = 150, GLOW_Y = 360;

let swirl = '';
for (let i = 0; i < 14; i++) {
    const r0 = 70 + (i * 37 % 80), turns = 1.1 + (i % 4) * .22, flat = .3 + (i % 3) * .09;
    swirl += toPath(whirlPoints(FX, FY, r0, turns, i / 14 * Math.PI * 2, flat));
}
let wisps = '';
[[-48, -1], [-30, 1], [-12, -1], [14, 1], [32, -1], [50, 1]].forEach(([dx, s]) => {
    wisps += 'M' + P(FX, FY) + 'C' + P(FX + dx * .1 + s * 6, FY - 60) + ' ' + P(FX + dx * .6 - s * 8, FY - 110) + ' ' + P(FX + dx * 2.1, -6);
});

// Stars thicken towards the crystal; the four-point glints twinkle in game, so only their spots are kept.
const r = rng(31);
let stars = '';
for (let i = 0; i < 150; i++) {
    let x, y;
    if (i < 70) {
        const a = r() * Math.PI * 2, d = Math.pow(r(), 1.6) * 150;
        x = FX + Math.cos(a) * d * .7; y = GLOW_Y + Math.sin(a) * d * 1.6;
    } else {
        x = r() * 200; y = r() * 704;
    }
    const s = .3 + Math.pow(r(), 3) * 1.1;
    stars += 'M' + P(x - s, y) + 'a' + f1(s) + ' ' + f1(s) + ' 0 1 0 ' + f1(2 * s) + ' 0a' + f1(s) + ' ' + f1(s) + ' 0 1 0 ' + f1(-2 * s) + ' 0';
}
const glints = [];
for (let i = 0; i < 9; i++) {
    const x = FX + (r() - .5) * 170, y = GLOW_Y + (r() - .5) * 560, size = 2 + r() * 3.5;
    glints.push({ x: f1(x), y: f1(y), r: f1(size), late: i % 2 === 0 });
}

const motes = [];
const r0 = rng(21);
for (let i = 0; i < 40; i++) {
    motes.push({ x: f1(r0() * 200), y: f1(r0() * 1408), r: f1(.5 + r0()) });
}

const gem = crystal(104, 150, 440, 110);
const shards = [[40, 250, 54, 20], [170, 430, 46, 18]].map(([cx, ty, h, w]) => crystal(cx, ty, h, w).body).join('');

process.stdout.write(JSON.stringify({
    glow: { x: FX, y: GLOW_Y, r: 150 },
    stars, swirl, wisps, eye: 'M' + P(FX - 7, FY - 4) + 'a7 8 0 1 0 14 0a7 8 0 1 0 -14 0',
    body: gem.body, facets: gem.facets, hi: gem.hi, shards,
    glints, motes,
    // Spirit paths, outer end first; each spirit runs one in 9, 13 and 17 s (the second backwards).
    orbits: [
        { points: whirlPoints(FX, FY, 140, 1.6, .4, .38), period: 9, reverse: false },
        { points: whirlPoints(FX, FY, 112, 1.3, 2.6, .46), period: 13, reverse: true },
        { points: whirlPoints(FX, FY, 96, 1.9, 4.4, .32), period: 17, reverse: false },
    ],
}));
