"""Original R1 scale furniture drawn directly on the logical pixel grid."""
from PIL import Image, ImageDraw


def draw_table(colors):
    """Return the 43×18 RGBA banquet table, with its hem at row 17."""
    image = Image.new("RGBA", (43, 18))
    draw = ImageDraw.Draw(image)
    c = colors

    # Red skirt. Narrower, darker folds face away from the upper-left light.
    draw.polygon([(0, 8), (42, 8), (41, 13), (38, 15), (33, 16),
                  (26, 17), (15, 17), (8, 16), (3, 14), (1, 12)], fill=c["car_d"])
    for fold in (
        [(2, 10), (6, 11), (7, 15), (4, 14)],
        [(8, 11), (13, 12), (13, 16), (10, 16)],
        [(15, 12), (19, 12), (19, 17), (16, 17)],
        [(25, 12), (30, 11), (29, 16), (25, 17)],
        [(33, 11), (37, 10), (36, 15), (33, 16)],
        [(39, 10), (41, 9), (40, 13), (38, 14)],
    ):
        draw.polygon(fold, fill=c["car_m"])
    draw.line([(4, 11), (5, 13), (5, 14)], fill=c["car_l"])
    draw.line([(10, 12), (11, 14), (11, 15)], fill=c["car_l"])
    draw.line((17, 13, 17, 16), fill=c["car_l"])

    draw.ellipse((0, 1, 42, 12), fill=c["car_d"])
    draw.ellipse((1, 1, 41, 11), fill=c["car_m"])
    draw.arc((1, 1, 40, 11), 185, 290, fill=c["car_l"])

    # A cream runner bends over the front edge and ends at the same hem.
    draw.polygon([(19, 1), (24, 1), (25, 12), (25, 16), (23, 17),
                  (19, 17), (18, 16), (18, 11)], fill=c["wall_m"])
    draw.polygon([(20, 1), (23, 1), (24, 11), (23, 16), (19, 16),
                  (19, 11)], fill=c["wall_hi"])
    draw.line((20, 12, 20, 16), fill=c["gold"])
    draw.line((22, 16, 24, 16), fill=c["wood_l"])

    # Three visible layers per setting: saucer shadow, ivory rim, and plate well.
    for x, y in ((9, 4), (15, 3), (27, 3), (33, 4),
                 (4, 7), (36, 7), (10, 9), (15, 10), (27, 10), (31, 9)):
        draw.ellipse((x, y, x + 4, y + 2), fill=c["wood_d"])
        draw.line((x + 1, y, x + 3, y), fill=c["wall_hi"])
        draw.point((x + 1, y + 1), fill=c["wall_hi"])
        draw.point((x + 2, y + 1), fill=c["wood_hi"])
        draw.point((x + 3, y + 1), fill=c["paper"])
        draw.point((x - 1, y - 1), fill=c["wall_hi"])

    # Centerpiece: gold bowl, foliage and clustered red and cream petals.
    draw.ellipse((17, 6, 25, 8), fill=c["wood_d"])
    draw.line((19, 7, 23, 7), fill=c["gold"])
    draw.polygon([(17, 5), (19, 3), (22, 4), (24, 3), (26, 6),
                  (23, 7), (19, 7)], fill=c["grass_d"])
    for x, y, color in ((18, 5, "car_l"), (19, 3, "wall_hi"),
                        (21, 4, "car_hi"), (23, 3, "car_l"),
                        (24, 5, "wall_hi"), (20, 6, "flower")):
        draw.point((x, y), fill=c[color])
    draw.point((22, 6), fill=c["grass_l"])
    draw.line([(20, 4), (21, 2), (21, 1)], fill=c["grass_l"])
    draw.point((21, 0), fill=c["wall_hi"])
    return image


def draw_chair(colors):
    """Return the 11×23 RGBA chair, with the nearest feet on row 22."""
    image = Image.new("RGBA", (11, 23))
    draw = ImageDraw.Draw(image)
    c = colors

    # Back legs recede toward the upper-left. Front feet share the floor line.
    draw.line((2, 14, 2, 19), fill=c["wood_d"], width=2)
    draw.line((7, 14, 7, 20), fill=c["wood_d"], width=2)
    draw.line((4, 16, 4, 22), fill=c["wood_d"], width=2)
    draw.line((8, 16, 8, 22), fill=c["wood_d"], width=2)
    draw.line((4, 17, 4, 21), fill=c["wood_l"])
    draw.line((5, 19, 8, 19), fill=c["wood_m"])

    # Warm carved crest, open side channels and a red inset.
    draw.polygon([(0, 2), (2, 0), (6, 0), (8, 2), (8, 4), (7, 5),
                  (7, 13), (5, 14), (5, 11), (2, 11), (2, 14), (0, 13)], fill=c["wood_d"])
    draw.line([(0, 3), (2, 1), (5, 1), (7, 2)], fill=c["wood_hi"])
    draw.line((1, 4, 1, 11), fill=c["wood_l"])
    draw.line((6, 5, 6, 11), fill=c["wood_m"])
    draw.rectangle((2, 4, 5, 10), fill=c["car_d"])
    draw.line([(2, 6), (3, 5), (4, 6), (5, 5)], fill=c["gold"])
    draw.line((3, 7, 3, 9), fill=c["wood_hi"])
    draw.point((4, 8), fill=c["car_l"])

    # Seat is offset down-right in the same 3/4 projection as the tabletop.
    draw.polygon([(1, 12), (6, 11), (10, 14), (10, 16), (4, 17), (1, 15)], fill=c["wood_d"])
    draw.polygon([(2, 12), (6, 12), (9, 14), (4, 15), (2, 14)], fill=c["car_m"])
    draw.line([(2, 13), (4, 12), (6, 12)], fill=c["car_l"])
    draw.line((5, 16, 9, 15), fill=c["wood_l"])
    return image
