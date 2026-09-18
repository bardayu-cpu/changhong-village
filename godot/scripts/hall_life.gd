extends Node2D
## 宴会厅的热闹（阿鱼 9/18 要的「氛围感」）：
##   服务员端着托盘在桌子之间走，到桌边停一下，走几桌从东边侧门出去，过一会儿再进来；
##   舞台右边乐队（钢琴、大提琴、两把小提琴），头上飘音符；舞台左边堆满贺礼；地上红彩带、彩纸；
##   灯笼的光一闪一闪；空中慢慢飘花瓣；别的桌坐着 NPC 宾客吃席，隔一会儿整桌举杯。
## 全是摆设：不挡路、点不开、不走服务器、不算真人座位。
## NPC 宾客改了蓝图 3.2（原文「坐着的人是真实住民」），阿鱼 9/18 晚定留，3.2 等总策划改。做法（助理 01 的建议）：
##   只坐 ambience.json 里 npc_tables 那几桌；真人坐到哪把椅子，那把的 NPC 就不画；NPC 坐着的椅子不出「坐这儿」
## 占位图在 assets/ambience/（tools/make_ambience_art.py 画的），正式美术按同名文件换，缺哪张那样东西就不摆；
## 摆哪、几个在 assets/ambience/ambience.json（tools/make_ambience_layout.py 生成）

const Spr = preload("res://scripts/sprites.gd")
const DIR := "res://assets/ambience/"
const FH := 32.0             # 代码画的人一帧 16×32
const WALK_FPS := 5.0        # 服务员走得比玩家慢，迈腿也慢一点
const BITE := Vector2(1.8, 4.5)     # 宾客隔多久低头吃一口，秒
const TOAST := Vector2(9.0, 16.0)   # 一桌隔多久举一次杯，秒
const TOAST_LEN := 1.6

var hall: Node2D             # layered_hall.gd
var conf: Dictionary = {}
var art: Dictionary = {}     # amb_art.json：每张占位图的大小和着地点
var texs: Dictionary = {}
var looks: Dictionary = {}   # 形象 key -> 9 帧图
var rng := RandomNumberGenerator.new()
var t := 0.0
var sc := 84.0 / FH

class Waiter:
    var node: Node2D
    var body: Sprite2D
    var tray: Sprite2D
    var pos := Vector2.ZERO
    var path: Array = []
    var face := "down"
    var state := "serve"     # walk 走去桌边、serve 停在桌边、leave 走去侧门、away 在门外
    var wait := 0.0
    var served := 0
    var shift := 4
    var anim := 0.0
    var table := ""
    var spot := Vector2.ZERO

class Guest:
    var node: Node2D
    var body: Sprite2D
    var cup: Sprite2D
    var table := ""
    var face_frame := 0      # 面朝桌心的那一帧
    var face_flip := false
    var bite := 0.0          # 距离下一口
    var dip := 0.0           # 低头还剩多久
    var turn := 0.0          # 转头还剩多久
    var next_turn := 0.0
    var side := 1.0          # 举杯用哪只手
    var toast_delay := 0.0

var waiters: Array = []
var waiter_speed := 62.0
var door := Vector2.ZERO
var spots: Dictionary = {}   # 桌号 -> 桌边能站的几个点
var guests: Array = []
var guest_holder: Node2D
var npc_taken: Dictionary = {}   # "T7:3" -> true：这把椅子上画了 NPC
var toast_next: Dictionary = {}  # 桌号 -> 还有多久举杯
var toast_left: Dictionary = {}  # 桌号 -> 举杯还剩多久
var bows: Array = []             # [{line, a, b, amp, speed, phase}]：拉琴的弓
var players: Array = []          # [{body, base, speed, phase}]：乐手跟着节拍晃
var heads: Array = []            # 乐手头顶，音符从这冒
var notes: Array = []
var note_timer := 0.5
var glows: Array = []

