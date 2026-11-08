"""Original standing figures. All contours are hand-placed on 32 × 42 grids."""

from PIL import Image, ImageDraw
from draw_r1 import C, OUT


class Figure:
    def __init__(self):
        self.im = Image.new('RGBA', (32, 42))
        self.d = ImageDraw.Draw(self.im)

    def poly(self, color, *points):
        self.d.polygon(points, fill=(*C[color], 255))

    def line(self, color, *points, width=1):
        self.d.line(points, fill=(*C[color], 255), width=width)

    def box(self, color, x1, y1, x2, y2):
        self.d.rectangle((x1, y1, x2, y2), fill=(*C[color], 255))

    def dot(self, color, x, y):
        self.d.point((x, y), fill=(*C[color], 255))

    def face(self, x, y, eye_row=9, old=False):
        def plane(color, *points):
            self.poly(color, *((x+px, y+py) for px,py in points))

        # One continuous contour and two broad skin planes; dark pupils are
        # intentionally the only isolated face pixels.
        plane('hair', (2,0),(8,0),(11,2),(13,5),(13,10),(11,13),(8,15),
              (5,15),(2,13),(0,10),(0,5),(1,2))
        plane('skin_m', (3,5),(9,4),(11,6),(12,9),(12,11),(10,13),(8,14),
              (5,14),(2,12),(1,10),(1,7))
        plane('skin_l', (3,5),(8,5),(10,6),(10,9),(9,11),(7,13),(4,12),(2,10),(2,7))
        plane('skin_m', (5,14),(8,14),(9,16),(8,17),(5,17),(4,16))
        self.line('hair', (x+4,y+eye_row), (x+4,y+eye_row+1))
        self.line('hair', (x+9,y+eye_row), (x+9,y+eye_row+1))
        self.line('skin_m', (x+6,y+12),(x+8,y+12))
        if old:
            self.line('hair', (x+3,y+8),(x+5,y+8),(x+6,y+9),(x+7,y+9),
                      (x+8,y+8),(x+10,y+8))

    def feet(self, left, right, boot='hair'):
        a, b = left, right
        self.poly(boot, (a,37),(a+3,37),(a+4,40),(a+3,41),
                  (a-2,41),(a-3,40),(a-2,39))
        self.poly(boot, (b,37),(b+3,37),(b+5,39),(b+5,40),
                  (b+4,41),(b,41),(b-1,40))
        self.line('wood_l', (a-2,39),(a,38),(a+2,38))
        self.line('wood_m', (b,39),(b+2,39),(b+4,40))
        self.line('wood_d', (a-2,41),(a+2,41))
        self.line('wood_d', (b,41),(b+4,41))

    def save(self, name):
        assert self.im.getbbox()[1] == 0 and self.im.getbbox()[3] == 42
        self.im.resize((64,84), Image.Resampling.NEAREST).save(OUT / (name + '.png'), optimize=True)


