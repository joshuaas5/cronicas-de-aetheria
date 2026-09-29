"""Builds alpha-cut leaf cluster textures from the scanned Poly Haven leaf photos.

Run from the project root:  python tools/make_foliage.py
Outputs go to assets/generated/.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(__file__), '..', 'assets')
OUT = os.path.join(ROOT, 'generated')
os.makedirs(OUT, exist_ok=True)


def load_leaves(tree):
    base = os.path.join(ROOT, 'models', tree, 'textures', tree + '_leaves_')
    diff = np.asarray(Image.open(base + 'diff_1k.jpg').convert('RGB')).astype(np.float32) / 255
    nrm = np.asarray(Image.open(base + 'nor_gl_1k.jpg').convert('RGB')).astype(np.float32) / 255
    mask = diff.max(axis=2) > 0.07
    mask = ndimage.binary_opening(mask, iterations=2)
    mask = ndimage.binary_fill_holes(mask)
    lab, n = ndimage.label(mask)
    leaves = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        m = lab[sl] == (i + 1)
        if m.sum() < 3000:
            continue
        soft = ndimage.gaussian_filter(m.astype(np.float32), 0.8)
        rgba = np.dstack([diff[sl], soft])
        leaves.append((rgba, nrm[sl]))
    return leaves


def to_img(rgba):
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), 'RGBA')


def rotate_normal(nrm_rgb, alpha, deg):
    """Rotates a tangent-space normal crop by deg (counter-clockwise), keeping vectors consistent."""
    v = nrm_rgb * 2 - 1
    t = math.radians(deg)
    x = v[..., 0] * math.cos(t) - v[..., 1] * math.sin(t)
    y = v[..., 0] * math.sin(t) + v[..., 1] * math.cos(t)
    out = np.dstack([x * 0.5 + 0.5, y * 0.5 + 0.5, v[..., 2] * 0.5 + 0.5, alpha])
    return to_img(out).rotate(deg, resample=Image.BICUBIC, expand=True)


def cluster(leaves, size, seed, count, spread, shape):
    rnd = random.Random(seed)
    alb = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    nrm = Image.new('RGBA', (size, size), (128, 128, 255, 0))
    twig = ImageDraw.Draw(alb)
    cx, base_y = size / 2, size * 0.9
    # branch skeleton
    branches = []
    for b in range(shape):
        ang = rnd.uniform(-spread, spread)
        length = size * rnd.uniform(0.38, 0.6)
        branches.append((ang, length))
        ex = cx + math.sin(math.radians(ang)) * length
        ey = base_y - math.cos(math.radians(ang)) * length
        twig.line([(cx, base_y), (ex, ey)], fill=(58, 44, 30, 255), width=max(2, size // 180))
    placements = []
    for i in range(count):
        ang, length = rnd.choice(branches)
        t = rnd.uniform(0.25, 1.0)
        px = cx + math.sin(math.radians(ang)) * length * t
        py = base_y - math.cos(math.radians(ang)) * length * t
        side = rnd.choice((-1, 1))
        leaf_ang = ang + side * rnd.uniform(25, 70)
        scale = rnd.uniform(0.12, 0.19) * size / 400
        placements.append((t + rnd.uniform(-0.2, 0.2), px, py, leaf_ang, scale))
    placements.sort(key=lambda p: p[0])  # inner leaves first, outer leaves on top
    for depth, px, py, leaf_ang, scale in placements:
        rgba, n = rnd.choice(leaves)
        h, w = rgba.shape[:2]
        tw, th = max(4, int(w * scale)), max(4, int(h * scale))
        shade = 0.62 + 0.45 * min(1, max(0, depth))
        col = rgba.copy()
        col[..., :3] *= shade * rnd.uniform(0.9, 1.08)
        li = to_img(col).resize((tw, th), Image.LANCZOS).rotate(-leaf_ang, resample=Image.BICUBIC, expand=True)
        ni_src = Image.fromarray((n * 255).astype(np.uint8)).resize((tw, th), Image.LANCZOS)
        a_small = np.asarray(to_img(col).resize((tw, th), Image.LANCZOS))[..., 3].astype(np.float32) / 255
        ni = rotate_normal(np.asarray(ni_src).astype(np.float32) / 255, a_small, -leaf_ang)
        # the leaf stem sits at the bottom of the crop: anchor it at the placement point
        ox = int(px - li.width / 2 + math.sin(math.radians(leaf_ang)) * th * 0.45)
        oy = int(py - li.height / 2 - math.cos(math.radians(leaf_ang)) * th * 0.45)
        alb.alpha_composite(li, (ox, oy))
        nrm.alpha_composite(ni, (ox, oy))
    # alpha-bleed the colour into transparent pixels so mipmaps don't fringe dark
    a = np.asarray(alb).astype(np.float32) / 255
    rgb, al = a[..., :3], a[..., 3:]
    blur_rgb = np.asarray(Image.fromarray((rgb * al * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(12))).astype(np.float32) / 255
    blur_a = ndimage.gaussian_filter(al[..., 0], 12)[..., None] + 1e-4
    fill = blur_rgb / blur_a
    rgb = np.where(al > 0.5, rgb, fill)
    alb = to_img(np.dstack([rgb, al[..., 0]]))
    n = np.asarray(nrm).astype(np.float32) / 255
    n[..., :3] = np.where(n[..., 3:] > 0.1, n[..., :3], np.array([0.5, 0.5, 1.0]))
    nrm_img = Image.fromarray((n[..., :3] * 255).astype(np.uint8), 'RGB')
    return alb, nrm_img


def main():
    leaves = load_leaves('island_tree_01') + load_leaves('island_tree_02')
    print('leaves found:', len(leaves))
    specs = [
        ('leaf_cluster_a', 11, 110, 55, 6),
        ('leaf_cluster_b', 23, 80, 38, 4),
        ('leaf_bush', 37, 140, 75, 8),
    ]
    for name, seed, count, spread, shape in specs:
        alb, nrm = cluster(leaves, 1024, seed, count, spread, shape)
        alb.save(os.path.join(OUT, name + '_alb.png'))
        nrm.save(os.path.join(OUT, name + '_nrm.png'))
        print('wrote', name)


if __name__ == '__main__':
    main()


def flower_patch(name, palettes, seed, flowers=38):
    """Wildflower card: grass blades plus five-petal blossoms on stems."""
    rnd = random.Random(seed)
    size = 1024
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = size * 0.97
    for i in range(160):
        x = rnd.uniform(size * 0.08, size * 0.92)
        h = rnd.uniform(size * 0.2, size * 0.55)
        lean = rnd.uniform(-60, 60)
        g = rnd.randint(95, 175)
        col = (int(g * 0.45), g, int(g * 0.25), 255)
        d.polygon([(x - 5, base), (x + 5, base), (x + lean, base - h)], fill=col)
    stems = []
    for i in range(flowers):
        x = rnd.uniform(size * 0.12, size * 0.88)
        y = rnd.uniform(size * 0.18, size * 0.65)
        stems.append((x, y))
        d.line([(x + rnd.uniform(-20, 20), base), (x, y)], fill=(70, 120, 40, 255), width=5)
    for x, y in sorted(stems, key=lambda s: s[1]):
        petal, centre = rnd.choice(palettes)
        r = rnd.uniform(16, 30)
        rot = rnd.uniform(0, math.pi)
        for k in range(5):
            a = rot + k * math.tau / 5
            px, py = x + math.cos(a) * r * 0.75, y + math.sin(a) * r * 0.6
            shade = rnd.uniform(0.85, 1.1)
            c = tuple(min(255, int(v * shade)) for v in petal) + (255,)
            d.ellipse([px - r * 0.55, py - r * 0.42, px + r * 0.55, py + r * 0.42], fill=c)
        d.ellipse([x - r * 0.3, y - r * 0.26, x + r * 0.3, y + r * 0.26], fill=centre + (255,))
    img = img.filter(ImageFilter.SMOOTH_MORE)
    a = np.asarray(img).astype(np.float32) / 255
    rgb, al = a[..., :3], a[..., 3:]
    blur_rgb = np.asarray(Image.fromarray((rgb * al * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10))).astype(np.float32) / 255
    blur_a = ndimage.gaussian_filter(al[..., 0], 10)[..., None] + 1e-4
    rgb = np.where(al > 0.5, rgb, blur_rgb / blur_a)
    to_img(np.dstack([rgb, al[..., 0]])).save(os.path.join(OUT, name + '_alb.png'))
    Image.new('RGB', (8, 8), (128, 128, 255)).save(os.path.join(OUT, name + '_nrm.png'))
    print('wrote', name)


if __name__ == '__main__':
    flower_patch('flowers_warm', [((255, 120, 170), (255, 220, 90)), ((255, 90, 120), (255, 230, 120)), ((255, 175, 60), (140, 70, 20)), ((255, 240, 245), (255, 200, 60))], 5)
    flower_patch('flowers_cool', [((120, 150, 255), (255, 240, 150)), ((190, 110, 255), (255, 230, 120)), ((255, 255, 255), (255, 210, 60)), ((110, 220, 255), (255, 250, 200))], 9)
