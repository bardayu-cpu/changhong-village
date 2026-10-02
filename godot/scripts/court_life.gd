extends Node2D
## 迎宾院里的人动起来（01 E 10/2「院子里的人走起来」；docs/迎宾院-玩家说明-v1.md 第 5 条；04 基线第六节第 2 条）：
## - 走动的客人 WALKERS 个：用罗曼山庄宾客的图（有图用图，没有就代码画的），从大门进来，在院子里逛，
##   去签到桌边、花墙前、祝福牌、回忆册旁、休息区站一会儿，最后往楼门走进去；进去一个，隔一会儿大门再进来一个
## - 04 划的四块不许站、不许走过：红毯中间、签到桌前一格、花墙前合影站位、回忆册前一格（NO_GO）。
##   客人用自己的一张走路格子（玩家那张再去掉这四块），所以只能从红毯两边、大门口和楼门口过
## - 玩家不会被客人卡住：客人不算挡路的东西，玩家照旧能从他们身上走过去；客人走到玩家跟前（YIELD_R）还会自己往旁边让开
## - 新娘爸妈在签到桌后面有待机小动作：互相看一眼说两句、欠身迎客，玩家走近签到桌就看着玩家；
##   摄影师在相机边：一会儿看取景器、一会儿转过来招呼人，玩家走进合影站位就对着相机
## 只在迎宾院（entrance.gd 的 layout 是迎宾院那份才搭）；后厅、草坪这些画布没有
const LMPeople = preload("res://scripts/lm_people.gd")
const Spr = preload("res://scripts/sprites.gd")

const WALKERS := 7             # 01 E：先 6～8 个
const SPEED_M := 0.9           # 逛着走，比玩家（1.4）慢
const YIELD_R := 44.0          # 离玩家这么近就让开（像素，约 1 米）
const STEP_ASIDE := 56.0       # 让开挪多远
const ENTER_GAP := Vector2(1.0, 3.0)   # 走了一个，隔多久大门再进来一个（秒）
const FADE := 0.6              # 进大门、进楼门淡入淡出多久
const STAY := Vector2(4.0, 9.0)        # 到一个地方站多久
## 不许站、不许走过的四块（04 基线第六节第 2 条）加进门金箭头那块，Rect2(x, y, 宽, 高)。客人走路格子里这几块整个去掉：
## 红毯中间（红毯 672～864 宽，两边各留 32 给客人从大门、楼门进出）；签到桌前一格（玩家站着签到那块，sign_in 点）；
## 花墙前合影站位（photo_mark、photo_wait 两个点和新人跟前）；回忆册前一格（album 点）
const NO_GO := {
    "carpet": Rect2(704, 236, 128, 628),
    "sign": Rect2(1040, 636, 120, 94),
    "photo": Rect2(1060, 380, 190, 140),
    "album": Rect2(1260, 633, 80, 92),
    # 进门第一眼指签到桌的金箭头（刚进门站在大门口时它在 (1016, 610)，entrance.gd 的 sign_arrow）：
    # 脚站在箭头下面 90 以内身子就把它盖住，所以往下多划一截（04 10/2 第二件第 1 条：一位老先生站上去盖了一半）
    "arrow": Rect2(988, 586, 60, 116),
}
## 客人会去站一会儿的地方：[x, y, 朝向, 哪边]。站不上的（离挡路的东西太近）开场时挪到最近能站的格子
const SPOTS := [
    [1000, 655, "right", "e", "签到桌西头排着"], [1198, 655, "left", "e", "签到桌东头排着"],
    [1030, 372, "up", "e", "花墙前看"], [1290, 372, "up", "e", "花墙前看"],
    [905, 715, "up", "e", "看祝福牌"], [1360, 700, "left", "e", "回忆册旁边"],
    [1250, 800, "down", "e", "院子里站着"], [990, 820, "left", "e", "院子里站着"], [1400, 560, "down", "e", "院子里站着"],
    [420, 610, "left", "w", "休息区"], [215, 560, "right", "w", "休息区"], [590, 700, "down", "w", "休息区"],
    [210, 770, "right", "w", "院子里站着"], [500, 820, "down", "w", "院子里站着"], [560, 360, "up", "w", "院子里站着"],
]
const GATE_IN := {"w": Vector2(684, 880), "e": Vector2(852, 880)}    # 大门进来：红毯两边
const HALL_IN := {"w": Vector2(684, 212), "e": Vector2(852, 212)}    # 楼门进去：红毯两边

