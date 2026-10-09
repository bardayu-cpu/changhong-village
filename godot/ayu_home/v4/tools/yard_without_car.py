"""第六轮第 8 条（一半）：院子里不画车（家里只有一台车，停车库）。
原画里车压在几层上：底图那块是抠过的补丁、房子那层底边画着车顶、车库那层和车库旁花盆那层底下也带着车身。
这里只把车拿掉、露出车后面本来该有的东西，别的一笔不动；原图不改，改好的放 assets/exterior-nocar/。
  底图：车那块用院子里一块干净的沙地平铺补上；
  房子那层：卷帘门、左边砖柱照它自己上面的样子往下接（卷帘每 16 像素一条，正好接到门底那条暗线），门底以下露出沙地；
  车库那层、花盆那层：车的颜色抠掉；花盆那层下半截原来被车挡着，借窗下那盆的盆（同一套画）接在原来那丛叶子下面。
用法：python3 godot/ayu_home/v4/tools/yard_without_car.py"""
from pathlib import Path
from PIL import Image
V3=Path(__file__).resolve().parents[2]/'v3'/'assets';OUT=Path(__file__).resolve().parents[1]/'assets'/'exterior-nocar'
OUT.mkdir(exist_ok=True)
def car(p):
	r,g,b,a=p
	if a<10:return False
	mx,mn=max(r,g,b),min(r,g,b)
	return (mx-mn<40 and mx<170) or (b>r+25 and b>=g) or (r>150 and g<90 and b<90 and r-g>90)
# 底图
base=Image.open(V3/'exterior_floor.png').convert('RGBA')
donor=base.crop((560,630,700,700))
for y in range(572,704,70):
	for x in range(232,516,140):
		t=donor.crop((0,0,min(140,516-x),min(70,704-y)));base.paste(t,(x,y))
base.save(OUT/'exterior_floor.png')
# 房子那层（摆在 353,147）：车占着左下 x 0～142、y 405 往下
house=Image.open(V3/'exterior_house.png').convert('RGBA');px=house.load()
for x in range(0,143):
	for y in range(405,437):
		src=y-32
		# 砖柱下半截压着叶子，往上隔整砖找一块干净的砖（同一行的砖缝照旧对齐）
		while x<28 and not (px[x,src][0]>140 and px[x,src][0]>px[x,src][1]+50) and src-16>=340:src-=16
		px[x,y]=px[x,src]
	for y in range(437,house.height):px[x,y]=(0,0,0,0)
house.save(OUT/'exterior_house.png')
# 车库那层（摆在 172,395）：右下角车身抠掉
gar=Image.open(V3/'exterior_garage.png').convert('RGBA');px=gar.load()
for x in range(100,gar.width):
	for y in range(160 if x>=146 else 186,gar.height):
		if car(px[x,y]) or y>=186:px[x,y]=(0,0,0,0) # 门底以下就是院子地面，交给底图
gar.save(OUT/'exterior_garage.png')
# 车库旁花盆那层（摆在 314,529）：叶子留着，下半截换成窗下那盆的盆
pot=Image.open(V3/'exterior_pot_garage.png').convert('RGBA');px=pot.load()
for x in range(pot.width):
	for y in range(36,pot.height):
		if car(px[x,y]) or y>=40:px[x,y]=(0,0,0,0)
src=Image.open(V3/'exterior_pot_window_left.png').convert('RGBA');sp=src.load()
dx,dy=4,2
for x in range(src.width):
	for y in range(35,src.height):
		r,g,b,a=sp[x,y]
		if a<128:continue
		# 只拿盆（橙褐色和描边），不拿窗下那盆身后的红墙、灰墙
		if not ((r>g+25 and g>=b-5 and r>60) or (r<70 and g<50 and b<50)):continue
		if (r>200 and g<110) or not 3<=x<=33:continue
		X,Y=x+dx,y+dy
		if 0<=X<pot.width and 0<=Y<pot.height:px[X,Y]=(r,g,b,255)
pot.save(OUT/'exterior_pot_garage.png')
print('ok',OUT)
