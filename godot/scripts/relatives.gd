extends Node2D
## 55 桌大厅的亲友 NPC（01 D 9/29，照 docs/宴会厅-亲友NPC-玩家说明.md，阿鱼点过头）。只在 55 桌厅有（ambience_55.json 的 relatives）。
## 18 位，头上挂称呼，走近冒「看看 XX」点开身份卡（称呼 + 跟阿鱼什么关系；【待讨论】的只写称呼，main.gd 管卡）。
## 开席前（北京时间不在 12:00～14:00、17:00～19:00）：在厅里走动、停下来跟人站着说话、去找熟人；不占座、不停在红毯上和门口。
## 开席：走回自己那桌坐下（T9、T11、T7，随机宾客给他们让出了座）；隔一阵有人端杯走到主桌边敬酒再回来；T11 四位凑一桌打牌，玩家只能看。
## 时间按北京时间（UTC+8）算，不看手机时区；调试面板能强制开席／开席前（force）。
## 走路、长相和服务员、宾客共用 hall_life 那套：宾客长相图集、找路 hall.find_path、站着 9 帧、坐着截上半身

signal rel_near(title: String, relation: String)   # 离我最近（REL_NEAR 内）的亲友换了；走开是空

const Spr = preload("res://scripts/sprites.gd")
const FH := 32.0
const WALK_FPS := 5.0
const SPEED_M := 1.1          # 亲友走得慢，逛着走
const REL_NEAR := 70.0        # 走到跟前多近算「在跟前」：冒「看看 XX」、坐着的那位亮称呼
const IDLE := Vector2(3.0, 8.0)       # 走到一个地方停多久
const CHAT := Vector2(6.0, 12.0)      # 站着说话多久
const SEEK_P := 0.45                  # 停够了去找熟人说话的机会（不然再随便走一处）
const TOAST_EVERY := Vector2(12.0, 24.0)   # 开席后隔多久有一位去主桌敬酒
const TOAST_HOLD := 2.6
const CARD_EVERY := Vector2(1.2, 2.2)      # 打牌：隔多久有人出一张
const CHECK_EVERY := 2.0                   # 隔多久看一次钟（到没到饭点）
const CARD_UP := 20.0                      # 牌摆在桌心往上多少（桌面露出来的那半）

class Rel:
    var title := ""
    var relation := ""
    var group := ""
    var table := ""
    var cards := false
    var toast := false
    var row := 0              # 长相：宾客图集第几行
    var node: Node2D
    var body: Sprite2D        # 站着、走路（9 帧）
    var seat_spr: Sprite2D    # 坐着（上半身）
    var cup: Sprite2D
    var tag: Label
    var pos := Vector2.ZERO
    var path: Array = []
    var face := "down"
    var anim := 0.0
    var state := "idle"       # idle 停着、walk 走去某处、seek 去找熟人、chat 站着说话、go_seat 走回座位、sit 坐着、
                              # stand 座位被真人占了就站在桌边、go_toast 走去主桌、toast 敬酒、back 回座位
    var wait := 0.0
    var partner: Rel = null
    var chair := 0            # 开席坐几号椅（0 是没座）
    var stand := Vector2.ZERO # 座位跟前起身那一步

var hall: Node2D
var life: Node2D
var conf: Dictionary = {}
var rels: Array = []
var rng := RandomNumberGenerator.new()
var speed := 50.0
var force := ""               # 调试：""按北京时间，"feast" 强制开席，"pre" 强制开席前
var feast := false
var check_t := 0.0
var spots: Array = []         # 开席前能停下来的地方（不在红毯上、不在门口、不贴桌）
var toast_t := 0.0
var toaster: Rel = null
var near_key: Rel = null
var cards_node: Node2D
var card_t := 0.0
var card_pile: Array = []
var cards_dealt := 0          # 一共出了几张（测试看打没打起来）
var carpet := Vector2(-1.0, -1.0)   # 红毯左右 x（从 scene 的 couple_table 点和 base 那条推不出来，按摆位图 CX±72）
var unix_override := -1.0     # 测试用：假装现在是几点（Unix 秒）；<0 用系统时间

## 北京时间几点（0～24 的小数）。unix 是 UTC 秒；不看手机时区
static func beijing_hour(unix: float, tz_hours := 8) -> float:
    var s := fposmod(unix + float(tz_hours) * 3600.0, 86400.0)
    return s / 3600.0

