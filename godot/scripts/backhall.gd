extends "res://scripts/entrance.gd"
## 罗曼山庄 · 后厅（蓝图 3.3，灰盒，01 9/19 派任务 7）：宴会楼后面，南边一条走廊，四个房间一字排开、门朝南，像剖开的房子。
## 全部代码画的占位（assets/layered/scene_luoman_backhall/layout.json），搭法、走路、交互点进出信号都和迎宾院一样（entrance.gd），
## 只换布局。西口回宴会厅、东口是厨房后门去草坪（草坪没做，出「还没修好」）；四个房间各一句话，按钮在 backhall_ui.gd

func _init() -> void:
    layout_path = "res://assets/layered/scene_luoman_backhall/layout.json"

const CanvasAssets = preload("res://scripts/canvas_assets.gd")
const KitchenArt = preload("res://scripts/kitchen/kitchen_art.gd")
signal kitchen_requested
var pending_cook := false
var kitchen_walkers: Array = []
# K8（04 10/1 挡路）：进后厅第一眼只看到「回宴会厅」，厨房在最东头屏幕外。照迎宾院签到台那个做法，
# 厨房在屏幕外时屏幕边一个金色小箭头指着它；走到厨房门口（离大锅 KITCHEN_NEAR 以内）就收，下回进后厅再出
var kitchen_arrow: Polygon2D
var kitchen_hint := true
const KITCHEN_NEAR := 220.0

func build(preset: int, nickname: String, f: Font) -> void:
    super(preset,nickname,f)
    var room := Sprite2D.new()
    room.texture = CanvasAssets.texture("res://assets/kitchen/kitchen_room_v1.png")
    if room.texture:
        room.centered = false
        room.position = Vector2(1008,104)
        room.scale = Vector2(528.0/room.texture.get_width(),586.0/room.texture.get_height())
        room.z_index = -9
        add_child(room)
    for id in ["counter_w","counter_e","brick_stove","pot"]:
        var item := world.get_node_or_null(id)
        if item: item.visible = false
    var stove := Sprite2D.new()
    stove.texture = KitchenArt.texture("soup")
    stove.position = Vector2(1272,296)
    stove.offset = Vector2(0,-stove.texture.get_height()/2.0)
    stove.scale = Vector2(100.0/stove.texture.get_width(),70.0/stove.texture.get_height())
    world.add_child(stove)
    for prop in [{"id":"board","region":Rect2(60,228,809,571),"at":Vector2(1140,452),"size":Vector2(112,62)},{"id":"bowl_table","region":Rect2(1233,186,460,613),"at":Vector2(1410,456),"size":Vector2(65,62)}]:
        var old_prop := world.get_node_or_null(prop.id)
        if old_prop: old_prop.visible = false
        var tx := AtlasTexture.new()
        tx.atlas = CanvasAssets.texture("res://assets/kitchen/kitchen_tables_v1.png")
        tx.region = prop.region
        var sprite := Sprite2D.new()
        sprite.texture = tx
        sprite.position = prop.at
        sprite.offset = Vector2(0,-tx.region.size.y/2.0)
        sprite.scale = Vector2(prop.size.x/tx.region.size.x,prop.size.y/tx.region.size.y)
        world.add_child(sprite)
    if npc_nodes.has("cook"):
        var cook: Sprite2D = npc_nodes.cook
        cook.texture = KitchenArt.texture("chef")
        cook.hframes = 1
        cook.frame = 0
        cook.offset = Vector2(0,-cook.texture.get_height()/2.0)
        cook.scale = Vector2.ONE * (84.0/cook.texture.get_height())
        cook.set_meta("base_offset",cook.offset)
    for i in 2:
        var waiter := Sprite2D.new()
        waiter.texture = KitchenArt.texture("male" if i == 0 else "female")
        waiter.offset = Vector2(0,-waiter.texture.get_height()/2.0)
        waiter.scale = Vector2.ONE * (84.0/waiter.texture.get_height())
        waiter.position = Vector2(1245+i*90,565)
        world.add_child(waiter)
        kitchen_walkers.append(waiter)

func reset_to(p: Vector2) -> void:
    super(p)
    kitchen_hint = true   # 每回进后厅都重新指一次

func _process(dt: float) -> void:
    super(dt)
    if kitchen_arrow == null:
        kitchen_arrow = edge_arrow()
        add_child(kitchen_arrow)
    if kitchen_hint and pos.distance_to(spot_pos("pot")) < KITCHEN_NEAR:
        kitchen_hint = false
    point_edge_arrow(kitchen_arrow, spot_pos("pot"), kitchen_hint and visible)
    if pending_cook and walking_enabled and pos.distance_to(spot_pos("pot")) < 60:
        pending_cook = false
        path.clear()
        kitchen_requested.emit()
    for i in kitchen_walkers.size():
        var waiter: Sprite2D = kitchen_walkers[i]
        waiter.position = Vector2(1245+i*90,565+sin(t*0.7+i*PI)*52)
        waiter.offset.y = -waiter.texture.get_height()/2.0 + sin(t*9+i)*3

func tap(screen: Vector2) -> void:
    if not walking_enabled: return
    var at := get_viewport().get_canvas_transform().affine_inverse() * screen
    if Rect2(1210,210,124,110).has_point(at):
        pending_cook = true
        go_to(spot_pos("pot"))
        return
    pending_cook = false
    super(screen)
