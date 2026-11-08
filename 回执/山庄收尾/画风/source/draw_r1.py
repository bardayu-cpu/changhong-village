from PIL import Image, ImageDraw
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]
# Named shared palette. Every exported visible RGB is checked against this table at the end.
P={
'grass_d':'#536d4e','grass_m':'#72885b','grass_l':'#93a36b','grass_hi':'#c0b779','flower':'#e1c779',
'asphalt_d':'#424b50','asphalt_m':'#5e686b','asphalt_l':'#78817e','asphalt_hi':'#9b9c8d','crack':'#39454a',
'stone_d':'#696d73','stone_m':'#858681','stone_l':'#aaa391','stone_hi':'#d0be98',
'wood_d':'#62473d','wood_m':'#896046','wood_l':'#b37b4e','wood_hi':'#d9a96c',
'wall_d':'#777982','wall_m':'#a5a39a','wall_l':'#d2cbbb','wall_hi':'#f0dfb8','roof':'#505c70',
'water_d':'#326773','water_m':'#4d8887','water_l':'#75aaa0','water_hi':'#afd0b0',
'car_d':'#85362f','car_m':'#b44a3d','car_l':'#d66d53','car_hi':'#f3b176','glass_d':'#2f4c5e','glass_l':'#63818b',
'cloth_d':'#754e57','cloth_m':'#a36468','cloth_l':'#cd8d83','cloth_hi':'#e9bca0',
'metal_d':'#505b66','metal_m':'#7b8990','metal_l':'#b2bdb5','metal_hi':'#e2dfcc',
'skin_d':'#a96850','skin_m':'#d08d68','skin_l':'#e8b78b','hair':'#443633','hairgray':'#a5a49b',
'navy':'#394556','green':'#48654c','blue':'#587d9d','gold':'#d4af70','paper':'#d9d1b8','shadow':'#414746'}
C={k:tuple(bytes.fromhex(v[1:])) for k,v in P.items()}
import argparse
import subprocess
import sys

from draw_r1_car import export_car
from draw_r1_furniture import draw_chair, draw_table

MATERIALS = (
    ('草地', 'GRASS'), ('柏油', 'ASPHALT'), ('石板', 'STONE'),
    ('木头', 'WOOD'), ('白墙灰瓦', 'WALL / TILE'), ('水', 'WATER'),
    ('红毯', 'RED CARPET'), ('布', 'CLOTH'), ('金属玻璃', 'METAL / GLASS'),
)
PEOPLE = ('photographer_w', 'elder', 'farmer_2')

# Original bitmap lettering, on the same art grid as the drawings.
GLYPHS = {
 '0':(7,5,5,5,7), '1':(2,6,2,2,7), '2':(7,1,7,4,7), '3':(7,1,7,1,7),
 '4':(5,5,7,1,1), '5':(7,4,7,1,7), '6':(7,4,7,5,7), '7':(7,1,2,2,2),
 '8':(7,5,7,5,7), '9':(7,5,7,1,7), 'A':(2,5,7,5,5), 'B':(6,5,6,5,6),
 'C':(7,4,4,4,7), 'D':(6,5,5,5,6), 'E':(7,4,6,4,7), 'F':(7,4,6,4,4),
 'G':(7,4,5,5,7), 'H':(5,5,7,5,5), 'I':(7,2,2,2,7), 'L':(4,4,4,4,7),
 'M':(5,7,7,5,5), 'N':(5,7,7,7,5), 'O':(7,5,5,5,7), 'P':(7,5,7,4,4),
 'R':(6,5,6,5,5), 'S':(7,4,7,1,7), 'T':(7,2,2,2,2), 'U':(5,5,5,5,7),
 'V':(5,5,5,5,2), 'W':(5,5,7,7,5), 'X':(5,5,2,5,5), 'Y':(5,5,2,2,2),
 'Z':(7,1,2,4,7), '/':(1,1,2,4,4), ':':(0,2,0,2,0), ' ':(0,0,0,0,0)
}

def color(key):
    return (*C[key], 255)


def plate(width, height):
    canvas = Image.new('RGBA', (width, height), color('paper'))
    return canvas, ImageDraw.Draw(canvas)


def box(draw, x, y, w, h, key):
    draw.rectangle((x, y, x + w - 1, y + h - 1), fill=color(key))


def stroke(draw, key, *points, width=1):
    draw.line(points, fill=color(key), width=width)


def label(draw, x, y, text):
    for index, char in enumerate(text):
        for row, bits in enumerate(GLYPHS[char]):
            for col in range(3):
                if bits & (4 >> col):
                    draw.point((x + 4 * index + col, y + row), fill=color('navy'))


def export(canvas, name):
    canvas.resize((canvas.width * 2, canvas.height * 2), Image.Resampling.NEAREST).save(
        OUT / (name + '.png'), optimize=True,
    )