## 是不是在饭点：windows 是 [[12,14],[17,19]] 这种，前闭后开
static func in_feast(hour: float, windows: Array) -> bool:
    for w in windows:
        if hour >= float(w[0]) and hour < float(w[1]):
            return true
    return false

func setup(h: Node2D, l: Node2D, c: Dictionary) -> void:
    hall = h
    life = l
    conf = c
    rng.seed = 929
    speed = SPEED_M * hall.px_per_m(1200.0)
    carpet = Vector2(768.0 - 72.0 - 14.0, 768.0 + 72.0 + 14.0)   # 红毯 3 米宽（摆位图 CX=768），两边各留 14 像素，停人不停在上面
    _spots()
    var i := 0
    var pools: Dictionary = life.look_pools()
    var counters := {}
    for p in c.get("people", []):
        var r := Rel.new()
        r.title = str(p["title"])
        r.relation = str(p.get("relation", ""))
        r.group = str(p.get("group", ""))
        r.table = str(p.get("table", ""))
        r.cards = bool(p.get("cards", false))
        r.toast = bool(p.get("toast", false))
        r.row = life.pick_look(p, pools, counters)   # 按称呼分男女挑长相（04 9/29）
        _make_node(r)
        rels.append(r)
        i += 1
    feast = _feast_now()
    _cards_node()
    for k in rels.size():
        var r: Rel = rels[k]
        if feast:
            r.pos = spots[(k * 7) % spots.size()] if not spots.is_empty() else hall.SPAWN   # 先放着，seat() 会把有座的直接坐下
        else:
            r.pos = spots[(k * 11 + 3) % spots.size()] if not spots.is_empty() else hall.SPAWN
            r.state = "idle"
            r.wait = rng.randf_range(0.5, IDLE.y)
        _pose(r, false)

## 真人座位变了（进厅、换桌）以后重排座：hall_life.seat_guests 末尾调，taken 是真人坐的 "T9:3"
func seat(taken: Dictionary) -> void:
    var used: Dictionary = {}
    for r in rels:
        var tc: Dictionary = hall._table_cfg(r.table)
        r.chair = 0
        if tc.is_empty():
            continue
        # 椅子：这桌没画随机宾客、也没真人坐的，从大号往小号挑（服务端分座从 1 号往上排，真人先占小号）
        for no in range(hall.seats_of(tc), 0, -1):
            var key := "%s:%d" % [r.table, no]
            if taken.has(key) or life.npc_taken.has(key) or used.has(key):
                continue
            r.chair = no
            used[key] = true
            break
        var center: Vector2 = hall._seat_center(tc)
        if r.chair > 0:
            r.stand = hall._stand_spot(hall.chair_world(tc, r.chair), center)
        else:
            r.stand = _near_free(center + Vector2(float(tc["rx"]) + 20.0, 10.0))
    _arrange_cards()
    if feast:
        for r in rels:
            if r.state in ["go_toast", "toast", "back"]:
                continue
            _sit_now(r)

## 真人坐下占了哪把：坐那把的亲友换这桌别的空椅子（没有就站到桌边）
func vacate(key: String) -> void:
    for r in rels:
        if r.chair > 0 and "%s:%d" % [r.table, r.chair] == key:
            var was_sitting: bool = r.state == "sit"
            if was_sitting:
                _stand_up(r)
            var used: Dictionary = {}
            for o in rels:
                if o != r and o.chair > 0:
                    used["%s:%d" % [o.table, o.chair]] = true
            var tc: Dictionary = hall._table_cfg(r.table)
            r.chair = 0
            for no in range(hall.seats_of(tc), 0, -1):
                var k := "%s:%d" % [r.table, no]
                if k == key or hall.seat_taken.has(k) or life.npc_taken.has(k) or used.has(k):
                    continue
                r.chair = no
                break
            var center: Vector2 = hall._seat_center(tc)
            r.stand = hall._stand_spot(hall.chair_world(tc, r.chair), center) if r.chair > 0 \
                else _near_free(center + Vector2(float(tc["rx"]) + 20.0, 10.0))
            if was_sitting:
                _sit_now(r)
            _arrange_cards()

func _feast_now() -> bool:
    if force == "feast":
        return true
    if force == "pre":
        return false
    var unix := unix_override if unix_override >= 0.0 else Time.get_unix_time_from_system()
    return in_feast(beijing_hour(unix, int(conf.get("tz_hours", 8))), conf.get("feast", []))

