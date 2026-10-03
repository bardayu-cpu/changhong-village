extends Node2D
## 休息间的人（docs/人物新做法-休息间样板-v0.1.md 第 2、3 节，01 F 10/4）：后厅 backhall.gd 搭好以后挂上来。
##   冒泡：两三个人一组，头顶轮流冒像素对话气泡（白底深描边、小尾巴指着说话的人），几个字，几秒换下一个人；
##         话在 assets/backhall/lounge.json 的 chat（02 拟的，待校对）。玩家正在跟谁说话，那一组先停
##   坐下：休息间每个座位（layout.json 的 seats）都能坐；NPC 占着的不能坐。走到空座位跟前出「坐下」（按钮在 lounge_ui.gd），
##         坐下人滑到椅面上、朝向跟座位一致、只画上半身；再点或推摇杆就站起来，站到座位跟前那块空地上
##   说话：点 NPC（或走到跟前点「聊聊」）走过去，到了就弹对话框（lounge_ui.gd 管框）
## 人现在是 GPT 宾客图的上半截顶着（layout 的 standin，entrance.gd 画）；01 画的代码小人到了换图，这里不用改

signal talk_ready(id: String)   # 点了某位、走到他跟前了：lounge_ui 弹对话框

const DATA := "res://assets/backhall/lounge.json"
const SEAT_NEAR := 28.0         # 离座位跟前那块空地多近出「坐下」
const TALK_NEAR := 34.0         # 离 NPC 跟前多近算走到了（出「聊聊」、点了他走到就说）
const BUBBLE_HOLD := 2.6        # 一句冒多久
const BUBBLE_GAP := 0.9         # 一句收了隔多久下一个人说
const BUBBLE_POP := 0.12        # 冒出来那一下（从小变大）
const BUBBLE_FONT := 15         # 屏幕上的字号（540 宽算）：气泡按镜头缩放反着放大，后厅镜头缩到 0.5 多也认得出字
const INK := Color("#2b1d16")
const BUBBLE_BG := Color("#fffdf6")
const FACE_DIR := {"down": Vector2(0, 1), "up": Vector2(0, -1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}

var c                          # 后厅画布（backhall.gd）
var data: Dictionary = {}
var seats: Array = []          # [{id, x, y, seat_y, face, npc, stand}]
var people: Dictionary = {}    # id -> {code, title, relation, talk, seat, head, stand}
var groups: Array = []         # [{lines, i, t, showing, who}]
var bubbles: Dictionary = {}   # id -> Node2D
var my_seat := ""              # 玩家坐在哪个座位上（空的是没坐）
var pending_talk := ""         # 点了谁、正走过去
var talking := ""              # 正在跟谁说话（lounge_ui 开框时设、关框时清）
var frozen := false            # 截图用：冒泡停在那，不轮换

func setup(canvas) -> void:
    c = canvas
    z_index = 6                # 气泡压在人、家具上面
    var raw = JSON.parse_string(FileAccess.get_file_as_string(DATA))
    data = raw if raw is Dictionary else {}
    for s in c.cfg.get("seats", []):
        var seat: Dictionary = (s as Dictionary).duplicate()
        seat["stand"] = _stand_spot(seat)
        seats.append(seat)
    var pdata: Dictionary = data.get("people", {})
    for n in c.cfg.get("npcs", []):
        if not bool(n.get("lounge", false)):
            continue
        var id := str(n["id"])
        var sd: Dictionary = n.get("standin", {})
        var p: Dictionary = (pdata.get(id, {}) as Dictionary).duplicate()
        p["id"] = id
        p["code"] = str(p.get("code", sd.get("code", "")))
        p["foot"] = Vector2(float(n["x"]), float(sd.get("bottom", n["y"])))
        p["head"] = p["foot"] - Vector2(0, float(sd.get("rows", 48)))
        p["sort_y"] = float(n["y"])
        p["seat"] = ""
        for s in seats:
            if str(s.get("npc", "")) == id:
                p["seat"] = str(s["id"])
                p["stand"] = s["stand"]
        if not p.has("stand"):
            p["stand"] = _nearest_free(p["foot"] + Vector2(0, 30))
        people[id] = p
    var k := 0
    for g in data.get("chat", []):
        var lines: Array = (g.get("lines", []) as Array).filter(func(l): return people.has(str(l[0])))
        if lines.is_empty():
            continue
        groups.append({"lines": lines, "i": 0, "t": -0.8 - 1.7 * float(k), "showing": false, "who": ""})
        k += 1

## 座位跟前那块空地（起来站这、走到这出「坐下」）：座位朝向那边一步，找最近的能站的点
func _stand_spot(seat: Dictionary) -> Vector2:
    var d: Vector2 = FACE_DIR.get(str(seat["face"]), Vector2(0, 1))
    return _nearest_free(Vector2(float(seat["x"]), float(seat["seat_y"])) + d * 30.0)

func _nearest_free(p: Vector2) -> Vector2:
    var best := Vector2.ZERO
    var bd := INF
    for dy in range(-72, 73, 4):
        for dx in range(-72, 73, 4):
            var q := p + Vector2(dx, dy)
            var d := Vector2(dx, dy).length()
            if d < bd and c._free(q):
                bd = d
                best = q
    return best

# ---------- 座位 ----------
func seat_by_id(id: String) -> Dictionary:
    for s in seats:
        if str(s["id"]) == id:
            return s
    return {}

## 离玩家最近的、能坐的空座位（没人占、玩家站在它跟前）；坐着、走着路的时候没有
func near_seat() -> Dictionary:
    if c.seated or not c.path.is_empty():
        return {}
    var best: Dictionary = {}
    var bd := SEAT_NEAR
    for s in seats:
        if str(s.get("npc", "")) != "" or s["stand"] == Vector2.ZERO:
            continue
        var d: float = c.pos.distance_to(s["stand"])
        if d < bd:
            bd = d
            best = s
    return best

## 坐下：跟湖边长凳一个做法（layered_hall 的坐姿：只画上半身）。排前后用座位的 y（家具着地线 +1，画在家具前面），
## 上半身下沿画在椅面 seat_y（seat_lift 抬上去）
func sit(seat: Dictionary) -> void:
    if seat.is_empty() or str(seat.get("npc", "")) != "":
        return
    c.path.clear()
    c.stick = Vector2.ZERO
    c.sit_from = c.pos
    c.sit_seat = Vector2(float(seat["x"]), float(seat["y"]))
    c.sit_t = 0.0
    c.face = str(seat["face"])
    c.seated = true
    c.seat_front = false
    c.seat_lift = float(seat["y"]) - float(seat["seat_y"])
    c.seat_stand_spot = seat["stand"]
    my_seat = str(seat["id"])

func stand_up() -> void:
    c.stand_up()

## 每帧（backhall._process）：人自己站起来了就记成没坐；点了的人走到了就说；冒泡轮着来
func step(dt: float) -> void:
    if my_seat != "" and not c.seated:
        my_seat = ""
    if pending_talk != "":
        var p: Dictionary = people.get(pending_talk, {})
        if p.is_empty():
            pending_talk = ""
        elif c.path.is_empty():
            var id := pending_talk
            pending_talk = ""
            if c.pos.distance_to(p["stand"]) <= TALK_NEAR:
                c.face = c._face_for(p["foot"] - c.pos)
                talk_ready.emit(id)
    if not frozen:
        for g in groups:
            _step_group(g, dt)
    var full := _bubble_scale()
    for id in bubbles:
        var b: Node2D = bubbles[id]
        if b.visible and b.scale.x < full:
            b.scale = Vector2.ONE * minf(full, b.scale.x + dt / BUBBLE_POP * 0.4 * full)

## 气泡放多大：镜头缩小多少就反着放大多少，屏幕上字一样大
func _bubble_scale() -> float:
    var z: float = c.cam.zoom.x if c.cam != null else 1.0
    return 1.0 / maxf(z, 0.2)

func _step_group(g: Dictionary, dt: float) -> void:
    var lines: Array = g["lines"]
    var paused := false
    for l in lines:
        if str(l[0]) == talking:
            paused = true
    if paused:
        if g["showing"]:
            _hide_bubble(str(g["who"]))
            g["showing"] = false
            g["t"] = 0.0
        return
    g["t"] = float(g["t"]) + dt
    if g["showing"]:
        if g["t"] >= BUBBLE_HOLD:
            _hide_bubble(str(g["who"]))
            g["showing"] = false
            g["t"] = 0.0
            g["i"] = (int(g["i"]) + 1) % lines.size()
    elif g["t"] >= BUBBLE_GAP:
        var l: Array = lines[int(g["i"])]
        g["who"] = str(l[0])
        g["showing"] = true
        g["t"] = 0.0
        show_bubble(str(l[0]), str(l[1]))

## 某人头顶冒一句（像素气泡：白底、2 像素深描边、方角，底下一个小尾巴指着他）
func show_bubble(id: String, text: String) -> void:
    var p: Dictionary = people.get(id, {})
    if p.is_empty():
        return
    _hide_bubble(id)
    var b := Node2D.new()
    b.name = "bubble_" + id
    var f: Font = c.font
    var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BUBBLE_FONT).x if f != null else float(text.length() * BUBBLE_FONT)
    var w := ceilf(tw) + 12.0
    var h := float(BUBBLE_FONT) + 10.0
    var tail := 6.0
    var box := Panel.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = BUBBLE_BG
    sb.border_color = INK
    sb.set_border_width_all(2)
    sb.anti_aliasing = false
    box.add_theme_stylebox_override("panel", sb)
    box.position = Vector2(-w * 0.5, -h - tail)
    box.size = Vector2(w, h)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(box)
    var lb := Label.new()
    lb.text = text
    if f != null:
        lb.add_theme_font_override("font", f)
    lb.add_theme_font_size_override("font_size", BUBBLE_FONT)
    lb.add_theme_color_override("font_color", INK)
    lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lb.position = Vector2.ZERO
    lb.size = Vector2(w, h)
    box.add_child(lb)
    # 小尾巴：白三角压住描边下沿，两条斜边描深色
    var tri := Polygon2D.new()
    tri.polygon = PackedVector2Array([Vector2(-5, -tail - 2), Vector2(5, -tail - 2), Vector2(0, 0)])
    tri.color = BUBBLE_BG
    tri.antialiased = false
    b.add_child(tri)
    var edge := Line2D.new()
    edge.points = PackedVector2Array([Vector2(-5, -tail), Vector2(0, 0), Vector2(5, -tail)])
    edge.width = 2.0
    edge.default_color = INK
    edge.antialiased = false
    b.add_child(edge)
    b.position = (p["head"] as Vector2) + Vector2(0, -4)
    b.scale = Vector2.ONE * 0.6 * _bubble_scale()
    b.set_meta("text", text)
    add_child(b)
    bubbles[id] = b

