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
# Short trunk below the low leaf clusters; the root flare reaches the floor.
poly([(23,74),(26,70),(27,49),(24,39),(29,39),(33,50),(35,69),
      (38,72),(43,74),(36,74),(33,73),(29,74)], 'bark_d')
poly([(26,73),(28,69),(29,51),(27,44),(30,45),(32,57),(32,69),
      (34,72),(32,73),(30,72)], 'bark_m')
poly([(27,72),(29,68),(29,62),(30,62),(31,69),(30,72)], 'bark_l')
d.line([(33,62),(33,67),(34,70),(36,72)], fill=C['bark_d'])
d.line([(27,73),(29,71),(29,69)], fill=C['bark_hi'])
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
# Lower boughs hide the upper trunk; keep a dark notch between the clusters.
poly([(13,43),(20,42),(26,46),(28,50),(27,55),(23,58),(17,58),
      (12,56),(10,51),(11,46)], 'leaf_d')
poly([(11,48),(15,45),(20,45),(23,48),(22,51),(18,53),(13,52)], 'leaf_m')
poly([(12,48),(15,46),(18,46),(19,48),(16,49),(13,49)], 'leaf_l')
poly([(23,47),(29,44),(37,46),(42,50),(43,55),(40,59),(35,61),
      (29,60),(25,57),(22,53)], 'leaf_d')
poly([(24,50),(29,47),(34,48),(38,51),(38,54),(34,56),(28,55)], 'leaf_m')
poly([(25,51),(29,48),(32,48),(33,50),(30,52),(26,52)], 'leaf_l')
poly([(38,43),(45,42),(51,44),(54,48),(53,52),(50,55),(44,56),
      (40,54),(38,51)], 'leaf_d')
poly([(40,46),(45,44),(49,46),(50,49),(46,50),(41,49)], 'leaf_m')
im.resize((120,150),Image.Resampling.NEAREST).save(OUT/'tree_scale.png',optimize=True)

shadow = Image.new('RGBA',(60,10),(0,0,0,0))
sd = ImageDraw.Draw(shadow)
sd.polygon([(11,4),(17,2),(29,1),(37,2),(47,3),(55,5),(59,7),
            (54,9),(40,9),(32,8),(22,8),(14,7),(9,6)], fill=(*C['bark_d'][:3],77))
sd.polygon([(25,5),(29,4),(34,4),(38,5),(39,6),(32,7),(26,6)], fill=C['bark_d'])
shadow.resize((120,20),Image.Resampling.NEAREST).save(OUT/'tree_scale_shadow.png',optimize=True)
