extends Node2D
## 宴会厅的热闹（阿鱼 9/18 要的「氛围感」）：
##   服务员从东侧门端菜出来，走到桌边把菜放上桌（冒热气），端空托盘回去再端下一盘（9/18 晚改：原来只端着走不放下）；
##   舞台右边乐队（钢琴、大提琴、两把小提琴），头上飘音符；舞台左边堆满贺礼；地上红彩带、彩纸；
##   灯笼的光一闪一闪；空中慢慢飘花瓣；每张桌都坐着 NPC 宾客吃席，隔一会儿整桌举杯（9/18 晚：原来只坐 7～12 号桌、人太少）。
## 全是摆设：不挡路、点不开、不走服务器、不算真人座位。
## NPC 宾客（蓝图 3.2，阿鱼 9/18 定）：坐 ambience.json 里 npc_tables 那几桌；真人坐了的椅子 NPC 不坐；
##   9/18 晚起 NPC 坐着的椅子也出「坐这儿」，真人坐下时那个 NPC 起身、从大门走掉（vacate），所以真人哪把都能坐
## 占位图在 assets/ambience/（tools/make_ambience_art.py 画的），正式美术按同名文件换，缺哪张那样东西就不摆；
## 摆哪、几个在 assets/ambience/ambience.json（tools/make_ambience_layout.py 生成）

const Spr = preload("res://scripts/sprites.gd")
const DIR := "res://assets/ambience/"
const FH := 32.0             # 代码画的人一帧 16×32
const WALK_FPS := 5.0        # 服务员走得比玩家慢，迈腿也慢一点
const BITE := Vector2(1.8, 4.5)     # 宾客隔多久低头吃一口，秒
const TOAST := Vector2(9.0, 16.0)   # 一桌隔多久举一次杯，秒
const TOAST_LEN := 1.6
const SERVE_LEN := 1.2      # 服务员放菜那一下多久，秒：前一半托盘放低，正中把菜放上桌，后一半收回
const DISH_LIFE := Vector2(30.0, 45.0)   # 新上的菜在桌上留多久（吃完了淡出）
const DISH_MAX := 2          # 一张桌上最多同时几盘新上的菜，多了先撤最早那盘
const LOOKS := 20            # 别桌宾客几种长相：长相是代码现画的，拼成一张图，所有宾客共用（手机上少切几次图）

var hall: Node2D             # layered_hall.gd
var conf: Dictionary = {}
var art: Dictionary = {}     # amb_art.json：每张占位图的大小和着地点
var texs: Dictionary = {}
var looks: Dictionary = {}   # 形象 key -> 9 帧图
var rng := RandomNumberGenerator.new()
var t := 0.0
var sc := 84.0 / FH

## 走来走去的人：服务员，还有让了座往外走的 NPC 宾客（kind = "leaver"）
class Waiter:
    var kind := "waiter"
    var node: Node2D
    var body: Sprite2D
    var tray: Sprite2D
    var pos := Vector2.ZERO
    var path: Array = []
    var face := "down"
    var state := "carry"     # carry 端菜走去桌边、serve 放菜、return 空托盘回侧门、away 在门里、leave 让座的宾客往外走
    var wait := 0.0
    var serve_t := 0.0
    var placed := false
    var full := true         # 托盘上有没有菜
    var anim := 0.0
    var table := ""
    var spot := Vector2.ZERO
    var gone := false
    var order := ""          # 这一趟端的是玩家添的哪道菜（空串是平常上菜，随机挑桌）
    var order_t := 0.0       # 这一单接了多久了：超过 ORDER_WAIT_MAX 直接摆上桌，不让人干等

class Guest:
    var node: Node2D
    var body: Sprite2D
    var cup: Sprite2D
    var table := ""
    var key := ""            # "T7:3"
    var row := 0             # 长相在宾客拼图里是第几行
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
var dishes: Array = []           # [{spr, table, left, keep}]：服务员新放上桌的菜。keep 的是玩家添的，不淡出
## 玩家添的菜还没端到的（玩法过目-金币花在哪 第一样）：[{tid, name, wait}]。
## 下一个空出来的服务员接单；等太久（都在放菜、路一时走不通）就直接摆上，钱不能白花
var orders: Array = []
const ORDER_WAIT_MAX := 12.0
const ORDER_NAME_SECS := 6.0     # 菜名在桌上显示几秒（看清是哪道，然后收掉，不长期挡着）
var guest_atlas: ImageTexture

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
    _rugs()
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

