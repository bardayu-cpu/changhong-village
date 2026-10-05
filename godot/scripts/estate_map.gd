extends Control
## 罗曼山庄全景地图（07 10/4，蓝图第 22 条，01 H 派）：入口在左上角「罗曼山庄」名字牌里（阿鱼：「快捷切换地图的入口放到罗曼山庄几个字里边，加一个传送门的 icon 就行了」）——
## 签到以后名字后面多一个像素传送门小图标，点名字牌打开；签到前照旧只有名字、点了没反应。点开是整座山庄，每块写名字、标出你在哪；
## 点一块先问「去 XX？」（去 / 不去），点「去」淡出淡入到那块的门口站好；点自己那块提示「你就在这里」。
## 阿鱼原话：「但是地区位太大了呢，你就需要有一些直达的切换的路径。所以左上角应该是能够看到这一整个地图，然后用户点了之后就可以问他确认一下是不是要直接传送过去，
## 或者点了之后就直接传送好吧」「这个地图这种展开的区域地图的话，你也可以把它做一张地图，就绘制得好一点。如果你不会画，你就让GPT来帮你画得更写真一点」
## 地图是代码画的（像素硬边、暖色，跟游戏一个画风），数据在 assets/map/estate_map.json（tools/layout_court/make_estate_map.py 从连法总图、各块布局出，
## 各块挪了、加了口重跑就跟着变）。开车、说话框开着、厨房小游戏、签到前都打不开（can_open）。确认框先用游戏现有的深底金边框，05 定了新样子再统一换

const DATA := "res://assets/map/estate_map.json"
const MAP_W := 512.0            # 地图在屏幕上多宽（540 宽算）
const INK := Color("#3e2a24")
const PAPER := Color("#f3e6c8")
const FILL := {"hall": Color("#9c3d2e"), "house": Color("#c19a68"), "yard": Color("#d9c9a8"), "grass": Color("#7fa85c"),
    "water": Color("#d9c9a8"), "lot": Color("#77716c"), "plaza": Color("#d6c8a6"), "gate": Color("#a83a30")}
const TEXT := {"hall": PAPER, "house": INK, "yard": INK, "grass": INK, "water": INK, "lot": PAPER, "plaza": INK, "gate": PAPER}

var m                            # main.gd
var data: Dictionary = {}
var lines: Dictionary = {}
var chip: Control                # 左上角「罗曼山庄」名字牌（main.gd 建的），点它开地图
var icon: PortalIcon             # 名字后面的传送门小图标
var overlay: Control             # 打开时整屏一层
var view: MapView
var confirm: PanelContainer
var confirm_label: Label
var hint: Label
var picked := ""                 # 点了哪块、在问去不去
var walk_was := false            # 打开前那块画布能不能走（关了照旧）
var flash_left := 0.0            # 传送门图标还要闪多久（秒）：签到后图标出来时闪几下，点开过一次地图就不再闪（第 69 版小修，04：图标小，长辈未必知道能点）
const FLASH_SECS := 4.0

func setup(main_ref, place_chip: Control) -> void:
    m = main_ref
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var raw = JSON.parse_string(FileAccess.get_file_as_string(DATA))
    data = raw if raw is Dictionary else {}
    lines = data.get("lines", {})
    chip = place_chip
    chip.mouse_filter = Control.MOUSE_FILTER_STOP
    chip.gui_input.connect(func(e):
        if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
            if icon.visible:
                open()
                chip.accept_event())
    icon = PortalIcon.new()
    icon.name = "portal_icon"
    icon.custom_minimum_size = Vector2(24, 28)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.visible = false
    var row: Node = chip.get_node_or_null("row")
    (row if row != null else chip).add_child(icon)
    _build_overlay()

func _t(k: String) -> String:
    return str(lines.get(k, k))

