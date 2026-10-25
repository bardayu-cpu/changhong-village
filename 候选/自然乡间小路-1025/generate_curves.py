import math,json,argparse
from pathlib import Path
p=Path(__file__).resolve().parent
ap=argparse.ArgumentParser();ap.add_argument("--project",type=Path,required=True);args=ap.parse_args()
layout=json.loads((p/'原布局只读.json').read_text())
obstacles=layout['surface_obstacles']
def distance(a,b):return math.hypot(a[0]-b[0],a[1]-b[1])
def lerp(a,b,t):return [a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t]
def projection(q,a,b):
 dx,dy=b[0]-a[0],b[1]-a[1];d=dx*dx+dy*dy
 return lerp(a,b,max(0,min(1,((q[0]-a[0])*dx+(q[1]-a[1])*dy)/d))) if d else list(a)
def nearest(q,ps):return min((projection(q,a,b) for a,b in zip(ps,ps[1:])),key=lambda x:distance(q,x))
def simplify(ps,tol=14):
 if len(ps)<3:return ps
 a,b=ps[0],ps[-1];ds=[distance(q,projection(q,a,b)) for q in ps[1:-1]]
 if max(ds,default=0)<=tol:return [a,b]
 k=ds.index(max(ds))+1
 return simplify(ps[:k+1],tol)[:-1]+simplify(ps[k:],tol)
def smooth(ps):
 # Quadratic round corners within the existing safe corridor; no rectangular detours.
 result=[ps[0]]
 for i in range(1,len(ps)-1):
  a,b,c=ps[i-1:i+2];rad=min(48,distance(a,b)*.27,distance(b,c)*.27)
  if rad<1:continue
  start=lerp(b,a,rad/distance(a,b));end=lerp(b,c,rad/distance(b,c))
  result.append(start)
  for k in range(1,9):
   t=k/8;result.append([(1-t)**2*start[j]+2*(1-t)*t*b[j]+t*t*end[j] for j in (0,1)])
 result.append(ps[-1]);return result
water=layout['water_polygon']
def inside(q,poly):
 yes=False;j=len(poly)-1
 for i in range(len(poly)):
  x,y=poly[i];xx,yy=poly[j]
  if ((y>q[1])!=(yy>q[1])) and q[0]<(xx-x)*(q[1]-y)/(yy-y)+x:yes=not yes
  j=i
 return yes
def clearance(q):
 values=[]
 for x,y,w,h in obstacles:
  dx=max(x-q[0],0,q[0]-x-w);dy=max(y-q[1],0,q[1]-y-h)
  values.append(math.hypot(dx,dy) if dx or dy else -min(q[0]-x,x+w-q[0],q[1]-y,y+h-q[1]))
 wd=min(distance(q,projection(q,u,v)) for u,v in zip(water,water[1:]+water[:1]))
 values.append(-wd if inside(q,water) else wd)
 values.extend([q[0],4800-q[0],q[1],4700-q[1]])
 return min(values)
lines=layout['roads']+layout['field_paths']+layout['entry_paths']
junctions=[]
for line in lines:junctions.extend([line['points'][0],line['points'][-1]])
report=[]
for index,line in enumerate(lines):
 original=line['points'];width=float(line.get('width',56))
 if len(original)<2:continue
 centre=smooth(simplify(original))
 length=sum(distance(x,y) for x,y in zip(centre,centre[1:]));amp=min(58 if line in layout['roads'] else 24,length*.075)
 if line in layout['entry_paths']:amp=min(amp,12)
 points=[];at=0
 for aa,bb in zip(centre,centre[1:]):
  seg=distance(aa,bb)
  if seg<.01:continue
  normal=[-(bb[1]-aa[1])/seg,(bb[0]-aa[0])/seg]
  for k in range(max(1,math.ceil(seg/12))):
   t=k/max(1,math.ceil(seg/12));q=lerp(aa,bb,t);s=at+t*seg
   pin=min(distance(q,j) for j in junctions)
   fade=min(1,s/90,(length-s)/90)**2*(1-math.exp(-(pin/105)**2))
   wobble=amp*fade*(math.sin(s*math.tau/820+index*.71)+.24*math.sin(s*math.tau/1450+index*1.13))
   if 2975<q[0]<3075 and 2780<q[1]<3515:wobble=max(-8,min(8,wobble))
   desired=[q[j]+normal[j]*wobble for j in (0,1)]
   reference=nearest(q,original);floor=min(width/2+7,clearance(reference))
   # If a bend approaches a facade/bank, taper it back to its original corridor.
   for step in range(12):
    if clearance(desired)>=floor-1:break
    desired=lerp(desired,reference,.35)
   if clearance(desired)<3:desired=reference
   if not points or distance(points[-1],desired)>1:points.append([round(x,3) for x in desired])
  at+=seg
 points[0]=original[0];points.append(original[-1])
 deviation=max(distance(q,nearest(q,original)) for q in points)
 line['points']=points
 report.append({'id':line['id'],'original_points':len(original),'new_points':len(points),'max_bend_world_px':round(deviation,2)})
layout['version']='1025-user-natural-curves-v1'
layout['notes'].append('User 2026-10-25: paths should wind like real village lanes; organic curves with round turns, fixed houses/bank/thresholds, regenerated nav from rendered surfaces.')
(p/'弯路量测.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
dest=args.project.resolve()/'ayu_home/v4/assets/village/layout-1025.json';dest.write_text(json.dumps(layout,ensure_ascii=False,indent=2)+'\n')
