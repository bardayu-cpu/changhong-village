extends Node2D
## 休息间的人（docs/人物新做法-休息间样板-v0.1.md 第 2、3 节，01 F 10/4）：后厅 backhall.gd 搭好以后挂上来。
##   冒泡：两三个人一组，头顶轮流冒像素对话气泡（白底深描边、小尾巴指着说话的人），几个字，几秒换下一个人；
##         话在 assets/backhall/lounge.json 的 chat（02 拟的，待校对）。玩家正在跟谁说话，那一组先停
##   坐下：休息间每个座位（layout.json 的 seats）都能坐；NPC 占着的不能坐。走到空座位跟前出「坐下」（按钮在 lounge_ui.gd），
##         坐下人滑到椅面上、朝向跟座位一致、只画上半身；再点或推摇杆就站起来，站到座位跟前那块空地上
##   说话：点 NPC（或走到跟前点「聊聊」）走过去，到了就弹对话框（lounge_ui.gd 管框）
## 人（10/4 第二步）：01 画的代码小人（assets/characters/code/chr_CODE-GUEST-xx，两行图集：走路四向、待机、说话、坐四向），这里画、管动作：
##   坐着放坐姿格，脚点踩在座位前沿的地上（不截上半身）；站着不动放待机；跟玩家说话时站起来放说话格；
##   layout 写了 wander 的（叔叔）隔一阵起身，去唱片机、电视前各站一会，再走回来坐下（走路放四向走路格）
## 对话框、身份卡的人物图照旧用 GPT 宾客图（lounge.json 的 code，lounge_ui.gd）

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
const CODE_DIR := "res://assets/characters/code/chr_%s"
const SIT_H := 72.0             # 坐着头顶离脚点多高（01 画的朝下坐 70～75、侧坐 65～72）：气泡挂这
const STAND_H := 82.0           # 站着
const WALK_M := 0.9             # 起身走动走多快（米/秒，比玩家慢，逛着走）
const WANDER_SIT := Vector2(16.0, 28.0)   # 坐多久起身一次（秒）
const SOFA_MID_X := 1094.0   # 北边三人沙发正中（sofa_m 的 x；10/4 方案 C 休息室整间 +528，原来 566）
const WANDER_IDLE := 4.0        # 走到唱片机、电视前站多久

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
        var p: Dictionary = (pdata.get(id, {}) as Dictionary).duplicate()
        p["id"] = id
        p["code"] = str(p.get("code", ""))          # 对话框、身份卡用的 GPT 图
        p["home"] = Vector2(float(n["x"]), float(n["y"]))   # 坐着的脚点（座位前沿的地上）
        p["foot"] = p["home"]
        p["face"] = str(n.get("face", "down"))
        p["seat_face"] = p["face"]
        p["mode"] = "sit"
        p["phase"] = float(people.size()) * 0.37
        p["seat"] = ""
        for s in seats:
            if str(s.get("npc", "")) == id:
                p["seat"] = str(s["id"])
                p["stand"] = s["stand"]
        if not p.has("stand"):
            p["stand"] = _nearest_free(p["foot"] + Vector2(0, 30))
        p["spots"] = []
        for w in n.get("wander", []):
            for sp in c.cfg.get("stand_points", []):
                if str(sp["id"]) == str(w):
                    p["spots"].append(Vector2(float(sp["x"]), float(sp["y"])))
        p["legs"] = []
        p["path"] = []
        p["wait"] = randf_range(WANDER_SIT.x, WANDER_SIT.y) * 0.5
        _make_body(p, str(n.get("code_char", "")))
        _head(p)
        people[id] = p
    var k := 0
    for g in data.get("chat", []):
        var lines: Array = (g.get("lines", []) as Array).filter(func(l): return people.has(str(l[0])))
        if lines.is_empty():
            continue
        groups.append({"lines": lines, "i": 0, "t": -0.8 - 1.7 * float(k), "showing": false, "who": ""})
        k += 1