# ---------- 桌子下面的红地毯（阿鱼 9/18 晚：厅里看着太空）----------
## 每张桌一块，圈心在桌子加椅子那一圈的地面中间（着地点往上 20 像素）；桌子积木盖在它上面，只露一圈边
func _rugs() -> void:
    for tc in hall.cfg.get("tables", []):
        var s := _sprite("amb_rug")
        if s == null:
            return
        s.position = Vector2(float(tc["x"]), float(tc["y"]) - 20.0)
        s.z_index = -9   # 和彩带一样贴在底图上；先摆，彩带压在它上面
        s.name = "rug"
        add_child(s, true)

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
## 舞台右边的乐队。**先试 GPT 交的那批图**（assets/ambience/band/，v2，01 9/21 验收：
## 逐块和阿鱼确认的效果图比过，八块色差 0.0，是从那张图上拆的）；
## 图或者 band.json 缺了就退回原来代码画的那套色块，跟菜牌、阶梯图一个规矩。
## 音符和灯光走**单独的动效层**：音符按 band.json 给的点往上飘（换曲时换一种形状），灯光原地闪，
## 都不画死在乐手身上
func _band() -> void:
    if _band_art():
        return
    _band_blocks()

const BAND_DIR := "band/"
const BAND_CFG := DIR + "band/band.json"
var band_notes: Array = []       # 音符用哪几张图（图没到时是代码画的那两张）

## 按 band.json 摆那批图；json 或者图缺了返回 false，让调用方退回色块
func _band_art() -> bool:
    if not FileAccess.file_exists(BAND_CFG):
        return false
    var j = JSON.parse_string(FileAccess.get_file_as_string(BAND_CFG))
    if not (j is Dictionary):
        return false
    var cfg: Dictionary = j
    # 阿鱼 9/22 打回：这批图扣烂了（粘着地毯和墙、一个人的脸被顶掉）。
    # enabled 关着就走原来代码画的那套色块，图留着不删，GPT 重扣好再打开
    if not bool(cfg.get("enabled", true)):
        print("[suqi] 乐队的图被关着（band.json enabled=false），用代码画的那套")
        return false
    var blocks: Dictionary = cfg.get("blocks", {})
    var place: Array = cfg.get("place", [])
    if blocks.is_empty() or place.is_empty():
        return false
    # 一套图缺一张就整套不用（跟小游戏那边一个规矩：半图半色块比全色块更难看）
    for k in blocks:
        if _tex(BAND_DIR + str((blocks[k] as Dictionary).get("file", "")).replace(".png", "")) == null:
            print("[suqi] 乐队的图缺 ", k, "，这一片退回代码画的色块")
            return false
    var ordered: Array = place.duplicate()
    ordered.sort_custom(func(a, b): return int((a as Dictionary).get("z", 0)) < int((b as Dictionary).get("z", 0)))
    var blocked := 0
    band_notes = []
    for pl_any in ordered:
        var pl: Dictionary = pl_any
        var key := str(pl.get("block", ""))
        var bk: Dictionary = blocks.get(key, {})
        if bk.is_empty():
            continue
        var file := str(bk.get("file", "")).replace(".png", "")
        var at := _vec(pl.get("at", [0, 0]))
        var anchor := _vec(bk.get("anchor", [0, 0]))
        var motion := str(pl.get("motion", ""))
        if motion == "float_up":
            # 音符：不摆成一张死图，只记下从哪儿往上飘，交给 _step_notes
            heads.append(at)
            band_notes.append(BAND_DIR + file)
            continue
        var tx := _tex(BAND_DIR + file)
        var s := Sprite2D.new()
        s.texture = tx
        s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        s.centered = false
        s.offset = -anchor
        s.position = at
        s.name = key
        s.z_index = int(pl.get("z", 0)) - 30    # 和厅里别的东西一个坐标系：人和桌子按着地点排，这批固定在乐队这一片
        hall.world.add_child(s, true)
        if motion == "flicker":
            # 灯光：原地一闪一闪，和灯笼的光同一套
            glows.append({"spr": s, "a": 1.0, "phase": rng.randf() * TAU})
        elif bool(bk.get("can_block", false)):
            blocked += _block_cells(at, anchor, tx)
    print("[suqi] 乐队用 GPT 的图摆好了：%d 件，音符 %d 种，挡人挖掉 %d 格" % [ordered.size(), band_notes.size(), blocked])
    return true

