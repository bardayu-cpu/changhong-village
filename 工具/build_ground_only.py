"""Rebuild the existing code-authored ground only; leave houses, collisions and saves alone."""
from pathlib import Path
from PIL import Image, ImageDraw
import json, random
R=Path(__file__).resolve().parents[1]
V=R/'godot/ayu_home/v4/assets/village'
roads=json.loads((V/'topology.json').read_text())['roads']
houses={r['id']:r for r in json.loads((V/'houses.json').read_text())}
random.seed(1007)
# Fresh procedural road surface; PNG source buildings themselves remain unchanged.
W,H=4800,4700
ground=Image.new('RGB',(W//3,H//3),'#8aaa5a');d=ImageDraw.Draw(ground)
for i in range(145000):
    x=random.randrange(W//3);y=random.randrange(H//3)
    d.rectangle((x,y,x+random.randrange(1,4),y+random.randrange(1,3)),fill=random.choice(['#8baa5d','#8faf61','#7fa355','#99b564','#83a753','#91ac5b']))
def line(points,width,color):
    q=[(int(x/3),int(y/3)) for x,y in points];d.line(q,fill=color,width=max(1,int(width/3)),joint='curve')
    for x,y in q:d.ellipse((x-width/6,y-width/6,x+width/6,y+width/6),fill=color)
def rect(b,c):d.rectangle(tuple(int(a/3) for a in b),fill=c)
for width,color in [(126,'#a88956'),(113,'#cfb17b'),(94,'#ddc08a')]:
    for rd in roads:line(rd,width,color)
for row in houses.values():
    x,y,w,h=row['bounds'];gate=row['at']; points=[pt for rd in roads for pt in rd]
    near=min(points,key=lambda p:(p[0]-gate[0])**2+(p[1]-gate[1])**2)
    line([gate,(gate[0],gate[1]+36),near],76,'#d9bb85')
    for i in range(45):
        xx=gate[0]+random.randrange(-55,55);yy=gate[1]+random.randrange(-10,50);rect((xx,yy,xx+9,yy+3),'#c4a373')
# Curving stream stays along the outer edge, clear of all front gates.
river=[(3570,0),(3550,900),(3450,1560),(3550,2100),(3520,2870),(3560,3520),(3510,4050),(3550,4700)]
line(river,85,'#567f70');line(river,62,'#56a6a0');line(river,39,'#76bbb1')
for yy in range(55,H,67):rect((3530,yy,3560,yy+3),'#a5d6c2')
for yy in [750,1900,3050,4320]:
    rect((3440,yy-38,3630,yy+38),'#8e6745')
    for xx in range(3444,3628,12):rect((xx,yy-34,xx+9,yy+34),'#c49b63')
    rect((3434,yy-45,3636,yy-40),'#5f4937');rect((3434,yy+40,3636,yy+45),'#5f4937')
# Kitchen gardens on terraces; earth, golden grain and varied flowers punctuate the green.
for idx,(x,y) in enumerate([(2500,660),(20,1880),(2750,2530),(50,4380),(2720,3400)]):
    for j in range(4):
        line([(x+j*8,y+j*28),(x+210+j*8,y+j*28+10)],15,'#986940')
        for k in range(10):
            rect((x+k*21+j*8,y+j*28-5,x+k*21+j*8+8,y+j*28+1),['#4a7a3e','#d3b85c','#67964c'][idx%3])
for xx,yy in [(1130,3900),(1580,3900),(1130,4300),(1580,4300)]:
    d.polygon([(xx//3,yy//3),((xx+345)//3,(yy-12)//3),((xx+360)//3,(yy+230)//3),((xx-6)//3,(yy+245)//3)],fill='#b1a575')
    for i in range(100):
        px=random.randrange(xx,xx+340);py=random.randrange(yy,yy+225);rect((px,py,px+4,py+9),'#7d984f')
# Flower verge around the southern garden site, bamboo behind its northern neighbour.
for i in range(80):
    x=1900+random.randrange(30);y=4330+random.randrange(210);rect((x,y,x+4,y+6),'#4e8249');rect((x-2,y-3,x+5,y+1),random.choice(['#e8a7ba','#e6c85e','#9b81ba','#f1e8c3']))
for x in range(1890,2000,15):
    line([(x,4010),(x-10,3825)],4,'#527e49')
    for y in range(3840,3990,24):line([(x-10,y+8),(x-32,y-10)],4,'#739647')
ground.resize((W,H),Image.Resampling.NEAREST).save(V/'ground.png')
print("B3: ground generated in global border/fill passes; intersections have no inner border")
