extends RefCounted
const CanvasAssets = preload("res://scripts/canvas_assets.gd")
const REGIONS := {
    "male":Rect2(129,49,199,454),
    "female":Rect2(524,51,195,455),
    "chef":Rect2(932,54,242,454),
    "empty":Rect2(58,577,333,311),
    "soup":Rect2(462,578,331,311),
    "burnt":Rect2(863,577,332,311),
    "beef":Rect2(60,935,322,267),
    "tofu":Rect2(466,932,322,271),
    "noodles":Rect2(872,931,322,271)
}
static func texture(id: String) -> Texture2D:
    var atlas := AtlasTexture.new()
    atlas.atlas = CanvasAssets.texture("res://assets/kitchen/kitchen_atlas_v1.png")
    atlas.region = REGIONS.get(id,REGIONS.beef)
    return atlas
static func put(parent: Node, id: String, rect: Rect2) -> TextureRect:
    var t := TextureRect.new()
    t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.texture = texture(id)
    t.position = rect.position
    t.size = rect.size
    t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(t)
    return t
