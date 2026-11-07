"""把男女主角所有图拼成一张对照表，用来走查形象是否一致、肢体是否正常（R8）。
用法：python3 godot/hongyuan/tools/char_sheet.py 输出.png
新图进来先跑一遍，和第一格的标准形象逐张对比。"""
import glob, os, sys
from PIL import Image, ImageDraw
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets')
fs = sorted(f for f in glob.glob(os.path.join(root, '**/*.png'), recursive=True)
            if ('ayu' in f.lower() or 'toretto' in f.lower()) and 'w2_review' not in f and 'avatar' not in f)
cells = []
for f in fs:
    im = Image.open(f).convert('RGBA')
    if im.getbbox():
        im = im.crop(im.getbbox())
    im.thumbnail((150, 190))
    cells.append((os.path.relpath(f, root), im))
cols, W, H = 8, 160, 215
sheet = Image.new('RGB', (cols * W, ((len(cells) + cols - 1) // cols) * H), (235, 230, 220))
d = ImageDraw.Draw(sheet)
for i, (f, im) in enumerate(cells):
    x, y = (i % cols) * W, (i // cols) * H
    sheet.paste(im, (x + 5 + (150 - im.width) // 2, y + 5 + (190 - im.height)), im)
    d.text((x + 3, y + 200), '%d %s' % (i, os.path.basename(f)[:22]), fill=(0, 0, 0))
sheet.save(sys.argv[1] if len(sys.argv) > 1 else 'char_sheet.png')
for i, (f, _) in enumerate(cells):
    print(i, f)
