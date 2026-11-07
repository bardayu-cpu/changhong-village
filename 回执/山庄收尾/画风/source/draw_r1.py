from PIL import Image, ImageDraw
from pathlib import Path
import math
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
def cv(k): return C[k] if k in C else tuple(bytes.fromhex(k[1:]))
def new(w,h,bg=None):
 im=Image.new('RGBA',(w,h),(0,0,0,0) if bg is None else (*cv(bg),255));return im,ImageDraw.Draw(im)
def r(d,xy,c): d.rectangle(xy, fill=(*cv(c),255))
def export(im,n): im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST).save(OUT/(n+'.png'),optimize=True)
# Independent hand-built tiles (16x16 art grid -> exact 32x32 canvas px).
def tile(name,base,marks):
 im,d=new(16,16,base)
 for x,y,w,h,c in marks:r(d,(x,y,x+w-1,y+h-1),c)
 export(im,name)
tile('草地','grass_d',[(1,2,4,1,'grass_m'),(2,3,3,1,'grass_l'),(7,1,3,1,'grass_m'),(8,2,2,1,'grass_l'),(12,5,3,1,'grass_m'),(12,6,2,1,'grass_l'),(4,9,2,1,'grass_m'),(5,10,2,1,'grass_l'),(10,12,3,1,'grass_m'),(10,13,2,1,'grass_l'),(14,1,1,1,'flower'),(14,2,1,1,'grass_hi')])
tile('柏油','asphalt_d',[(0,0,16,3,'asphalt_m'),(0,0,6,1,'asphalt_l'),(2,3,2,1,'asphalt_hi'),(11,4,2,1,'asphalt_l'),(6,11,3,1,'crack'),(7,10,1,1,'crack'),(13,13,2,1,'asphalt_m'),(1,14,1,1,'asphalt_hi')])
tile('石板','stone_m',[(0,0,7,1,'stone_l'),(0,1,1,6,'stone_l'),(7,0,1,7,'stone_d'),(1,7,6,1,'stone_d'),(8,1,7,1,'stone_l'),(8,2,1,5,'stone_hi'),(9,8,7,1,'stone_d'),(3,10,1,2,'grass_m'),(12,11,2,1,'stone_hi')])
tile('木头','wood_m',[(0,0,16,1,'wood_hi'),(0,7,16,1,'wood_d'),(1,2,4,1,'wood_l'),(10,4,3,1,'wood_d'),(12,5,2,1,'wood_l'),(0,14,16,1,'wood_d'),(6,9,3,1,'wood_hi')])
tile('白墙灰瓦','wall_l',[(0,0,16,3,'roof'),(0,2,16,1,'wall_d'),(2,5,2,1,'wall_m'),(12,10,2,1,'wall_m'),(0,14,16,2,'wall_m'),(5,4,1,3,'wall_hi')])
tile('水','water_d',[(0,0,16,2,'water_m'),(1,2,5,1,'water_l'),(2,2,3,1,'water_hi'),(9,6,4,1,'water_l'),(10,6,2,1,'water_hi'),(4,12,6,1,'water_m'),(5,12,3,1,'water_hi'),(13,1,2,1,'water_l')])
tile('车漆','car_m',[(1,1,12,3,'car_l'),(2,1,8,1,'car_hi'),(2,5,10,1,'car_d'),(4,8,6,1,'glass_d'),(5,8,4,1,'glass_l'),(1,13,12,2,'car_d'),(2,14,8,1,'car_hi')])
tile('布','cloth_m',[(2,1,3,12,'cloth_l'),(5,2,2,10,'cloth_hi'),(8,1,2,12,'cloth_d'),(11,2,2,11,'cloth_l'),(1,14,13,1,'cloth_d')])
tile('金属玻璃','metal_m',[(1,1,12,1,'metal_hi'),(2,2,2,9,'metal_l'),(5,3,5,1,'metal_d'),(6,4,4,5,'metal_l'),(7,5,2,2,'metal_hi'),(12,2,1,10,'metal_d'),(1,13,12,1,'metal_d')])
# transparent material plate: all nine swatches are shown separately; name/order in README.
im,d=new(180,58)
for i,n in enumerate(['草地','柏油','石板','木头','白墙灰瓦','水','车漆','布','金属玻璃']):
 t=Image.open(OUT/(n+'.png')).convert('RGBA');im.alpha_composite(t,(i*32,0))
# People: 32x42 grid, exact body silhouette from y=0 through y=41 (84 px exported).
def person(name,shirt,hair='hair',glasses=False,straps=False,longhair=False):
 im,d=new(32,42)