func _build_overlay() -> void:
    overlay = Control.new()
    overlay.name = "estate_map"
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.visible = false
    add_child(overlay)
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.55)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    dim.gui_input.connect(func(e):
        if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed and confirm.visible:
            _cancel())
    overlay.add_child(dim)
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", m._sb(Color(0.12, 0.07, 0.06, 0.97), m.GOLD, 3, 10, 10))
    panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
    panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    panel.offset_top = 120
    overlay.add_child(panel)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 8)
    panel.add_child(v)
    var head := HBoxContainer.new()
    v.add_child(head)
    var title: Label = m._label(_t("title"), 28, m.GOLD1, HORIZONTAL_ALIGNMENT_LEFT, false)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(title)
    var close := Button.new()
    close.name = "map_close"
    close.text = _t("close")
    close.custom_minimum_size = Vector2(96, 48)
    close.pressed.connect(close_map)
    head.add_child(close)
    view = MapView.new()
    view.owner_map = self
    view.font = m.font
    view.mouse_filter = Control.MOUSE_FILTER_STOP
    v.add_child(view)
    view.setup(data, MAP_W)
    view.picked.connect(_on_pick)
    hint = m._label("", 22, m.PAPER, HORIZONTAL_ALIGNMENT_CENTER, false)
    hint.custom_minimum_size = Vector2(0, 30)
    v.add_child(hint)
    # 确认框：游戏现有的深底金边框，问「去 XX？」两个键
    confirm = PanelContainer.new()
    confirm.name = "map_confirm"
    confirm.add_theme_stylebox_override("panel", m._sb(Color(0.106, 0.078, 0.133, 0.97), m.GOLD1, 2, 8, 16))
    confirm.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    confirm.grow_horizontal = Control.GROW_DIRECTION_BOTH
    confirm.grow_vertical = Control.GROW_DIRECTION_BEGIN
    confirm.offset_bottom = -180
    confirm.visible = false
    overlay.add_child(confirm)
    var cv := VBoxContainer.new()
    cv.add_theme_constant_override("separation", 12)
    confirm.add_child(cv)
    confirm_label = m._label("", 28, m.GOLD1, HORIZONTAL_ALIGNMENT_CENTER, false)
    cv.add_child(confirm_label)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 24)
    cv.add_child(row)
    var yes := Button.new()
    yes.name = "map_yes"
    yes.text = _t("yes")
    yes.custom_minimum_size = Vector2(140, 56)
    yes.pressed.connect(_go)
    row.add_child(yes)
    var no := Button.new()
    no.name = "map_no"
    no.text = _t("no")
    no.custom_minimum_size = Vector2(140, 56)
    no.pressed.connect(_cancel)
    row.add_child(no)

## 现在能不能开：签过到、人在能走的场景里、没在开车切画布、说话框和各种面板都关着、这块画布能走（厨房小游戏不算场景）
func can_open() -> bool:
    if m == null or not m.court_save.signed_in or not m._in_scene() or m.driving or m.switching:
        return false
    if m.dialog.visible or m.whisper_box.visible or m.book_open or m.card_open:
        return false
    if m.lounge_ui != null and m.lounge_ui.is_open():
        return false
    return m.cv != null and m.cv.walking_enabled

func is_open() -> bool:
    return overlay.visible

## main 每帧调：传送门图标签过到、人在场景里才出（说话、开车时图标照样在，点了不开——can_open 管）；
## 没点开过地图的，图标每回出来闪几下（一亮一暗），点开过一次就不闪了（存档 map_used）
func sync() -> void:
    if icon == null:
        return
    var show: bool = m.court_save.signed_in and m._in_scene()
    if show and not icon.visible and not m.court_save.map_used:
        flash_left = FLASH_SECS
    icon.visible = show
    var dt := get_process_delta_time()
    if flash_left > 0.0 and not m.court_save.map_used:
        flash_left = maxf(flash_left - dt, 0.0)
        icon.modulate.a = 0.3 + 0.7 * absf(cos((FLASH_SECS - flash_left) * PI * 2.0))
    else:
        flash_left = 0.0
        icon.modulate.a = 1.0

func open() -> void:
    if overlay.visible or not can_open():
        return
    walk_was = m.cv.walking_enabled
    m.cv.walking_enabled = false
    m.cv.path.clear()
    m.cv.stick = Vector2.ZERO
    view.here = here_id()
    view.here_at = here_pos()
    view.queue_redraw()
    hint.text = ""
    confirm.visible = false
    picked = ""
    overlay.visible = true
    if not m.court_save.map_used:
        m.court_save.map_used = true   # 点开过一次了：图标不再闪
        m.court_save.save()
    flash_left = 0.0
    print("[suqi] 打开地图 在 ", view.here)