def photographer():
    f = Figure()
    # Tapered trousers with separate hems.
    f.poly('navy',(9,28),(23,28),(23,34),(21,39),(17,39),(16,34),(14,34),(13,39),(9,39),(8,34))
    f.poly('metal_d',(10,29),(15,30),(14,34),(12,38),(10,38))
    f.line('metal_m',(10,31),(10,34),(11,36))
    f.line('metal_d',(18,31),(19,35),(19,37))
    f.feet(10,18)
    # Olive vest. Left sleeve, bent far arm and low right fold are separate shapes.
    f.poly('green',(10,15),(20,15),(23,17),(24,21),(22,28),(21,32),
           (10,32),(7,30),(8,23),(7,19))
    f.poly('grass_d',(9,17),(15,16),(19,18),(21,22),(19,25),(19,30),(12,31),(8,28))
    f.poly('grass_m',(10,17),(14,17),(15,20),(14,26),(12,30),(9,29),(10,23))
    f.line('grass_l',(10,18),(11,17),(13,17))
    f.line('navy',(18,23),(19,27),(19,30))
    f.poly('grass_l',(10,27),(13,27),(13,29),(11,30),(10,29))
    f.poly('grass_d',(21,17),(24,17),(27,20),(27,23),(25,26),(21,25),(20,22))
    f.poly('skin_d',(25,19),(28,20),(27,24),(25,25),(23,23))
    f.poly('skin_m',(26,19),(28,20),(27,22),(25,23),(24,22))
    f.poly('grass_m',(8,18),(10,18),(11,21),(10,24),(7,25),(5,23),(6,20))
    f.poly('skin_d',(6,23),(9,23),(12,22),(13,23),(12,26),(8,27),(6,26))
    f.poly('skin_l',(7,23),(9,23),(11,22),(12,23),(11,24),(8,25),(7,25))
    f.face(9,0)
    f.poly('hair',(10,3),(12,1),(14,0),(18,0),(21,2),(22,4),
           (21,7),(19,5),(18,4),(16,6),(14,6),(12,8),(10,9))
    f.poly('wood_d',(11,3),(13,1),(17,1),(19,2),(17,3),(14,3),(12,5),(11,5))
    f.line('wood_m',(12,3),(14,2),(16,2))
    f.line('paper',(13,16),(15,17),(17,16))
    f.line('wood_d',(19,16),(20,19),(19,24),(17,29))
    # Viewfinder, lens barrel and grip: silhouette extends beyond elbow.
    f.poly('hair',(12,20),(14,18),(18,18),(19,17),(23,17),(24,19),
           (28,19),(29,20),(29,24),(27,26),(14,26),(12,25))
    f.poly('navy',(13,20),(19,19),(23,19),(25,20),(25,24),(14,25),(13,24))
    f.line('metal_l',(15,19),(18,19),(19,18),(22,18))
    f.box('metal_m',23,20,27,24)
    f.box('glass_d',24,20,27,24)
    f.line('glass_l',(24,21),(25,21),(26,22))
    f.dot('wall_hi',14,21)
    f.line('skin_m',(12,24),(14,24),(15,25))
    f.line('skin_l',(12,24),(13,24))
    f.save('photographer_w')


def elder():
    f = Figure()
    f.poly('navy',(11,30),(21,29),(22,35),(21,39),(18,39),(16,35),(15,35),
           (14,39),(10,39),(9,36))
    f.line('metal_d',(11,31),(11,35),(12,38))
    f.line('metal_m',(11,32),(12,33))
    f.line('metal_d',(19,32),(20,36),(19,38))
    f.feet(11,18)
    f.poly('cloth_d',(10,14),(19,14),(23,16),(25,21),(23,24),(22,31),(20,33),
           (11,33),(8,30),(8,25),(5,23),(6,18))
    f.poly('cloth_m',(10,15),(16,15),(20,16),(21,22),(20,29),(18,32),(11,32),(9,29),(10,23))
    f.poly('cloth_l',(9,17),(13,16),(16,17),(15,20),(11,22),(9,21),(7,22),(7,20))
    f.poly('cloth_hi',(7,19),(10,16),(13,16),(12,18),(9,19),(7,21))
    f.poly('cloth_m',(18,16),(21,16),(24,19),(24,22),(21,24),(20,21))
    f.poly('cloth_l',(10,22),(13,21),(16,21),(14,25),(13,29),(11,30),(10,28))
    f.poly('cloth_d',(20,23),(21,25),(21,28),(19,31),(16,32),(17,29),(18,26))
    f.line('cloth_d',(18,30),(20,29),(21,27))
    f.line('gold',(16,23),(16,24))
    f.poly('skin_d',(8,22),(10,23),(9,27),(7,28),(5,26),(6,24))
    f.line('skin_l',(7,24),(6,26),(7,27))
    f.line('skin_m',(8,24),(8,26),(7,27))
    # Cane curves around the right hand and sits on the same floor line.
    f.line('hair',(23,24),(26,23),(28,24),(28,26),(27,27),(28,40),(27,41),width=2)
    f.line('wood_m',(24,24),(26,24),(27,25),(27,29),(28,40))
    f.line('wood_hi',(25,24),(26,24),(27,25))
    f.poly('skin_d',(22,22),(24,22),(26,23),(26,25),(24,26),(22,25))
    f.line('skin_l',(23,23),(24,23),(25,24))
    f.face(9,0,old=True)
    f.poly('hairgray',(10,3),(11,1),(14,0),(18,0),(21,2),(22,4),(21,7),
           (19,5),(18,4),(15,5),(13,5),(11,7),(10,9))
    f.poly('wall_hi',(11,3),(13,1),(17,1),(19,2),(16,2),(14,3),(12,5),(11,5))
    f.line('wall_d',(20,3),(21,4),(21,6))
    f.line('cloth_hi',(12,16),(14,18),(16,18),(18,16))
    f.dot('gold',16,19)
    f.save('elder')


