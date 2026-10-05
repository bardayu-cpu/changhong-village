# 娱乐室排法图 v1（庄Z4，10/5 晚）：游戏里的最终大小（家具已 ×1.25，人 84 不动），色块 + 名字，给阿鱼看排法；同时出 零件表-草稿.json
import json
from PIL import Image,ImageDraw,ImageFont
W,H=1080,1560          # 横两屏、竖 1.6 屏；面积 = 化妆间 675×1200 的 2.08 倍
WALL_N=150; WALL_S=1460; SIDE=16
F=lambda s:ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc",s)
# 每件：编号、名字、放什么、中心 x、着地线 y、宽、高（游戏里 1.25 倍后的大小）；GPT 格子 = 宽高 ÷1.25×4
T={"Y01":(140,120),"Y02":(140,120),"Y03":(160,130),"Y04":(150,100),"Y05":(75,120),"Y06":(50,55),"Y07":(138,70),"Y08":(62,100),"Y09":(55,105),"Y10":(30,82)}
items=[]
def add(code,name,what,cx,foot,color):
    w,h=T[code]; items.append(dict(编号=code,名字=name,放什么=what,x=cx-w//2,y=foot-h,w=w,h=h,foot_y=foot,color=color))
MJ=(196,64,52); P27=(70,120,170); POK=(110,80,160); FUR=(150,105,60); GRN=(70,140,80); GOLD=(220,170,60)
# 第 1、2 排：四川麻将（5 张 NPC 在打）+ 中间第 2 排炸金花
for i,cx in enumerate([220,540,860]): add("Y01",f"mahjong_{i+1}","四川麻将（NPC 在打）",cx,470,MJ)
add("Y01","mahjong_4","四川麻将（NPC 在打）",220,760,MJ); add("Y01","mahjong_5","四川麻将（NPC 在打）",860,760,MJ)
add("Y03","poker","炸金花（只画，不能玩）",540,770,POK)
# 第 3 排：贰柒拾两桌
add("Y02","er27_1","贰柒拾（只画，不能玩）",220,1060,P27); add("Y02","er27_2","贰柒拾（只画，不能玩）",860,1060,P27)
# 能坐下玩的麻将桌：正对门，前面空出一大块
add("Y01","mahjong_play","能坐下玩的麻将（空一把椅子）",540,1230,(230,90,40))
# 北墙：茶水台 + 两个茶叶柜
add("Y04","tea_bar","茶水台",540,235,FUR); add("Y05","cab_tea_w","茶叶柜",420,235,FUR); add("Y05","cab_tea_e","茶叶柜",660,235,FUR)
# 南墙两边：看牌的长椅 + 小几
add("Y07","bench_w","长椅（看牌的人坐）",150,1440,FUR); add("Y06","side_w","小几（瓜子果盘）",255,1440,FUR)
add("Y07","bench_e","长椅（看牌的人坐）",930,1440,FUR); add("Y06","side_e","小几（瓜子果盘）",825,1440,FUR)
add("Y06","side_mid_w","小几",380,900,FUR); add("Y06","side_mid_e","小几",700,900,FUR)
# 记分小黑板、绿植、宫灯
add("Y08","board","记分小黑板",56,640,(60,60,60))
add("Y09","plant_nw","大盆绿植",52,250,GRN); add("Y09","plant_ne","大盆绿植",1028,250,GRN)
add("Y09","plant_door_w","大盆绿植",420,1450,GRN); add("Y09","plant_door_e","大盆绿植",660,1450,GRN)
for i,(x,f) in enumerate([(30,1000),(1050,1000),(1050,640)]): add("Y10",f"lamp_{i+1}","落地宫灯",x,f,GOLD)
im=Image.new("RGB",(W,H),(214,170,110)); d=ImageDraw.Draw(im)
d.rectangle((0,0,W,WALL_N),fill=(236,222,196)); d.text((W//2-120,40),"北墙：雕花木窗 · 红灯笼 · 挂画",font=F(28),fill=(120,60,40))
d.rectangle((0,WALL_S,W,H),fill=(120,80,50)); d.rectangle((470,WALL_S,610,H),fill=(214,170,110)); d.text((500,1490),"门",font=F(30),fill=(60,30,20))
d.rectangle((0,0,SIDE,H),fill=(120,80,50)); d.rectangle((W-SIDE,0,W,H),fill=(120,80,50))
for it in sorted(items,key=lambda i:i["foot_y"]):
    x,y,w,h=it["x"],it["y"],it["w"],it["h"]; c=it["color"]
    d.rectangle((x,y,x+w,y+h),fill=c,outline=(40,25,15),width=2)
    if it["编号"] in ("Y01","Y02","Y03"):  # 椅子位置示意
        for cx,cy in [(x+w//2,y+6),(x+w//2,y+h-6),(x+6,y+h//2),(x+w-6,y+h//2)]:
            if it["名字"]=="mahjong_play" and cy==y+h-6: d.rectangle((cx-12,cy-10,cx+12,cy+10),outline=(255,255,255),width=3); continue
            d.rectangle((cx-10,cy-8,cx+10,cy+8),fill=(90,50,30))
    LB={"Y01":"四川麻将","Y02":"贰柒拾·只看","Y03":"炸金花·只看","Y04":"茶水台","Y05":"茶叶柜","Y06":"小几","Y07":"长椅","Y08":"记分板","Y09":"绿植","Y10":"宫灯"}
    t="能玩的麻将" if it["名字"]=="mahjong_play" else LB[it["编号"]]
    fs=22 if w>=100 else 14
    tw=d.textlength(t,font=F(fs)); d.text((x+(w-tw)/2,y+h//2-fs//2),t,font=F(fs),fill=(255,255,255))
# 人 = 84 高的尺子
for (px,pf) in [(380,560),(540,1400)]:
    d.rectangle((px-14,pf-84,px+14,pf),fill=(250,240,220),outline=(40,25,15),width=2); d.text((px+18,pf-50),"人 84",font=F(16),fill=(40,25,15))
# 手机一屏
d.rectangle((270,560,810,1520),outline=(255,40,40),width=5); d.text((280,1525),"红框 = 手机一屏 540×960",font=F(22),fill=(255,40,40))
# 旁边放化妆间同比例的框比大小
out=Image.new("RGB",(W+40+675+20,H+60),(32,27,24)); od=ImageDraw.Draw(out)
out.paste(im,(0,50)); od.text((4,8),"娱乐室 1080×1560（横两屏、竖 1.6 屏）",font=F(30),fill=(250,242,228))
od.rectangle((W+40,50,W+40+675,50+1200),outline=(242,194,62),width=4); od.text((W+48,8),"化妆间 675×1200（同比例）",font=F(30),fill=(242,194,62))
out.save("娱乐室-排法图-v1.png")
json.dump({"说明":"娱乐室排法 v1 草稿（庄Z4 10/5 晚）：游戏里最终大小（家具已 ×1.25，人 84）。GPT 格子 = 宽高 ÷1.25×4。阿鱼点头前都是草稿","画布":{"w":W,"h":H},"零件":[{k:v for k,v in it.items() if k!="color"} for it in items]},open("零件表-草稿.json","w",encoding="utf-8"),ensure_ascii=False,indent=1)
print(len(items),"件")