func close_map() -> void:
    overlay.visible = false
    confirm.visible = false
    picked = ""
    if m.cv != null and m._in_scene():
        m.cv.walking_enabled = walk_was

## 你在哪块（宴会厅、迎宾院、各块画布 = main 的 state）
func here_id() -> String:
    return str(m.state)

## 你在那块画布里的位置（画布像素）
func here_pos() -> Vector2:
    return m.cv.pos if m.cv != null else Vector2.ZERO

func block(id: String) -> Dictionary:
    for b in data.get("blocks", []):
        if str(b["id"]) == id:
            return b
    return {}

func _on_pick(id: String) -> void:
    var b := block(id)
    if b.is_empty():
        return
    if id == here_id():
        confirm.visible = false
        picked = ""
        hint.text = _t("here")
        return
    picked = id
    hint.text = ""
    confirm_label.text = _t("go_fmt") % str(b["name"])
    confirm.visible = true

func _cancel() -> void:
    confirm.visible = false
    picked = ""

## 传送过去站哪：那块布局里门口那个口的里边（arrival_at，能走的地上）；spawn 是出生点（迎宾院大门里边）；宴会厅照它自己的进门站法（厅门口），回 ZERO
func target_pos(id: String) -> Vector2:
    var b := block(id)
    if id == "banquet" or b.is_empty():
        return Vector2.ZERO
    if id != "court":
        m.ensure_canvas(id)
    var c = m.court if id == "court" else m._canvas_by(id)
    if c == null:
        return Vector2.ZERO
    var door := str(b.get("door", "spawn"))
    if door == "spawn" or not c.points.has(door):
        return c.SPAWN
    return c.arrival_at(door)

func _go() -> void:
    var id := picked
    if id == "":
        return
    var at := target_pos(id)
    var name := str(block(id).get("name", id))
    close_map()
    print("[suqi] 地图传送 到 ", id, " 站 ", at)
    await m.teleport_to(id, at)
    if m.state == id:
        m._note(_t("arrive_fmt") % name, 2.5)   # 到了说一句（第 69 版小修，04：长辈才知道自己到了哪；字待校对）

## 传送门小图标（像素硬边，跟名字牌一套金色）：一道拱门，门里一圈紫蓝的漩涡，慢慢转
class PortalIcon extends Control:
    var t := 0.0
    func _process(dt: float) -> void:
        if is_visible_in_tree():
            t += dt
            queue_redraw()
    func _draw() -> void:
        var o := ((size - Vector2(20, 24)) * 0.5).floor()
        var gold := Color("#ffd75e")
        var dark := Color("#3e2a24")
        # 门框：两根柱 + 半圆拱（一格一格的方块拼）
        var frame := [Vector2(0, 8), Vector2(0, 12), Vector2(0, 16), Vector2(0, 20), Vector2(16, 8), Vector2(16, 12), Vector2(16, 16), Vector2(16, 20),
            Vector2(2, 4), Vector2(14, 4), Vector2(4, 2), Vector2(12, 2), Vector2(6, 0), Vector2(8, 0), Vector2(10, 0)]
        for q in frame:
            draw_rect(Rect2(o + q - Vector2(1, 1), Vector2(6, 6)), dark)
        for q in frame:
            draw_rect(Rect2(o + q, Vector2(4, 4)), gold)
        # 门里的漩涡：两色方块绕着转
        var inner := Rect2(o + Vector2(4, 6), Vector2(12, 18))
        draw_rect(inner, Color("#3b2a6e"))
        var c := inner.get_center()
        for i in 6:
            var a := t * 3.0 + TAU * float(i) / 6.0
            var p := (c + Vector2(cos(a) * 4.0, sin(a) * 6.0) - Vector2(1, 1)).floor()
            draw_rect(Rect2(p, Vector2(2, 2)), Color("#8fd3ff") if i % 2 == 0 else Color("#c38fff"))
        draw_rect(Rect2((c - Vector2(1, 1)).floor(), Vector2(2, 2)), Color("#ffffff"))

