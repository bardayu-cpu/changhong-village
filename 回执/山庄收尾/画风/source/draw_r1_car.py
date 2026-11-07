"""Hand-placed planes on the 43 × 74 art grid. The parking-space axis stays north."""

from PIL import Image, ImageDraw


def draw_car(colors):
    car = Image.new('RGBA', (43, 74))
    shadow = Image.new('RGBA', car.size)
    d = ImageDraw.Draw(car)
    s = ImageDraw.Draw(shadow)

    def ink(key, alpha=255):
        return (*colors[key], alpha)

    def plane(key, points):
        d.polygon(points, fill=ink(key))

    def edge(key, points, width=1):
        d.line(points, fill=ink(key), width=width)

    # Cast silhouette: warm dark, down and to the right. The two two-row
    # contact clusters sit under the nearer wheels rather than in a slab.
    s.polygon([(10, 10), (29, 9), (37, 15), (42, 28), (42, 67),
               (37, 71), (23, 72), (9, 67), (7, 58), (7, 22)],
              fill=ink('wood_d', 77))
    for x, y, width in [(33, 22, 7), (34, 61, 7), (6, 21, 4), (7, 60, 4)]:
        s.rectangle((x, y, x + width - 1, y + 1), fill=ink('wood_d'))

    # Far tires and underside first; the body then occludes their upper halves.
    plane('navy', [(6, 12), (10, 13), (10, 22), (4, 24), (0, 22), (0, 17), (2, 14)])
    plane('navy', [(7, 49), (10, 49), (11, 59), (7, 62), (3, 60), (3, 53), (5, 50)])
    edge('metal_d', [(2, 17), (2, 21), (5, 22)])
    edge('metal_d', [(4, 53), (4, 59), (7, 60)])
    plane('hair', [(9, 38), (34, 34), (40, 56), (39, 63), (34, 70),
                   (16, 72), (9, 66), (7, 52)])
    # Body shell and southern rear face; the offset roof exposes the right flank.
    plane('car_d', [(12, 0), (24, 0), (31, 4), (35, 11), (37, 22),
                    (38, 45), (39, 55), (39, 63), (35, 68), (28, 71),
                    (15, 71), (8, 67), (5, 60), (5, 49), (6, 29),
                    (6, 12), (8, 5)])
    plane('car_m', [(28, 5), (33, 9), (35, 18), (36, 32), (36, 48),
                    (38, 57), (37, 63), (32, 67), (26, 66), (28, 54)])
    plane('car_l', [(13, 1), (24, 1), (29, 4), (31, 11), (32, 19),
                    (31, 46), (34, 55), (34, 61), (30, 65), (16, 67),
                    (10, 64), (7, 59), (7, 48), (8, 12), (10, 5)])
    plane('car_m', [(18, 61), (33, 58), (37, 60), (35, 65), (28, 69),
                    (15, 69), (9, 65), (8, 62), (13, 65)])
    edge('car_hi', [(8, 53), (8, 31), (9, 12), (12, 5), (15, 3), (23, 3), (26, 4)])
    # Hood left bevel and panel seam.
    plane('car_m', [(13, 13), (25, 11), (28, 12), (29, 16), (26, 18), (12, 20)])
    plane('car_l', [(12, 9), (25, 7), (27, 11), (27, 14), (12, 17)])
    edge('car_hi', [(12, 10), (23, 8), (25, 9)])
    edge('car_d', [(11, 20), (18, 18), (27, 17)])
    plane('metal_hi', [(8, 8), (10, 5), (13, 4), (12, 7), (9, 10)])
    plane('wall_hi', [(25, 3), (28, 4), (30, 7), (29, 9), (27, 6)])
    # Windscreen, passenger side window and roof all sit on different planes.
    plane('navy', [(10, 21), (26, 18), (31, 20), (30, 32), (11, 35), (9, 31)])
    plane('glass_d', [(11, 22), (26, 19), (29, 21), (28, 29), (11, 33), (10, 30)])
    plane('glass_l', [(11, 23), (14, 22), (23, 29), (21, 31), (18, 31)])
    edge('metal_l', [(11, 23), (13, 23), (16, 25), (18, 27)])
    plane('navy', [(28, 31), (33, 23), (35, 24), (36, 45), (34, 52), (28, 53)])
    plane('glass_d', [(33, 27), (34, 25), (35, 39), (34, 43), (31, 44), (31, 36)])
    edge('glass_l', [(33, 31), (34, 34), (34, 36)])
    edge('car_d', [(31, 41), (35, 40)], 2)
    plane('car_d', [(10, 33), (27, 29), (32, 31), (32, 48), (28, 53), (10, 55)])
    plane('car_l', [(11, 34), (27, 31), (30, 33), (30, 46), (27, 49), (11, 52)])
    plane('car_m', [(12, 48), (26, 45), (29, 42), (29, 47), (26, 50), (12, 52)])
    plane('car_hi', [(12, 35), (26, 32), (29, 33), (29, 35), (12, 38)])
    edge('wall_hi', [(13, 35), (19, 34), (23, 34)])
    # Back glass and trunk, then the visible rear apron, inset lights and bumper.
    plane('navy', [(10, 53), (28, 50), (33, 51), (34, 56), (29, 58), (11, 61), (9, 59)])
    plane('glass_d', [(11, 54), (28, 51), (31, 52), (32, 55), (27, 57), (11, 59)])
    edge('glass_l', [(12, 55), (16, 54), (20, 57), (22, 57)], 2)
    # The rear fascia has a broad, distinct vertical plane below the deck edge.
    plane('car_d', [(8, 62), (14, 64), (29, 62), (37, 58), (38, 64),
                    (35, 69), (29, 72), (15, 72), (9, 68)])
    plane('car_m', [(10, 64), (15, 66), (28, 64), (35, 61), (35, 66),
                    (29, 69), (15, 70), (11, 68)])
    edge('car_hi', [(10, 61), (14, 63), (28, 61), (34, 58)])
    edge('car_hi', [(10, 64), (14, 65), (17, 65)], 2)
    edge('car_l', [(29, 64), (33, 62), (35, 61)], 2)
    edge('car_d', [(18, 67), (26, 66), (28, 66)], 2)
    edge('metal_d', [(10, 68), (15, 71), (28, 71), (34, 68)])
    edge('metal_m', [(15, 70), (21, 70), (25, 69)])

    # Near-side tires are readable against the dark flank; both show tread and hubs.
    for x, y in [(34, 15), (35, 53)]:
        plane('navy', [(x+1, y), (x+4, y), (x+6, y+3), (x+6, y+8),
                       (x+3, y+11), (x, y+10), (x-1, y+7), (x-1, y+3)])
        plane('metal_d', [(x+2, y+1), (x+4, y+2), (x+5, y+4), (x+5, y+7),
                          (x+3, y+9), (x+1, y+8), (x, y+5), (x+1, y+2)])
        edge('metal_m', [(x+3, y+3), (x+2, y+4), (x+2, y+7), (x+3, y+7)])
        d.point((x+3, y+5), fill=ink('metal_l'))
    edge('car_hi', [(32, 16), (33, 14), (35, 13)])
    edge('car_m', [(34, 53), (35, 51), (37, 51)])
    # Open passenger door sits above the two wheel wells; its gap reveals a dark seat.
    plane('hair', [(33, 29), (36, 29), (39, 32), (39, 44), (35, 49), (33, 47)])
    edge('cloth_d', [(34, 33), (35, 33), (35, 40), (34, 42)])
    plane('car_d', [(36, 29), (39, 29), (42, 33), (42, 46), (40, 49), (38, 48), (38, 35)])
    plane('car_m', [(39, 33), (41, 34), (41, 45), (40, 47), (39, 46)])
    edge('car_hi', [(37, 30), (39, 31), (41, 33), (41, 37)])
    d.point((40, 41), fill=ink('metal_hi'))

    return car, shadow


def export_car(out, colors):
    for name, part in zip(('car_mine.png', 'car_mine_shadow.png'), draw_car(colors)):
        # The bottom art row is empty; drop only one transparent physical row.
        assert part.getbbox()[3] <= 73
        part.resize((86, 148), Image.Resampling.NEAREST).crop((0, 0, 86, 147)).save(
            out / name, optimize=True
        )
