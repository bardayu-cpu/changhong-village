#!/usr/bin/env python3
"""Draw ten original south-facing rear views on a two-pixel art grid."""

import json
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1]
ROOT = OUT.parents[2]
LAYOUT = ROOT / 'godot/assets/layered/scene_luoman_parking/layout.json'
CONFIG = json.loads((OUT / 'source/palette.json').read_text())
PALETTE = {key: tuple(bytes.fromhex(value[1:])) for key, value in CONFIG['semantic'].items()}
APPROVED = {tuple(rgb) for rgb in CONFIG['approved_rgb']}

# Families position six key planes separately. Each model has a nose width,
# cabin width and rear shoulder width relative to the reference draft.
PROFILES = {
    'car_a':      ('compact', (.14,.31,.51,.68,.83), (.86,.94,.97), ('metal_d','metal_m','metal_l','metal_hi')),
    'car_e':      ('suv',     (.11,.24,.49,.65,.79), (1.05,1.05,1.05), ('green','grass_d','grass_m','grass_l')),
    'car_brz':    ('sports',  (.19,.34,.53,.70,.86), (.78,.89,1.04), ('navy','glass_d','blue','glass_l')),
    'car_b':      ('sedan',   (.17,.30,.49,.65,.83), (.88,.91,.98), ('wall_d','wall_m','wall_l','wall_hi')),
    'car_c':      ('suv',     (.11,.24,.45,.64,.78), (1.02,1.05,1.03), ('crack','asphalt_d','asphalt_m','asphalt_hi')),
    'car_h6':     ('suv',     (.10,.22,.46,.63,.77), (1.11,1.10,1.06), ('navy','crack','asphalt_d','metal_m')),
    'car_p911':   ('sports',  (.18,.33,.56,.72,.86), (.72,.86,1.08), ('wall_d','wall_m','wall_hi','metal_hi')),
    'car_d':      ('sedan',   (.15,.30,.51,.70,.85), (.95,.94,.99), ('wood_d','wood_m','wood_hi','wall_hi')),
    'car_bmw240': ('coupe',   (.19,.34,.54,.69,.84), (.89,.90,1.03), ('navy','cloth_d','cloth_m','cloth_l')),
    'car_mine':   ('sedan',   (.15,.29,.49,.68,.82), (.98,1.00,1.00), ('car_d','car_m','car_l','car_hi')),
}

KEY_ROWS = (0, 14, 24, 40, 53, 61, 72)


