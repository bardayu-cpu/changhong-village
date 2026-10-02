import math
from PIL import Image
G="/Users/kayra_ayu/Desktop/苏七镇奇缘/游戏制作中-gpt 和 claude 合作/地图一-苏七镇/罗曼山庄/001-宴会厅/拆景/人物-C01-v1-20261002/"
SC="/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件/godot/assets/layered/scene_roman_banquet_55/"
sheet=Image.open(G+'chr_B55S-C01_v1.png').convert('RGBA'); idle=Image.open(G+'chr_B55S-C01_idle_v1.png').convert('RGBA')
print('sheet',sheet.size,'idle',idle.size)
names=['下']*4+['左']*4+['右']*4+['上']*4
for k in range(16):
    f=sheet.crop((k*64,0,k*64+64,84)); bb=f.getchannel('A').point(lambda a:255 if a else 0).getbbox()
    print(k,names[k],'bbox',bb,'高',bb[3]-bb[1],'宽',bb[2]-bb[0])
for k in range(4):
    f=idle.crop((k*64,0,k*64+64,84)); bb=f.getchannel('A').point(lambda a:255 if a else 0).getbbox()
    print('idle',k,'bbox',bb,'高',bb[3]-bb[1],'宽',bb[2]-bb[0])
# 半透明检查
a=sheet.getchannel('A'); print('alpha 取值',sorted(set(a.getdata()))[:6])
# 头：从顶往下第一个肤色行到下巴大致——用 front 帧每行不透明宽度看
f=sheet.crop((0,0,64,84)); fa=f.getchannel('A')
rows=[(y,sum(1 for x in range(64) if fa.getpixel((x,y)))) for y in range(84)]
print([r for r in rows if r[0]%6==0])
# 坐姿合成
tab=Image.open(SC+'art_table.png').convert('RGBA')
lamp=Image.open(SC+'art_lantern.png').convert('RGBA')
W,H=420,260
cv=Image.new('RGBA',(W,H),(214,204,189,255))
tx,ty=40,40            # 桌子零件左上角
cx,cy=tx+90,ty+100      # 占地中心 = 桌图 x+90, y+100
sc_x,sc_y=cx+0, cy-18   # 椅位圈心
rx,ry,a0=63.0,50.0,18.0
def seat(no):
    a=-math.pi/2+2*math.pi*(no-1)/10+math.radians(a0)
    return (sc_x+math.cos(a)*rx, sc_y+math.sin(a)*ry)
def face(dx,dy):
    if abs(dx)>abs(dy)*1.2: return '右' if dx>0 else '左'
    return '下' if dy>0 else '上'
def guest(no,keep=52):
    sx,sy=seat(no)
    base={'下':0,'左':4,'右':8,'上':12}[face(cx-sx,(cy-18)-sy)]
    fr=sheet.crop((base*64,0,base*64+64,84)).crop((0,0,64,keep))   # 上半身 62%
    return fr,(int(round(sx))-32,int(round(sy))-keep),sy
backs=[];fronts=[]
for no in range(1,11):
    fr,pos,sy=guest(no)
    (fronts if sy>=sc_y-0.5*50 else backs).append((sy,fr,pos))
for sy,fr,pos in sorted(backs,key=lambda t:t[0]): cv.alpha_composite(fr,pos)
cv.alpha_composite(tab,(tx,ty))
for sy,fr,pos in sorted(fronts,key=lambda t:t[0]): cv.alpha_composite(fr,pos)
# 旁边：站着的 C01、灯柱，当尺子
st=idle.crop((0,0,64,84)); cv.alpha_composite(st,(250,H-84-30))
cv.alpha_composite(lamp,(330,H-112-30))
cv.convert('RGB').save('out/char_seat.png')
cv.convert('RGB').resize((W*3,H*3),Image.NEAREST).save('out/char_seat_x3.png')
for no in range(1,11): print(no,[round(v) for v in seat(no)],face(cx-seat(no)[0],(cy-18)-seat(no)[1]))
