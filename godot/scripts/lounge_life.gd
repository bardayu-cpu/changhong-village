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
## 10/4 07 铺开（阿鱼：「其他房间里的 npc 也要动起来，对话起来，走动起来，灵活起来」）：一间屋一份，麻将室 mahjong.json、化妆间 makeup.json，
##   布局里 NPC 写 "life": "mahjong" 就归那间（休息间照旧 lounge: true）。那两间的人照旧用现在的样子（GPT 宾客图当替身，entrance._standin 画的），
##   这里接过来管：坐着的照旧坐着（说话也不起身、不转身，牌桌上的人就是扭头答你一句）；写了 wander 的起身走一圈再坐回去，走路放宾客图四向走路格；
##   站着的（化妆师）不动时放朝向那格。approach 写了就是玩家走到哪跟他说（别站到他身前把人挡住）；stand 是起身先站哪。
##   说不说得上话看数据里有没有 talk / dialogue：没写的只冒泡、点了不理（当路过）

signal talk_ready(id: String)   # 点了某位、走到他跟前了：lounge_ui 弹对话框

const DATA := "res://assets/backhall/lounge.json"
const SEAT_NEAR := 28.0         # 离座位跟前那块空地多近出「坐下」
const TALK_NEAR := 34.0         # 离 NPC 跟前多近算走到了（出「聊聊」、点了他走到就说）
const BUBBLE_HOLD := 2.6        # 一句冒多久
const BUBBLE_GAP := 0.9         # 一句收了隔多久下一个人说
const BUBBLE_POP := 0.12        # 冒出来那一下（从小变大）
const BUBBLE_FONT := 22         # 字号（540 宽算）：气泡按镜头缩放反着放大，后厅镜头缩到 0.5 多也认得出字。
                                # 原来 15，04 量第 67 版截图上字只有约 12 像素、长辈看不清（建议 18）；22 在 540×960 上字约 18 像素