## 地图本身：代码画的像素地图。点到哪块发 picked
class MapView extends Control:
    signal picked(id: String)
    var owner_map
    var font: Font
    var blocks: Array = []
    var roads: Array = []
    var origin := Vector2.ZERO   # 连法坐标 bounds 左上
    var k := 1.0                 # 连法坐标 → 屏幕
    var here := ""
    var here_at := Vector2.ZERO
    var t := 0.0

    func setup(d: Dictionary, width: float) -> void:
        blocks = d.get("blocks", [])
        roads = d.get("roads", [])
        var bd: Array = d.get("bounds", [0, 0, 1, 1])
        origin = Vector2(float(bd[0]) - 14.0, float(bd[1]) - 14.0)
        var span := Vector2(float(bd[2]) - float(bd[0]) + 28.0, float(bd[3]) - float(bd[1]) + 28.0)
        k = width / span.x
        custom_minimum_size = (span * k).floor()

    func _process(dt: float) -> void:
        if is_visible_in_tree():
            t += dt
            queue_redraw()

    func to_view(p: Vector2) -> Vector2:
        return ((p - origin) * k).floor()

    func rect_of(b: Dictionary) -> Rect2:
        var r: Array = b["rect"]
        var a := to_view(Vector2(float(r[0]), float(r[1])))
        var c := to_view(Vector2(float(r[2]), float(r[3])))
        return Rect2(a, c - a)

    func block_at(p: Vector2) -> String:
        var best := ""
        for b in blocks:
            if rect_of(b).grow(4.0).has_point(p):
                best = str(b["id"])
        return best

    func _gui_input(e: InputEvent) -> void:
        if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
            var id := block_at(e.position)
            if id != "":
                picked.emit(id)
            accept_event()

    func _draw() -> void:
        var full := Rect2(Vector2.ZERO, size)
        draw_rect(full, Color("#5f8f55"))
        # 外面一圈稀疏的草点（像素地面感）
        for i in 60:
            var q := Vector2(fmod(float(i) * 97.0, size.x), fmod(float(i) * 53.0 + 11.0, size.y)).floor()
            draw_rect(Rect2(q, Vector2(2, 2)), Color("#6f9f60"))
        # 湖（湖边那块北边一大片水）
        for b in blocks:
            if str(b["kind"]) == "water":
                var r := rect_of(b)
                var water := Rect2(Vector2(r.position.x - 6.0, 0.0), Vector2(r.size.x + 12.0, r.position.y + 2.0))
                draw_rect(water, Color("#6fa8cf"))
                for j in 6:
                    var y := water.position.y + 8.0 + float(j) * floorf(water.size.y / 7.0)
                    draw_rect(Rect2(Vector2(water.position.x + 14.0 + float(j % 2) * 30.0, y), Vector2(18, 2)), Color("#a8d0ea"))
        # 路：两块之间能直接走过去的，画沙色宽线（先画，块盖在上面，看得见的是块中间那截）
        for rd in roads:
            var a := to_view(Vector2(float(rd[2]), float(rd[3])))
            var c := to_view(Vector2(float(rd[4]), float(rd[5])))
            draw_line(a, c, Color(0.89, 0.81, 0.6, 0.45), 3.0)   # 路淡一点、细一点（04：原来一圈深边像蜘蛛网）
        for b in blocks:
            _draw_block(b)
        # 你在这：那块里你站的位置（画布坐标换算），金圈一闪一闪 +「你」
        for b in blocks:
            if str(b["id"]) != here:
                continue
            var r := rect_of(b)
            var sz: Array = b["size"]
            # 金点放在那块的上沿（左右照你在那块里站哪），不盖住块中间的名字（04）；
            # 块在地图最上面、上头没地方挂「你」的（后门）：金点挂在块的右边沿，「你」挂在块右边（03 收尾复核：原来盖住「后门」上半截）
            var fx := clampf(here_at.x / maxf(1.0, float(sz[0])), 0.1, 0.9)
            var th0 := font.get_height(18) if font != null else 24.0
            var no_room_above: bool = r.position.y < th0 + 10.0
            var p := Vector2(r.end.x, r.get_center().y).floor() if no_room_above else Vector2(r.position.x + r.size.x * fx, r.position.y).floor()
            var pulse := 5.0 + absf(sin(t * 4.0)) * 3.0
            draw_circle(p, pulse + 2.0, Color("#3e2a24"), true, -1.0, false)
            draw_circle(p, pulse, Color("#ffd75e"), true, -1.0, false)
            if font != null:
                # 「你」挂在那块上沿外面（不盖住块的名字），一根竖线连到金点
                var me := str(owner_map._t("me"))
                var w := font.get_string_size(me, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
                var th := font.get_height(18)
                var tp := Vector2(clampf(p.x - w * 0.5 - 4.0, 0.0, size.x - w - 8.0), maxf(0.0, r.position.y - th - 6.0)).floor()
                if no_room_above:
                    tp = Vector2(p.x + pulse + 6.0, p.y - th * 0.5).floor()
                    draw_line(Vector2(tp.x, p.y), p, Color("#3e2a24"), 2.0)
                else:
                    draw_line(Vector2(p.x, tp.y + th), p, Color("#3e2a24"), 2.0)
                draw_rect(Rect2(tp, Vector2(w + 8.0, th)), Color("#3e2a24"))
                draw_string(font, tp + Vector2(4.0, font.get_ascent(18)), me, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffd75e"))

    func _draw_block(b: Dictionary) -> void:
        var r := rect_of(b)
        var kind := str(b["kind"])
        var fill: Color = owner_map.FILL.get(kind, Color("#c19a68"))
        draw_rect(r, INK)
        var inner := r.grow(-2.0)
        draw_rect(inner, fill)
        match kind:
            "hall", "house", "gate":   # 屋顶：上面一条深一点的瓦檐
                draw_rect(Rect2(inner.position, Vector2(inner.size.x, minf(6.0, inner.size.y * 0.25))), fill.darkened(0.25))
            "yard":                     # 迎宾院：正中一条红毯
                draw_rect(Rect2(Vector2(inner.get_center().x - 3.0, inner.position.y), Vector2(6, inner.size.y)), Color("#b0322a"))
            "plaza":                    # 喷泉
                draw_circle(inner.get_center().floor(), minf(inner.size.x, inner.size.y) * 0.18, Color("#6fa8cf"), true, -1.0, false)
            "lot":                      # 车位线
                var x := inner.position.x + 6.0
                while x < inner.end.x - 4.0:
                    draw_rect(Rect2(Vector2(x, inner.position.y + 4.0), Vector2(1, inner.size.y * 0.35)), Color("#e8e4d8"))
                    x += 8.0
            "grass":                    # 几簇深绿
                for i in 5:
                    var q := inner.position + Vector2(fmod(float(i) * 23.0 + 5.0, maxf(4.0, inner.size.x - 6.0)), fmod(float(i) * 17.0 + 7.0, maxf(4.0, inner.size.y - 6.0)))
                    draw_rect(Rect2(q.floor(), Vector2(4, 3)), fill.darkened(0.2))
        if str(b["id"]) == here:
            draw_rect(r.grow(1.0), Color("#ffd75e"), false, 2.0)
        if font != null:
            _draw_name(str(b.get("short", b["name"])), inner, owner_map.TEXT.get(kind, INK))

    ## 名字：一行、18 号（像素字 18 号以下会缩成 12 像素一格，长辈看不清）、不垫底。写不下的块在地图数据里用短叫法（short，make_estate_map.py 的 SHORT）
    func _draw_name(name: String, r: Rect2, col: Color) -> void:
        var fs := 18
        var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
        var p := Vector2(r.get_center().x - w * 0.5, r.get_center().y - font.get_height(fs) * 0.5 + font.get_ascent(fs)).floor()
        draw_string(font, p, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

    ## 名字放不放得下（测试用）
    func name_fits(b: Dictionary) -> bool:
        var r := rect_of(b).grow(-2.0)
        return font.get_string_size(str(b.get("short", b["name"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x <= r.size.x - 2.0