def grid_image(name):
    with Image.open(OUT / (name + '.png')) as original:
        size = (original.width // 2 * 2, original.height // 2 * 2)
        return original.convert('RGBA').crop((0, 0, *size)).resize(
            (size[0] // 2, size[1] // 2), Image.Resampling.NEAREST,
        )


def door(draw, x, base):
    y = base - 50
    box(draw, x, y, 22, 50, 'wood_d')
    box(draw, x + 1, y + 1, 18, 49, 'wood_m')
    box(draw, x + 1, y + 1, 18, 2, 'wood_hi')
    box(draw, x + 2, y + 4, 16, 44, 'wood_l')
    for a, b, h in ((4, 7, 16), (4, 29, 15)):
        box(draw, x + a, y + b, 12, h, 'wood_d')
        box(draw, x + a + 1, y + b + 1, 10, h - 2, 'wood_m')
        stroke(draw, 'wood_hi', (x + a + 1, y + b + 1), (x + a + 8, y + b + 1))
        stroke(draw, 'wood_l', (x + a + 2, y + b + 3), (x + a + 2, y + b + h - 4))
    box(draw, x + 15, y + 26, 2, 2, 'gold')
    box(draw, x + 20, y + 3, 2, 47, 'hair')


def scale_board():
    canvas, draw = plate(280, 224)
    base = 115
    canvas.alpha_composite(grid_image('elder'), (6, base - 42))
    door(draw, 47, base)
    canvas.alpha_composite(draw_chair(C), (82, base-23))
    canvas.alpha_composite(draw_table(C), (102, base-18))
    tree_shadow = grid_image('tree_scale_shadow').getchannel('A')
    # Use the approved ground tones on the printed scale board. The independent
    # sprite retains its real contact and cast alpha for runtime integration.
    canvas.paste(color('stone_hi'), (146, base-7, 206, base+3), tree_shadow.point(lambda a: 255 if a else 0))
    canvas.paste(color('stone_d'), (146, base-7, 206, base+3), tree_shadow.point(lambda a: 255 if a==255 else 0))
    canvas.alpha_composite(grid_image('tree_scale'), (146, base - 75))

    car_grid = grid_image('car_mine')
    # Same original 3/4 drawing shown at 1:1; vertical measure is not the parked depth.
    canvas.alpha_composite(car_grid, (210, base - car_grid.height))
    box(draw, 262, base-98, 12, 98, 'roof')
    box(draw, 265, base-95, 7, 95, 'wall_hi')
    stroke(draw, 'wall_l', (268,base-93), (268,base-1))
    stroke(draw, 'wall_d', (272,base-89), (272,base-1))
    label(draw, 7, 6, 'ESTATE SCALE / CANVAS PX')
    stroke(draw, 'stone_d', (5, base), (275, base))
    for x, name, size in ((6,'NPC','H 84'), (42,'DOOR','H100 W43'), (78,'CHAIR','H46 W22'),
                          (111,'TABLE','H36 W86'), (150,'TREE','H150 W120'),
                          (208,'CAR','H 71'), (258,'POST','H 196')):
        label(draw, x, base+5, name)
        label(draw, x, base+13, size)
    label(draw, 7, base+23, 'H HEIGHT / W WIDTH')
    stroke(draw, 'stone_d', (5,149), (275,149))
    label(draw, 7,159,'1 METER ON EACH AXIS')
    for points in (((33,199),(57,199)), ((33,199),(33,175)), ((33,199),(20,208)),
                   ((54,197),(57,199),(54,201)), ((31,178),(33,175),(35,178)),
                   ((21,205),(20,208),(23,208))):
        stroke(draw, 'navy', *points)
    for x, y, t in ((60,197,'X'), (31,167,'Z'), (13,209,'Y'), (74,176,'X WIDTH 48 PX/M'),
                     (74,187,'Z HEIGHT 48 PX/M'), (74,198,'Y DEPTH 32 PX/M'),
                     (176,172,'CAR FOOTPRINT'), (176,183,'86X147 PX'), (176,196,'HEIGHT 71 PX')):
        label(draw, x, y, t)
    canvas.alpha_composite(car_grid.resize((22,37), Image.Resampling.NEAREST), (247,173))
    stroke(draw, 'stone_d', (246,171), (269,171))
    stroke(draw, 'stone_d', (244,173), (244,209))
    export(canvas, '比例尺')


def material_board():
    canvas, draw = plate(278, 248)
    label(draw, 8, 7, 'ESTATE MATERIALS / 64X64 ART PX')
    for i, (file, title) in enumerate(MATERIALS):
        x, y = 8 + i % 3 * 76, 21 + i // 3 * 75
        tile = grid_image(file)
        assert tile.size == (64, 64), (file, tile.size)
        canvas.alpha_composite(tile, (x, y))
        label(draw, x, y + 66, title)
    canvas.alpha_composite(grid_image('photographer_w'), (238, 88))
    label(draw, 238, 135, 'NPC')
    label(draw, 238, 144, 'H 84 PX')
    export(canvas, '材质样')


def palette():
    with Image.open(OUT / '主色板.png') as image:
        approved = {pixel[:3] for pixel in image.convert('RGBA').getdata() if pixel[3]}
    names = (*PEOPLE, '脚影', 'tree_scale', 'tree_scale_shadow', 'car_mine', 'car_mine_shadow', '比例尺', '材质样',
             *(name for name, _ in MATERIALS))
    used = set()
    for name in names:
        with Image.open(OUT / (name + '.png')) as image:
            used.update(pixel[:3] for pixel in image.convert('RGBA').getdata() if pixel[3])
    assert used <= approved, f'Production RGB outside the approved board: {sorted(used-approved)}'
    assert len(approved) == 51, f'The approved 51-color R1 board was changed: {len(approved)}'
    print(f'R1 production artwork: {len(used)} of {len(approved)} approved RGB in use')


def main():
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--compose-only', action='store_true')
    mode.add_argument('--car-only', action='store_true')
    args = parser.parse_args()
    if not args.compose_only:
        export_car(OUT, C)
    if args.car_only:
        return
    if not args.compose_only:
        for script in ('draw_r1_portraits.py', 'draw_r1_tree.py', 'draw_r1_materials.py'):
            subprocess.run([sys.executable, str(Path(__file__).with_name(script))], check=True)
    scale_board()
    material_board()
    palette()


if __name__ == '__main__':
    main()
