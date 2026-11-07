#!/usr/bin/env python3
"""Read-only R1 visual foundation audit. Does not modify or regenerate artwork."""
from pathlib import Path
import json, subprocess, hashlib, statistics, sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[4]
ART = ROOT / '回执/山庄收尾/画风'
BASE = '61c0500'
PEOPLE = ['photographer_w.png', 'elder.png', 'farmer_2.png']
MATERIALS = ['草地.png', '柏油.png', '石板.png', '木头.png', '白墙灰瓦.png', '水.png', '红毯.png', '布.png', '金属玻璃.png']
CORE = PEOPLE + MATERIALS + ['car_mine.png', '脚影.png', 'car_mine_shadow.png', 'tree_scale.png', 'tree_scale_shadow.png']
SHEETS = ['主色板.png', '材质样.png', '比例尺.png']

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()

def grid_check(im):
    im = im.convert('RGBA'); px = im.load(); bad = 0
    # R1 is 2 canvas pixels per source pixel. Odd trailing anchor row/column is ignored.
    for y in range(0, im.height - im.height % 2, 2):
        for x in range(0, im.width - im.width % 2, 2):
            if len({px[x,y],px[x+1,y],px[x,y+1],px[x+1,y+1]}) > 1: bad += 1
    return bad

def seam(im):
    im = im.convert('RGBA'); w,h=im.size
    if w < 4 or h < 4: return None
    px=im.load(); wrap=[]; inner=[]
    for y in range(h): wrap.append(sum(abs(px[0,y][c]-px[w-1,y][c]) for c in range(3)))
    for y in range(h): inner.append(sum(abs(px[1,y][c]-px[w-2,y][c]) for c in range(3)))
    for x in range(w): wrap.append(sum(abs(px[x,0][c]-px[x,h-1][c]) for c in range(3)))
    for x in range(w): inner.append(sum(abs(px[x,1][c]-px[x,h-2][c]) for c in range(3)))
    return round(statistics.mean(wrap),2), round(statistics.mean(inner),2)

def main():
    checks=[]; images={}; visible=set(); missing=[]
    for name in CORE+SHEETS:
        p=ART/name
        if not p.is_file(): missing.append(name); continue
        try: im=Image.open(p).convert('RGBA')
        except Exception as e: checks.append((name,'FAIL',f'PNG decode: {e}')); continue
        images[name]=im
        visible.update(v[:3] for v in im.getdata() if v[3])
        checks.append((name,'INFO',f'{im.width}x{im.height}; 2x2 mixed blocks={grid_check(im)}'))
    for n in PEOPLE:
        if n in images: checks.append((n,'AUTO',f'84px body target: {images[n].size==(64,84)}'))
    for n in MATERIALS:
        if n not in images: continue
        im=images[n]; sm=seam(im)
        checks.append((n,'AUTO',f'min 128x128={im.width>=128 and im.height>=128}; wrap/internal edge mean RGB jump={sm}'))
    if 'car_mine.png' in images:
        im=images['car_mine.png']; a=im.getchannel('A')
        odd_tail=(im.height%2==1 and all(a.getpixel((x,im.height-1))==0 for x in range(im.width)))
        checks.append(('car_mine.png','AUTO',f'86x147={im.size==(86,147)}; transparent odd anchor row={odd_tail}'))
    for n in ['脚影.png','car_mine_shadow.png','tree_scale_shadow.png']:
        if n in images:
            alphas=sorted(set(images[n].getchannel('A').getdata()))
            checks.append((n,'AUTO',f'alpha values include cast ~30% (70-85)={any(70<=x<=85 for x in alphas)}; alpha values={alphas[:20]}'))
    palette=images.get('主色板.png')
    if palette:
        swatches={p[:3] for p in palette.getdata() if p[3]}
        checks.append(('palette','AUTO',f'{len(visible)} visible colors across sampled PNGs; palette swatches={len(swatches)}; <=64={len(swatches)<=64}; missing swatches={len(visible-swatches)}'))
    # Runtime-code change audit relative to the merged R1 baseline.
    try:
        changed=git('diff','--name-only',f'{BASE}..HEAD','--','godot/scripts','godot/project.godot','godot/main.tscn').splitlines()
        wt=git('diff','--name-only','--','godot/scripts','godot/project.godot','godot/main.tscn').splitlines()
        checks.append(('runtime','AUTO',f'committed runtime paths changed since {BASE}: {len(changed)}; worktree runtime paths modified: {len(wt)}; paths={changed+wt}'))
    except Exception as e: checks.append(('runtime','PENDING',f'git baseline check unavailable: {e}'))
    for n in missing: checks.append((n,'PENDING','required item not present'))
    for name,status,detail in checks: print(f'{status}\t{name}\t{detail}')
    print('MANUAL\tpeople\t鞋左右脚色块、三人职业可辨性、是否84px实际身体、树团枝干形态与三阶暖光方向。')
    print('MANUAL\tmaterials\t检查九种材质纹样是否可辨、光向统一；依据报告的边缘跳变量在原尺寸和实际平铺下目视接缝。')
    print('MANUAL\tcar\t3/4俯视车顶造型；前后轮位置和轮数、斜车窗、71px立高；两种影子的接触暗边和右下约30%拖影。')
    print('MANUAL\tscale\t比例尺、同一素材原尺寸/2倍并排审看；核对84px人和门/桌椅/树/车的相对尺度。')
    print('MANUAL\truntime\t无运行代码差异只证明文件级未改；候选场景运行行为需独立核对。')
    print(f'INPUT_SHA256\t{hashlib.sha256("".join(sorted(missing)+[n+str(images[n].size) for n in images]).encode()).hexdigest()}')
    return 0 if not missing else 2

if __name__=='__main__': sys.exit(main())
