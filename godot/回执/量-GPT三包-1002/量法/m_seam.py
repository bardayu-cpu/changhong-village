import sys, statistics as st
from PIL import Image
S=Image.open('out/gpt_stitch.png').convert('RGB'); px=S.load(); W,H=S.size
def blobs(y0,y1,x0,x1,thr=70):
    seen=set(); out=[]
    for y in range(y0,y1):
        for x in range(x0,x1):
            if (x,y) in seen: continue
            r,g,b=px[x,y]
            if r-b>thr and r>180 and g>140:
                stack=[(x,y)]; seen.add((x,y)); pts=[]
                while stack:
                    cx,cy=stack.pop(); pts.append((cx,cy))
                    for nx,ny in ((cx+1,cy),(cx-1,cy),(cx,cy+1),(cx,cy-1),(cx+1,cy+1),(cx-1,cy-1),(cx+1,cy-1),(cx-1,cy+1)):
                        if y0<=ny<y1 and x0<=nx<x1 and (nx,ny) not in seen:
                            r2,g2,b2=px[nx,ny]
                            if r2-b2>thr and r2>180 and g2>140:
                                seen.add((nx,ny)); stack.append((nx,ny))
                if len(pts)>=8:
                    xs=[p[0] for p in pts]; ys=[p[1] for p in pts]
                    out.append(((min(xs)+max(xs))/2,(min(ys)+max(ys))/2,max(xs)-min(xs)+1,max(ys)-min(ys)+1,len(pts)))
    return out
def rows(bl,tol=6):
    bl=sorted(bl,key=lambda b:b[1]); rs=[]
    for b in bl:
        if rs and abs(rs[-1][0][1]-b[1])<=tol: rs[-1].append(b)
        else: rs.append([b])
    return rs
for name,(y0,y1) in {'北边下段 y700~1024':(700,1024),'南边上段 y1024~1350':(1024,1350)}.items():
    for side,(x0,x1) in {'西半':(60,690),'东半':(850,1480)}.items():
        bl=blobs(y0,y1,x0,x1)
        rs=rows(bl)
        print(name,side,'motifs',len(bl))
        for r in rs:
            r=sorted(r); xs=[b[0] for b in r]
            gaps=[round(xs[i+1]-xs[i],1) for i in range(len(xs)-1)]
            print('  row y≈%.0f n=%d x0=%.0f gaps=%s size=%s'%(sum(b[1] for b in r)/len(r),len(r),xs[0],gaps,[(b[2],b[3]) for b in r][:3]))
        ys=[sum(b[1] for b in r)/len(r) for r in rs]
        print('  row pitch', [round(ys[i+1]-ys[i],1) for i in range(len(ys)-1)])
