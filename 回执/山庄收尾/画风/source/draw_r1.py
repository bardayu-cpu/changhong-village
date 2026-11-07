from PIL import Image, ImageDraw
from pathlib import Path
import json, math
OUT=Path(__file__).resolve().parents[1]
# Hand-authored 2x2 art-grid swatches. All marks are integer blocks on the art grid.
P={
'grass0':'#668454','grass1':'#809963','grass2':'#a4aa70','flower':'#e5c879',
'asphalt0':'#555d60','asphalt1':'#697174','asphalt2':'#89908a','crack':'#424c50',
'stone0':'#777779','stone1':'#92918b','stone2':'#b4aa96','stone3':'#d2c39e',
'wood0':'#694b3d','wood1':'#8a6247','wood2':'#b47d50','wood3':'#d5a76b',
'wall0':'#777b82','wall1':'#a3a39a','wall2':'#d6d0bd','wall3':'#efe1be','roof':'#536173',
'water0':'#39717a','water1':'#4c9290','water2':'#78b2a1','water3':'#bad5b1',
'car0':'#293a4b','car1':'#47718a','car2':'#77a0ac','glass':'#35566b','shine':'#d7e1d0',
'cloth0':'#754e57','cloth1':'#a36468','cloth2':'#cd8d83','cloth3':'#e9bca0',
'metal0':'#505b66','metal1':'#7b8990','metal2':'#b2bdb5','metal3':'#e2dfcc',
'skin0':'#a96850','skin1':'#d08d68','skin2':'#e8b78b','hair':'#443633','cream':'#eee0bd',
'navy':'#394556','green':'#48654c','red':'#a65148','blue':'#587d9d','purple':'#735777'
}
def canvas(w,h,bg=None):
 im=Image.new('RGBA',(w,h),bg or (0,0,0,0)); return im,ImageDraw.Draw(im)
