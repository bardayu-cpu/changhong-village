extends Node
## 进山庄自动开车（10/4 连图，01 G 派；阿鱼原话：「先要走大门，然后绕喷泉开一圈，去到停车场停车，然后再从停车场走出来，去到迎宾院……
## 开车这一步变成自动的，所以每次进来都绕着那个喷泉绕一圈，去到停车场找个车位停车」）：
##   10/4 第 68 版（07，阿鱼：「中国是绕右开，所以，应该是先看见喷泉广场，然后直接往右开，拐进停车场」「你的前门就要挪到正对着喷泉了，
##   不然没有人会去故意绕一下」）：前门挪到喷泉正下方，不绕整圈——
##   前门：车从山庄外头的路开进门楼，直直往上开 → 喷泉广场：从南边正中进来，喷泉就在正前方；开到喷泉跟前靠右、右拐，沿车道往东出 →
##   停车场：从西边上面那个口进来（跟车道一条线），开到自己的车位倒进去停好 → 人下车
##   （原来：前门往西拐 → 广场东进、绕一圈、东出 → 停车场西进，左右来回折腾）
## 每次进山庄都播（新号、老号都是）；看过一次以后点一下屏幕就跳过（01 默认，阿鱼看了再改）。倒车小游戏以后补，这次不做。
## 做法：车就是画布上的「人」——把人藏起来、在人的脚点画一辆车，脚点照路线挪，镜头照旧跟着脚点走；三块画布之间照常淡出淡入

const SPEED := 330.0            # 车开多快（画布像素/秒）
const MINE := ["#c0392b", "#8c2a20"]   # 自己的车（跟停车场 car_mine 一个色）
const CAR_LEN_H := 221.0        # 车横着开：长 4.6 米 × 48
const CAR_DEP_H := 58.0         # 宽 1.8 米 × 32
const CAR_W_V := 86.0           # 车竖着开：宽 1.8 米 × 48
const CAR_LEN_V := 147.0        # 长 4.6 米 × 32
const CAR_H := 71.0             # 车高 1.48 米

var m                           # main.gd
var skipped := false
var leg := ""                   # 现在开到哪一段（截图、测试看）
var car: Node2D
var paused := false             # 截图用：车停在路上那一格不动
var leg_t := 0.0                # 这一段开了多久（截图用）

## 三段路线（画布坐标）
const GATE_ROUTE := [Vector2(768, 990), Vector2(768, 36)]          # 前门：门洞正对广场，直直往上开（make_areas.py 前门北口 x 768）
## 喷泉广场：南边正中进来（喷泉正前方）→ 开到喷泉跟前（广场车道 y 780 那条线）靠右、右拐 → 沿车道往东出（make_plaza.py 的 DRIVE_Y、东口去停车场）
const PLAZA_ROUTE := [Vector2(768, 1010), Vector2(768, 812), Vector2(782, 788), Vector2(810, 780), Vector2(1510, 780)]
## 停车场：西边上面那个口进来，沿 B、C 两排中间的车道开到自己车位跟前，倒进去（车头朝北）。照停车场布局算（make_parking.py 的 to_plaza、car_mine），
## 布局改了不用改这里。10/4 03 测第 65 版：车道走 y 800 时车顶压在北边那排车上，车道定在靠南（846）
func park_route() -> Array:
    var cfg: Dictionary = m.parking.cfg
    var lane_y := 846.0
    for p in cfg.get("points", []):
        if str(p["id"]) == "to_plaza":
            lane_y = float(p["y"])
    var mine := Rect2()
    for it in cfg.get("items", []):
        if str(it.get("id", "")) == "car_mine":
            var r: Array = it["rect"]
            mine = Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
    var cx := mine.get_center().x
    return [Vector2(24, lane_y), Vector2(cx, lane_y), Vector2(cx, mine.end.y)]

func setup(main_ref) -> void:
    m = main_ref

## 看过一次以后开车时屏幕下方一行小字「点一下屏幕跳过」（04 看第 65 版，01 G 派；界面字，不画进图；待校对）
const LINE_SKIP := "点一下屏幕跳过"
var tip: PanelContainer

