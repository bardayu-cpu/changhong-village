"""Check that road-border pixels never cut through the inner road network."""
from pathlib import Path
from PIL import Image, ImageDraw
import io, json, subprocess

root = Path(__file__).resolve().parents[1]
asset = 'godot/ayu_home/v4/assets/village/ground.png'
roads = json.loads((root/'godot/ayu_home/v4/assets/village/topology.json').read_text())['roads']
mask = Image.new('L', (1600, 4700//3))
draw = ImageDraw.Draw(mask)
for road in roads:
    points = [(int(x/3), int(y/3)) for x, y in road]
    draw.line(points, fill=255, width=26, joint='curve')
    for x, y in points:
        draw.ellipse((x-13, y-13, x+13, y+13), fill=255)
mask = mask.resize((4800, 4700), Image.Resampling.NEAREST)

def internal_borders(image):
    return sum(m and rgb == (168, 137, 86) for m, rgb in zip(mask.getdata(), image.convert('RGB').getdata()))

before = Image.open(io.BytesIO(subprocess.check_output(['git','show','30b0f16:'+asset], cwd=root)))
after = Image.open(root/asset)
bad_before, bad_after = internal_borders(before), internal_borders(after)
print(json.dumps({'road_count': len(roads), 'size': list(after.size), 'before_internal_border_pixels': bad_before, 'after_internal_border_pixels': bad_after}, ensure_ascii=False))
assert before.size == after.size == (4800,4700)
assert bad_before > 0, 'baseline must reproduce crossing border lines'
assert bad_after == 0, 'a border still cuts across the road interior'
print('B3_ROADS PASS; C3 normal route screenshots still required')