func build(h: Node2D) -> void:
    var t0 := Time.get_ticks_usec()
    hall = h
    rng.seed = 918
    sc = hall._px_h(500.0) / FH
    var cp := DIR + "ambience.json"
    if not FileAccess.file_exists(cp):
        return
    conf = JSON.parse_string(FileAccess.get_file_as_string(cp))
    if FileAccess.file_exists(DIR + "amb_art.json"):
        var a = JSON.parse_string(FileAccess.get_file_as_string(DIR + "amb_art.json"))
        if typeof(a) == TYPE_DICTIONARY:
            art = a
    _decals()
    _gifts()
    _band()
    _glows()
    _petals()
    _waiters()
    print("[suqi] 厅里的热闹搭好了 用时 %d 毫秒（彩带 %d 灯笼光 %d 服务员 %d）" % [
        (Time.get_ticks_usec() - t0) / 1000, conf.get("decals", []).size(), glows.size(), waiters.size()])

# ---------- 图 ----------
func _tex(name: String) -> Texture2D:
    if not texs.has(name):
        var p := DIR + name + ".png"
        texs[name] = load(p) if ResourceLoader.exists(p) else null
    return texs[name]

## 一张占位图做成精灵，原点放在着地点（amb_art.json 的 anchor；没写就按底边中点）。缺图返回 null
func _sprite(name: String) -> Sprite2D:
    var tx := _tex(name)
    if tx == null:
        return null
    var s := Sprite2D.new()
    s.texture = tx
    s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    s.centered = false
    var a: Array = art.get(name, {}).get("anchor", [tx.get_width() * 0.5, tx.get_height()])
    s.offset = -Vector2(float(a[0]), float(a[1]))
    return s

func _look(key: String, pr: Dictionary) -> Texture2D:
    if not looks.has(key):
        looks[key] = ImageTexture.create_from_image(Spr.sheet_of(pr))
    return looks[key]

## 站着的人：9 帧图，原点在脚底
func _stander(tx: Texture2D) -> Sprite2D:
    var s := Sprite2D.new()
    s.texture = tx
    s.hframes = 9
    s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    s.centered = true
    s.offset = Vector2(0, -FH * 0.5)
    s.scale = Vector2(sc, sc)
    return s

## 坐着的人：只截上半身（和 layered_hall 画住民一样，SIT_KEEP），原点在椅面
func _upper(tx: Texture2D, frame: int, flip: bool) -> Sprite2D:
    var s := Sprite2D.new()
    s.texture = tx
    s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    s.region_enabled = true
    var keep := floorf(FH * hall.SIT_KEEP)
    s.region_rect = Rect2(frame * 16.0, 0.0, 16.0, keep)
    s.flip_h = flip
    s.centered = true
    s.offset = Vector2(0, -keep * 0.5)
    s.scale = Vector2(sc, sc)
    return s

## 坐着、正面朝外的人的小腿和脚（第 24～31 行），接在椅面下面，大腿缩短不画
func _shins(tx: Texture2D) -> Sprite2D:
    var s := Sprite2D.new()
    s.texture = tx
    s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    s.region_enabled = true
    s.region_rect = Rect2(0.0, 24.0, 16.0, 8.0)
    s.centered = true
    s.offset = Vector2(0, 4.0)
    s.scale = Vector2(sc, sc)
    return s

func _vec(a) -> Vector2:
    return Vector2(float(a[0]), float(a[1]))

# ---------- 地上的彩带、彩纸 ----------
func _decals() -> void:
    for d in conf.get("decals", []):
        var s := _sprite(str(d["art"]))
        if s == null:
            continue
        s.position = Vector2(float(d["x"]), float(d["y"]))
        s.flip_h = bool(d.get("flip", false))
        s.z_index = -9   # 贴在底图上（底图 -10），人和桌子都盖在它上面
        s.name = "decal"
        add_child(s, true)