func _show_tip() -> void:
    tip = PanelContainer.new()
    tip.name = "drive_skip_tip"
    tip.add_theme_stylebox_override("panel", m._sb(Color(0.106, 0.078, 0.133, 0.85), m.GOLD1, 2, 6, 12))
    tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tip.add_child(m._label(LINE_SKIP, 22, m.GOLD1, HORIZONTAL_ALIGNMENT_CENTER, false))
    tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    tip.grow_horizontal = Control.GROW_DIRECTION_BOTH
    tip.grow_vertical = Control.GROW_DIRECTION_BEGIN
    tip.offset_bottom = -200
    tip.offset_top = -200
    m.hud.add_child(tip)

## 开一趟：可跳过的话点屏幕（main 的 _unhandled_input 调 skip）就直接到停车场下车
func play() -> void:
    skipped = false
    if m.court_save.drive_seen:
        _show_tip()
    for cn in ["frontgate", "plaza", "parking"]:
        m.ensure_canvas(cn)
    var parking = m.parking
    var mine: Node = parking.world.get_node_or_null("car_mine")
    if mine != null:
        mine.visible = false   # 自己的车开进来以前，车位是空的
    await _leg("frontgate", GATE_ROUTE, [])
    if not skipped:
        await _leg("plaza", PLAZA_ROUTE, [])
    if not skipped:
        await _leg("parking", park_route(), [])
    if mine != null:
        mine.visible = true
    _clear_car()
    if tip != null:
        tip.queue_free()
        tip = null
    leg = ""
    m.court_save.drive_seen = true
    m.court_save.save()

func skip() -> void:
    if m.court_save.drive_seen:
        skipped = true

## 一段：切到那块画布、人藏起来、车沿路线开；开完（或跳过）回来
func _leg(cn: String, route: Array, _extra: Array) -> void:
    leg = cn
    await m._fade_to(1.0)
    m._show_canvas(cn)
    m._goto(cn)
    var c = m.cv
    c.walking_enabled = false
    c.player.visible = false
    c.reset_to(route[0])
    _make_car(c)
    await m._fade_to(0.0)
    var i := 1
    var from: Vector2 = route[0]
    leg_t = 0.0
    while i < route.size() and not skipped:
        while paused:
            await get_tree().process_frame
        leg_t += 1.0 / 60.0
        var to: Vector2 = route[i]
        var d := from.distance_to(to)
        var step := SPEED * (1.0 / 60.0 if m.fast else get_process_delta_time())
        if d <= step:
            from = to
            i += 1
        else:
            from = from + (to - from) / d * step
        c.pos = from
        _place_car(c, to - from)
        await get_tree().process_frame
    c.player.visible = true
    _clear_car()

func _make_car(c) -> void:
    _clear_car()
    car = Node2D.new()
    car.name = "drive_car"
    c.world.add_child(car)

func _clear_car() -> void:
    if car != null and is_instance_valid(car):
        car.queue_free()
    car = null

## 车画在脚点上：横着开画长条、竖着开画竖条（跟停车场的车一样是色块：前面一块、顶上一块）
func _place_car(c, dir: Vector2) -> void:
    if car == null:
        return
    car.position = c.pos
    var horizontal := absf(dir.x) >= absf(dir.y)
    if car.has_meta("h") and bool(car.get_meta("h")) == horizontal:
        return
    car.set_meta("h", horizontal)
    for ch in car.get_children():
        ch.queue_free()
    var w := CAR_LEN_H if horizontal else CAR_W_V
    var dpt := CAR_DEP_H if horizontal else CAR_LEN_V
    var front := Polygon2D.new()
    front.polygon = PackedVector2Array([Vector2(-w / 2, -CAR_H), Vector2(w / 2, -CAR_H), Vector2(w / 2, 0), Vector2(-w / 2, 0)])
    front.color = Color(MINE[1])
    car.add_child(front)
    var top := Polygon2D.new()
    top.polygon = PackedVector2Array([Vector2(-w / 2, -CAR_H - dpt), Vector2(w / 2, -CAR_H - dpt), Vector2(w / 2, -CAR_H), Vector2(-w / 2, -CAR_H)])
    top.color = Color(MINE[0])
    car.add_child(top)
    var glass := Polygon2D.new()   # 车窗：顶上一条深色
    var gw := w * 0.6 if horizontal else w * 0.7
    glass.polygon = PackedVector2Array([Vector2(-gw / 2, -CAR_H - dpt * 0.75), Vector2(gw / 2, -CAR_H - dpt * 0.75), Vector2(gw / 2, -CAR_H - dpt * 0.35), Vector2(-gw / 2, -CAR_H - dpt * 0.35)])
    glass.color = Color("#2b2833")
    car.add_child(glass)
