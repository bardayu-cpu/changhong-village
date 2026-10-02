import importlib.util, sys
from PIL import Image, ImageDraw, ImageFont
src=open('m_seam.py',encoding='utf-8').read().split("for name,(y0,y1)")[0]
ns={}; exec(src,ns)
blobs=ns['blobs']; S=ns['S']
x0,x1,y0,y1=40,1500,960,1130
crop=S.crop((x0,y0,x1,y1)).convert('RGB'); d=ImageDraw.Draw(crop)
for (yy0,yy1,col) in ((960,1024,(255,0,0)),(1024,1130,(0,120,255))):
    for cx,cy,w,h,n in blobs(yy0,yy1,60,690)+blobs(yy0,yy1,850,1480):
        if n>=60: d.ellipse([cx-x0-3,cy-y0-3,cx-x0+3,cy-y0+3],fill=col)
d.line([(0,1024-y0),(x1-x0,1024-y0)],fill=(0,200,0),width=1)
f=ImageFont.truetype("/System/Library/Fonts/STHeiti Medium.ttc",16)
d.text((8,6),"红点 = 北边地砖十字中心（最下两排间距约 82）；蓝点 = 南边（间距约 78）；绿线 = 两张图的接缝 y1024",font=f,fill=(0,0,0))
crop.resize((crop.width*1,crop.height*1)).save('out/seam_dots.png'); print(crop.size)
