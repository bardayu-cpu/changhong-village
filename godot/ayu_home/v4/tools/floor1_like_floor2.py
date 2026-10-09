#!/usr/bin/env python3
"""一楼的墙和门照二楼的画法（Claude 10/5 第三轮，阿鱼一开始就要「一楼跟二楼像一栋房子」）。

只改墙和门的画法，不动房间排法、家具、可走区和门的位置：
1. 先跑 paint_doorways.py（门洞换成木地板加门槛，从 astra 交付的原图开始）
2. 墙：一楼深蓝灰 → 二楼的暖灰墙顶；横墙下沿一截画成二楼那种米色墙面（在原来墙的范围里，
   不往地上伸，可走区不变），所以深色的墙顶看着跟二楼一样细
3. 门：每个门洞旁边立一扇开着的木门板，门板直接从二楼原图里抠（approved-2.png 露台那扇），
   横墙的门板靠在门洞左边的墙下、竖墙的门板贴着墙立在门洞上方，都不挡路
用法：python3 godot/ayu_home/v4/tools/floor1_like_floor2.py
"""
from pathlib import Path
from PIL import Image, ImageDraw
import importlib.util, json
V=Path(__file__).resolve().parents[1]; A=V/'assets'; F=A/'floor1-redraw'/'floor1.png'; SECOND=V.parent/'v3'/'assets'/'approved-2.png'
spec=importlib.util.spec_from_file_location('paint_doorways',Path(__file__).with_name('paint_doorways.py'));pd=importlib.util.module_from_spec(spec);spec.loader.exec_module(pd)

def is_wall(c):
	r,g,b=c[:3];return b>=r+6 and b>=g+3 and max(r,g,b)<135 and max(r,g,b)-min(r,g,b)<40
def lum(c):return .3*c[0]+.59*c[1]+.11*c[2]
TOP=(87,77,79);FACE=(196,165,130);FACE_DARK=(150,117,94)

def leaf_from_second():
	a=Image.open(SECOND).convert('RGBA')
	poly=[(838,470),(844,465),(850,466),(889,495),(890,562),(881,563),(838,537)]
	m=Image.new('L',a.size,0);ImageDraw.Draw(m).polygon(poly,fill=255)
	leaf=Image.new('RGBA',a.size,(0,0,0,0));leaf.paste(a,(0,0),m);leaf=leaf.crop((836,463,892,565))
	px=leaf.load()
	for y in range(leaf.height):
		for x in range(leaf.width):
			r,g,b,al=px[x,y]
			if al==0:continue
			if (min(r,g,b)>140 and r-b<75) or (max(r,g,b)-min(r,g,b)<30 and min(r,g,b)>55):px[x,y]=(0,0,0,0)
	return leaf

def main():
	pd.main()
	im=Image.open(F).convert('RGBA');px=im.load();W,H=im.size
	# 卫生间洗衣左上角的缺口（阿鱼 10/5：「是墙，缺口你填上」）：照左边那截墙（同一行）补满，下沿那道浅色条和蓝线换成卫生间的地砖
	for y in range(250,280):
		for x in range(86,142):px[x,y]=px[30+(x-86)%50,y]
	for y in range(280,284):
		for x in range(90,138):px[x,y]=px[x,y+6]
	wall=[[is_wall(px[x,y]) for x in range(W)] for y in range(H)]
	# 竖向连续多长（判断横墙）
	vrun=[[0]*W for _ in range(H)];
	for x in range(W):
		y=0
		while y<H:
			if not wall[y][x]:y+=1;continue
			y0=y
			while y<H and wall[y][x]:y+=1
			for k in range(y0,y):vrun[k][x]=(y0,y)
	hlen=[[0]*W for _ in range(H)]
	for y in range(H):
		x=0
		while x<W:
			if not wall[y][x]:x+=1;continue
			x0=x
			while x<W and wall[y][x]:x+=1
			for k in range(x0,x):hlen[y][k]=x-x0
	recolored=0;faces=0
	for y in range(H):
		for x in range(W):
			if not wall[y][x]:continue
			c=px[x,y];t=lum(c)/60.0
			y0,y1=vrun[y][x];run=y1-y0
			horizontal=run<=48 and hlen[y][x]>=40
			if horizontal and run>=14 and y>=y1-max(6,int(run*.38)):
				# 横墙下沿：米色墙面，最下面一道深一点的踢脚线，竖向的细缝像二楼的墙板
				k=1.0 if (x//2)%14 else .92
				col=FACE_DARK if y>=y1-2 else tuple(int(v*k) for v in FACE)
				px[x,y]=col+(255,);faces+=1
			else:
				px[x,y]=tuple(max(0,min(255,int(v*t))) for v in TOP)+(255,);recolored+=1
	# 门板
	# 门开得更大一点、更贴着墙（宽度收到六成），少占走道
	leaf=leaf_from_second();leaf=leaf.resize((int(leaf.width*.6),leaf.height),Image.NEAREST);mirror=leaf.transpose(Image.FLIP_LEFT_RIGHT)
	narrow=leaf.resize((16,leaf.height),Image.NEAREST)
	# 第六轮（阿鱼 10/5）：一楼只留爸妈卧室（门号 11）、麻将室（门号 10）进门那两扇门板，其余全拆，门洞就是开口
	KEEP=[(1078,500,1127,527),(1094,352,1135,387)]
	horiz=[o for o in pd.OPENINGS if o in KEEP];placed=[]
	base=im.copy();bp=base.load()
	taken=set()
	def clutter(sprite,at):
		# 门板盖住的地方有多少不是空地板（墙、家具），挑盖得最少的一边；跟已经放好的门板叠在一起更不行
		n=0;sp=sprite.load()
		for yy in range(sprite.height):
			for xx in range(sprite.width):
				X,Y=at[0]+xx,at[1]+yy
				if sp[xx,yy][3]==0 or not(0<=X<W and 0<=Y<H):continue
				if (X,Y) in taken:n+=6;continue
				c=bp[X,Y];floor=(c[0]>120 and c[0]-c[2]>45 and c[1]>70) or min(c[:3])>175
				n+=0 if floor else 1
		return n
	def place(sprite,at):
		im.alpha_composite(sprite,at);placed.append(at);sp=sprite.load()
		for yy in range(sprite.height):
			for xx in range(sprite.width):
				if sp[xx,yy][3]>0:taken.add((at[0]+xx,at[1]+yy))
	for x0,y0,x1,y1 in horiz:
		# 门轴靠在门洞一边的门框上，门板朝屋里打开、靠着墙，不挡门洞；左右哪边空就放哪边
		cands=[(mirror,(x0-mirror.width+3,y0+4)),(leaf,(x1-3,y0+4))]
		sprite,at=min(cands,key=lambda c:clutter(c[0],c[1]))
		place(sprite,at)
	for x0,y0,x1,y1 in []: # 竖墙上的门板也拆了
		# 竖墙：门板贴着墙立在门洞上方或下方、左边或右边，挑空的、不跟别的门板叠的那处（东侧过道原来两扇叠成 V 字）
		cands=[(narrow,(x1+1,max(0,y0-narrow.height+14))),(narrow,(x1+1,y1-12)),(narrow,(x0-narrow.width-1,max(0,y0-narrow.height+14))),(narrow,(x0-narrow.width-1,y1-12))]
		sprite,at=min(cands,key=lambda c:clutter(c[0],c[1]))
		place(sprite,at)
	im.save(F,optimize=True)
	print('墙顶改色',recolored,'墙面',faces,'门板',len(placed))
if __name__=='__main__':main()