def draw_body(size, model):
    family, levels, widths, body_colors = PROFILES[model]
    width, height = size
    car = Image.new('RGBA', size)
    draw = ImageDraw.Draw(car)
    target_rows = (0, *(round(level*(height-1)) for level in levels), height-1)
    paint = dict(PALETTE)
    paint.update({k: PALETTE[v] for k,v in zip(('car_d','car_m','car_l','car_hi'), body_colors)})
    paint.update(taillight_hi=PALETTE['car_hi'], taillight=PALETTE['car_l'])

    def point(coord):
        x, y = coord
        for i, boundary in enumerate(KEY_ROWS[1:]):
            if y <= boundary:
                ratio = (y - KEY_ROWS[i]) / (boundary - KEY_ROWS[i])
                actual_y = round(target_rows[i] + ratio*(target_rows[i+1]-target_rows[i]))
                break
        else:
            actual_y = height - 1
        left, cabin, rear = widths
        if y < 24:
            lateral = left + (cabin-left)*y/24
        elif y < 58:
            lateral = cabin + (rear-cabin)*(y-24)/34
        else:
            lateral = rear
        # Keep a whole transparent art pixel around the body. Broader models
        # spread their interior planes without flattening their outer contour.
        cross = (x-21)/21
        if lateral > 1:
            cross += (lateral-1)*cross*(1-abs(cross))
        else:
            cross *= lateral
        actual_x = 1 + round((cross+1)*(width-3)/2)
        return actual_x, actual_y

    def plane(key, points):
        draw.polygon([point(p) for p in points], fill=paint[key])

    def edge(key, points, width=1):
        draw.line([point(p) for p in points], fill=paint[key], width=width)

    # Camera is on the south axis. Widen the near bumper relative to the
    # distant nose and keep both side slivers narrow and almost symmetric.
    plane('navy', [(2, 53), (10, 54), (12, 65), (10, 71), (5, 73), (2, 71), (0, 67), (0, 60)])
    plane('navy', [(33, 54), (40, 53), (42, 57), (42, 67), (40, 72), (35, 73), (32, 70), (31, 63)])
    plane('metal_d', [(1, 61), (7, 61), (9, 66), (8, 71), (5, 72), (2, 70)])
    plane('metal_d', [(35, 62), (40, 60), (41, 66), (39, 71), (35, 72), (33, 69)])
    edge('metal_m', [(1, 66), (2, 69), (4, 71), (6, 71)])
    edge('metal_m', [(34, 69), (36, 71), (38, 70), (40, 67)])
    # The last complete art row is y=72; y=73 is reserved for the anchor.

    plane('car_d', [(12, 0), (28, 0), (33, 3), (36, 10), (38, 21), (39, 36),
                    (41, 49), (41, 61), (38, 68), (33, 71), (10, 71),
                    (5, 68), (1, 62), (1, 53), (3, 37), (4, 20), (7, 9), (8, 4)])
    # Two narrow flank strips. The surface within them is the roof and decks.
    plane('car_m', [(9, 6), (12, 2), (28, 2), (33, 5), (36, 13), (37, 28), (38, 47),
                    (37, 60), (32, 65), (9, 65), (4, 60), (4, 50), (6, 33), (6, 18)])
    plane('car_l', [(10, 7), (13, 3), (28, 3), (32, 6), (34, 13), (35, 30),
                    (37, 46), (36, 57), (31, 62), (10, 62), (6, 58), (6, 48), (8, 28), (8, 16)])
    edge('car_hi', [(6, 52), (7, 36), (8, 20), (9, 11), (12, 5), (17, 4), (24, 4)])
    edge('car_d', [(35, 20), (36, 37), (38, 51), (38, 57)])

    # A thin far hood and front glass beyond the bright roof, away from the camera.
    plane('car_m', [(11, 12), (14, 7), (27, 7), (31, 10), (32, 15), (29, 17), (12, 16)])
    plane('car_l', [(12, 11), (15, 7), (26, 7), (29, 9), (30, 12), (26, 14), (13, 14)])
    edge('car_hi', [(14, 9), (19, 8), (26, 8)])
    plane('navy', [(10, 19), (13, 15), (28, 15), (32, 18), (33, 23), (29, 25), (12, 25), (9, 23)])
    plane('glass_d', [(11, 19), (14, 16), (27, 16), (31, 18), (32, 22), (29, 23), (12, 23), (10, 22)])
    edge('glass_l', [(13, 18), (15, 18), (21, 21)])

    # Roof with restrained, continuous light band; mirrors are short lateral cues.
    plane('car_m', [(12, 23), (29, 23), (32, 26), (33, 35), (31, 41), (11, 41),
                    (8, 37), (9, 27)])
    plane('car_l', [(13, 24), (28, 24), (30, 26), (31, 34), (29, 38),
                    (12, 38), (10, 35), (11, 27)])
    plane('car_hi', [(12, 27), (15, 25), (27, 25), (29, 27), (29, 29), (12, 29)])
    edge('wall_hi', [(14, 26), (21, 26), (24, 27)])
    edge('car_d', [(10, 39), (14, 41), (29, 41), (32, 39)])
    plane('car_d', [(5, 24), (2, 25), (2, 27), (5, 28), (7, 27), (7, 25)])
    plane('car_d', [(36, 24), (39, 25), (40, 27), (38, 28), (35, 27)])
    edge('car_hi', [(3, 25), (5, 25)])

    # Large near rear windshield: two continuous reflections slant across it.
    plane('navy', [(11, 40), (30, 40), (33, 43), (35, 50), (33, 53), (9, 53), (7, 50), (9, 43)])
    plane('glass_d', [(12, 41), (29, 41), (32, 44), (33, 50), (31, 51), (11, 51), (9, 49), (10, 44)])
    plane('glass_l', [(12, 43), (16, 42), (24, 49), (21, 50), (18, 49)])
    edge('metal_l', [(13, 43), (16, 44), (19, 47)])
    edge('glass_l', [(24, 43), (28, 46), (31, 49)])
    edge('car_hi', [(9, 54), (16, 54), (24, 54), (32, 54)])

    # Trunk top ends above a broad south-facing fascia. Lights sit on this
    # face, not on the deck. Both wheels remain visible below the bumper.
    plane('car_l', [(9, 54), (33, 54), (37, 58), (34, 61), (9, 61), (5, 58)])
    edge('car_hi', [(8, 56), (14, 55), (29, 55), (33, 56)])
    plane('car_d', [(4, 58), (8, 60), (33, 60), (38, 57), (40, 61), (38, 66),
                    (34, 70), (8, 70), (4, 67), (2, 63)])
    plane('car_m', [(5, 60), (9, 61), (32, 61), (37, 59), (38, 62), (36, 65),
                    (32, 67), (9, 67), (5, 66), (4, 63)])
    for x in (6, 29):
        plane('hair', [(x, 61), (x+7, 61), (x+8, 63), (x+6, 65), (x, 65)])
        edge('taillight_hi', [(x+1, 62), (x+6, 62), (x+7, 63)])
        edge('taillight', [(x+1, 64), (x+5, 64)])
    plane('metal_d', [(4, 65), (9, 67), (33, 67), (38, 65), (37, 68),
                     (33, 70), (9, 70), (6, 68)])
    edge('metal_m', [(7, 67), (10, 68), (26, 68), (34, 67)])
    edge('metal_l', [(11, 68), (18, 68)])
    edge('hair', [(11, 70), (31, 70)])
    edge('navy', [(2, 72), (6, 72)])
    edge('navy', [(36, 72), (40, 72)])


    if family == 'suv':
        # High hatch glass and vertically stacked rear lamps.
        plane('navy', [(9,43),(33,43),(35,49),(34,53),(8,53),(7,49)])
        plane('glass_d', [(11,44),(31,44),(33,49),(32,51),(10,51),(9,49)])
        edge('glass_l', [(12,45),(15,45),(21,49),(22,50)])
        for x in (7, 34):
            edge('taillight_hi', [(x,60),(x,63),(x,65)], 2)
        edge('metal_m', [(7,69),(14,70),(28,70),(35,69)])
    elif family == 'sports':
        # Low roof, rear-window sweep and a low, full-width light bar.
        edge('taillight', [(8,64),(15,65),(27,65),(34,64)])
        edge('metal_d', [(11,69),(19,70),(23,70),(31,69)])
        edge('metal_l', [(10,70),(13,70)])
        edge('metal_l', [(29,70),(32,70)])
    elif family == 'coupe':
        edge('taillight_hi', [(7,62),(12,62),(14,64)])
        edge('taillight', [(35,62),(31,62),(28,64)])
        edge('glass_l', [(13,45),(18,46),(24,49)])
    return car