# body top row zero; 3-head proportion, feet occupy final row
 r(d,(13,0,18,1),hair);r(d,(10,2,21,8),hair);r(d,(11,5,20,13),'skin_m')
 if longhair:r(d,(10,9,11,19),hair);r(d,(20,9,21,19),hair)
 r(d,(13,9,14,10),hair);r(d,(18,9,19,10),hair);r(d,(15,12,17,12),'skin_d')
 if glasses:r(d,(12,9,15,9),'metal_hi');r(d,(17,9,20,9),'metal_hi');r(d,(15,9,17,9),'metal_d')
 r(d,(14,14,18,16),'skin_m')
 r(d,(8,17,23,29),shirt);r(d,(6,19,9,27),shirt);r(d,(22,19,25,27),shirt)
 if straps:r(d,(10,18,12,28),'gold');r(d,(20,18,22,28),'gold')
 r(d,(14,18,16,28),'cloth_hi')
 r(d,(11,29,14,37),'navy');r(d,(17,29,20,37),'navy')
 r(d,(9,38,15,41),'metal_d');r(d,(16,38,22,41),'metal_d')
 export(im,name)
 return im
person('photographer_w','green',straps=True)
elder_grid=person('elder','cloth_m',hair='hairgray',glasses=True)
person('farmer_2','cloth_l',straps=True,longhair=True)
# Separate shared foot-shadow component: exactly 2 art px contact + ~30% cast alpha.
sh=Image.new('RGBA',(20,8),(0,0,0,0));sd=ImageDraw.Draw(sh)
sd.rectangle((1,1,5,3),fill=(*C['shadow'],255));sd.rectangle((12,1,16,3),fill=(*C['shadow'],255));sd.rectangle((8,3,18,6),fill=(*C['shadow'],77))
sh.resize((40,16),Image.Resampling.NEAREST).save(OUT/'脚影.png')
# Car top-view body is hand-painted on a 43x74 2px grid, four distinct wheels and open right door.
im,d=new(43,74)
# Exactly four tires: front pair and rear pair, two per side.
for x,y in [(0,14),(39,14),(0,54),(39,54)]:r(d,(x,y,x+3,y+7),'metal_d')
# warm-lit red body outline fills the locked 86x147 footprint, nose north
r(d,(3,0,39,72),'car_d');r(d,(4,0,38,70),'car_m');r(d,(5,1,37,67),'car_l')
r(d,(7,1,34,6),'car_hi');r(d,(5,8,36,20),'car_l')
# windscreen, passenger cabin, rear window
r(d,(6,21,36,34),'glass_d');r(d,(8,22,34,25),'glass_l');r(d,(7,35,35,49),'car_m')
r(d,(7,50,35,59),'glass_d');r(d,(9,51,33,52),'glass_l');r(d,(5,60,37,67),'car_l')
r(d,(5,4,7,56),'car_hi');r(d,(36,4,38,61),'car_d')
# lamps, bumpers, mirrors; avoid logos and text
r(d,(5,0,14,2),'metal_hi');r(d,(29,0,37,2),'metal_hi');r(d,(5,68,14,70),'gold');r(d,(29,68,37,70),'gold')
r(d,(3,71,39,72),'metal_d');r(d,(2,18,3,20),'metal_l');r(d,(39,18,40,20),'metal_d')
# right front door swung open, clearly separated from body
r(d,(35,29,42,43),'car_d');r(d,(41,30,42,41),'car_hi');r(d,(36,31,39,39),'car_m')
# 86x148 container = 43x74 art grid. Odd locked footprint is 86x147; final row is transparent anchor allowance.
big=im.resize((86,148),Image.Resampling.NEAREST); big.crop((0,0,86,147)).save(OUT/'car_mine.png')
# Car's soft cast shadow is a separate 30%-alpha component, cast down/right.
csh=Image.new('RGBA',(43,74),(0,0,0,0));cd=ImageDraw.Draw(csh)
cd.rectangle((5,5,42,72),fill=(*C['shadow'],77))
csh.resize((86,148),Image.Resampling.NEAREST).crop((0,0,86,147)).save(OUT/'car_mine_shadow.png')
# Compose scale board on half-resolution art grid, then nearest-neighbor enlarge 2x.
S=Image.new('RGBA',(280,224),(*C['paper'],255));D=ImageDraw.Draw(S);base=115
S.alpha_composite(elder_grid,(6,base-42))
# Door ~44x100; table 86x36; chair 22x46; tree 120x150; car height ~72.
def R(x,y,w,h,c):D.rectangle((x,y,x+w-1,y+h-1),fill=(*C[c],255))
R(47,base-50,22,50,'wood_d');R(49,base-48,18,48,'wood_l');R(63,base-26,2,2,'gold')
R(82,base-23,11,2,'wood_d');R(83,base-21,9,10,'wood_m');R(84,base-11,7,10,'wood_d');R(83,base-2,9,2,'wood_l')
D.ellipse((102,base-18,144,base-9),fill=(*C['stone_l'],255),outline=(*C['stone_d'],255),width=1);R(106,base-10,35,8,'wood_m')
R(163,base-31,8,31,'wood_d');D.ellipse((138,base-75,197,base-21),fill=(*C['grass_m'],255),outline=(*C['grass_d'],255),width=2);D.ellipse((146,base-71,187,base-41),fill=(*C['grass_l'],255))
D.polygon([(210,base-7),(210,base-18),(218,base-22),(225,base-36),
           (241,base-36),(248,base-22),(252,base-19),(252,base-7)],fill=(*C['car_d'],255))