# ---------- 舞台左边的贺礼 ----------
func _gifts() -> void:
    if not conf.has("gifts"):
        return
    var s := _sprite("amb_gift_pile")
    if s == null:
        return
    s.position = _vec(conf["gifts"])
    s.name = "gifts"
    hall.world.add_child(s)

# ---------- 舞台右边的乐队 ----------
func _band() -> void:
    var b: Dictionary = conf.get("band", {})
    if b.is_empty():
        return
    var piano := _sprite("amb_piano")
    if piano != null:
        piano.position = _vec(b["piano"])
        piano.name = "piano"
        hall.world.add_child(piano)
    for st in b.get("stands", []):
        var s := _sprite("amb_music_stand")
        if s != null:
            s.position = _vec(st)
            hall.world.add_child(s)
    # 弹钢琴的：坐在琴凳上，侧身朝右对着琴键；比钢琴着地线靠前一点，画在琴键前面
    var bench_at := _vec(b["bench"])
    var pn := Node2D.new()
    pn.position = bench_at + Vector2(0, 3)
    pn.name = "pianist"
    hall.world.add_child(pn)
    var bench := _sprite("amb_piano_bench")
    var seat_h := 22.0
    if bench != null:
        bench.position = Vector2(0, -3)
        pn.add_child(bench)
        seat_h = float(art.get("amb_piano_bench", {}).get("size", [30, 20])[1]) - 4.0
    var ptx := _look("m_piano", Spr.MUSICIANS["piano"])
    var pb := _upper(ptx, 6, false)
    pb.position = Vector2(4, -3 - seat_h)
    pn.add_child(pb)
    players.append({"body": pb, "base": pb.offset, "speed": 2.6, "phase": 0.0})
    heads.append(pn.position + Vector2(4, -3 - seat_h - 50))
    # 拉大提琴的：坐在椅子上正面朝外，大提琴立在两腿前面，弓横着来回拉
    var cello_at := _vec(b["cello"])
    var cn := Node2D.new()
    cn.position = cello_at
    cn.name = "cellist"
    hall.world.add_child(cn)
    var chair := _sprite("amb_chair")
    if chair != null:
        cn.add_child(chair)
    var ctx := _look("m_cello", Spr.MUSICIANS["cello"])
    var seat := Vector2(0, -20)
    var cb := _upper(ctx, 0, false)
    cb.position = seat
    cn.add_child(cb)
    var cl := _shins(ctx)
    cl.position = seat
    cn.add_child(cl)
    var cello := _sprite("amb_cello")
    if cello != null:
        cello.position = Vector2(-1, 6)
        cn.add_child(cello)
        _bow(cn, Vector2(-17, -16), Vector2(15, -12), 6.0, 2.2)
    players.append({"body": cb, "base": cb.offset, "speed": 1.8, "phase": 1.0})
    heads.append(cn.position + seat + Vector2(0, -50))
    # 两个拉小提琴的：站着正面朝外，琴架在左肩（画面右边），弓斜着拉
    for k in [1, 2]:
        var key := "violin%d" % k
        var vn := Node2D.new()
        vn.position = _vec(b[key])
        vn.name = key
        hall.world.add_child(vn)
        var vb := _stander(_look("m_" + key, Spr.MUSICIANS[key]))
        vb.frame = 0
        vn.add_child(vb)
        var vi := _sprite("amb_violin")
        if vi != null:
            vi.position = Vector2(12, -53)
            vn.add_child(vi)
            _bow(vn, Vector2(-16, -38), Vector2(14, -58), 5.0, 2.8 + k * 0.3)
        players.append({"body": vb, "base": vb.offset, "speed": 2.2 + k * 0.4, "phase": k * 1.3})
        heads.append(vn.position + Vector2(0, -86))