func set_force(f: String) -> void:
    force = f
    _apply_mode(_feast_now())

func _apply_mode(f: bool) -> void:
    if f == feast:
        return
    feast = f
    toaster = null
    for r in rels:
        r.partner = null
        if feast:
            _go_seat(r)
        else:
            if r.state == "sit":
                _stand_up(r)
            r.cup.visible = false
            r.state = "idle"
            r.wait = rng.randf_range(0.0, 2.0)
            if not _stop_ok(r.pos):
                _walk_to(r, _nearest_spot(r.pos), "walk")   # 正走在红毯上（敬酒回来的路上）就到饭点完了：先走到旁边能停的地方，不停在红毯上
    _arrange_cards()

func _nearest_spot(p: Vector2) -> Vector2:
    var best := p
    var bd := INF
    for sp in spots:
        var d: float = p.distance_squared_to(sp)
        if d < bd:
            bd = d
            best = sp
    return best

# ---------- 画 ----------
func _make_node(r: Rel) -> void:
    r.node = Node2D.new()
    r.node.name = "rel_" + r.title
    hall.world.add_child(r.node)
    var s := Sprite2D.new()
    s.texture = life._guest_atlas()
    s.region_enabled = true
    s.region_rect = Rect2(0.0, r.row * FH, 16.0 * 9, FH)
    s.hframes = 9
    s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    s.centered = true
    s.offset = Vector2(0, -FH * 0.5)
    s.scale = Vector2(life.sc, life.sc)
    r.node.add_child(s)
    r.body = s
    r.seat_spr = life._upper(life._guest_atlas(), 0, false)
    r.seat_spr.region_rect.position.y = r.row * FH
    r.seat_spr.visible = false
    r.node.add_child(r.seat_spr)
    r.cup = life._sprite("amb_cup")
    if r.cup == null:
        r.cup = Sprite2D.new()
    r.cup.visible = false
    r.node.add_child(r.cup)
    if hall.font != null:
        var l := Label.new()
        l.text = r.title
        l.name = "reltag_" + r.title
        l.z_index = 5
        r.node.add_child(l)   # 先进树再量大小（不在树里量出来偏窄，牌子歪）
        hall.name_plate(l)
        r.tag = l

func _pose(r: Rel, moving: bool) -> void:
    r.node.position = r.pos
    var sitting := r.state == "sit"
    r.body.visible = not sitting
    r.seat_spr.visible = sitting
    var fl: Dictionary = Spr.PROC_ANIM[r.face]
    if sitting:
        r.seat_spr.region_rect.position.x = float(fl["idle"]) * 16.0
        r.seat_spr.flip_h = bool(fl["flip"])
    else:
        var walk: Array = fl["walk"]
        r.body.frame = walk[int(r.anim * WALK_FPS) % walk.size()] if moving else int(fl["idle"])
        r.body.flip_h = bool(fl["flip"])
        var bob := -absf(sin(r.anim * WALK_FPS * PI)) * 1.2 if moving else 0.0
        r.body.offset = Vector2(0, -FH * 0.5 + bob)
    var h: float = hall._px_h(r.pos.y) * (hall.SIT_KEEP if sitting else 1.0)
    if r.cup.visible:
        r.cup.position = Vector2(-14.0 if r.face == "left" else 14.0, -h + 22.0)
    if r.tag != null:
        r.tag.position = Vector2(-r.tag.size.x * 0.5, -h - r.tag.size.y - 2.0)
        # 称呼：走着、站着的一直挂（人散开，不会叠）；坐下了只亮离我最近那位（一桌六七位一起挂会叠成一摞，和主桌一样）
        r.tag.visible = not sitting or r == near_key

# ---------- 地方 ----------
## 开席前停下来的地方：能走的格子里，离桌子占地、墙有点距离，不在红毯上、不在大门／侧门／台阶前，每 60 像素取一个
func _spots() -> void:
    spots.clear()
    var sz := Vector2(float(hall.cfg["size"][0]), float(hall.cfg["size"][1]))
    var y := 560.0
    while y < sz.y - 260.0:
        var x := 90.0
        while x < sz.x - 90.0:
            var p := Vector2(x, y)
            if _stop_ok(p):
                spots.append(p)
            x += 60.0
        y += 60.0

