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

    # Camera is on the south axis. Widen the near bumper relative to the
    # distant nose and keep both side slivers narrow and almost symmetric.
    plane('navy', [(2, 53), (10, 54), (12, 65), (10, 71), (5, 73), (2, 71), (0, 67), (0, 60)])
    plane('navy', [(33, 54), (40, 53), (42, 57), (42, 67), (40, 72), (35, 73), (32, 70), (31, 63)])
    plane('metal_d', [(1, 61), (7, 61), (9, 66), (8, 71), (5, 72), (2, 70)])
    plane('metal_d', [(35, 62), (40, 60), (41, 66), (39, 71), (35, 72), (33, 69)])
    edge('metal_m', [(1, 66), (2, 69), (4, 71), (6, 71)])
    edge('metal_m', [(34, 69), (36, 71), (38, 70), (40, 67)])
    # The last complete art row is y=72; y=73 is reserved for the anchor.
    d.line([(0, 73), (42, 73)], fill=(0, 0, 0, 0))

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
        edge('car_hi', [(x+1, 62), (x+6, 62), (x+7, 63)])
        edge('car_l', [(x+1, 64), (x+5, 64)])
    plane('metal_d', [(4, 65), (9, 67), (33, 67), (38, 65), (37, 68),
                     (33, 70), (9, 70), (6, 68)])
    edge('metal_m', [(7, 67), (10, 68), (26, 68), (34, 67)])
    edge('metal_l', [(11, 68), (18, 68)])
    edge('hair', [(11, 70), (31, 70)])
    edge('navy', [(2, 72), (6, 72)])
    edge('navy', [(36, 72), (40, 72)])

    return car, shadow


def export_car(out, colors):
    for name, part in zip(('car_mine.png', 'car_mine_shadow.png'), draw_car(colors)):
        # The bottom art row is empty; drop only one transparent physical row.
        assert part.getbbox()[3] <= 73
        part.resize((86, 148), Image.Resampling.NEAREST).crop((0, 0, 86, 147)).save(
            out / name, optimize=True
        )