## 乐手脚下那一小片标成走不进去。**乐队这一片本来就不在能走的格子里**（能走的从 y 320 起），
## 所以今天一格都挖不掉；留着这段是为了以后谁把乐队往厅里挪的时候不用再想一遍
func _block_cells(at: Vector2, anchor: Vector2, tx: Texture2D) -> int:
    if tx == null:
        return 0
    var half := float(tx.get_width()) * 0.5
    var n := 0
    var y := at.y - 6.0
    while y <= at.y + 4.0:
        var x := at.x - half
        while x <= at.x + half:
            var c: Vector2i = hall._cell_of(Vector2(x, y))
            if c.x >= 0 and c.y >= 0 and c.x < hall.cols and c.y < hall.rows and hall.walk[c.y * hall.cols + c.x] == 1:
                hall.walk[c.y * hall.cols + c.x] = 0
                n += 1
            x += 8.0
        y += 8.0
    return n

## 原来那套：钢琴、琴凳、大提琴、两把小提琴全是代码画的色块，图没到的时候用
func _band_blocks() -> void:
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
## 一趟：在东侧门端上一盘（托盘上扣着盖）→ 走到一张桌边 → 托盘放低、把菜放上桌（冒热气）→ 端空托盘回侧门 → 门里待几秒再端下一盘
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
        # 开场时分散在几张桌边，已经端着菜在走了
        w.table = str(ids[(i * 5 + 2) % ids.size()])
        var sp: Array = spots[w.table]
        w.pos = sp[i % sp.size()]
        _start_trip(w)
        waiters.append(w)
        _pose_waiter(w, false)

func _table_center(tid: String) -> Vector2:
    var tc: Dictionary = hall._table_cfg(tid)
    return Vector2(float(tc["x"]), float(tc["y"]))

## 每张桌边几个能站的点（桌子左、右、前面），服务员放菜时停在这
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

## 端上一盘，挑一张桌走过去
func _start_trip(w: Waiter) -> void:
    w.full = true
    _tray_look(w)
    _pick_table(w)

func _pick_table(w: Waiter) -> void:
    w.order = ""
    # 有人添了菜就先走这一单（玩法过目-金币花在哪 第一样：服务员真的端过来）
    if not orders.is_empty() and _take_order(w):
        return
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
        w.state = "carry"
        return
    # 一时挑不到（别的服务员占着）：原地等一秒再挑
    w.state = "away"
    w.wait = 1.0

# ---------- 玩家添的菜（玩法过目-金币花在哪 第一样，阿鱼 9/20 点头） ----------

## 添一道菜：叫服务员端这道菜去那张桌。和平常上菜不一样的三处——端的是指定那张桌、
## 放下不撤（摆到离开宴会厅为止）、放下那会儿菜名在桌上显示几秒。桌号不认得返回 false（钱不扣）
func order_dish(tid: String, dish_name: String) -> bool:
    if dish_name == "" or not spots.has(tid):
        return false
    orders.append({"tid": tid, "name": dish_name, "wait": 0.0})
    # 当场调一个服务员过来，别等它把手上这趟走完——那一趟可能还有大半圈，
    # 说了「马上端来」就不能让人等一分钟
    var best = null
    var best_d := INF
    for w in waiters:
        if w.kind != "waiter" or w.order != "" or w.state == "serve":
            continue
        var d: float = w.pos.distance_to(_table_center(tid))
        if d < best_d:
            best_d = d
            best = w
    # 在门里待着的是藏起来的（state=away、node.visible=false）：先让它从门口现身再派活，
    # 不然它一路隐身走过去，菜像凭空出现在桌上（03 9/20 报的）。
    # 也必须先挪到门口再算路——不然算的是它上一趟停下的老位置
    if best != null and best.state == "away":
        best.pos = door
        best.node.visible = true
        best.wait = 0.0
    if best != null and _take_order(best):
        best.full = true
        _tray_look(best)
    else:
        # 一个都调不动（都在放菜）：门里待着的先出来，剩下的交给下一个空出来的，再不行走兜底
        for w in waiters:
            if w.kind == "waiter" and w.state == "away":
                w.wait = minf(w.wait, 0.2)
    return true