func _hide_bubble(id: String) -> void:
    if bubbles.has(id):
        var b: Node2D = bubbles[id]
        if is_instance_valid(b):
            b.queue_free()
        bubbles.erase(id)

## 现在头顶冒着话的人（测试、截图用）
func bubble_text(id: String) -> String:
    if bubbles.has(id) and is_instance_valid(bubbles[id]):
        return str((bubbles[id] as Node2D).get_meta("text"))
    return ""

# ---------- 说话 ----------
## 画布上这一点点到了谁（人画出来那一块，宽 36）
func npc_at(at: Vector2) -> String:
    for id in people:
        var p: Dictionary = people[id]
        var r := Rect2(p["head"].x - 18.0, p["head"].y, 36.0, (p["foot"] as Vector2).y - (p["head"] as Vector2).y)
        if r.grow(4.0).has_point(at):
            return id
    return ""

## 玩家站在谁跟前（出「聊聊」）
func near_npc() -> String:
    if not c.path.is_empty():
        return ""
    var best := ""
    var bd := TALK_NEAR
    for id in people:
        var d: float = c.pos.distance_to(people[id]["stand"])
        if d < bd:
            bd = d
            best = id
    return best

## 点了某位：走到他跟前，到了 talk_ready（已经在跟前、或坐在他旁边就直接说）
func request_talk(id: String) -> void:
    var p: Dictionary = people.get(id, {})
    if p.is_empty():
        return
    if c.seated and c.pos.distance_to(p["foot"]) < 90.0:
        talk_ready.emit(id)
        return
    if c.seated:
        c.stand_up()
    if c.pos.distance_to(p["stand"]) <= TALK_NEAR:
        c.face = c._face_for(p["foot"] - c.pos)
        talk_ready.emit(id)
        return
    pending_talk = id
    c.go_to(p["stand"])

func person(id: String) -> Dictionary:
    return people.get(id, {})
