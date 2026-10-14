from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[4]
CONFIG = json.loads((HERE / "三套房屋布局-v5.json").read_text(encoding="utf-8"))


def crop_visible(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value >= 10 else 0)
    bbox = mask.getbbox()
    if bbox is None:
        raise ValueError(f"No visible pixels: {source}")
    return image.crop(bbox)


def fit_nearest(image: Image.Image, max_size: list[int]) -> Image.Image:
    max_width, max_height = max_size
    ratio = min(max_width / image.width, max_height / image.height)
    size = (max(1, round(image.width * ratio)), max(1, round(image.height * ratio)))
    return image.resize(size, Image.Resampling.NEAREST)


def add_ground_shadow(canvas: Image.Image, box: tuple[int, int, int, int]) -> None:
    left, top, right, bottom = box
    width = right - left
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    ellipse = (
        left + round(width * 0.12),
        bottom - 13,
        right - round(width * 0.12),
        bottom + 4,
    )
    draw.ellipse(ellipse, fill=(42, 73, 30, 62))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(2)))


def render_layout(layout: dict, sprites: dict[str, Image.Image]) -> list[dict]:
    canvas = Image.open(HERE / CONFIG["base"]).convert("RGBA")
    centers = layout["centers"]
    records = []
    order = sorted(CONFIG["houses"], key=lambda house: centers[house["id"]][1])
    for house in order:
        house_id = house["id"]
        sprite = sprites[house_id]
        center_x, center_y = centers[house_id]
        left = round(center_x - sprite.width / 2)
        top = round(center_y - sprite.height / 2)
        box = (left, top, left + sprite.width, top + sprite.height)
        add_ground_shadow(canvas, box)
        canvas.alpha_composite(sprite, (left, top))
        records.append({"id": house_id, "title": house["title"], "box": list(box)})
    canvas.save(HERE / layout["output"])
    return records


def main() -> None:
    sprites = {}
    for house in CONFIG["houses"]:
        source = PROJECT / house["source"]
        sprites[house["id"]] = fit_nearest(crop_visible(source), house["max_size"])

    results = {}
    for layout in CONFIG["layouts"]:
        results[layout["id"]] = render_layout(layout, sprites)
        print(layout["id"], layout["name"], layout["output"], len(results[layout["id"]]))

    (HERE / "三套布局房屋边界-v5.json").write_text(
        json.dumps(results, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