class Walker:
    var node: Node2D
    var body: Sprite2D
    var lm := {}               # 罗曼山庄宾客的图和数；空的是代码画的
    var proc := false
    var side := "e"
    var pos := Vector2.ZERO
    var path: Array = []
    var face := "down"
    var anim := 0.0
    var state := "walk"        # enter 从大门进来、walk 走去下一处、stay 站着、yield 让玩家、leave 走进楼门、gone
    var wait := 0.0
    var plan: Array = []       # 还要去的地方（SPOTS 的下标），走完了去楼门
    var spot := -1             # 现在去的 / 站着的那处
    var fade := 1.0
    var code := ""

var hall                       # entrance.gd
var rng := RandomNumberGenerator.new()
var nav := AStarGrid2D.new()   # 客人自己的走路格子：玩家的那张去掉 NO_GO
var ok_cells := PackedByteArray()
var spots: Array = []          # [{pos, face, side}]，已经挪到能站的格子
var walkers: Array = []
var taken := {}                # 哪处有人站着 / 正往那儿走：spot -> Walker
var enter_t := 0.0             # 还有多久大门进来下一个
var looks: Array = []          # 能用的长相：{"lm": {...}} 或 {"proc": i}
var look_i := 0
var greeters: Array = []       # 新娘爸妈、摄影师的小动作：{node, kind, base_face, act, t, ...}

func setup(h, seed_n := -1) -> void:
    hall = h
    name = "court_life"
    if seed_n >= 0:
        rng.seed = seed_n
    else:
        rng.randomize()
    _grid()
    spots.clear()
    for s in SPOTS:
        var c := _snap(Vector2(s[0], s[1]))
        spots.append({"pos": _cpos(c), "face": str(s[2]), "side": str(s[3]), "what": str(s[4])})
    _looks()
    _greeters()
    _populate()

## 重新摆一遍（截图、测试要每回一样：给个固定的种子）
func reseed(seed_n: int) -> void:
    for w in walkers:
        if is_instance_valid(w.node):
            w.node.queue_free()
    walkers.clear()
    taken.clear()
    rng.seed = seed_n
    look_i = 0
    _looks()
    _populate()

# ---------- 走路格子 ----------
func _grid() -> void:
    var cols: int = hall.cols
    var rows: int = hall.rows
    nav.region = Rect2i(0, 0, cols, rows)
    nav.cell_size = Vector2.ONE
    nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    nav.update()
    ok_cells.resize(cols * rows)
    for j in rows:
        for i in cols:
            var c := Vector2i(i, j)
            var ok: bool = hall._cell_ok(c) and not in_no_go(_cpos(c), 8.0)
            ok_cells[j * cols + i] = 1 if ok else 0
            if not ok:
                nav.set_point_solid(c, true)

## 这一点在不在四块不许站的地方里（pad：人身子半宽，脚点离边这么近也算踩进去）
static func in_no_go(p: Vector2, pad := 0.0) -> bool:
    for k in NO_GO:
        if (NO_GO[k] as Rect2).grow(pad).has_point(p):
            return true
    return false

func _cpos(c: Vector2i) -> Vector2:
    return hall._cell_pos(c)

func _wok(p: Vector2) -> bool:
    var c: Vector2i = hall._cell_of(p)
    return ok_cells[c.y * hall.cols + c.x] == 1

func _snap(p: Vector2) -> Vector2i:
    var c: Vector2i = hall._cell_of(p)
    if ok_cells[c.y * hall.cols + c.x] == 1:
        return c
    for rad in range(1, 30):
        for dj in range(-rad, rad + 1):
            for di in range(-rad, rad + 1):
                var n := c + Vector2i(di, dj)
                if nav.is_in_boundsv(n) and not nav.is_point_solid(n):
                    return n
    return c