## 琴弓：一根细线，沿着自己的方向来回推拉
func _bow(parent: Node2D, a: Vector2, b: Vector2, amp: float, speed: float) -> void:
    var l := Line2D.new()
    l.width = 1.5
    l.default_color = Color("#d9c29a")
    l.points = PackedVector2Array([a, b])
    l.antialiased = false
    parent.add_child(l)
    bows.append({"line": l, "a": a, "b": b, "amp": amp, "speed": speed, "phase": rng.randf() * TAU})

# ---------- 灯笼的光、飘的花瓣 ----------
func _glows() -> void:
    var g := Gradient.new()
    g.set_color(0, Color(1.0, 0.8, 0.45, 1.0))
    g.set_color(1, Color(1.0, 0.55, 0.25, 0.0))
    var gt := GradientTexture2D.new()
    gt.gradient = g
    gt.width = 64
    gt.height = 64
    gt.fill = GradientTexture2D.FILL_RADIAL
    gt.fill_from = Vector2(0.5, 0.5)
    gt.fill_to = Vector2(1.0, 0.5)
    var mat := CanvasItemMaterial.new()
    mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    for p in conf.get("glows", []):
        var s := Sprite2D.new()
        s.texture = gt
        s.material = mat
        s.position = Vector2(float(p[0]), float(p[1]))
        var r := float(p[2])
        s.scale = Vector2(r / 32.0, r / 32.0)
        s.z_index = 3
        s.modulate.a = float(p[3])
        s.name = "glow"
        add_child(s, true)
        glows.append({"spr": s, "a": float(p[3]), "phase": rng.randf() * TAU})

func _petals() -> void:
    var amount := int(conf.get("petals", {}).get("amount", 0))
    if amount <= 0:
        return
    var size: Vector2 = Vector2(hall.cfg["size"][0], hall.cfg["size"][1])
    for k in 2:
        var tx := _tex("amb_petal_%d" % (k + 1))
        if tx == null:
            continue
        var p := CPUParticles2D.new()
        p.texture = tx
        p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        p.amount = amount if k == 0 else maxi(amount / 3, 1)
        p.lifetime = 18.0
        p.preprocess = 18.0   # 一进厅就已经在飘，不是从天花板刚开始往下掉
        p.randomness = 0.6
        p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
        p.emission_rect_extents = Vector2(size.x * 0.5, 8.0)
        p.position = Vector2(size.x * 0.5, -12.0)
        p.direction = Vector2(0.25, 1.0)
        p.spread = 25.0
        p.gravity = Vector2(0.0, 4.0)
        p.initial_velocity_min = 34.0
        p.initial_velocity_max = 58.0
        p.angular_velocity_min = -90.0
        p.angular_velocity_max = 90.0
        p.z_index = 3
        p.name = "petals"
        add_child(p)

# ---------- 服务员 ----------
func _waiters() -> void:
    var wc: Dictionary = conf.get("waiters", {})
    var n := int(wc.get("count", 0))
    if n <= 0:
        return
    door = _vec(wc.get("door", [1448, 800]))
    waiter_speed = float(wc.get("speed_m", 1.3)) * hall.px_per_m(600.0)
    _spots()
    var ids: Array = spots.keys()
    ids.sort()
    for i in n:
        var w := Waiter.new()
        w.node = Node2D.new()
        w.node.name = "waiter%d" % i
        hall.world.add_child(w.node)
        w.body = _stander(_look("w%d" % (i % Spr.WAITERS.size()), Spr.WAITERS[i % Spr.WAITERS.size()]))
        w.node.add_child(w.body)
        w.tray = _sprite("amb_tray")
        if w.tray != null:
            w.node.add_child(w.tray)
        # 开场时分散在几张桌边，已经在上菜了
        w.table = str(ids[(i * 5 + 2) % ids.size()])
        var sp: Array = spots[w.table]
        w.pos = sp[i % sp.size()]
        w.spot = w.pos
        w.state = "serve"
        w.wait = rng.randf_range(0.5, 3.0)
        w.shift = rng.randi_range(3, 5)
        w.face = hall._face_for(_table_center(w.table) - w.pos)
        waiters.append(w)
        _pose_waiter(w, false)