## 代码小人的图集（两行 16×2 格，每格 64×84，脚踩格子最后一行正中）：一比一放，不缩放（json 的 height_m 就是照这个算的）
func _make_body(p: Dictionary, code: String) -> void:
    if code == "" or not ResourceLoader.exists(CODE_DIR % code + ".png"):
        return
    var j = JSON.parse_string(FileAccess.get_file_as_string(CODE_DIR % code + ".json"))
    p["frames"] = (j as Dictionary).get("frames", {}) if j is Dictionary else {}
    p["fps"] = {"walk": float(j.get("fps", 8)), "idle": float(j.get("idle_fps", 2)), "talk": float(j.get("talk_fps", 3)), "sit": float(j.get("sit_fps", 1))}
    var s := Sprite2D.new()
    s.texture = load(CODE_DIR % code + ".png")
    s.hframes = 16
    s.vframes = 2
    s.centered = false
    s.offset = Vector2(-32, -83)
    s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    s.name = "npc_" + str(p["id"])
    s.position = p["foot"]
    c.world.add_child(s)
    c.npc_nodes[str(p["id"])] = s
    p["spr"] = s
    _pose(p, 0.0)

## 这一帧放哪格：坐着放坐姿（两格呼吸）、跟玩家说话放说话格、站着不动放待机、走路放四向走路格
func _pose(p: Dictionary, walk_t: float) -> void:
    if not p.has("spr"):
        return
    var fr: Dictionary = p["frames"]
    var fps: Dictionary = p["fps"]
    var tt: float = c.t + float(p["phase"])
    var cells: Array = fr.get("down", [0])
    var rate := 1.0
    match str(p["mode"]):
        "sit":
            cells = fr.get("sit_" + str(p["face"]), fr.get("sit_down", [0]))
            rate = float(fps["sit"])
        "talk":
            cells = fr.get("talk", [0])
            rate = float(fps["talk"])
        "walk":
            cells = fr.get(str(p["face"]), [0])
            rate = float(fps["walk"])
            tt = walk_t
        _:
            cells = fr.get("idle", [0]) if str(p["face"]) == "down" else [fr.get(str(p["face"]), [0])[0]]
            rate = float(fps["idle"])
    (p["spr"] as Sprite2D).frame = int(cells[int(tt * rate) % cells.size()])
    (p["spr"] as Sprite2D).position = p["foot"]

func _head(p: Dictionary) -> void:
    p["head"] = (p["foot"] as Vector2) - Vector2(0, SIT_H if str(p["mode"]) == "sit" else STAND_H)

## 起身走动（layout 写了 wander 的）：坐够了 → 站到座位跟前 → 挨个去 spots 站一会 → 走回座位跟前 → 坐回去。
## 玩家点了他、正跟他说话：原地停下（说话时站着放说话格），说完接着走
func _step_body(p: Dictionary, dt: float) -> void:
    var id := str(p["id"])
    var busy := talking == id or pending_talk == id
    if busy:
        p["mode"] = "talk" if talking == id else ("idle" if str(p["mode"]) != "sit" else "sit")
        if talking == id:
            p["face"] = "down"
    elif str(p["mode"]) == "talk":
        p["mode"] = "sit" if (p["foot"] as Vector2) == p["home"] else "idle"
        if str(p["mode"]) == "sit":
            p["face"] = p["seat_face"]
    if not busy and not (p["spots"] as Array).is_empty():
        p["wait"] = float(p["wait"]) - dt
        var legs: Array = p["legs"]
        var path: Array = p["path"]
        if legs.is_empty() and path.is_empty() and float(p["wait"]) <= 0.0:
            if str(p["mode"]) == "sit":
                # 起身：先站到座位跟前，再挨个去 spots，最后回座位跟前、坐下
                legs.append({"to": p["stand"], "direct": true})
                for sp in p["spots"]:
                    legs.append({"to": sp, "idle": WANDER_IDLE})
                legs.append({"to": p["stand"]})
                legs.append({"to": p["home"], "direct": true, "sit": true})
                p["mode"] = "idle"
                p["face"] = "down"
                p["wait"] = 0.6
        if path.is_empty() and not legs.is_empty() and float(p["wait"]) <= 0.0:
            var leg: Dictionary = legs.pop_front()
            p["leg"] = leg
            if bool(leg.get("direct", false)):
                path.append(leg["to"])
            else:
                path.append_array(c.find_path(p["foot"], leg["to"]))
        if not path.is_empty():
            var tgt: Vector2 = path[0]
            var to: Vector2 = tgt - (p["foot"] as Vector2)
            var step: float = WALK_M * c.px_per_m((p["foot"] as Vector2).y) * dt
            if to.length() <= step:
                p["foot"] = tgt
                path.pop_front()
                if path.is_empty():
                    var leg: Dictionary = p.get("leg", {})
                    if bool(leg.get("sit", false)):
                        p["mode"] = "sit"
                        p["face"] = p["seat_face"]
                        p["wait"] = randf_range(WANDER_SIT.x, WANDER_SIT.y)
                    else:
                        p["mode"] = "idle"
                        p["face"] = "down"
                        p["wait"] = float(leg.get("idle", 0.0))
            else:
                p["foot"] = (p["foot"] as Vector2) + to / to.length() * step
                p["mode"] = "walk"
                p["face"] = c._face_for(to)
                p["walk_t"] = float(p.get("walk_t", 0.0)) + dt
    _head(p)
    _pose(p, float(p.get("walk_t", 0.0)))
    var b: Node2D = bubbles.get(id)
    if b != null and is_instance_valid(b):
        b.position = (p["head"] as Vector2) + Vector2(0, -4)

