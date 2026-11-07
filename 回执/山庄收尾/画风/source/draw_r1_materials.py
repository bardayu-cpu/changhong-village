#!/usr/bin/env python3
"""Draw nine periodic R1 swatches on a 64×64 integer art grid."""
import argparse
import ast
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 64
OUT = Path(__file__).resolve().parents[1]


def read_palette():
    # Read the literal swatches without executing the legacy all-assets generator.
    tree = ast.parse((OUT / "source/draw_r1.py").read_text())
    palette = next(
        ast.literal_eval(node.value)
        for node in tree.body
        if isinstance(node, ast.Assign)
        and any(isinstance(target, ast.Name) and target.id == "P" for target in node.targets)
    )
    return palette


class Tile:
    def __init__(self, palette, size, base):
        self.palette = palette
        self.image = Image.new("RGB", (size, size), palette[base])
        self.draw = ImageDraw.Draw(self.image)
        self.operations = []
        self.colors = {base}

    def stamp(self, kind, points, color):
        self.operations.append((kind, points, color))
        self.colors.add(color)
        self.repeat(kind, points, color)

    def repeat(self, kind, points, color):
        xs, ys = zip(*points)
        width, height = self.image.size
        for dy in range(-max(ys)//SIZE * SIZE, height-min(ys), SIZE):
            for dx in range(-max(xs)//SIZE * SIZE, width-min(xs), SIZE):
                shifted = [(x+dx, y+dy) for x, y in points]
                getattr(self.draw, kind)(shifted, fill=self.palette[color])

    def line(self, color, *points):
        self.stamp("line", points, color)

    def poly(self, color, *points):
        self.stamp("polygon", points, color)

    def rect(self, color, x0, y0, x1, y1):
        self.stamp("rectangle", ((x0, y0), (x1, y1)), color)


def grass(t):
    for x, y, width in ((-3, 11, 6), (12, 5, 5), (27, 9, 5), (47, 5, 8), (58, 22, 5),
                        (17, 24, 7), (35, 30, 5), (3, 40, 8), (49, 43, 7),
                        (19, 48, 5), (36, 57, 7), (56, 63, 5), (9, 61, 5)):
        t.line("grass_d", (x, y+2), (x+width-1, y+2), (x+width+1, y+1))
        t.line("grass_l", (x, y+1), (x+2, y-2), (x+3, y+1), (x+5, y-1))
        if width > 5:
            t.line("grass_hi", (x+2, y-2), (x+3, y-2))
    for x, y in ((14, 21), (52, 41), (8, 59)):
        t.rect("flower", x, y, x+1, y)
        t.rect("grass_l", x, y+1, x, y+2)


def asphalt(t):
    t.poly("asphalt_d", (38, 37), (45, 35), (52, 37), (55, 41), (52, 44), (45, 45), (40, 43))
    t.line("crack", (-3, 49), (3, 46), (8, 46), (11, 42), (16, 40), (19, 34))
    t.line("crack", (9, 45), (13, 47), (17, 47))
    t.line("asphalt_l", (2, 47), (7, 47), (10, 44))
    for x, y in ((4, 8), (21, 3), (30, 18), (48, 28), (59, 11), (28, 44), (10, 58), (40, 60), (54, 54)):
        t.rect("asphalt_l", x, y, x+1, y)
        t.rect("asphalt_d", x+1, y+1, x+1, y+1)
    for x0, x1, y0, y1 in ((-2, 18, 22, 25), (19, 38, 22, 24), (39, 62, 23, 25)):
        t.rect("asphalt_hi", x0, y0, x1, y1)
    for x, y in ((5, 22), (15, 25), (26, 23), (44, 25), (58, 23)):
        t.rect("asphalt_m", x, y, x+1, y)


def stone(t):
    # Each row spans one full period, with staggered unequal-width chipped blocks.
    for y, start, widths in ((-4, -7, (18, 25, 21)), (12, 4, (23, 19, 22)),
                             (28, -10, (26, 17, 21)), (44, 0, (19, 26, 19))):
        x = start
        for index, width in enumerate(widths):
            right = x + width - 1
            t.poly("stone_l", (x, y+2), (x+3, y), (right-3, y), (right, y+3),
                   (right, y+12), (right-3, y+14), (x+2, y+14), (x, y+11))
            t.line("stone_hi", (x+1, y+9), (x+1, y+3), (x+4, y+1), (right-4, y+1))
            t.line("stone_m", (right-1, y+4), (right-1, y+11), (right-4, y+13), (x+3, y+13))
            t.line("stone_m", (x+5, y+7+index), (x+9, y+7+index))
            x += width
    for x, y in ((5, 11), (40, 27), (19, 59)):
        t.line("grass_m", (x-1, y+1), (x, y-1), (x+1, y+1), (x+3, y))


def wood(t):
    for y, joints in ((-3, (8, 37)), (13, (22, 52)), (29, (2, 31)), (45, (14, 46))):
        t.line("wood_d", (0, y), (63, y))
        t.line("wood_l", (0, y+1), (63, y+1))
        for x in joints:
            t.line("wood_d", (x, y), (x, y+15))
            t.rect("wood_hi", x+1, y+2, x+3, y+2)
            t.rect("wood_hi", x-3, y+12, x-1, y+12)
            t.line("wood_l", (x+4, y+6), (x+9, y+5), (x+18, y+5), (x+24, y+6))
            t.line("wood_l", (x+7, y+9), (x+12, y+10), (x+19, y+10))
    t.line("wood_d", (30, 22), (33, 20), (38, 20), (41, 22), (37, 24), (33, 24), (30, 22))
    t.line("wood_l", (33, 22), (38, 22))


def wall(t):
    t.rect("roof", 0, -5, 63, 15)
    for y, shift in ((-4, 0), (2, 4), (8, 0)):
        for x in range(shift-8, 64, 8):
            t.line("wall_d", (x, y+4), (x+2, y+1), (x+5, y+1), (x+7, y+4))
            t.line("wall_m", (x+1, y+3), (x+3, y+1), (x+5, y+1))
    t.line("wall_d", (0, 15), (63, 15))
    t.line("wall_hi", (0, 17), (63, 17))
    for x, y in ((-1, 29), (14, 37), (35, 25), (52, 45)):
        t.line("wall_m", (x, y), (x+4, y), (x+6, y+2), (x+9, y+2))
        t.line("wall_hi", (x+1, y+1), (x+4, y+1))
    t.rect("wall_d", 0, 55, 63, 58)
    t.rect("wall_m", 0, 53, 63, 54)
    for x, span in ((-4, 8), (14, 6), (29, 11), (49, 7)):
        t.line("wall_m", (x, 52), (x+span, 52))


def water(t):
    for x, y, span in ((-7, 10, 21), (22, 6, 17), (47, 13, 13), (11, 23, 23),
                       (40, 27, 16), (57, 34, 19), (20, 40, 15), (36, 49, 20), (8, 55, 15)):
        t.poly("water_m", (x, y+3), (x+4, y), (x+span-5, y), (x+span, y+2),
               (x+span-4, y+4), (x+6, y+5))
        t.line("water_l", (x+2, y+2), (x+5, y+1), (x+span-5, y+1))
        t.line("water_hi", (x+5, y+1), (x+8, y+1))
    shore = [(0, 60), (8, 59), (17, 60), (26, 61), (38, 60), (49, 59), (64, 60)]
    t.poly("water_m", *shore, (64, 66), (0, 66))
    t.line("water_l", *((x, y+1) for x, y in shore))
    t.line("water_hi", (61, 61), (66, 61), (70, 60))
    t.line("water_hi", (18, 61), (24, 62), (28, 62))


def car(t):
    for y in (0, 32):
        t.poly("car_d", (0, y+23), (12, y+25), (31, y+24), (48, y+22), (64, y+23),
               (64, y+31), (0, y+31))
        t.poly("car_hi", (-5, y+7), (13, y+8), (35, y+6), (55, y+5), (65, y+7),
               (65, y+8), (47, y+7), (25, y+9), (10, y+10), (-5, y+8))
        t.poly("glass_d", (21, y+13), (39, y+12), (45, y+20), (18, y+21))
        t.line("asphalt_d", (23, y+14), (36, y+13))
        t.line("car_hi", (27, y+19), (32, y+15), (35, y+14))
        t.rect("asphalt_d", 5, y+25, 14, y+28)
        t.line("glass_d", (6, y+28), (12, y+28))


def cloth(t):
    for x, shift in ((-5, 1), (11, -1), (27, 1), (43, -1)):
        # Every fold returns to its opening coordinate at the period boundary.
        spine = [(x, -1), (x+shift, 15), (x+3, 30), (x+2, 45), (x, 64)]
        t.poly("cloth_d", *spine, *((px+5, py) for px, py in reversed(spine)))
        t.poly("cloth_l", *((px-4, py) for px, py in spine),
               *((px-1, py) for px, py in reversed(spine)))
        t.line("cloth_hi", *((px-3, py) for px, py in spine))
    for x, y in ((5, 7), (22, 25), (37, 45), (54, 55), (12, 62)):
        t.line("cloth_l", (x, y), (x+2, y+1))


def metal(t):
    for y in (-4, 28):
        for x in (-6, 26):
            t.rect("metal_d", x, y, x+30, y+30)
            t.rect("metal_l", x, y, x+29, y+2)
            t.rect("glass_d", x+3, y+4, x+27, y+25)
            t.poly("glass_l", (x+4, y+23), (x+4, y+19), (x+17, y+5), (x+20, y+5))
            t.line("metal_l", (x+10, y+20), (x+19, y+10), (x+24, y+6))
            t.rect("metal_hi", x+2, y+1, x+3, y+1)
            t.rect("metal_hi", x+21, y+8, x+21, y+8)
            t.line("metal_l", (x+4, y+27), (x+26, y+27))


MATERIALS = {
    "草地": ("grass_m", grass), "柏油": ("asphalt_m", asphalt), "石板": ("stone_d", stone),
    "木头": ("wood_m", wood), "白墙灰瓦": ("wall_l", wall), "水": ("water_d", water),
    "车漆": ("car_m", car), "布": ("cloth_m", cloth), "金属玻璃": ("metal_d", metal),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="verify existing PNGs without rewriting")
    args = parser.parse_args()
    palette = read_palette()
    with Image.open(OUT / "主色板.png") as swatches:
        approved = set(swatches.convert("RGB").getdata())
    for name, (base, paint) in MATERIALS.items():
        tile = Tile(palette, SIZE, base)
        paint(tile)
        result = tile.image.resize((SIZE*2, SIZE*2), Image.Resampling.NEAREST)
        path = OUT / f"{name}.png"
        if not args.verify:
            result.save(path, optimize=True)
        with Image.open(path) as saved:
            assert saved.size == (128, 128) and saved.mode == "RGB", name
            assert saved.tobytes() == result.tobytes(), name
            assert 3 <= len(set(saved.getdata())) <= 5 and set(saved.getdata()) <= approved, name
        joined = Image.new("RGB", (SIZE*2, SIZE*2))
        for x, y in ((0, 0), (SIZE, 0), (0, SIZE), (SIZE, SIZE)):
            joined.paste(tile.image, (x, y))
        full = Tile(palette, SIZE*2, base)
        for op in tile.operations:
            full.repeat(*op)
        assert ImageChops.difference(joined, full.image).getbbox() is None, name
        print(f"PASS {name} · 64×64 art grid · {len(set(result.getdata()))} swatches · 2×2 repeat")


if __name__ == "__main__":
    main()