func _table_center(tid: String) -> Vector2:
    var tc: Dictionary = hall._table_cfg(tid)
    return Vector2(float(tc["x"]), float(tc["y"]))

## 每张桌边几个能站的点（桌子左、右、前面），服务员上菜时停在这
func _spots() -> void:
    for tc in hall.cfg.get("tables", []):
        var c := Vector2(float(tc["x"]), float(tc["y"]))
        var rx := float(tc["rx"])
        var ry := float(tc["ry"])
        var out: Array = []
        for v in [Vector2(-(rx + 16.0), -14.0), Vector2(rx + 16.0, -14.0), Vector2(-rx * 0.55, ry + 12.0), Vector2(rx * 0.55, ry + 12.0)]:
            var p: Vector2 = c + v
            if hall._free(p):
                out.append(p)
        if not out.is_empty():
            spots[str(tc["id"])] = out

func _pick_table(w: Waiter) -> void:
    var ids: Array = spots.keys()
    for tries in 12:
        var tid := str(ids[rng.randi() % ids.size()])
        if tid == w.table:
            continue
        var sp: Array = spots[tid]
        var p: Vector2 = sp[rng.randi() % sp.size()]
        var busy := false
        for o in waiters:
            if o != w and o.spot.distance_to(p) < 30.0:
                busy = true
        if busy:
            continue
        var route: Array = hall.find_path(w.pos, p)
        if route.is_empty():
            continue
        w.table = tid
        w.spot = p
        w.path = route
        w.state = "walk"
        return
    w.state = "serve"
    w.wait = 1.0

func _step_waiter(w: Waiter, dt: float) -> void:
    var moving := false
    match w.state:
        "walk", "leave":
            if w.path.is_empty():
                if w.state == "walk":
                    w.state = "serve"
                    w.wait = rng.randf_range(2.0, 3.6)
                    w.face = hall._face_for(_table_center(w.table) - w.pos)
                else:
                    w.state = "away"
                    w.wait = rng.randf_range(3.0, 7.0)
                    w.node.visible = false
            else:
                var tgt: Vector2 = w.path[0]
                var to := tgt - w.pos
                var d := to.length()
                if d < 1.5:
                    w.pos = tgt
                    w.path.pop_front()
                else:
                    w.pos += to / d * minf(d, waiter_speed * dt)
                    w.face = hall._face_for(to)
                    moving = true
        "serve":
            w.wait -= dt
            if w.wait <= 0.0:
                w.served += 1
                if w.served >= w.shift:
                    w.path = hall.find_path(w.pos, door)
                    w.state = "leave"
                    w.spot = door
                else:
                    _pick_table(w)
        "away":
            w.wait -= dt
            if w.wait <= 0.0:
                w.pos = door
                w.node.visible = true
                w.served = 0
                w.shift = rng.randi_range(3, 5)
                _pick_table(w)
    w.anim = w.anim + dt if moving else 0.0
    _pose_waiter(w, moving)

func _pose_waiter(w: Waiter, moving: bool) -> void:
    var fl: Dictionary = Spr.PROC_ANIM[w.face]
    var walk: Array = fl["walk"]
    w.body.frame = walk[int(w.anim * WALK_FPS) % walk.size()] if moving else int(fl["idle"])
    w.body.flip_h = bool(fl["flip"])
    var bob := -absf(sin(w.anim * WALK_FPS * PI)) * 1.2 if moving else 0.0
    w.body.offset = Vector2(0, -FH * 0.5 + bob)
    w.node.position = w.pos
    if w.tray != null:
        # 托盘端在左手、举到肩膀高：面朝外时在画面右边，背对时在左边，侧身时在身前
        var tx := 14.0
        match w.face:
            "up": tx = -14.0
            "right": tx = 10.0
            "left": tx = -10.0
        w.tray.position = Vector2(tx, -50.0 + bob * sc)

