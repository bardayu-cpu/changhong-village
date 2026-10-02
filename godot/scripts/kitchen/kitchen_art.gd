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
const UI_REFERENCE_SIZE := Vector2(941,1672)
const UI_REGIONS := {
    "汤底":Rect2(18,1184,137,174),
    "牛肉":Rect2(158,1184,143,174),
    "葱花":Rect2(304,1184,144,174),
    "香菜":Rect2(452,1184,143,174),
    "鸡蛋":Rect2(17,1363,139,184),
    "米饭":Rect2(159,1363,142,184),
    "凉粉":Rect2(304,1363,143,184),
    "辣椒":Rect2(451,1363,143,184),
    "plate":Rect2(596,1184,329,174),
    "serve":Rect2(574,1361,169,220),
    "deliver":Rect2(745,1361,181,220),
    "icon_汤底":Rect2(28,1202,117,94),
    "icon_牛肉":Rect2(173,1203,116,93),
    "icon_葱花":Rect2(318,1202,117,94),
    "icon_香菜":Rect2(465,1202,118,94),
    "icon_鸡蛋":Rect2(26,1381,119,91),
    "icon_米饭":Rect2(172,1380,117,93),
    "icon_凉粉":Rect2(318,1381,117,92),
    "icon_辣椒":Rect2(462,1380,123,94),
    "dish_egg_rice":Rect2(171,367,130,103),
    "dish_beef":Rect2(463,368,151,111),
    "dish_liangfen":Rect2(744,403,91,70)
}
static func texture(id: String) -> Texture2D:
    var atlas := AtlasTexture.new()
    atlas.atlas = CanvasAssets.texture("res://assets/kitchen/kitchen_atlas_v1.png")
    var source_rect: Rect2 = REGIONS.get(id,REGIONS.beef)
    var ratio := atlas.atlas.get_size() / Vector2(1254,1254)
    atlas.region = Rect2(source_rect.position * ratio, source_rect.size * ratio)
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

const PIECE_FILES := {
    "汤底":"cards/ingredient_soup_base.png","牛肉":"cards/ingredient_beef.png",
    "葱花":"cards/ingredient_scallion.png","香菜":"cards/ingredient_cilantro.png",
    "鸡蛋":"cards/ingredient_egg.png","米饭":"cards/ingredient_rice.png",
    "凉粉":"cards/ingredient_liangfen.png","辣椒":"cards/ingredient_chili.png",
    "plate":"cards/empty_plate.png","serve":"cards/button_serve.png","deliver":"cards/button_deliver.png",
    "dish_egg_rice":"dishes/dish_egg_rice.png","dish_beef":"dishes/dish_beef.png","dish_liangfen":"dishes/dish_liangfen.png"
}
static func reference_texture(id: String) -> Texture2D:
    if PIECE_FILES.has(id):
        var piece := CanvasAssets.texture("res://assets/kitchen/v2/"+str(PIECE_FILES[id]))
        if id == "dish_liangfen":
            var dish := AtlasTexture.new()
            dish.atlas = piece
            dish.region = Rect2(0,14,piece.get_width(),piece.get_height()-14)
            return dish
        return piece
    var atlas := AtlasTexture.new()
    atlas.atlas = CanvasAssets.texture("res://assets/kitchen/v2/kitchen_ui_reference_v2.png")
    var region: Rect2 = UI_REGIONS.get(id,UI_REGIONS.plate)
    atlas.region = Rect2(region.position * atlas.atlas.get_size()/UI_REFERENCE_SIZE,region.size * atlas.atlas.get_size()/UI_REFERENCE_SIZE)
    return atlas

static func put_reference(parent: Node, id: String, rect: Rect2) -> TextureRect:
    var t := TextureRect.new()
    t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.texture = reference_texture(id)
    t.position = rect.position
    t.size = rect.size
    t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(t)
    return t

# Source geometry is in approved-reference pixels; the renderer scales all layers together.
const REFERENCE := "res://assets/kitchen/v2/kitchen_ui_reference_v2.png"
const REFERENCE_REGIONS := {
    "sign":Rect2(0,0,263,148),
    "rank_frame":Rect2(285,5,291,71),
    "coin_frame":Rect2(592,5,310,71),
    "hat_icon":Rect2(306,16,59,43),
    "coin_icon":Rect2(615,17,51,44),
    "order_汤底":Rect2(463,478,48,42),
    "order_牛肉":Rect2(520,477,43,43),
    "order_香菜":Rect2(566,475,44,44),
    "order_葱花":Rect2(886,538,39,32),
    "order_鸡蛋":Rect2(176,474,37,46),
    "order_米饭":Rect2(236,475,58,43),
    "order_凉粉":Rect2(831,436,28,37),
    "order_辣椒":Rect2(860,437,33,38)
}

static func reference_region(region: Rect2) -> Texture2D:
    var atlas := AtlasTexture.new()
    atlas.atlas = CanvasAssets.texture(REFERENCE)
    var ratio := atlas.atlas.get_size() / UI_REFERENCE_SIZE
    atlas.region = Rect2(region.position * ratio,region.size * ratio)
    return atlas

static func put_source(parent: Node, region: Rect2, rect: Rect2) -> TextureRect:
    var t := TextureRect.new()
    t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.texture = reference_region(region)
    t.position = rect.position
    t.size = rect.size
    t.stretch_mode = TextureRect.STRETCH_SCALE
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(t)
    return t