func _stop_ok(p: Vector2) -> bool:
    if not hall._free(p):
        return false
    if p.x > carpet.x and p.x < carpet.y:
        return false   # 不堵红毯
    if p.distance_to(hall.door) < 160.0 or p.distance_to(hall.side_door) < 110.0 or p.distance_to(hall.COUPLE_SPOT) < 110.0:
        return false   # 不堵门口、不堵台阶前
    for d in [Vector2(24, 0), Vector2(-24, 0), Vector2(0, 20), Vector2(0, -20)]:
        if not hall._free(p + d):
            return false   # 不贴着桌子、墙站
    return true

func _near_free(p: Vector2) -> Vector2:
    return hall._cell_pos(hall._nearest_free(hall._cell_of(p)))

# ---------- 每帧 ----------
func _process(dt: float) -> void:
    if rels.is_empty():
        return
    check_t -= dt
    if check_t <= 0.0:
        check_t = CHECK_EVERY
        _apply_mode(_feast_now())
    for r in rels:
        _step(r, dt)
    if feast:
        _toast_tick(dt)
        _cards_tick(dt)
    _near()
    _declutter()

## 称呼牌不叠、不被屏幕边切（04 新 2、新 3；跟名字牌第一轮 B4 同一条规矩）：
## 1. 贴屏幕边：牌子中点还在屏幕里的往里收，中点出了屏幕的先不显示（和 layered_hall._keep_tags_on_screen 一样）
## 2. 两位挨着站时：从上往下排，跟已经排好的哪块叠了就往上抬一行；抬两行还叠（三四个人挤成一团），
##    这一位的牌先收起来，散开了自己回来（走到跟前照样冒「看看 XX」）
const TAG_GAP := 4.0
func _declutter() -> void:
    var lo := -INF
    var hi := INF
    var cam: Camera2D = hall.cam
    if cam != null and cam.zoom.x > 0.0:
        var half := float(hall.get_viewport().get_visible_rect().size.x) * 0.5 / cam.zoom.x
        var cx := cam.get_screen_center_position().x
        lo = cx - half + 4.0
        hi = cx + half - 4.0
    var placed: Array = []   # [Rect2]
    # 桌牌、主桌家里人的称呼先排（04 v7 新 2：原来只比称呼牌对称呼牌，「大爸」被「1 号桌 · 连连看」压住下半截；
    # 桌牌贴屏幕边也没收口）：它们位置定死，贴边的往里收，占的地方先记上，亲友的称呼再让开它们
    var fixed: Array = []
    if hall.get("table_signs") != null:
        for k in hall.table_signs:
            fixed.append(hall.table_signs[k])
    if life.get("family_tags") != null:
        for k in life.family_tags:
            fixed.append(life.family_tags[k])
    for l in fixed:
        if not is_instance_valid(l) or not (l as Control).visible:
            continue
        var c: Control = l
        var w: float = c.size.x
        c.position.x = clampf(c.position.x, lo, maxf(lo, hi - w))
        placed.append(Rect2(c.position, c.size))   # 桌牌、称呼牌的爹（seat_tags）在厅的原点，position 就是厅里的坐标
    var order: Array = []
    for r in rels:
        if r.tag != null and r.tag.visible:
            order.append(r)
    order.sort_custom(func(a, b): return a.pos.y < b.pos.y)
    for r in order:
        var rect := Rect2(r.pos + r.tag.position, r.tag.size)
        var mid := rect.position.x + rect.size.x * 0.5
        if mid < lo or mid > hi:
            r.tag.visible = false
            continue
        rect.position.x = clampf(rect.position.x, lo, maxf(lo, hi - rect.size.x))
        var hit := true
        for k in 3:
            hit = false
            for q in placed:
                if rect.grow(TAG_GAP * 0.5).intersects(q.grow(TAG_GAP * 0.5)):
                    hit = true
                    break
            if not hit or k == 2:
                break
            rect.position.y -= r.tag.size.y + TAG_GAP
        if hit and r != near_key:
            r.tag.visible = false
            continue
        r.tag.position = rect.position - r.pos
        placed.append(rect)