# ---------- 别桌的 NPC 宾客 ----------
## set_seats 每次重画真人以后调：按 npc_tables 摆 NPC，真人坐了的椅子跳过。返回 NPC 坐着的椅子
func seat_guests(taken: Dictionary) -> Dictionary:
    var t0 := Time.get_ticks_usec()
    if guest_holder != null:
        guest_holder.queue_free()
    guests.clear()
    npc_taken = {}
    guest_holder = Node2D.new()
    guest_holder.y_sort_enabled = true
    guest_holder.name = "npc_guests"
    hall.world.add_child(guest_holder)
    var plan: Dictionary = conf.get("npc_tables", {})
    var ids: Array = plan.keys()
    ids.sort()
    for tid in ids:
        var tc: Dictionary = hall._table_cfg(str(tid))
        if tc.is_empty():
            continue
        var r := RandomNumberGenerator.new()
        r.seed = hash(str(tid)) & 0x7fffffff
        var nos: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        for i in range(nos.size() - 1, 0, -1):
            var j := r.randi_range(0, i)
            var tmp = nos[i]
            nos[i] = nos[j]
            nos[j] = tmp
        var center: Vector2 = hall._seat_center(tc)
        for k in mini(int(plan[tid]), 10):
            var no: int = nos[k]
            var key := "%s:%d" % [tid, no]
            if taken.has(key):
                continue   # 真人坐了这把，NPC 让座
            npc_taken[key] = true
            var at: Vector2 = hall.chair_world(tc, no)
            _guest(str(tid), key, at, center, hall.seat_in_front(tc, at))
        if not toast_next.has(tid):
            toast_next[tid] = rng.randf_range(2.0, TOAST.y)
    print("[suqi] 别桌 NPC 宾客 %d 个 用时 %d 毫秒" % [guests.size(), (Time.get_ticks_usec() - t0) / 1000])
    return npc_taken

func _guest(tid: String, key: String, at: Vector2, center: Vector2, front: bool) -> void:
    var g := Guest.new()
    g.table = tid
    g.node = Node2D.new()
    g.node.position = at
    g.node.z_index = 1 if front else 0   # 和 layered_hall 画住民一样：桌子两边和前面的画在桌子前面
    guest_holder.add_child(g.node)
    var li := absi(hash(key)) % 20   # 20 种长相轮着用：长相是现画的，太多了进厅那一下会卡
    var tx := _look("g%d" % li, Spr.guest_look(li))
    var fl: Dictionary = Spr.PROC_ANIM[hall._face_for(center - at)]
    g.face_frame = int(fl["idle"])
    g.face_flip = bool(fl["flip"])
    g.body = _upper(tx, g.face_frame, g.face_flip)
    g.node.add_child(g.body)
    g.cup = _sprite("amb_cup")
    if g.cup != null:
        g.cup.visible = false
        g.node.add_child(g.cup)
    g.side = -1.0 if rng.randf() < 0.5 else 1.0
    g.bite = rng.randf_range(0.2, BITE.y)
    g.next_turn = rng.randf_range(2.0, 8.0)
    guests.append(g)