## 这张桌上玩家自己添的菜，已经摆上桌的有几道
func ordered_count(tid: String) -> int:
    var n := 0
    for dd in dishes:
        if bool(dd.get("keep", false)) and str(dd["table"]) == tid:
            n += 1
    return n

## 添了还没摆上桌的有几道：单子里排队的 + 服务员已经端在手上往这张桌走的。
## 服务员走过去要好几秒，只数桌上的话，这几秒里连点就能绕过上限（03 9/20 测出来：连点 6 次上了 6 道）
func coming_count(tid: String) -> int:
    var n := 0
    for od in orders:
        if str(od["tid"]) == tid:
            n += 1
    for w in waiters:
        if w.order != "" and w.table == tid:
            n += 1
    return n

## 这张桌一共几道（摆上的 + 在路上的）。判断「桌上摆满了」要拿这个数比
func ordered_total(tid: String) -> int:
    return ordered_count(tid) + coming_count(tid)

## 离开宴会厅：添的菜和还没端到的单子都清掉（不累计、不进存档）
func clear_orders() -> void:
    orders.clear()
    for dd in dishes.duplicate():
        if bool(dd.get("keep", false)):
            _drop_dish(dd)

## 这个服务员接一单：走得到就接，走不到（路被占）留给下一个
func _take_order(w: Waiter) -> bool:
    for od in orders:
        var tid := str(od["tid"])
        if not spots.has(tid):
            orders.erase(od)
            return false
        var sp: Array = spots[tid]
        for p in sp:
            var route: Array = hall.find_path(w.pos, p)
            if route.is_empty():
                continue
            w.table = tid
            w.spot = p
            w.path = route
            w.state = "carry"
            w.order = str(od["name"])
            w.order_t = 0.0
            orders.erase(od)
            return true
    return false

## 添的菜从下单到上桌一律封顶 ORDER_WAIT_MAX 秒，钱不能白花、也不能让人干等：
## 没人接的（服务员都在放菜、一时走不过去）到点直接摆上桌；接了单但路上走太久的也一样
func _orders_tick(dt: float) -> void:
    for od in orders.duplicate():
        od["wait"] = float(od["wait"]) + dt
        if float(od["wait"]) < ORDER_WAIT_MAX:
            continue
        var tid := str(od["tid"])
        orders.erase(od)
        if not spots.has(tid):
            continue
        var sp: Array = spots[tid]
        _place_dish(tid, sp[0], str(od["name"]))
    for w in waiters:
        if w.order == "":
            continue
        w.order_t += dt
        if w.order_t < ORDER_WAIT_MAX:
            continue
        # 这一单先记在桌上，服务员该怎么走还怎么走（它待会儿放的就是平常那盘菜）
        var tid2: String = w.table
        var name2: String = w.order
        w.order = ""
        w.order_t = 0.0
        if spots.has(tid2):
            _place_dish(tid2, (spots[tid2] as Array)[0], name2)

func _tray_look(w: Waiter) -> void:
    if w.tray == null:
        return
    var tx := _tex("amb_tray" if w.full else "amb_tray_empty")
    if tx != null:
        w.tray.texture = tx

func _step_waiter(w: Waiter, dt: float) -> void:
    var moving := false
    match w.state:
        "carry", "return", "leave":
            if w.path.is_empty():
                _arrive(w)
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
            w.serve_t += dt
            if not w.placed and w.serve_t >= SERVE_LEN * 0.5:
                w.placed = true
                _place_dish(w.table, w.pos, w.order)
                w.order = ""
                w.full = false
                _tray_look(w)
            if w.serve_t >= SERVE_LEN:
                w.path = hall.find_path(w.pos, door)
                w.spot = door
                w.state = "return"
        "away":
            w.wait -= dt
            if w.wait <= 0.0:
                if not w.node.visible:
                    w.pos = door
                    w.node.visible = true
                _start_trip(w)
    w.anim = w.anim + dt if moving else 0.0
    _pose_waiter(w, moving)

