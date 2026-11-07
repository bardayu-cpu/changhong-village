"""Draw the R1 scale tree as original 60x75 art pixels, exported at 2x."""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1]
P = {
    'leaf_d':'#536d4e', 'leaf_m':'#72885b', 'leaf_l':'#93a36b',
    'leaf_hi':'#c0b779', 'bark_d':'#62473d', 'bark_m':'#896046',
    'bark_l':'#b37b4e', 'bark_hi':'#d9a96c',
}
C = {k: tuple(bytes.fromhex(v[1:])) + (255,) for k,v in P.items()}
im=Image.new('RGBA',(60,75),(0,0,0,0)); d=ImageDraw.Draw(im)
def poly(points,c): d.polygon(points,fill=C[c])
def ellipse(box,c): d.ellipse(box,fill=C[c])
# Tapered trunk and branching limbs, kept readable through the crown.
poly([(24,74),(25,45),(22,34),(24,32),(31,44),(35,74),(35,75),(24,75)],'bark_d')
poly([(27,74),(28,46),(24,35),(25,34),(30,46),(32,74)],'bark_m')
# Two small branch windows remain visible between foliage clusters.
poly([(17,30),(20,31),(23,35),(21,34)],'bark_l')
poly([(39,30),(42,29),(44,27),(43,31)],'bark_l')
poly([(30,47),(39,33),(42,31),(41,34),(32,50)],'bark_d')
poly([(27,45),(18,34),(16,31),(19,33),(29,45)],'bark_d')
# Overlapping clustered foliage masses, dark lower/right edges and warm upper-left caps.
clusters=[((3,17,26,39),'leaf_d'),((14,7,40,31),'leaf_m'),((32,13,57,37),'leaf_d'),((10,26,35,49),'leaf_d'),((29,26,51,48),'leaf_m'),((19,0,36,20),'leaf_d'),((1,22,17,35),'leaf_m'),((44,20,59,35),'leaf_m')]
for b,c in clusters: ellipse(b,c)
# Faceted inner leaves; warm light comes from upper left.
for points,c in [
 ([(11,22),(15,14),(21,12),(23,17),(19,20),(18,25)],'leaf_hi'),
 ([(22,10),(27,6),(33,8),(34,13),(29,15),(25,14)],'leaf_hi'),
 ([(34,18),(39,14),(45,17),(44,22),(39,24)],'leaf_l'),
 ([(9,29),(13,24),(18,25),(18,31),(14,34)],'leaf_l'),
 ([(23,24),(28,19),(34,21),(33,27),(28,29)],'leaf_l'),
 ([(37,29),(42,25),(47,28),(45,34),(40,35)],'leaf_d'),
 ([(18,36),(23,32),(27,34),(26,39),(22,41)],'leaf_d'),
 ([(30,37),(35,33),(40,35),(39,40),(34,42)],'leaf_d')]: poly(points,c)
# Small stepped silhouettes break the oval edges into readable foliage tiers.
for pts,c in [([(4,20),(8,20),(8,17),(13,17),(13,22),(8,22),(8,25),(4,25)],'leaf_l'), ([(47,17),(51,17),(51,14),(55,14),(55,19),(59,19),(59,25),(54,25),(54,22),(47,22)],'leaf_m'), ([(16,5),(20,5),(20,2),(25,2),(25,7),(21,7),(21,10),(16,10)],'leaf_l')]: poly(pts,c)
# Pixel-like glints grouped as leaf clusters, not scattered noise.
for b,c in [((14,18,17,20),'leaf_hi'),((26,11,29,13),'leaf_hi'),((38,19,41,21),'leaf_hi'),((21,27,23,29),'leaf_hi'),((31,24,34,26),'leaf_hi'),((45,29,47,31),'leaf_l')]: d.rectangle(b,fill=C[c])
# Root tip touches art row 74 (PNG row 148); extend one centered foot pixel to art row 74-1?
# Use a single art-pixel root toe on row 74 so the 2x export ends at y=149.
d.rectangle((29,74,29,74),fill=C['bark_l'])
im.resize((120,150),Image.Resampling.NEAREST).save(OUT/'tree_scale.png',optimize=True)