## 玩家要跟他说话走到哪：坐着的走到座位跟前，起身走动的走到他脚边最近的空地
func approach_of(id: String) -> Vector2:
    var p: Dictionary = people.get(id, {})
    if p.is_empty():
        return Vector2.ZERO
    if (p["foot"] as Vector2) == p["home"]:
        # 坐在北边沙发上（朝下坐）的：站到她斜前方，别正挡在她身前（第 62 版截图奶奶被玩家挡住一大半，01 G 叫调）
        if str(p["seat_face"]) == "down":
            if not p.has("side_stand"):
                p["side_stand"] = _nearest_free((p["foot"] as Vector2) + Vector2(-52 if (p["foot"] as Vector2).x < SOFA_MID_X else 52, 40))
            return p["side_stand"]
        return p["stand"]
    return _nearest_free((p["foot"] as Vector2) + Vector2(0, 30))

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
            if c.pos.distance_to(approach_of(id)) <= TALK_NEAR:
                c.face = c._face_for(p["foot"] - c.pos)
                talk_ready.emit(id)
    if not frozen:
        for g in groups:
            _step_group(g, dt)
    for id in people:
        if frozen:   # 截图：人停在摆好的那一格
            _head(people[id])
            _pose(people[id], float(people[id].get("walk_t", 0.0)))
        else:
            _step_body(people[id], dt)
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
## 画布上这一点点到了谁（人画出来那一块，宽 32）；叠在一起的（叔叔起身走过阿姨跟前）算前面那个（脚点靠下的）
func npc_at(at: Vector2) -> String:
    var best := ""
    var by := -INF
    for id in people:
        var p: Dictionary = people[id]
        var r := Rect2(p["head"].x - 16.0, p["head"].y, 32.0, (p["foot"] as Vector2).y - (p["head"] as Vector2).y)
        if r.grow(4.0).has_point(at) and (p["foot"] as Vector2).y > by:
            by = (p["foot"] as Vector2).y
            best = id
    return best

## 玩家站在谁跟前（出「聊聊」）
func near_npc() -> String:
    if not c.path.is_empty():
        return ""
    var best := ""
    var bd := TALK_NEAR
    for id in people:
        var d: float = c.pos.distance_to(approach_of(id))
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
    var ap := approach_of(id)
    if c.pos.distance_to(ap) <= TALK_NEAR:
        c.face = c._face_for(p["foot"] - c.pos)
        talk_ready.emit(id)
        return
    pending_talk = id
    c.go_to(ap)

func person(id: String) -> Dictionary:
    return people.get(id, {})
