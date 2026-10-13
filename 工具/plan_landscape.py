"""Plan outdoor planting in world coordinates, protecting complete route segments."""
from pathlib import Path
import json, math, random

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'godot/ayu_home/v4/assets'
VILLAGE = ASSETS / 'village'

def point_segment(p, a, b):
    dx, dy = b[0]-a[0], b[1]-a[1]
    t = max(0, min(1, ((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy or 1)))
    return math.hypot(p[0]-a[0]-t*dx, p[1]-a[1]-t*dy)

def intersects(a, b, pad=0):
    return a[0] < b[0]+b[2]+pad and a[0]+a[2] > b[0]-pad and a[1] < b[1]+b[3]+pad and a[1]+a[3] > b[1]-pad

def plan():
    cfg = json.loads((ASSETS/'village.json').read_text())
    houses = json.loads((VILLAGE/'houses.json').read_text())
    roads = json.loads((VILLAGE/'topology.json').read_text())['roads']
    # Include exactly the current gate connectors, as well as the complete main polylines.
    vertices = [p for road in roads for p in road]
    connectors = []
    for h in houses:
        gate = h['at']; near = min(vertices, key=lambda p:math.dist(p,gate))
        connectors.append([gate, [gate[0],gate[1]+36], near])
    lines = [(a,b) for road in roads+connectors for a,b in zip(road,road[1:])]
    keep = [h['bounds'] for h in houses]+[[1050,3850,900,800]]
    # Ponds, activity props and existing trees remain readable, including their canopies.
    for prop in cfg['props']:
        if prop['id'].startswith(('land_', 'wildtree')) or prop['id'] in {h['id'] for h in houses} or prop['id']=='house_community':continue
        from PIL import Image
        name = prop['file']
        path = ROOT/'godot'/name.removeprefix('res://') if name.startswith('res://') else ROOT/'godot/ayu_home/v3/assets'/name
        with Image.open(path) as image:w,h=image.size
        sx,sy=prop.get('scale',[1,1]);keep.append([*prop['pos'],w*sx,h*sy])
    circles = [(h['at'],110) for h in houses]
    circles += [(p['approach'],120) for p in cfg['doors']+cfg['hotspots']]
    circles += [([3540,y],140) for y in [750,1900,3050,4320]]
    river = [(3570,0),(3550,900),(3450,1560),(3550,2100),(3520,2870),(3560,3520),(3510,4050),(3550,4700)]
    occupied = []
    def safe(rect, road_clear=110):
        x,y,w,h = rect
        if x<12 or y<12 or x+w>4788 or y+h>4688:return False
        if any(intersects(rect,b,24) for b in keep) or any(intersects(rect,b,20) for b in occupied):return False
        # Sample the entire proposed footprint, adding a half-cell safety margin.
        nx,ny=math.ceil(w/24),math.ceil(h/24)
        for iy in range(ny+1):
            for ix in range(nx+1):
                p=(x+w*ix/max(1,nx),y+h*iy/max(1,ny))
                if any(point_segment(p,a,b)<road_clear+17 for a,b in lines):return False
                if any(math.dist(p,c)<r+17 for c,r in circles):return False
                if any(point_segment(p,a,b)<65 for a,b in zip(river,river[1:])):return False
        return True
    design = json.loads((ROOT/'回执/第1轮/设计/村外铺景/铺景接口-v1.json').read_text())
    rng=random.Random(1014);fields=[]
    # Whole cultivated plots have different dimensions; individual crop rows are added later.
    for zone,rect in [('north_field',[1260,120,270,230]),('east_field',[3018,845,345,195]),('east_field',[3020,1110,280,180]),('east_field',[3030,1370,260,230]),('central_green',[2510,2580,360,80]),('east_bank_garden',[3880,2150,430,170]),('east_bank_south',[3850,3300,450,170]),('east_bank_south',[4350,3370,210,160])]:
        if safe([rect[0]-8,rect[1]-8,rect[2]+16,rect[3]+32]):
            fields.append({'id':f'field_{len(fields)}','zone':zone,'rect':rect,'crop':len(fields)%3});occupied.append(rect)
    plants=[]
    legacy=cfg.get('landscape_legacy_trees',[p for p in cfg['props'] if p['id'].startswith('wildtree')])
    for original in legacy:
        cx=original['pos'][0]+75;cy=original['foot']
        for dx,dy in [(0,0),(-180,0),(180,0),(0,-180),(0,180),(-300,-150),(300,150)]:
            rect=[cx+dx-80,cy+dy-192,160,192]
            if safe(rect):plants.append({'kind':'tree','rect':rect,'replaces':original['id']});occupied.append(rect);break
    for cx,cy in [(1320,3140),(170,1960),(2520,3980),(4060,2180)]:
        group=[]
        for dx,dy in [(-50,0),(50,45),(0,100)]:
            rect=[cx+dx-80,cy+dy-192,160,192]
            if safe(rect):group.append({'kind':'tree','rect':rect})
        if len(group)>=2:
            plants.extend(group);occupied.extend(p['rect'] for p in group)
    # Banks and village fringes use irregular groups, with no planting on a road/entrance.
    candidates=[]
    for y in range(150,4620,156):
        for x in range(50,4750,174):
            if rng.random()<.46:continue
            candidates.append([x+rng.randrange(-24,25),y+rng.randrange(-24,25)])
    for x,y in candidates:
        kind='bamboo' if 3370<x<3740 else ('tree' if rng.random()<.65 else 'shrub')
        w,h=(132,174) if kind=='tree' else ((92,126) if kind=='bamboo' else (78,48))
        rect=[x-w//2,y-h,w,h]
        if safe(rect):plants.append({'kind':kind,'rect':rect});occupied.append(rect)
    gardens=[]
    for i,h in enumerate(houses):
        x,y,w,hh=h['bounds']
        for side in [-1,1]:
            # Outside the courtyard corners, leaving the whole central gate approach free.
            for dx,dy in [(0,38),(0,94),(side*90,38)]:
                xx=(x+40 if side<0 else x+w-166)+dx
                rect=[xx,y+hh+dy,126,45]
                if safe(rect,90):
                    gardens.append({'house':h['id'],'rect':rect,'variant':(i+(side>0))%3});occupied.append(rect);break
    field_paths=[]
    for f in fields:
        x,y,w,h=f['rect'];goal=[x-19,y+h+12]
        candidates=[]
        for a,b in [(a,b) for road in roads for a,b in zip(road,road[1:])]:
            dx,dy=b[0]-a[0],b[1]-a[1];t=max(0,min(1,((goal[0]-a[0])*dx+(goal[1]-a[1])*dy)/(dx*dx+dy*dy or 1)))
            candidates.append([round(a[0]+t*dx),round(a[1]+t*dy)])
        near=min(candidates,key=lambda p:math.dist(p,goal))
        route=[near,[goal[0],near[1]],goal,[x+18,goal[1]]]
        # Reject any connector that would cross another household or the watercourse.
        clear=True
        for a,b in zip(route,route[1:]):
            for n in range(math.ceil(math.dist(a,b)/12)+1):
                t=n/max(1,math.ceil(math.dist(a,b)/12));px,py=a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t
                if any(intersects([px-14,py-14,28,28],r,6) for r in keep):clear=False;break
        if clear:field_paths.append(route)
    result={'world_size':[4800,4700],'fields':fields,'field_paths':field_paths,'plants':plants,'gardens':gardens,'protection':{'road_half_width':110,'house_margin':24,'doors':110,'public':120,'bridges':140,'dynamic_plot':[1050,3850,900,800]}}
    (VILLAGE/'landscape-layout.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:len(result[k]) for k in ['fields','plants','gardens']}))
    return result

if __name__=='__main__':plan()