func _step(r: Rel, dt: float) -> void:
    var moving := false
    match r.state:
        "idle":
            r.wait -= dt
            if r.wait <= 0.0:
                if rng.randf() < SEEK_P and _seek(r):
                    pass
                else:
                    _walk_to(r, spots[rng.randi() % spots.size()] if not spots.is_empty() else r.pos, "walk")
        "chat":
            r.wait -= dt
            if r.partner != null:
                r.face = hall._face_for(r.partner.pos - r.pos)
            if r.wait <= 0.0:
                r.partner = null
                r.state = "idle"
                r.wait = rng.randf_range(0.5, 2.0)
        "toast":
            r.wait -= dt
            r.face = hall._face_for(Vector2(float(hall._table_cfg("MAIN")["x"]), float(hall._table_cfg("MAIN")["y"])) - r.pos)
            if r.wait <= 0.0:
                r.cup.visible = false
                _walk_to(r, r.stand, "back")
        "sit", "stand":
            pass
        _:
            moving = _move(r, dt)
            if not moving and r.path.is_empty():
                _arrive(r)
    r.anim = r.anim + dt if moving else 0.0
    _pose(r, moving)

func _move(r: Rel, dt: float) -> bool:
    if r.path.is_empty():
        return false
    var tgt: Vector2 = r.path[0]
    var to := tgt - r.pos
    var d := to.length()
    if d < 1.5:
        r.pos = tgt
        r.path.pop_front()
        return not r.path.is_empty()
    r.pos += to / d * minf(d, speed * dt)
    r.face = hall._face_for(to)
    return true

func _walk_to(r: Rel, target: Vector2, state: String) -> void:
    r.path = hall.find_path(r.pos, target)
    r.state = state
    if r.path.is_empty():
        _arrive(r)

func _arrive(r: Rel) -> void:
    match r.state:
        "walk":
            r.state = "idle"
            r.wait = rng.randf_range(IDLE.x, IDLE.y)
            r.face = ["down", "left", "right", "down"][rng.randi() % 4]
        "seek":
            var p: Rel = r.partner
            if p != null and p.state in ["idle", "chat"] and p.pos.distance_to(r.pos) < 60.0:
                var chat_len := rng.randf_range(CHAT.x, CHAT.y)
                r.state = "chat"
                r.wait = chat_len
                p.state = "chat"
                p.partner = r
                p.wait = chat_len
            else:
                r.partner = null
                r.state = "idle"
                r.wait = rng.randf_range(IDLE.x, IDLE.y)
        "go_seat", "back":
            _sit_now(r)
        "go_toast":
            r.state = "toast"
            r.wait = TOAST_HOLD
            r.cup.visible = true

## 找熟人：先找同一组的，没有就随便一位，要在停着（不在走、不在跟别人说话）；走到他旁边一步
func _seek(r: Rel) -> bool:
    var cands: Array = []
    for o in rels:
        if o != r and o.state == "idle" and o.group == r.group:
            cands.append(o)
    if cands.is_empty():
        for o in rels:
            if o != r and o.state == "idle":
                cands.append(o)
    if cands.is_empty():
        return false
    var o: Rel = cands[rng.randi() % cands.size()]
    var side := 34.0 if rng.randf() < 0.5 else -34.0
    var target := o.pos + Vector2(side, 0.0)
    if not _stop_ok(target):
        target = o.pos + Vector2(-side, 0.0)
        if not _stop_ok(target):
            return false
    o.wait = maxf(o.wait, 12.0)   # 等人走过来
    r.partner = o
    _walk_to(r, target, "seek")
    return true

# ---------- 开席 ----------
func _go_seat(r: Rel) -> void:
    r.cup.visible = false
    _walk_to(r, r.stand, "go_seat")

func _sit_now(r: Rel) -> void:
    var tc: Dictionary = hall._table_cfg(r.table)
    r.path.clear()
    r.cup.visible = false
    if r.chair <= 0 or tc.is_empty():
        r.pos = r.stand
        r.state = "stand"
        r.face = hall._face_for(hall._seat_center(tc) - r.pos) if not tc.is_empty() else "down"
        return
    var at: Vector2 = hall.chair_world(tc, r.chair)
    var center: Vector2 = hall._seat_center(tc)
    r.pos = at
    r.state = "sit"
    r.face = hall._face_for(center - at)
    r.node.z_index = 1 if hall.seat_in_front(tc, at) else 0

func _stand_up(r: Rel) -> void:
    r.node.z_index = 0
    if r.state == "sit":
        r.pos = r.stand
    r.state = "idle"