def draw_shadow(size):
    width, depth = size
    image = Image.new('RGBA', size)
    draw = ImageDraw.Draw(image)
    warm_dark = PALETTE['wood_d']
    draw.polygon([(1,6),(width-5,1),(width-1,depth//5),
                  (width-1,depth-4),(width-8,depth-1),(9,depth-3),(1,depth-10)],
                 fill=(*warm_dark,77))
    for x in (3,width-12):
        draw.rectangle((x,depth-8,x+7,depth-7),fill=(*warm_dark,255))
    return image


def export_grid(image, exact_size, path):
    result = image.resize((image.width*2,image.height*2),Image.Resampling.NEAREST).crop(
        (0,0,*exact_size))
    assert {px[:3] for px in result.getdata() if px[3]} <= APPROVED, path
    result.save(path,optimize=True)
    return result


def make_sheet(records, bodies):
    columns, column_width = 5, 202
    row_heights = {1: 266, 2: 505}
    sheet = Image.new('RGBA',(columns*column_width+24,1610), (226,223,204,255))
    draw = ImageDraw.Draw(sheet)
    ink = (57,69,74,255)
    y = 14
    for scale in (1,2):
        draw.text((15,y), f'{scale}X / SOUTH REAR VIEW - NORTH-FACING PARKING', fill=ink)
        y += 18
        for i, (record, original) in enumerate(zip(records,bodies)):
            x = 12+(i%columns)*column_width
            row = y+(i//columns)*row_heights[scale]
            w,h = original.size
            draw.text((x+3,row), f"{record['id']} / {record['family']} {w}X{h}",fill=ink)
            sprite = original if scale==1 else original.resize((w*2,h*2),Image.Resampling.NEAREST)
            assert sprite.width < column_width and sprite.height < row_heights[scale]-21
            sheet.alpha_composite(sprite,(x+(column_width-sprite.width)//2,row+18))
        y += 2*row_heights[scale]+6
    sheet.convert('RGB').save(OUT/'十车原尺寸与2倍对照.png',optimize=True)


def main():
    layout=json.loads(LAYOUT.read_text())
    records,bodies=[],[]
    for item in layout['items']:
        model=item['id']
        if model not in PROFILES:
            continue
        x0,y0,x1,foot=item['rect']
        height=item['h']
        width,depth=x1-x0,foot-y0
        envelope=(width,depth+height)
        w,h=((n+1)//2 for n in envelope)
        body=export_grid(draw_body((w,h),model),envelope,OUT/(model+'.png'))
        left, top, right, bottom = body.getbbox()
        assert left >= 2 and right <= envelope[0]-1, model
        assert top <= 2 and bottom >= envelope[1]-2, model
        shadow_size=(width+6,depth+8)
        shadow_grid=tuple((n+1)//2 for n in shadow_size)
        export_grid(draw_shadow(shadow_grid),shadow_size,OUT/(model+'_shadow.png'))
        records.append(dict(id=model,label=item.get('scale', {}).get('name', model),family=PROFILES[model][0],
                            rect=item['rect'],h=height,x=x0,y=y0-height,foot=foot,
                            png=model+'.png',png_size=list(envelope),alpha_bbox=list(body.getbbox()),
                            shadow=model+'_shadow.png',shadow_at=[x0,y0],shadow_size=list(shadow_size)))
        bodies.append(body)
    assert len(records)==10 and set(PROFILES)=={p['id'] for p in records}
    (OUT/'逐车定位.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
    make_sheet(records,bodies)


if __name__=='__main__':
    main()