## 两点之间客人能不能直着走（每半格看一下）
func _line_ok(a: Vector2, b: Vector2) -> bool:
    var n := maxi(1, int(a.distance_to(b) / (float(hall.cell) * 0.5)))
    for i in range(1, n + 1):
        if not _wok(a.lerp(b, float(i) / float(n))):
            return false
    return true

func _path(from: Vector2, to: Vector2) -> Array:
    var ids := nav.get_id_path(_snap(from), _snap(to))
    if ids.is_empty():
        return []
    var pts: Array = []
    for id in ids:
        pts.append(_cpos(id))
    if _wok(to):
        pts[pts.size() - 1] = to
    var out: Array = []
    var cur := from
    var k := 0
    while k < pts.size():
        var far := k
        for m in range(pts.size() - 1, k, -1):
            if _line_ok(cur, pts[m]):
                far = m
                break
        out.append(pts[far])
        cur = pts[far]
        k = far + 1
    return out

# ---------- 长相 ----------
## 罗曼山庄宾客的图（大人，01～10 里在的；小孩不单独逛），不够 WALKERS 个就用代码画的补
func _looks() -> void:
    looks.clear()
    for i in range(1, LMPeople.GUESTS + 1):
        var code := LMPeople.guest_code(i)
        if code in LMPeople.KIDS:
            continue
        var l: Dictionary = LMPeople.look(code)
        if not l.is_empty():
            looks.append({"lm": l, "code": code})
    # 打乱：每回进院子看到的不是同一拨人
    for i in range(looks.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var tmp = looks[i]
        looks[i] = looks[j]
        looks[j] = tmp
    # 代码画的排在后面：图的长相都在院子里了才用它补
    var n := 0
    while looks.size() < WALKERS + 4:
        looks.append({"proc": n, "code": "proc%d" % n})
        n += 1

## 下一个客人的长相：跟院子里现有的人、玩家自己都不撞；有图的先用（轮着来），图的都在院子里了才用代码画的
func _next_look() -> Dictionary:
    var used := {}
    for w in walkers:
        if w.state != "gone":
            used[w.code] = true
    var lm_n := looks.filter(func(x): return x.has("lm")).size()
    for pass_lm in [true, false]:
        var span: int = lm_n if pass_lm else looks.size() - lm_n
        var start: int = 0 if pass_lm else lm_n
        for k in span:
            var idx: int = start + (look_i + k) % maxi(1, span) if pass_lm else start + k
            var lk: Dictionary = looks[idx]
            if used.has(lk["code"]):
                continue
            if lk.has("lm") and hall.player != null and hall.player.texture == lk["lm"]["tex"]:
                continue
            if pass_lm:
                look_i = (look_i + k + 1) % maxi(1, span)
            return lk
    return looks[looks.size() - 1]

func _make(lk: Dictionary, at: Vector2, side: String) -> Walker:
    var w := Walker.new()
    w.side = side
    w.pos = at
    w.code = str(lk["code"])
    w.node = Node2D.new()
    w.node.name = "walker_" + w.code
    w.node.position = at
    w.body = Sprite2D.new()
    w.body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    w.body.centered = true
    if lk.has("lm"):
        var l: Dictionary = lk["lm"]
        w.lm = l
        w.body.texture = l["tex"]
        w.body.hframes = int(l["hframes"])
        w.body.vframes = int(l["vframes"])
        w.body.offset = Vector2(0, float(l["fh"]) * 0.5 - float(l["top"]) - float(l["h"]))
        var k: float = hall._px_h(at.y) * float(l["height_m"]) / LMPeople.ADULT_M / maxf(1.0, float(l["h"]))
        w.body.scale = Vector2(k, k)
    else:
        w.proc = true
        w.body.texture = ImageTexture.create_from_image(Spr.sheet_of(Spr.guest_look(int(lk["proc"]))))
        w.body.hframes = 9
        w.body.offset = Vector2(0, -16.0)
        var k2: float = hall._px_h(at.y) / 32.0
        w.body.scale = Vector2(k2, k2)
    w.node.add_child(w.body)
    hall.world.add_child(w.node)
    walkers.append(w)
    return w

# ---------- 摆人、进出 ----------
## 一进院子已经有人：WALKERS - 2 个已经站在各处，另外两个马上从大门进来
func _populate() -> void:
    var order: Array = range(spots.size())
    for i in range(order.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var tmp = order[i]
        order[i] = order[j]
        order[j] = tmp
    var placed := 0
    for si in order:
        if placed >= WALKERS - 2:
            break
        # 东边（签到、花墙、回忆册）人多些：西边最多两个
        var side: String = spots[si]["side"]
        if side == "w" and walkers.filter(func(x): return x.side == "w").size() >= 2:
            continue
        var w := _make(_next_look(), spots[si]["pos"], side)
        w.spot = si
        taken[si] = w
        w.state = "stay"
        w.face = spots[si]["face"]
        w.wait = rng.randf_range(0.5, STAY.y)
        w.plan = _plan(side, rng.randi_range(0, 2))
        placed += 1
    enter_t = 0.8

func _plan(side: String, n: int) -> Array:
    var pool: Array = []
    for i in spots.size():
        if spots[i]["side"] == side:
            pool.append(i)
    var out: Array = []
    for k in n:
        if pool.is_empty():
            break
        out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
    return out

func _enter() -> void:
    var side := "e" if rng.randf() < 0.7 else "w"
    var w := _make(_next_look(), GATE_IN[side], side)
    w.state = "enter"
    w.fade = 0.0
    w.node.modulate.a = 0.0
    w.plan = _plan(side, rng.randi_range(2, 4))
    w.path = [GATE_IN[side] + Vector2(0, -40)]
    w.face = "up"

## 去 plan 里下一处；那处有人了就换一处；都去过了去楼门
func _next(w: Walker) -> void:
    if w.spot >= 0 and taken.get(w.spot) == w:
        taken.erase(w.spot)
    w.spot = -1
    while not w.plan.is_empty():
        var si: int = w.plan.pop_front()
        if taken.has(si) or (spots[si]["pos"] as Vector2).distance_to(hall.pos) < YIELD_R * 1.5:
            continue
        var p := _path(w.pos, spots[si]["pos"])
        if p.is_empty():
            continue
        w.spot = si
        taken[si] = w
        w.path = p
        w.state = "walk"
        return
    # 一次只走一个进楼门（两个前后脚走，院子里一下空掉两个）：已经有人在往楼门走，这位再多逛一处
    if walkers.any(func(x): return x != w and x.state == "leave"):
        for si in _plan(w.side, 3):
            if taken.has(si) or (spots[si]["pos"] as Vector2).distance_to(hall.pos) < YIELD_R * 1.5:
                continue
            var p2 := _path(w.pos, spots[si]["pos"])
            if p2.is_empty():
                continue
            w.spot = si
            taken[si] = w
            w.path = p2
            w.state = "walk"
            return
        w.state = "stay"   # 没处可去：原地再站一会儿
        w.wait = rng.randf_range(1.5, 3.0)
        return
    var exit_p: Vector2 = HALL_IN[w.side]
    w.path = _path(w.pos, exit_p)
    w.path.append(exit_p + Vector2(0, -20))
    w.state = "leave"

# ---------- 每帧 ----------
func _process(dt: float) -> void:
    if hall == null or not hall.visible:
        return
    step(dt)

## 走一步（截图、测试可以连着调来快进）
func step(dt: float) -> void:
    # 少了人才从大门补：少一个隔 ENTER_GAP 进一个（走进楼门还没淡完的也算在院子里）
    var present := walkers.filter(func(x): return x.state != "gone").size()
    if present < WALKERS:
        enter_t -= dt
        if enter_t <= 0.0:
            _enter()
            enter_t = rng.randf_range(ENTER_GAP.x, ENTER_GAP.y)
    for w in walkers:
        if w.state == "gone":
            continue
        _yield_check(w)
        _move(w, dt)
        _pose(w, dt)
    for w in walkers.filter(func(x): return x.state == "gone"):
        if is_instance_valid(w.node):
            w.node.queue_free()
        walkers.erase(w)
    _greet(dt)

## 玩家走到跟前：往离开玩家的那边挪一步（挪不了就试斜着、横着），站一下再接着走
func _yield_check(w: Walker) -> void:
    if w.state in ["enter", "leave", "yield"]:
        return
    var d: Vector2 = w.pos - hall.pos
    if d.length() >= YIELD_R:
        return
    var away := d.normalized() if d.length() > 0.5 else Vector2.DOWN
    for ang in [0.0, 0.8, -0.8, 1.57, -1.57, 2.4, -2.4]:
        var to: Vector2 = w.pos + away.rotated(ang) * STEP_ASIDE
        if _wok(to) and _line_ok(w.pos, to) and to.distance_to(hall.pos) > YIELD_R:
            w.path = [to]
            w.state = "yield"
            w.wait = rng.randf_range(0.8, 1.6)
            if w.spot >= 0 and taken.get(w.spot) == w:
                w.plan.push_front(w.spot)   # 站的那处让给玩家，等会儿再回来
                taken.erase(w.spot)
                w.spot = -1
            return

func _move(w: Walker, dt: float) -> void:
    if w.state == "enter":
        w.fade = minf(1.0, w.fade + dt / FADE)
    if w.state == "leave" and w.pos.y < HALL_IN[w.side].y + 4.0:
        w.fade = maxf(0.0, w.fade - dt / FADE)
        if w.fade <= 0.0:
            w.state = "gone"
            if w.spot >= 0 and taken.get(w.spot) == w:
                taken.erase(w.spot)
            return
    w.node.modulate.a = w.fade
    if w.path.is_empty():
        match w.state:
            "enter":
                _next(w)
            "walk":
                w.state = "stay"
                w.wait = rng.randf_range(STAY.x, STAY.y)
                if w.spot >= 0:
                    w.face = spots[w.spot]["face"]
            "stay":
                w.wait -= dt
                if w.wait <= 0.0:
                    _next(w)
            "yield":
                w.wait -= dt
                if w.wait <= 0.0:
                    _next(w)
            "leave":
                w.path = [w.pos + Vector2(0, -20)]
        w.anim = 0.0
        return
    var tgt: Vector2 = w.path[0]
    var to := tgt - w.pos
    var dist := to.length()
    var speed: float = SPEED_M * hall.px_per_m(w.pos.y)
    if dist < 2.0:
        w.pos = tgt
        w.path.pop_front()
    else:
        w.pos += to / dist * minf(dist, speed * dt)
        w.face = hall._face_for(to)
        w.anim += dt
    w.node.position = w.pos

func _pose(w: Walker, _dt: float) -> void:
    var walking := not w.path.is_empty()
    if not w.lm.is_empty():
        var fr: Array = LMPeople.dir_frames(w.lm, w.face)
        w.body.frame = int(fr[int(w.anim * float(w.lm["fps"])) % fr.size()]) if walking else int(fr[0])
    else:
        var fl: Dictionary = Spr.PROC_ANIM[w.face]
        w.body.flip_h = bool(fl["flip"])
        var wf: Array = fl["walk"]
        w.body.frame = int(wf[int(w.anim * 6.0) % wf.size()]) if walking else int(fl["idle"])

# ---------- 新娘爸妈、摄影师的小动作 ----------
func _greeters() -> void:
    greeters.clear()
    var plan := {
        "bride_mom": {"kind": "parent", "other": "bride_dad"},
        "bride_dad": {"kind": "parent", "other": "bride_mom"},
        "photographer_w": {"kind": "photo", "cam": Vector2(980, 470)},
        "photographer_e": {"kind": "photo", "cam": Vector2(1330, 470)},
    }
    for id in plan:
        if not hall.npc_nodes.has(id):
            continue
        var s: Sprite2D = hall.npc_nodes[id]
        if s.hframes != 9:
            continue   # 只认代码画的那种 9 格；以后换成 GPT 的图再照图的朝向帧改
        var g: Dictionary = plan[id].duplicate()
        g["id"] = id
        g["node"] = s
        g["base"] = s.get_meta("base_offset", s.offset)
        g["face0"] = _face_of(s)
        g["act"] = ""
        g["t"] = rng.randf_range(1.0, 4.0)   # 多久以后做下一个动作
        g["n"] = 0 if id.ends_with("mom") else 1   # 爸妈错开：一个说两句的时候另一个欠身
        g["dur"] = 0.0
        greeters.append(g)

func _face_of(s: Sprite2D) -> String:
    for f in ["down", "up", "right", "left"]:
        var fl: Dictionary = Spr.PROC_ANIM[f]
        if int(fl["idle"]) == s.frame and bool(fl["flip"]) == s.flip_h:
            return f
    return "down"

func _set_face(s: Sprite2D, f: String) -> void:
    var fl: Dictionary = Spr.PROC_ANIM[f]
    s.frame = int(fl["idle"])
    s.flip_h = bool(fl["flip"])

func _toward(from: Vector2, to: Vector2) -> String:
    return hall._face_for(to - from)

## 爸妈：玩家走近签到桌（200 以内）就看着玩家，刚走进来那一下欠个身；不然隔几秒互相看一眼「说两句」或者欠身。
## 摄影师：玩家在合影那儿（photo_wait、photo_mark）就对着相机；不然看取景器、转过来招呼人轮着来
const NEAR_DESK := 220.0      # 玩家离爸妈这么近，爸妈就看着玩家（签到桌前那一片）
func _greet(dt: float) -> void:
    for g in greeters:
        var s: Sprite2D = g["node"]
        if not is_instance_valid(s):
            continue
        var at := s.position
        var dip := 0.0
        g["t"] = float(g["t"]) - dt
        # 上一个动作做完了先收掉，这一帧就照没动作摆朝向（不然欠完身多朝前一帧）
        if g["act"] != "":
            g["dur"] = float(g["dur"]) - dt
            if float(g["dur"]) <= 0.0:
                g["act"] = ""
                g["t"] = rng.randf_range(3.0, 7.0)
        if g["kind"] == "parent":
            var near: bool = hall.pos.distance_to(at) < NEAR_DESK
            if near and not bool(g.get("near", false)):
                g["act"] = "bow"
                g["dur"] = 0.7
            g["near"] = near
            if g["act"] == "" and float(g["t"]) <= 0.0:
                # 说两句、欠身轮着来；玩家在跟前就不扭头说话了，只欠身
                g["act"] = "bow" if near or int(g["n"]) % 2 == 1 else "talk"
                g["n"] = int(g["n"]) + 1
                g["dur"] = rng.randf_range(1.2, 2.2) if g["act"] == "talk" else 0.7
            match g["act"]:
                "talk":
                    var o: Sprite2D = hall.npc_nodes.get(g["other"])
                    _set_face(s, _toward(at, o.position) if o != null else g["face0"])
                "bow":
                    var k := 1.0 - float(g["dur"]) / 0.7
                    dip = sin(clampf(k, 0.0, 1.0) * PI) * 2.0   # 低头一下再起来
                    _set_face(s, g["face0"])
                _:
                    _set_face(s, _toward(at, hall.pos) if near else g["face0"])
        else:
            var shooting: bool = hall.in_spot("photo_wait") or hall.in_spot("photo_mark")
            if g["act"] == "" and float(g["t"]) <= 0.0:
                g["act"] = "wave"
                g["dur"] = rng.randf_range(1.5, 3.0)
            if shooting:
                _set_face(s, _toward(at, g["cam"]))
            elif g["act"] == "wave":
                _set_face(s, "down")
            else:
                _set_face(s, _toward(at, g["cam"]))
        s.set_meta("base_offset", (g["base"] as Vector2) + Vector2(0, dip))