func _arrive(w: Waiter) -> void:
    match w.state:
        "carry":
            w.state = "serve"
            w.serve_t = 0.0
            w.placed = false
            w.face = hall._face_for(_table_center(w.table) - w.pos)
        "return":
            w.state = "away"
            w.wait = rng.randf_range(2.0, 5.0)
            w.node.visible = false
        "leave":
            w.node.queue_free()
            w.gone = true

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
        var tp := Vector2(tx, -50.0 + bob * sc)
        if w.state == "serve":
            # 放菜：托盘往桌子那边伸、往下放，放完收回
            var k := sin(clampf(w.serve_t / SERVE_LEN, 0.0, 1.0) * PI)
            var toward := (_table_center(w.table) - w.pos).normalized()
            tp += Vector2(toward.x * 12.0, 14.0) * k
        w.tray.position = tp

## 菜放上桌：在桌面靠服务员那一边，按桌子着地那一行排前后（画在桌面上、桌前的人后面；簿子是 +0.5）。
## ordered 不是空串：这是玩家添的那道菜，放下不撤，菜名在桌上显示几秒
func _place_dish(tid: String, from: Vector2, ordered := "") -> void:
    var tc: Dictionary = hall._table_cfg(tid)
    if tc.is_empty():
        return
    var s := _sprite("amb_dish_%d" % rng.randi_range(1, 3))
    if s == null:
        return
    # 撤旧的只撤服务员自己上的那几盘，玩家添的不撤
    var mine := dishes.filter(func(d): return d["table"] == tid and not bool(d.get("keep", false)))
    if mine.size() >= DISH_MAX:
        _drop_dish(mine[0])
    var top: Vector2 = hall._seat_center(tc) + Vector2(0, -6)   # 桌面中心：比椅面那一圈高一点
    var d := from - top
    var dir := Vector2(d.x / float(tc["rx"]), d.y / float(tc["ry"]))
    dir = dir.normalized() if dir.length() > 0.001 else Vector2(0, 1)
    var p := top + Vector2(dir.x * 36.0, dir.y * 14.0)
    var foot := Vector2(float(tc["x"]), float(tc["y"]) + 0.6)
    s.position = foot
    s.offset += p - foot
    s.name = "dish"
    hall.world.add_child(s, true)
    var steam := _steam()
    if steam != null:
        steam.position = p - foot + Vector2(0, -6)
        s.add_child(steam)
    if ordered == "":
        dishes.append({"spr": s, "table": tid, "left": rng.randf_range(DISH_LIFE.x, DISH_LIFE.y), "keep": false})
        return
    # 玩家添的：菜名在盘子上方显示几秒（看清是哪道），盘子留到离开宴会厅
    var tag := Label.new()
    tag.text = ordered
    if hall.font != null:
        tag.add_theme_font_override("font", hall.font)
    tag.add_theme_font_size_override("font_size", 20)
    tag.add_theme_color_override("font_color", Color("#f4d97a"))
    tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
    tag.add_theme_constant_override("shadow_offset_x", 2)
    tag.add_theme_constant_override("shadow_offset_y", 2)
    tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tag.position = p - foot + Vector2(-60, -34)
    tag.custom_minimum_size = Vector2(120, 0)
    tag.size = Vector2(120, 24)
    tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
    s.add_child(tag)
    dishes.append({"spr": s, "table": tid, "left": INF, "keep": true, "tag": tag, "tag_left": ORDER_NAME_SECS})

func _drop_dish(dd: Dictionary) -> void:
    (dd["spr"] as Sprite2D).queue_free()
    dishes.erase(dd)

## 热菜冒的气：三两团白气往上飘、慢慢淡掉
func _steam() -> CPUParticles2D:
    var tx := _tex("amb_steam")
    if tx == null:
        return null
    var p := CPUParticles2D.new()
    p.texture = tx
    p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    p.amount = 3
    p.lifetime = 1.6
    p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    p.emission_rect_extents = Vector2(5.0, 1.0)
    p.direction = Vector2(0.0, -1.0)
    p.spread = 12.0
    p.gravity = Vector2.ZERO
    p.initial_velocity_min = 10.0
    p.initial_velocity_max = 16.0
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1, 1, 1, 0.75))
    ramp.set_color(1, Color(1, 1, 1, 0.0))
    p.color_ramp = ramp
    return p

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