def farmer():
    f = Figure()
    f.poly('navy',(9,28),(22,28),(23,32),(21,39),(17,39),(16,35),
           (14,35),(13,39),(8,39),(8,33))
    f.poly('blue',(9,29),(14,29),(14,33),(12,38),(9,38))
    f.poly('metal_d',(17,31),(21,30),(21,34),(19,38),(17,38))
    f.line('metal_l',(9,32),(9,35),(10,36))
    f.feet(10,18)
    f.poly('wood_d',(11,11),(17,11),(22,13),(24,17),(22,22),(19,24),
           (16,21),(11,21),(9,17))
    f.line('wood_m',(19,14),(21,16),(21,19))
    f.poly('cloth_d',(9,16),(20,16),(23,18),(25,23),(22,26),(21,29),
           (19,32),(11,32),(8,29),(8,25),(5,24),(5,20))
    f.poly('cloth_m',(9,17),(17,16),(21,18),(21,24),(20,29),(17,31),(10,31),(8,28),(9,23))
    f.poly('cloth_l',(8,18),(12,17),(14,18),(13,21),(11,22),(9,22),(7,24),(6,22),(6,20))
    f.line('cloth_hi',(7,20),(8,18),(10,18))
    f.line('cloth_l',(19,18),(22,19),(23,22))
    f.poly('skin_d',(6,23),(9,24),(9,27),(8,29),(6,28),(5,26))
    f.line('skin_l',(6,24),(6,26),(7,27))
    f.line('skin_m',(8,25),(8,27),(7,28))
    f.poly('skin_d',(22,23),(24,23),(26,24),(26,27),(24,28),(22,27),(21,25))
    f.line('skin_m',(23,24),(24,24),(25,25),(25,26))
    f.line('skin_l',(23,24),(24,24))
    f.line('blue',(11,18),(12,21),(11,26),(11,29),width=2)
    f.line('navy',(19,18),(18,22),(19,25),(19,29),width=2)
    f.poly('blue',(12,23),(17,22),(19,24),(18,28),(14,30),(11,29))
    f.line('metal_m',(12,23),(15,23),(17,22))
    f.poly('navy',(14,25),(17,24),(17,26),(15,28),(13,28),(13,26))
    f.poly('blue',(14,25),(16,25),(15,27),(14,27))
    f.dot('gold',12,22)
    f.dot('gold',18,22)
    f.face(9,0,eye_row=10)
    # Braided side lock and flared straw brim define the silhouette.
    f.poly('hair',(20,8),(22,8),(24,10),(24,14),(23,16),(24,18),(22,19),
           (21,17),(22,14),(20,13))
    f.line('wood_m',(22,10),(23,11),(23,13),(22,14))
    f.poly('wood_d',(5,7),(7,5),(10,4),(12,1),(14,0),(19,0),(22,2),
           (23,4),(26,5),(28,7),(27,9),(22,9),(18,8),(12,10),(7,10),(5,9))
    f.poly('gold',(6,7),(9,6),(12,5),(13,2),(15,1),(19,1),(21,2),
           (22,5),(25,6),(27,7),(25,8),(20,7),(12,9),(7,9))
    f.poly('wood_hi',(12,4),(14,2),(16,1),(19,1),(20,2),(17,3),(15,4))
    f.line('wood_m',(10,5),(15,5),(20,4),(22,5))
    f.line('wall_hi',(7,7),(10,6),(13,6),(15,5))
    f.line('wood_m',(21,7),(23,7),(25,8))
    f.line('cloth_hi',(13,16),(15,18),(17,17))
    f.save('farmer_2')


def foot_shadow():
    fig = Image.new('RGBA', (20, 8))
    draw = ImageDraw.Draw(fig)
    dark = C['wood_d']
    draw.polygon([(1,3),(4,2),(11,2),(16,3),(19,5),(18,6),(9,7),(4,6),(1,5)],
                 fill=(*dark, 77))
    draw.line([(3,2),(7,2),(7,3),(3,3),(3,2)], fill=(*dark, 255))
    draw.line([(11,2),(15,2),(15,3),(11,3),(11,2)], fill=(*dark, 255))
    fig.resize((40,16), Image.Resampling.NEAREST).save(OUT / '脚影.png', optimize=True)


if __name__ == '__main__':
    photographer()
    elder()
    farmer()
    foot_shadow()
