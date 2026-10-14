from pathlib import Path
import json
from PIL import Image, ImageFilter

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[4]
spec = json.loads((HERE / "房屋布局与一键直达-v4.json").read_text())
base = Image.open(HERE / spec["ground"]).convert("RGBA")

def source_path(value):
    path = Path(value)
    return path if path.is_absolute() else REPO / path

def fit_sprite(src, box):
    alpha = src.getchannel("A")
    bbox = alpha.point(lambda x: 255 if x >= 10 else 0).getbbox()
    if bbox:
        src = src.crop(bbox)
    ratio = min(box[0] / src.width, box[1] / src.height)
    size = (max(1, round(src.width * ratio)), max(1, round(src.height * ratio)))
    return src.resize(size, Image.Resampling.NEAREST)

def paste_center(canvas, sprite, center):
    pos = (round(center[0] - sprite.width / 2), round(center[1] - sprite.height / 2))
    canvas.alpha_composite(sprite, pos)
    return [pos[0], pos[1], sprite.width, sprite.height]

hitboxes = {}
for house in spec["houses"]:
    if house.get("render") is False:
        continue
    sprite = fit_sprite(Image.open(source_path(house["source"])).convert("RGBA"), house["max_size"])
    hitboxes[house["id"]] = paste_center(base, sprite, house["center"])

base.save(HERE / "方案二-真实房屋缩小地图-v4.png")

# A single representative selection state: the golden contour belongs to UI only,
# and does not alter the real Kaikai house pixels used by the clean map.
selected = base.copy()
kaikai = spec["houses"][7]
sprite = fit_sprite(Image.open(source_path(kaikai["source"])).convert("RGBA"), kaikai["max_size"])
alpha = sprite.getchannel("A").point(lambda x: 255 if x >= 18 else 0)
outline = alpha.filter(ImageFilter.MaxFilter(15))
ring = Image.new("RGBA", sprite.size, (255, 211, 74, 0))
ring.putalpha(outline)
pos = (round(kaikai["center"][0] - sprite.width / 2), round(kaikai["center"][1] - sprite.height / 2))
selected.alpha_composite(ring, pos)
selected.alpha_composite(sprite, pos)
selected.save(HERE / "凯凯家-点击态预览-v4.png")

print(json.dumps({"map": base.size, "houses": len(spec["houses"]), "hitboxes": hitboxes}, ensure_ascii=False))