const MAX_BUBBLES := 2         # 同屏最多几个在冒（04 第 8 条，05 10/4）
const BUBBLE_GAP_Y := 4.0       # 两个气泡叠上了：后冒的那个往上让开，中间留这么多（屏幕像素）
const INK := Color("#2b1d16")
const BUBBLE_BG := Color("#fffdf6")
const DialogSkin = preload("res://scripts/ui/dialog_skin.gd")   # 冒泡长什么样（05 10/4）
const FACE_DIR := {"down": Vector2(0, 1), "up": Vector2(0, -1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}
const CODE_DIR := "res://assets/characters/code/chr_%s"
const LMPeople = preload("res://scripts/lm_people.gd")
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
var room := "lounge"           # 哪间屋（lounge 休息间、mahjong 麻将室、makeup 化妆间）

## path：这间屋的话（people、chat）；room：布局里 NPC 的 life 写的那间（休息间照旧认 lounge: true；座位：休息间认没写 life 的，别的屋认写了自己屋名的）
func setup(canvas, path := DATA, room_id := "lounge") -> void:
    c = canvas
    room = room_id
    name = "life_" + room
    z_index = 6                # 气泡压在人、家具上面
    var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
    data = raw if raw is Dictionary else {}
    for s in c.cfg.get("seats", []):
        # 休息间照旧认没写 life 的座位；别的屋只认写了自己屋名的（10/6 化妆间第二轮：奶油沙发东头空一座给玩家坐）
        if str((s as Dictionary).get("life", "lounge")) == room:
            var seat: Dictionary = (s as Dictionary).duplicate()
            seat["stand"] = _stand_spot(seat)
            seats.append(seat)
    var pdata: Dictionary = data.get("people", {})
    for n in c.cfg.get("npcs", []):
        var mine: bool = bool(n.get("lounge", false)) if room == "lounge" else str(n.get("life", "")) == room
        if not mine:
            continue
        var id := str(n["id"])
        var p: Dictionary = (pdata.get(id, {}) as Dictionary).duplicate()
        p["id"] = id
        p["code"] = str(p.get("code", ""))          # 对话框、身份卡用的 GPT 图
        p["home"] = Vector2(float(n["x"]), float(n["y"]))   # 坐着的脚点（座位前沿的地上）
        p["foot"] = p["home"]
        p["face"] = str(n.get("face", "down"))
        p["seat_face"] = p["face"]
        p["home_mode"] = "sit" if bool(n.get("sit", false)) or n.has("code_char") else "idle"   # 在家是坐着还是站着
        p["mode"] = p["home_mode"]
        p["phase"] = float(people.size()) * 0.37
        p["seat"] = ""
        if n.has("approach"):
            p["approach"] = Vector2(float(n["approach"][0]), float(n["approach"][1]))
        if n.has("stand"):
            p["stand"] = Vector2(float(n["stand"][0]), float(n["stand"][1]))
        elif p["home_mode"] == "idle":
            p["stand"] = p["home"]
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
        if n.has("code_char"):
            _make_body(p, str(n.get("code_char", "")))
        else:
            _adopt_standin(p, n)
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

## 替身（GPT 宾客图，entrance._standin 已经画上了）：接过来，记下坐着那格怎么截（frame、rows、bottom），走路时换整格
func _adopt_standin(p: Dictionary, n: Dictionary) -> void:
    var s: Sprite2D = c.npc_nodes.get(str(n["id"]))
    var sd: Dictionary = n.get("standin", {})
    var l: Dictionary = LMPeople.look(str(sd.get("code", "")))
    if s == null or l.is_empty():
        return
    p["spr"] = s
    p["look"] = l
    p["sit_frame"] = int(sd.get("frame", 0))
    p["sit_rows"] = int(sd.get("rows", int(l["fh"])))
    p["sit_bottom"] = float(sd.get("bottom", float(n["y"]))) - float(n["y"])   # 图底比脚点高多少（坐着，凳面）
    p["fps"] = {"walk": float(l.get("fps", 8))}
    p["stand_h"] = float(l.get("h", STAND_H))

## 替身这一帧：坐着照布局那格截上半身（不转身）；走路放四向走路格；站着、说话放朝向那格（整格）
func _pose_standin(p: Dictionary, walk_t: float) -> void:
    var l: Dictionary = p["look"]
    var fw := int(l["fw"])
    var fh := int(l["fh"])
    var hf := int(l["hframes"])
    var frs: Dictionary = l.get("frames", {})
    var fr: int = int(p["sit_frame"])
    var rows: int = fh
    var bottom := 0.0
    match str(p["mode"]):
        "sit":
            rows = int(p["sit_rows"])
            bottom = float(p["sit_bottom"])
        "walk":
            var cells: Array = frs.get(str(p["face"]), [0])
            fr = int(cells[int(walk_t * float(p["fps"]["walk"])) % cells.size()])
        _:
            fr = int((frs.get(str(p["face"]), [0]) as Array)[0])
    var s: Sprite2D = p["spr"]
    s.region_rect = Rect2(float((fr % hf) * fw), float((fr / hf) * fh), float(fw), float(rows))
    var off := Vector2(-fw / 2.0, bottom - float(rows))
    if s.get_meta("base_offset", Vector2.ZERO) != off:
        s.set_meta("base_offset", off)   # entrance._breathe 照这个上下起伏
        s.offset = off
    s.position = p["foot"]

## 这一帧放哪格：坐着放坐姿（两格呼吸）、跟玩家说话放说话格、站着不动放待机、走路放四向走路格
func _pose(p: Dictionary, walk_t: float) -> void:
    if not p.has("spr"):
        return
    if p.has("look"):
        _pose_standin(p, walk_t)
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
    if p.has("look"):
        var h: float = float(p["sit_rows"]) - float(p["sit_bottom"]) if str(p["mode"]) == "sit" else float(p["stand_h"])
        p["head"] = (p["foot"] as Vector2) - Vector2(0, h)
        return
    p["head"] = (p["foot"] as Vector2) - Vector2(0, SIT_H if str(p["mode"]) == "sit" else STAND_H)

## 能不能跟他说话（数据里写了 talk 或 dialogue）；不能的只冒泡，点他当没点
func can_talk(id: String) -> bool:
    var p: Dictionary = people.get(id, {})
    return not p.is_empty() and (str(p.get("dialogue", "")) != "" or not (p.get("talk", []) as Array).is_empty())

## 起身走动（layout 写了 wander 的）：坐够了 → 站到座位跟前 → 挨个去 spots 站一会 → 走回座位跟前 → 坐回去。
## 玩家点了他、正跟他说话：原地停下（说话时站着放说话格），说完接着走
func _step_body(p: Dictionary, dt: float) -> void:
    var id := str(p["id"])
    var busy := talking == id or pending_talk == id
    var at_home: bool = (p["foot"] as Vector2) == p["home"]
    if busy:
        if p.has("look") and at_home and str(p["home_mode"]) == "sit":
            p["mode"] = "sit"   # 替身坐在牌桌、化妆台前：不起身、不转身
        else:
            p["mode"] = "talk" if talking == id else ("idle" if str(p["mode"]) != "sit" else "sit")
            if talking == id:
                p["face"] = "down"
    elif str(p["mode"]) == "talk":
        p["mode"] = p["home_mode"] if at_home else "idle"
        if at_home:
            p["face"] = p["seat_face"]
    if not busy and not (p["spots"] as Array).is_empty():
        p["wait"] = float(p["wait"]) - dt
        var legs: Array = p["legs"]
        var path: Array = p["path"]
        if legs.is_empty() and path.is_empty() and float(p["wait"]) <= 0.0:
            if (p["foot"] as Vector2) == p["home"]:
                # 起身：先站到座位跟前，再挨个去 spots，最后回座位跟前、坐下（站着的化妆师：stand 就是原地）
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
                        p["mode"] = p["home_mode"]
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
        b.position = (p["head"] as Vector2) + Vector2(0, -4.0 - float(b.get_meta("lift", 0.0)))

## 玩家要跟他说话走到哪：坐着的走到座位跟前，起身走动的走到他脚边最近的空地
func approach_of(id: String) -> Vector2:
    var p: Dictionary = people.get(id, {})
    if p.is_empty():
        return Vector2.ZERO
    if (p["foot"] as Vector2) == p["home"]:
        if p.has("approach"):
            return p["approach"]   # 布局写了站哪（麻将桌、化妆台边的人：站他侧边，不挡人）
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

## 后厅三间屋里有没有谁正在跟玩家说话（对话框开着）：开着的时候哪间都不冒泡，免得气泡从选项按钮底下露出来（03 测第 67 版）
func _anyone_talking() -> bool:
    var all: Array = c.get("lives") if c.get("lives") is Array and not (c.get("lives") as Array).is_empty() else [self]
    for lf in all:
        if str(lf.talking) != "":
            return true
    return false

## 气泡要是冒在 id 头顶、说 text，在画布上占哪块（还没冒，先量）
func _rect_for(id: String, text: String) -> Rect2:
    var p: Dictionary = people.get(id, {})
    if p.is_empty():
        return Rect2()
    var sz := (DialogSkin.bubble_box_size(text, c.font, BUBBLE_FONT) + Vector2(0, DialogSkin.bubble_tail_h())) * _bubble_scale()
    var at: Vector2 = (p["head"] as Vector2) + Vector2(0, -4)
    return Rect2(at.x - sz.x * 0.5, at.y - sz.y, sz.x, sz.y)

## 这块跟别的正冒着的气泡（三间屋都算，除了 skip 那个）叠不叠
func _crowded(r: Rect2, skip: Node2D = null) -> bool:
    var all: Array = c.get("lives") if c.get("lives") is Array and not (c.get("lives") as Array).is_empty() else [self]
    var gap := BUBBLE_GAP_Y * _bubble_scale()
    for lf in all:
        for id in lf.bubbles:
            var o: Node2D = lf.bubbles[id]
            if o != skip and is_instance_valid(o) and r.grow(gap * 0.5).intersects(lf.bubble_rect(o)):
                return true
    return false

## 冒泡轮换：一组一次一个人说。轮到的这句要是会跟别组正冒着的叠上，先等等再冒（挨着的两桌字放大以后会撞，04、03 看第 67 版）；
## 正说着的这句跟别人的气泡叠上了（走着走着撞上、站起来抬高），这句提前收
func _step_group(g: Dictionary, dt: float) -> void:
    var lines: Array = g["lines"]
    var paused := _anyone_talking()
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
        # 正说着的这句跟别人的气泡叠上了（起身走动、站起来气泡跟着头抬高、字带了引号变宽……）：这句提前收
        var mine: Node2D = bubbles.get(str(g["who"]))
        if mine != null and is_instance_valid(mine) and mine.scale.x >= _bubble_scale() * 0.99 and _crowded(bubble_rect(mine), mine):
            g["t"] = BUBBLE_HOLD
        if g["t"] >= BUBBLE_HOLD:
            _hide_bubble(str(g["who"]))
            g["showing"] = false
            g["t"] = 0.0
            g["i"] = (int(g["i"]) + 1) % lines.size()
    elif g["t"] >= BUBBLE_GAP:
        if _showing_count() >= MAX_BUBBLES:
            g["t"] = BUBBLE_GAP - 0.5   # 同屏已经两个在冒：半秒后再看（04 第 8 条：同屏最多两个）
            return
        var l: Array = lines[int(g["i"])]
        if _crowded(_rect_for(str(l[0]), str(l[1]))):
            g["t"] = BUBBLE_GAP - 0.5   # 旁边有人正说着：半秒后再看
            return
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
    # 长什么样交给 scripts/ui/dialog_skin.gd（05 10/4 重做样子）；冒在哪、多久、让位照旧在这里
    var built: Dictionary = DialogSkin.bubble(text, c.font, BUBBLE_FONT)
    var b: Node2D = built["node"]
    b.name = "bubble_" + id
    b.position = (p["head"] as Vector2) + Vector2(0, -4)
    b.scale = Vector2.ONE * 0.6 * _bubble_scale()
    b.set_meta("size", built["size"])
    _make_room(b)
    b.set_meta("text", text)
    add_child(b)
    bubbles[id] = b

## 后厅三间屋里现在一共冒着几个（同屏最多 MAX_BUBBLES 个，04 第 8 条）
func _showing_count() -> int:
    var all: Array = c.get("lives") if c.get("lives") is Array and not (c.get("lives") as Array).is_empty() else [self]
    var n := 0
    for lf in all:
        for id in lf.bubbles:
            if is_instance_valid(lf.bubbles[id]):
                n += 1
    return n

## 气泡在画布上占哪块（按放满了的大小算）
func bubble_rect(b: Node2D) -> Rect2:
    var sz: Vector2 = b.get_meta("size", Vector2.ZERO) * _bubble_scale()
    return Rect2(b.position.x - sz.x * 0.5, b.position.y - sz.y, sz.x, sz.y)

## 新冒的气泡跟别的正冒着的（三间屋都算）叠上了就往上让，一直让到不叠（挨着的两桌同时说话，04 看第 67 版）
func _make_room(b: Node2D) -> void:
    var others: Array = []
    var all: Array = c.get("lives") if c.get("lives") is Array and not (c.get("lives") as Array).is_empty() else [self]
    for lf in all:
        for id in lf.bubbles:
            var o: Node2D = lf.bubbles[id]
            if o != b and is_instance_valid(o):
                others.append(lf.bubble_rect(o))
    var lift := 0.0
    var gap := BUBBLE_GAP_Y * _bubble_scale()
    var top_y: float = float(c.cfg.get("walk", [[[0, 0]]])[0][0][1]) - 8.0   # 最多让到屋子北墙这一线（布局能走范围的上沿），不顶出屋子
    for pass_i in 6:
        var r := bubble_rect(b)
        r.position.y -= lift
        var hit := false
        for o in others:
            if r.intersects(o):
                lift += r.end.y - (o as Rect2).position.y + gap
                hit = true
                break
        if not hit:
            break
    lift = minf(lift, maxf(0.0, bubble_rect(b).position.y - top_y))
    b.set_meta("lift", lift)
    b.position.y -= lift

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
        if not can_talk(id):
            continue
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
        if not can_talk(id):
            continue
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