def rect(d,xy,c): d.rectangle(xy,fill=P.get(c,c))
def export(im,name): im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST).save(OUT/(name+'.png'),optimize=True)
# palette swatch
im,d=canvas(16*8,math.ceil(len(P)/8)*10,'#ece5d3')
for i,(n,c) in enumerate(P.items()):
 x=(i%8)*16;y=(i//8)*10; rect(d,(x,y,x+12,y+7),c)
export(im,'主色板')
# tiles: each hand-authored 16x16 art pixels, exported 32x32 canvas px
# scatter cluster motifs arranged deliberately, no procedural noise.
def tile(name,base, marks):
 im,d=canvas(16,16,P[base]);
 for x,y,w,h,c in marks: rect(d,(x,y,x+w-1,y+h-1),c)
 export(im,name)
tile('草地',( 'grass0'),[(1,2,3,1,'grass1'),(2,3,2,1,'grass2'),(7,1,2,1,'grass1'),(8,2,2,1,'grass2'),(12,5,3,1,'grass1'),(12,6,2,1,'grass2'),(4,9,2,1,'grass1'),(5,10,2,1,'grass2'),(10,12,3,1,'grass1'),(10,13,2,1,'grass2'),(14,1,1,1,'flower')])
tile('柏油', 'asphalt0',[(2,3,2,1,'asphalt1'),(3,3,1,1,'asphalt2'),(12,2,1,1,'asphalt1'),(6,11,3,1,'crack'),(7,10,1,1,'crack'),(13,13,2,1,'asphalt1'),(1,14,1,1,'asphalt2')])
tile('石板', 'stone1',[(0,0,7,1,'stone2'),(0,1,1,6,'stone2'),(7,0,1,7,'stone0'),(1,7,6,1,'stone0'),(8,1,7,1,'stone2'),(8,2,1,5,'stone2'),(9,8,7,1,'stone0'),(3,10,1,2,'grass1')])
tile('木头','wood1',[(0,0,16,1,'wood3'),(0,7,16,1,'wood0'),(1,2,4,1,'wood2'),(10,4,3,1,'wood0'),(12,5,2,1,'wood2'),(0,14,16,1,'wood0'),(6,9,3,1,'wood3')])
tile('白墙灰瓦','wall2',[(0,0,16,3,'roof'),(0,2,16,1,'wall0'),(2,5,2,1,'wall1'),(12,10,2,1,'wall1'),(0,14,16,2,'wall1'),(5,4,1,3,'wall3')])
tile('水','water0',[(1,2,5,1,'water1'),(2,2,3,1,'water3'),(9,6,4,1,'water1'),(10,6,2,1,'water3'),(4,12,6,1,'water2'),(5,12,3,1,'water3'),(13,1,2,1,'water2')])
tile('车漆','car1',[(1,1,12,3,'car2'),(2,1,8,1,'shine'),(2,5,10,1,'car0'),(4,8,6,1,'glass'),(5,8,4,1,'shine'),(1,13,12,2,'metal0')])
tile('布','cloth1',[(2,1,3,12,'cloth2'),(5,2,2,10,'cloth3'),(8,1,2,12,'cloth0'),(11,2,2,11,'cloth2'),(1,14,13,1,'cloth0')])
tile('金属玻璃','metal1',[(1,1,12,1,'metal3'),(2,2,2,9,'metal2'),(5,3,5,1,'metal0'),(6,4,4,5,'metal2'),(7,5,2,2,'metal3'),(12,2,1,10,'metal0'),(1,13,12,1,'metal0')])
# material overview, independent swatches with headers encoded as no text; nine labeled panels in QA file.
im,d=canvas(16*9,16*3,'#e8dfc4')
for i,n in enumerate(['草地','柏油','石板','木头','白墙灰瓦','水','车漆','布','金属玻璃']):
 t=Image.open(OUT/(n+'.png')).convert('RGBA').resize((16,16),Image.Resampling.NEAREST); im.alpha_composite(t,(i*16,8))
export(im,'材质样')
# 84px human silhouette = 42 art-grid pixels, 32x42 art grid transparent; 2x output.
def person(name,coat,hair='hair',hat=False,apron=False,glasses=False,straps=False,longhair=False):
 im,d=canvas(32,42)
 # foot shadow to lower right, then shoes
 rect(d,(13,39,24,40),'#566052'); rect(d,(10,39,14,40),'navy');rect(d,(18,39,22,40),'navy')
 # legs
 rect(d,(11,29,14,38),'navy');rect(d,(17,29,20,38),'navy');rect(d,(10,37,15,38),'metal0');rect(d,(17,37,22,38),'metal0')
 # torso & arms
 rect(d,(9,17,22,29),coat);rect(d,(7,19,9,27),coat);rect(d,(22,19,24,27),coat)
 rect(d,(12,19,13,28),'cream');rect(d,(18,19,19,28),'#7b6955')
 if apron: rect(d,(12,23,19,29),'cream')
 # neck/head hair/head pixels
 rect(d,(14,14,18,17),'skin1');rect(d,(11,5,21,14),'skin1');rect(d,(10,4,21,8),hair);rect(d,(10,7,12,12),hair);rect(d,(20,7,21,11),hair)
 if longhair: rect(d,(10,10,11,17),hair);rect(d,(20,10,21,17),hair)
 rect(d,(13,9,14,10),'hair');rect(d,(18,9,19,10),'hair');rect(d,(15,12,17,12),'skin0')
 if glasses: rect(d,(12,9,15,9),'metal3');rect(d,(17,9,20,9),'metal3');rect(d,(15,9,17,9),'metal0')
 if straps: rect(d,(11,18,12,26),'cream');rect(d,(19,18,20,26),'cream')
 if hat:
  rect(d,(9,2,22,4),'green');rect(d,(12,0,19,2),'green')
 export(im,name)
person('photographer_w','green',straps=True)
person('elder','cloth2',hair='#a5a49b',glasses=True)
person('farmer_2','cloth2',straps=True,longhair=True)
# north-facing compact car: art-grid canvas is 43x74; exact canvas target 86x148 then trim one blank row for footprint 147.
im,d=canvas(43,74)
# shadow right/down
rect(d,(6,8,38,68),'#414746')
# tires
for y in (15,26,47,59): rect(d,(5,y,9,y+6),'metal0');rect(d,(35,y,39,y+6),'metal0')
# body nose at top, trunk bottom
rect(d,(9,7,34,67),'car1');rect(d,(10,8,33,66),'car2');rect(d,(12,9,31,14),'shine')
# hood, windshield, cabin, rear glass
rect(d,(12,15,31,24),'car1');rect(d,(12,25,31,36),'glass');rect(d,(14,26,28,28),'#7798a2');rect(d,(12,38,31,51),'car1');rect(d,(14,39,29,41),'shine');rect(d,(12,52,31,62),'car2')
# lamps and bumpers
rect(d,(11,7,16,9),'cream');rect(d,(27,7,32,9),'cream');rect(d,(11,65,16,67),'red');rect(d,(27,65,32,67),'red');rect(d,(10,68,33,69),'metal0')
# driver door open on right, tiny door silhouette
rect(d,(33,34,40,48),'car1');rect(d,(39,36,40,38),'shine')
# export 2x then preserve odd exact required rect canvas width 86 x 147 with bottom trim; 2x grid footprint, 1px transparent allowance on south edge
big=im.resize((86,148),Image.Resampling.NEAREST); big.crop((0,0,86,147)).save(OUT/'car_mine.png')
# Scale sheet: hand-built silhouettes at 2x art grid.
im,d=canvas(240,112,'#d9d1b8')
def box(x,y,w,h,c): rect(d,(x,y,x+w-1,y+h-1),c)
# person 84px high; door 100; chair 46; table 36; car 86x147; tree 150; gate column 196
box(8,13,20,42,'green');box(12,5,12,9,'skin1');box(14,2,8,3,'hair');box(10,55,7,2,'navy');box(21,55,7,2,'navy')
box(40,5,22,50,'wood1');box(42,7,18,46,'wood2');box(53,30,2,2,'metal3')
box(72,37,11,18,'wood1');box(74,26,7,11,'wood2');box(87,32,26,18,'stone1');box(89,27,22,8,'stone2')
box(117,18,2,38,'wood0');box(113,19,12,2,'wood2');box(115,39,8,15,'wood1')
box(134,15,22,38,'green');box(137,8,16,12,'grass2');box(138,6,14,4,'green')
box(166,15,43,37,'car1');box(172,8,31,7,'car2');box(174,24,27,10,'glass');box(168,45,6,9,'metal0');box(201,45,6,9,'metal0')
box(216,0,14,56,'roof');box(219,4,8,52,'wall2')
export(im,'比例尺')