# 顶栏 5 件（招牌、等级框、金币框、帽子、铜钱）：01 E 10/2 定，照 REFERENCE_REGIONS 的框从 v2 参考图切成 5 张小图
# （mobile/ui/kitchen_ui_<id>.png，像素一个不差），那张 2.6 MB 的参考图不进包
const PIECE_DIR := "res://assets/kitchen/mobile/ui/kitchen_ui_%s.png"

static func put_piece(parent: Node, id: String, rect: Rect2) -> TextureRect:
    var t := TextureRect.new()
    t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.texture = CanvasAssets.texture(PIECE_DIR % id)
    t.position = rect.position
    t.size = rect.size
    t.stretch_mode = TextureRect.STRETCH_SCALE
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(t)
    return t

const VISUAL_CONFIG := "res://data/kitchen/visual_assets.json"
static var visual_assets: Dictionary = _read_visual_assets()

static func _read_visual_assets() -> Dictionary:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(VISUAL_CONFIG))
    return parsed.get("assets",{}) if parsed is Dictionary else {}

static func put_configured(parent: Node, key: String, rect: Rect2, required := true) -> Control:
    var entry: Dictionary = visual_assets.get(key,{})
    var frames: Array = entry.get("frames",[])
    var valid := bool(entry.get("approved",false)) and not frames.is_empty()
    for path in frames:
        valid = valid and ResourceLoader.exists(str(path))
    if not valid:
        if not required: return null
        # Development-only missing slot: never substitute an unrelated dish or reference crop.
        var missing := Label.new()
        missing.text = "素材待补"
        missing.position = rect.position
        missing.size = rect.size
        missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        missing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        missing.mouse_filter = Control.MOUSE_FILTER_IGNORE
        missing.set_meta("asset_missing",key)
        parent.add_child(missing)
        return missing
    var sprite := TextureRect.new()
    # Ignore source pixel dimensions before assigning the texture/target rectangle.
    # Otherwise Control clamps the size to the original PNG and keeps that enlarged size.
    sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sprite.texture = _configured_texture(entry,str(frames[0]))
    sprite.position = rect.position
    sprite.size = rect.size
    sprite.stretch_mode = TextureRect.STRETCH_SCALE if bool(entry.get("stretch_scale",false)) else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
    sprite.set_meta("asset_key",key)
    sprite.set_meta("frames",frames)
    sprite.set_meta("frame_seconds",maxf(0.01,float(entry.get("frame_seconds",0.12))))
    sprite.set_meta("loop",bool(entry.get("loop",true)))
    sprite.set_meta("elapsed",0.0)
    sprite.set_meta("motion",str(entry.get("motion","")))
    sprite.set_meta("base_position",rect.position)
    sprite.set_meta("texture_entry",entry)
    parent.add_child(sprite)
    return sprite

static func update_animations(parent: Node, dt: float) -> void:
    for node in parent.get_children():
        if node is TextureRect and node.has_meta("frames"):
            var frames: Array = node.get_meta("frames")
            var elapsed: float = float(node.get_meta("elapsed")) + dt
            node.set_meta("elapsed",elapsed)
            var frame := int(elapsed / float(node.get_meta("frame_seconds")))
            frame = frame % frames.size() if bool(node.get_meta("loop")) else mini(frame,frames.size()-1)
            node.texture = _configured_texture(node.get_meta("texture_entry",{}),str(frames[frame]))
            if node.get_meta("motion","") == "rise":
                node.position = node.get_meta("base_position") + Vector2(0,-6.0*sin(elapsed*3.0))
            elif node.get_meta("motion","") == "pulse":
                var pulse := 1.0+0.035*sin(elapsed*8.0)
                node.scale = Vector2(pulse,pulse)
                node.position = node.get_meta("base_position")-node.size*(pulse-1.0)*0.5
        update_animations(node,dt)

static func _configured_texture(entry: Dictionary, path: String) -> Texture2D:
    var source := CanvasAssets.texture(path)
    var bounds: Array = entry.get("content_bounds",[])
    if bounds.size() != 4: return source
    # Remove only empty transparent padding at render time. The complete RGBA source
    # remains unchanged, and all visible pixels stay inside the configured bounds.
    var atlas := AtlasTexture.new()
    atlas.atlas = source
    var pixels: Array = entry.pixel_size
    var ratio := source.get_size()/Vector2(float(pixels[0]),float(pixels[1]))
    atlas.region = Rect2(Vector2(float(bounds[0]),float(bounds[1]))*ratio,Vector2(float(bounds[2]),float(bounds[3]))*ratio)
    return atlas

static func put_anchored(parent: Node, key: String, foot: Vector2) -> Control:
    var entry: Dictionary = visual_assets.get(key,{})
    var dimensions: Array = entry.get("pixel_size",[158,420])
    var anchor: Array = entry.get("foot_anchor",[79,420])
    var reference_scale := float(entry.get("scale_in_reference",1.0))
    var size := Vector2(float(dimensions[0]),float(dimensions[1]))*reference_scale
    var position := foot-Vector2(float(anchor[0]),float(anchor[1]))*reference_scale
    var sprite := put_configured(parent,key,Rect2(position,size))
    sprite.set_meta("foot_reference",foot)
    sprite.set_meta("foot_anchor",Vector2(float(anchor[0]),float(anchor[1]))*reference_scale)
    return sprite
