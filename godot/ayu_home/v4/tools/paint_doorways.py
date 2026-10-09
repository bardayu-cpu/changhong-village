#!/usr/bin/env python3
"""一楼室内门洞重画（Claude 10/5，阿鱼细节第 5 节「门和墙又厚又怪」）。

astra 一楼重画版里，墙上的门洞是一块白色瓷砖样的长条，在游戏里像墙上又多了一条横带，
看不出是能穿过去的门。这里把门洞里的白条换成和两边房间一样的木地板，中间压一道深色门槛，
两边原有的木门框不动；墙不动。一楼家具前景层里如果盖到门洞，也从新底图重新取色。

只改 assets/floor1-redraw/floor1.png 和被盖到的前景贴图；每次都从 astra 交付提交 66dbcd0 里的原图开始画，可以反复跑。
用法：python3 godot/ayu_home/v4/tools/paint_doorways.py
"""
from pathlib import Path
from PIL import Image
import json, statistics, subprocess, io
V=Path(__file__).resolve().parents[1]; A=V/'assets'; F=A/'floor1-redraw'/'floor1.png'
# 门洞（底图坐标，2 像素一格）：x0,y0,x1,y1 是白条的范围；墙都是横的，人上下穿过
OPENINGS=[(390,412,455,445),(608,414,661,445),(772,410,827,445),(896,412,973,445),(1094,352,1135,387),(1078,500,1127,527),(1236,508,1287,539),
	# 南墙通往院子的三扇门（客厅、车库、手作房）也换成地板 + 门槛；客厅左边那条是窗，保留玻璃，好和门分开
	(818,796,981,821),(268,792,469,821),(90,786,143,819)]
VERTICAL=[(326,176,362,232),(325,368,366,411),(1026,434,1058,496)]
def woodish(c):return c[0]>120 and c[0]-c[2]>55 and c[1]>60
def main():
	raw=subprocess.run(['git','show','66dbcd0:godot/ayu_home/v4/assets/floor1-redraw/floor1.png'],cwd=V,capture_output=True,check=True).stdout
	im=Image.open(io.BytesIO(raw)).convert('RGBA');px=im.load();W,H=im.size
	changed=[]
	for x0,y0,x1,y1 in OPENINGS:
		# 往上下各扩到碰到木地板为止（包括白条下面那道浅蓝线和墙脚的黑线）
		top=y0
		while top>y0-8 and not woodish(px[(x0+x1)//2,top-1]):top-=1
		bot=y1
		while bot<y1+8 and not woodish(px[(x0+x1)//2,bot+1]):bot+=1
		# 白条旁边残留的浅色、浅蓝色细线（列 / 行）也算进门洞
		def stray(c):return (min(c[:3])>140 and not woodish(c)) or (c[2]>c[0]+10 and c[2]>90)
		while x0>0 and sum(stray(px[x0-1,y]) for y in range(top,bot+1))>(bot-top)*.5:x0-=1
		while x1<W-1 and sum(stray(px[x1+1,y]) for y in range(top,bot+1))>(bot-top)*.5:x1+=1
		while sum(stray(px[x,top-1]) for x in range(x0,x1+1))>(x1-x0)*.4:top-=1
		while sum(stray(px[x,bot+1]) for x in range(x0,x1+1))>(x1-x0)*.4:bot+=1
		# 地板颜色：门洞上下各 12 行里木头色的中位数
		samples=[px[x,y] for x in range(x0,x1+1,2) for y in list(range(top-12,top))+list(range(bot+1,bot+13)) if woodish(px[x,y])]
		base=tuple(int(statistics.median(c[i] for c in samples)) for i in range(3))
		def shade(k):return tuple(max(0,min(255,int(v*k))) for v in base)+(255,)
		mid=((top+bot)//2)//2*2
		for y in range(top,bot+1):
			for x in range(x0,x1+1):
				gy=(y-top)//2;gx=(x-x0)//2
				board=gy//4;row=gy%4
				k=1.0+(0.05 if board%2 else -0.03)
				if row==0:k*=.82 # 木板缝
				if (gx+board*5)%13==0 and row!=0:k*=.88 # 板头接缝错开
				c=shade(k)
				if mid-4<=y<mid+2:c=shade(.62) # 门槛
				if mid-6<=y<mid-4:c=shade(1.18) # 门槛上沿的亮边
				if y in (mid+2,mid+3):c=shade(.8)
				px[x,y]=c
		changed.append((x0,top,x1,bot))
	# 竖墙上的门洞（人左右穿过）：白条换成木地板，木板横着走，门槛是一道竖的深色条（体验师第三轮）
	for x0,y0,x1,y1 in VERTICAL:
		samples=[px[x,y] for y in range(y0,y1+1,2) for x in list(range(x1+2,x1+16))+list(range(x0-16,x0-2)) if 0<=x<W and woodish(px[x,y])]
		base=tuple(int(statistics.median(c[i] for c in samples)) for i in range(3))
		def vshade(k):return tuple(max(0,min(255,int(v*k))) for v in base)+(255,)
		mid=((x0+x1)//2)//2*2
		for y in range(y0,y1+1):
			for x in range(x0,x1+1):
				gy=(y-y0)//2;gx=(x-x0)//2;board=gy//4;row=gy%4
				k=1.0+(0.05 if board%2 else -0.03)
				if row==0:k*=.82
				if (gx+board*5)%13==0 and row!=0:k*=.88
				c=vshade(k)
				if mid-3<=x<mid+3:c=vshade(.62)
				if x in (mid-5,mid-4):c=vshade(1.18)
				if x in (mid+3,mid+4):c=vshade(.8)
				px[x,y]=c
		changed.append((x0,y0,x1,y1))
	im.save(F,optimize=True)
	# 盖到门洞的一楼前景贴图：按自己的透明度从新底图重新取色
	rooms=json.loads((A/'rooms.json').read_text())['rooms'];fixed=[]
	for rid,c in rooms.items():
		if int(c.get('floor',0))!=1:continue
		ox=c['source_crop'][0]-c['source_offset'][0];oy=c['source_crop'][1]-c['source_offset'][1]
		for p in c['props']:
			path=Path(str(p['file']).replace('res://ayu_home/v4/',str(V)+'/'))
			if not path.exists():continue
			art=Image.open(path).convert('RGBA');fx,fy=p['pos'][0]+ox,p['pos'][1]+oy
			if not any(fx<x1 and fx+art.width>x0 and fy<y1 and fy+art.height>y0 for x0,y0,x1,y1 in changed):continue
			src=im.crop((fx,fy,fx+art.width,fy+art.height));src.putalpha(art.getchannel('A'));src.save(path,optimize=True);fixed.append(path.name)
	print('门洞',len(changed),changed);print('重新取色的前景',sorted(set(fixed)))
if __name__=='__main__':main()