func _toast_tick(dt: float) -> void:
    if toaster != null:
        if toaster.state == "sit" or toaster.state == "stand":
            toaster = null
        return
    toast_t -= dt
    if toast_t > 0.0:
        return
    toast_t = rng.randf_range(TOAST_EVERY.x, TOAST_EVERY.y)
    var cands: Array = []
    for r in rels:
        if r.toast and r.state == "sit":
            cands.append(r)
    if cands.is_empty() or not life.spots.has("MAIN"):
        return
    var r: Rel = cands[rng.randi() % cands.size()]
    var sp: Array = life.spots["MAIN"]
    toaster = r
    _stand_up(r)
    _walk_to(r, sp[rng.randi() % sp.size()], "go_toast")

## 打牌：T11 那四位坐下了才打；桌心一小摞牌，隔一阵有人甩一张到中间，攒够 8 张收了重来
func _cards_node() -> void:
    var tid := str(conf.get("cards_table", ""))
    var tc: Dictionary = hall._table_cfg(tid)
    if tc.is_empty():
        return
    cards_node = Node2D.new()
    cards_node.name = "cards_" + tid
    cards_node.position = Vector2(float(tc["x"]), float(tc["y"]) + 0.6)   # 排前后和桌心的簿子一样（桌子着地线 +0.5 那一层）
    hall.world.add_child(cards_node)
    cards_node.visible = false

func _card(at: Vector2, rot: float) -> Polygon2D:
    var p := Polygon2D.new()
    p.polygon = PackedVector2Array([Vector2(-5, -7), Vector2(5, -7), Vector2(5, 7), Vector2(-5, 7)])
    p.color = Color("#f4efe2")
    p.position = at
    p.rotation = rot
    var edge := Line2D.new()
    edge.points = PackedVector2Array([Vector2(-5, -7), Vector2(5, -7), Vector2(5, 7), Vector2(-5, 7), Vector2(-5, -7)])
    edge.width = 1.0
    edge.default_color = Color("#b3282d")
    p.add_child(edge)
    return p

func _cards_playing() -> Array:
    var out: Array = []
    for r in rels:
        if r.cards and r.state == "sit":
            out.append(r)
    return out

func _arrange_cards() -> void:
    if cards_node == null:
        return
    for c in cards_node.get_children():
        c.queue_free()
    card_pile.clear()
    var players := _cards_playing() if feast else []
    cards_node.visible = players.size() >= 2
    card_t = rng.randf_range(CARD_EVERY.x, CARD_EVERY.y)

func _cards_tick(dt: float) -> void:
    if cards_node == null:
        return
    var players := _cards_playing()
    var on := players.size() >= 2
    if on != cards_node.visible:
        _arrange_cards()
    if not on:
        return
    card_t -= dt
    if card_t > 0.0:
        return
    card_t = rng.randf_range(CARD_EVERY.x, CARD_EVERY.y)
    if card_pile.size() >= 8:
        for c in card_pile:
            c.queue_free()
        card_pile.clear()
        return
    var who: Rel = players[rng.randi() % players.size()]
    var tc: Dictionary = hall._table_cfg(who.table)
    # 桌面靠后那半（桌心往上 CARD_UP）：桌心正中被前排坐着的人的头挡住，往后放才看得见（04 新 1 挪完桌牌后发现）
    var top: Vector2 = hall._seat_center(tc) + Vector2(0.0, -CARD_UP) - cards_node.position
    var from: Vector2 = who.pos - cards_node.position
    var c := _card(from.lerp(top, 0.35), rng.randf_range(-0.6, 0.6))
    cards_node.add_child(c)
    card_pile.append(c)
    cards_dealt += 1
    var tw := create_tween()
    tw.tween_property(c, "position", top + Vector2(rng.randf_range(-8, 8), rng.randf_range(-5, 5)), 0.25)

# ---------- 走到跟前 ----------
func _near() -> void:
    var best: Rel = null
    var bd := REL_NEAR
    for r in rels:
        var d: float = hall.pos.distance_to(r.pos)
        if d < bd:
            bd = d
            best = r
    if best != near_key:
        near_key = best
        rel_near.emit(best.title if best != null else "", best.relation if best != null else "")

func find(title: String) -> Rel:
    for r in rels:
        if r.title == title:
            return r
    return null
