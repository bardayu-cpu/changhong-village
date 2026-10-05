# 娱乐室 v3 布局预览（庄Z4，10/5 晚）：照阿鱼认可的 GPT 效果图摆，用代码画 v1 的桌椅拼；只看布局
import json,collections
from PIL import Image,ImageDraw,ImageFont
V1="../代码画-v1/"
r=json.load(open(V1+"room.json",encoding="utf-8"))
base=Image.open(V1+"room.png").convert("RGBA")
W,H=1000,1440; X0=40   # v3b：比化妆间大，照 GPT 图的疏密往外多摆
room=Image.new("RGBA",(W,H))
room.alpha_composite(base.crop((X0,0,X0+W,1300)),(0,0))          # 北墙 + 地板
room.alpha_composite(base.crop((X0,1420,X0+W,1560)),(0,1300))    # 南墙、门、门外走廊
# v1 每组：组里各件相对「桌子着地线、组中心 x」的偏移
groups=collections.defaultdict(list)
for p in r["props"]:
    g=p.get("组") or p["id"]; groups[g].append(p)
def anchor(g):
    ps=groups[g]; t=[p for p in ps if p["id"].endswith("_table")] or ps
    xs=[p["x"] for p in ps]; xe=[p["x"]+p["w"] for p in ps]
    return (min(xs)+max(xe))/2, t[0]["foot"]
def place(g,cx,foot,skip=()):
    ax,af=anchor(g)
    for p in sorted(groups[g],key=lambda p:p["foot"]):
        if any(p["id"].endswith(s) for s in skip): continue
        im=Image.open(V1+p["png"]).convert("RGBA")
        room.alpha_composite(im,(int(p["x"]-ax+cx),int(p["y"]-af+foot)))
# 地毯（阿鱼：中间那张在地毯上，留给玩家）
d=ImageDraw.Draw(room)
cx,foot=500,660
d.rectangle((cx-118,foot-178,cx+118,foot+34),fill=(168,52,40),outline=(222,170,70),width=4)
d.rectangle((cx-106,foot-166,cx+106,foot+22),outline=(222,170,70),width=2)
# 北墙一排：茶水台、两个茶叶柜（照 v1 那几件平移）
for g,x in [("tea_bar",500),("cab_tea_w",382),("cab_tea_e",618)]:
    if g in groups: place(g,x,anchor(g)[1])
mj=[g for g in groups if g.startswith("mahjong_") and g!="mahjong_play"]
pos=[(155,420),(385,420),(615,420),(845,420),(155,660),(845,660),(155,900),(385,900),(615,900),(845,900),(500,1140)]
for i,(x,f) in enumerate(pos): place(mj[i%len(mj)],x,f)
place("mahjong_play",500,660)
# 左下炸金花、右下贰柒拾：长方形小桌、三个人（预览先借 v1 贰柒拾桌，去掉朝下那把椅子）
er=[g for g in groups if g.startswith("er27")]
place(er[0],150,1140,skip=("_chair_s",)); place(er[-1],850,1140,skip=("_chair_s",))
for g,x in [("bench_w",150),("bench_e",850)]:
    if g in groups: place(g,x,1290)
for g,x in [("plant_nw",42),("plant_ne",958)]:
    if g in groups: place(g,x,anchor(g)[1])
for g,x in [("plant_door_w",410),("plant_door_e",590)]:
    if g in groups: place(g,x,1295)
d=ImageDraw.Draw(room)
# 西北：沙发瓜子闲聊区（沙发靠墙、前面茶几）
d.rectangle((60,232,240,300),fill=(160,50,40),outline=(40,20,10),width=3)
d.rectangle((250,240,300,300),fill=(160,50,40),outline=(40,20,10),width=3)
d.rectangle((110,305,200,345),fill=(120,80,50),outline=(40,20,10),width=3)
# 东北：电子游戏区（电视柜靠墙、前面小凳、懒人沙发）
d.rectangle((720,200,840,290),fill=(70,45,30),outline=(30,20,10),width=3)
d.rectangle((735,212,825,262),fill=(40,60,90),outline=(20,20,20),width=3)
d.rectangle((760,305,800,335),fill=(150,100,60),outline=(30,20,10),width=2)
d.rectangle((850,300,920,345),fill=(200,140,60),outline=(30,20,10),width=2)
F=ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc",20)
lab=[(500,700,"玩家坐这张（地毯上）"),(150,1170,"炸金花·三人小桌"),(850,1170,"贰柒拾·三人小桌"),(180,350,"沙发瓜子闲聊区"),(800,350,"电子游戏区")]
out=room.copy(); od=ImageDraw.Draw(out)
for x,y,t in lab:
    tw=od.textlength(t,font=F); od.rectangle((x-tw/2-6,y-2,x+tw/2+6,y+26),fill=(30,20,15)); od.text((x-tw/2,y),t,font=F,fill=(250,242,228))
# 手机一屏框
od.rectangle((230,500,770,1460),outline=(255,40,40),width=5)
# 旁边放化妆间同比例框
big=Image.new("RGB",(W+40+675,max(H,1200)+80),(32,27,24)); bd=ImageDraw.Draw(big)
big.paste(out.convert("RGB"),(0,50)); bd.text((4,10),f"娱乐室 定稿布局 {W}×{H}（红框=手机一屏）",font=ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc",28),fill=(250,242,228))
bd.rectangle((W+40,50,W+40+675,1250),outline=(242,194,62),width=4); bd.text((W+48,10),"化妆间 675×1200",font=ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc",28),fill=(242,194,62))
big.save("娱乐室-定稿布局.jpg",quality=90); print(sorted(groups)[:40])