R(212,base-19,39,8,'car_m');R(218,base-21,30,3,'car_hi')
D.polygon([(221,base-23),(227,base-33),(239,base-33),(245,base-23)],fill=(*C['glass_d'],255))
R(228,base-32,10,2,'glass_l');R(234,base-33,2,11,'car_d')
for wheel in (216,239):
 D.ellipse((wheel,base-11,wheel+10,base-1),fill=(*C['navy'],255))
 D.ellipse((wheel+3,base-8,wheel+7,base-4),fill=(*C['metal_l'],255))
R(262,base-98,12,98,'roof');R(265,base-95,7,95,'wall_hi')
# Original 3x5 bitmap glyphs keep annotations on the same art grid as the figures.
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
ink = (*C['navy'],255)
guide = (*C['stone_d'],255)

def label(x, y, value):
 for index, char in enumerate(value):
  for row, bits in enumerate(GLYPHS[char]):
   for col in range(3):
    if bits & (4 >> col):
     D.point((x+4*index+col,y+row),fill=ink)

label(7,6,'ESTATE SCALE / CANVAS PX')
D.line((5,base,275,base),fill=guide)
for x,name,size in [(6,'NPC','H 84'),(43,'DOOR','100X43'),(77,'CHAIR','46X22'),
                    (109,'TABLE','36X86'),(151,'TREE','150X120'),
                    (208,'CAR','H 71'),(258,'POST','H 196')]:
 label(x,base+5,name)
 label(x,base+13,size)
label(7,base+23,'SIZES H X W')
D.line((5,149,275,149),fill=guide)

label(7,159,'1 METER ON EACH AXIS')
origin = (33,199)
D.line((origin,(57,199)),fill=ink)
D.line((origin,(33,175)),fill=ink)
D.line((origin,(20,208)),fill=ink)
D.line(((54,197),(57,199),(54,201)),fill=ink)
D.line(((31,178),(33,175),(35,178)),fill=ink)
D.line(((21,205),(20,208),(23,208)),fill=ink)
label(60,197,'X')
label(31,167,'Z')
label(13,209,'Y')
label(74,176,'X WIDTH 48 PX/M')
label(74,187,'Z HEIGHT 48 PX/M')
label(74,198,'Y DEPTH 32 PX/M')

car_grid = Image.open(OUT/'car_mine.png').crop((0,0,86,146)).resize((43,73),Image.Resampling.NEAREST)
# Half-height reference thumbnail. The full 86x147 part remains independent.
thumbnail = car_grid.resize((22,37),Image.Resampling.NEAREST)
S.alpha_composite(thumbnail,(247,173))
label(176,172,'CAR FOOTPRINT')
label(176,183,'86X147 PX')
label(176,196,'HEIGHT 71 PX')
D.line((246,171,269,171),fill=guide)
D.line((244,173,244,209),fill=guide)
export(S,'比例尺')
# Contact sheet previews for materials also include the actual 84px person as scale.
sample=Image.new('RGBA',(360,92),(0,0,0,0))
for i,n in enumerate(['草地','柏油','石板','木头','白墙灰瓦','水','车漆','布','金属玻璃']):
 sample.alpha_composite(Image.open(OUT/(n+'.png')).convert('RGBA'),(i*32,56))
sample.alpha_composite(Image.open(OUT/'photographer_w.png').convert('RGBA'),(292,8))
sample.save(OUT/'材质样.png')
# 2x2 art output and palette audit (palette chips are exactly all visible RGBs in deliverable art).
assets=[f for f in OUT.glob('*.png') if f.name!='主色板.png']
used=set()
for f in assets:
 im=Image.open(f).convert('RGBA')
 used.update(px[:3] for px in im.getdata() if px[3]>0)
assert len(used)<=64, f'palette over 64: {len(used)}'
known=set(C.values())
missing=used-known
assert not missing, f'visible colors absent from palette: {missing}'
# write palette from actual used colors; transparent background so no extra untracked color.
colors=sorted(used); sw=Image.new('RGBA',(16*8,math.ceil(len(colors)/8)*16),(0,0,0,0));sd=ImageDraw.Draw(sw)
for i,col in enumerate(colors):
 x=(i%8)*16;y=(i//8)*16;sd.rectangle((x,y,x+15,y+15),fill=(*col,255))
sw.resize((sw.width*2,sw.height*2),Image.Resampling.NEAREST).save(OUT/'主色板.png')
assert len(colors)==len(used)