## 别桌宾客的长相拼成一张图：一种长相一行（9 帧 144×32），所有宾客共用这一张
func _guest_atlas() -> ImageTexture:
    if guest_atlas == null:
        var im := Image.create_empty(16 * 9, 32 * LOOKS, false, Image.FORMAT_RGBA8)
        for i in LOOKS:
            im.blit_rect(Spr.sheet_of(Spr.guest_look(i)), Rect2i(0, 0, 16 * 9, 32), Vector2i(0, i * 32))
        guest_atlas = ImageTexture.create_from_image(im)
    return guest_atlas

func _guest(tid: String, key: String, at: Vector2, center: Vector2, front: bool) -> void:
    var g := Guest.new()
    g.table = tid
    g.key = key
    g.node = Node2D.new()
    g.node.position = at
    g.node.z_index = 1 if front else 0   # 和 layered_hall 画住民一样：桌子两边和前面的画在桌子前面
    guest_holder.add_child(g.node)
    g.row = absi(hash(key)) % LOOKS
    var fl: Dictionary = Spr.PROC_ANIM[hall._face_for(center - at)]
    g.face_frame = int(fl["idle"])
    g.face_flip = bool(fl["flip"])
    g.body = _upper(_guest_atlas(), g.face_frame, g.face_flip)
    g.body.region_rect.position.y = g.row * FH
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
            g.body.region_rect = Rect2(6 * 16.0, g.row * FH, 16.0, keep)
            g.body.flip_h = rng.randf() < 0.5
    if g.turn > 0.0:
        g.turn -= dt
        if g.turn <= 0.0:
            g.body.region_rect = Rect2(g.face_frame * 16.0, g.row * FH, 16.0, keep)
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

## 真人坐到 NPC 坐着的椅子上（换桌成功，layered_hall.apply_change 调）：那个 NPC 站起来，从大门走出去
func vacate(key: String) -> void:
    if not npc_taken.has(key):
        return
    npc_taken.erase(key)
    for g in guests:
        if g.key == key:
            var tc: Dictionary = hall._table_cfg(g.table)
            var from: Vector2 = hall._stand_spot(g.node.position, hall._seat_center(tc))
            g.node.queue_free()
            guests.erase(g)
            _leaver(g.row, from)
            return

## 让了座的宾客：站起来，走到大门（厅里的出口）淡出。走路和服务员共用一套
func _leaver(row: int, from: Vector2) -> void:
    var w := Waiter.new()
    w.kind = "leaver"
    w.node = Node2D.new()
    w.node.name = "leaver"
    hall.world.add_child(w.node, true)
    var s := Sprite2D.new()
    s.texture = _guest_atlas()
    s.region_enabled = true
    s.region_rect = Rect2(0.0, row * FH, 16.0 * 9, FH)
    s.hframes = 9
    s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    s.centered = true
    s.offset = Vector2(0, -FH * 0.5)
    s.scale = Vector2(sc, sc)
    w.node.add_child(s)
    w.body = s
    w.pos = from
    w.path = hall.find_path(from, hall.door)
    w.spot = hall.door
    w.state = "leave"
    waiters.append(w)
    _pose_waiter(w, false)

# ---------- 每帧 ----------
func _process(dt: float) -> void:
    t += dt
    for w in waiters.duplicate():
        _step_waiter(w, dt)
        if w.gone:
            waiters.erase(w)
    _orders_tick(dt)
    for dd in dishes.duplicate():
        if bool(dd.get("keep", false)):
            # 玩家添的菜不撤；菜名显示几秒就收
            var tg = dd.get("tag")
            if tg != null and is_instance_valid(tg):
                dd["tag_left"] = float(dd["tag_left"]) - dt
                (tg as Label).modulate.a = clampf(float(dd["tag_left"]), 0.0, 1.0)
                if float(dd["tag_left"]) <= 0.0:
                    (tg as Label).queue_free()
                    dd["tag"] = null
            continue
        dd["left"] -= dt
        var ds: Sprite2D = dd["spr"]
        ds.modulate.a = clampf(dd["left"], 0.0, 1.0)   # 最后一秒淡掉（吃完了）
        if dd["left"] <= 0.0:
            _drop_dish(dd)
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
        var s := _sprite(str(band_notes[rng.randi() % band_notes.size()])) if not band_notes.is_empty() \
            else _sprite("amb_note_%d" % rng.randi_range(1, 2))
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