func _step_guest(g: Guest, dt: float) -> void:
    var keep := floorf(FH * hall.SIT_KEEP)
    # 吃一口：低一下头（整个上半身往下 1 个美术像素）
    g.bite -= dt
    if g.bite <= 0.0:
        g.bite = rng.randf_range(BITE.x, BITE.y)
        g.dip = 0.35
    g.dip = maxf(g.dip - dt, 0.0)
    # 转头跟旁边的人说话：换成侧面那一帧，过一会儿转回来
    g.next_turn -= dt
    if g.next_turn <= 0.0:
        g.next_turn = rng.randf_range(4.0, 9.0)
        if rng.randf() < 0.4:
            g.turn = rng.randf_range(1.4, 2.6)
            g.body.region_rect = Rect2(6 * 16.0, 0.0, 16.0, keep)
            g.body.flip_h = rng.randf() < 0.5
    if g.turn > 0.0:
        g.turn -= dt
        if g.turn <= 0.0:
            g.body.region_rect = Rect2(g.face_frame * 16.0, 0.0, 16.0, keep)
            g.body.flip_h = g.face_flip
    g.body.offset = Vector2(0, -keep * 0.5 + (1.0 if g.dip > 0.0 else 0.0))
    # 举杯：这桌举杯的时候，酒杯举过头顶，先升后落
    var left: float = toast_left.get(g.table, 0.0)
    if g.cup != null:
        var k := TOAST_LEN - left - g.toast_delay
        if left > 0.0 and k > 0.0:
            g.cup.visible = true
            var up := minf(k / 0.3, 1.0) * minf(maxf(TOAST_LEN - k, 0.0) / 0.3, 1.0)
            # 手从下巴高举到头顶旁边（上半身高 keep*sc，头在上面那一截）
            g.cup.position = Vector2(g.side * 16.0, -keep * sc * (0.6 + 0.45 * up))
        else:
            g.cup.visible = false

# ---------- 每帧 ----------
func _process(dt: float) -> void:
    t += dt
    for w in waiters:
        _step_waiter(w, dt)
    # 举杯：每桌自己的节奏
    for tid in toast_next.keys():
        if toast_left.get(tid, 0.0) > 0.0:
            toast_left[tid] = maxf(toast_left[tid] - dt, 0.0)
            continue
        toast_next[tid] -= dt
        if toast_next[tid] <= 0.0:
            toast_next[tid] = rng.randf_range(TOAST.x, TOAST.y)
            toast_left[tid] = TOAST_LEN
            for g in guests:
                if g.table == tid:
                    g.toast_delay = rng.randf_range(0.0, 0.25)
    for g in guests:
        _step_guest(g, dt)
    for b in bows:
        var d: Vector2 = (b["b"] - b["a"]).normalized() * b["amp"] * sin(t * b["speed"] + b["phase"])
        b["line"].points = PackedVector2Array([b["a"] + d, b["b"] + d])
    for p in players:
        # 跟着节拍轻轻晃：1 个美术像素上下
        var on := sin(t * p["speed"] * PI + p["phase"]) > 0.3
        p["body"].offset = p["base"] + Vector2(0, 1.0 if on else 0.0)
    _step_notes(dt)
    for gl in glows:
        var f := 0.86 + 0.08 * sin(t * 2.3 + gl["phase"]) + 0.06 * sin(t * 5.1 + gl["phase"] * 1.7)
        gl["spr"].modulate.a = gl["a"] * f

func _step_notes(dt: float) -> void:
    note_timer -= dt
    if note_timer <= 0.0 and not heads.is_empty():
        note_timer = rng.randf_range(0.5, 1.0)
        var s := _sprite("amb_note_%d" % rng.randi_range(1, 2))
        if s != null:
            var h: Vector2 = heads[rng.randi() % heads.size()]
            s.z_index = 3
            add_child(s)
            notes.append({"spr": s, "t": 0.0, "life": 2.4, "x0": h.x + rng.randf_range(-12.0, 12.0), "y0": h.y})
    for n in notes.duplicate():
        n["t"] += dt
        var k: float = n["t"] / n["life"]
        var s: Sprite2D = n["spr"]
        s.position = Vector2(n["x0"] + sin(n["t"] * 3.0) * 5.0, n["y0"] - 46.0 * k)
        s.modulate.a = 1.0 - smoothstep(0.55, 1.0, k)
        if k >= 1.0:
            s.queue_free()
            notes.erase(n)
