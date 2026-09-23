extends "res://scripts/layered_hall.gd"
## 罗曼山庄 · 迎宾院（蓝图 3.1，灰盒，01 9/19 派）：全部代码画的占位，没有图（落地灯笼复用宴会厅积木）。
## 走路、寻路、摇杆、镜头、人都沿用宴会厅那一套（layered_hall.gd；蓝图 §6：六块画布共用），这里只重写「搭场景」：
## 照 assets/layered/scene_luoman_entrance/layout.json 画地面、红毯、大门、楼门、签到桌……能走的格子开场时按布局现算
## （灰盒没有 build_layered.py 那一步；GPT 出 A05 底图和积木以后换成宴会厅那样的 scene.json，这份灰盒整个换掉）。
## 交互点：走进、走出半径各发一次 spot(id, 进没进)。刚到这块画布时人要是正好站在某个点里，先走出去一次才算（不会来回弹）
## 后厅（backhall.gd，蓝图 3.3）也是这一套，只换 layout_path：布局里有 couple 才摆新人，exit_mark 说金光圈放在哪个点上
signal spot(id: String, inside: bool)

const LAYOUT := "res://assets/layered/scene_luoman_entrance/layout.json"
var layout_path := LAYOUT      # 这块画布的布局；后厅在 _init 里换成自己的
const GRID_CELL := 12
const CLEAR := 12.0            # 离东西多远算挡住，像素（和宴会厅拼装脚本一样）
const NPC_FOOT := Vector2(12, 6)    # 站着的 NPC 占地（椭圆半宽、半高），人不穿过去
const COUPLE_FOOT := Vector2(40, 10)

var points: Dictionary = {}    # id -> {pos, r}
var inside_spot: Dictionary = {}   # id -> 现在人在不在这个点的半径里
var npc_nodes: Dictionary = {}     # id -> Sprite2D
var obstacles: Array = []      # 挡路的占地：{"rect": [x0,y0,x1,y1]} / {"ellipse": [cx,cy,rx,ry]}
var labels: Node2D
## 占位底图（01 9/24：这轮 GPT 画整张占位底图，不抠图）：有图就铺图，灰盒的地面和摆设不再画，但挡人的占地照旧算，
## 走路格子、交互点、出入口一概不变；没图照旧灰盒。默认找布局旁边的 base.png（和宴会厅 scene_roman_banquet/base.png 一样），
## 布局里写了 "base" 就用它。图到了只要拷到那个位置就换上，代码不用再动
var base_on := false
var base_path_override := ""   # 测试用：指到 user:// 下的一张图
var sign_mark: Polygon2D       # B20：签到台头顶的记号（体验第一轮，04 报告「签到台在屏幕外」）
var sign_arrow: Polygon2D      # 签到台在屏幕外时，屏幕边上指着它的小箭头（体验第二轮）
var sign_needed := true        # 还没签到：记号、箭头才出（main 按 court_save.signed_in 设，签完到就没了）

func build(preset: int, nickname: String, f: Font) -> void:
    font = f
    cfg = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
    var flat := Node2D.new()
    flat.z_index = -10
    add_child(flat)
    world = Node2D.new()
    world.y_sort_enabled = true
    add_child(world)
    labels = Node2D.new()
    labels.z_index = 3
    add_child(labels)
    _base(flat)
    for it in cfg.get("flat", []):
        if base_on and str(it.get("type", "")) != "label":
            continue   # 地面、路、水面都画在底图里了；物件名那层字照旧
        _flat(flat, it)
    for it in cfg.get("items", []):
        _item(it)
    for p in cfg.get("points", []):
        points[str(p["id"])] = {"pos": Vector2(float(p["x"]), float(p["y"])), "r": float(p["r"])}
    SPAWN = Vector2(cfg["spawn"][0], cfg["spawn"][1])
    couple_armed = false   # 迎宾院没有新人桌，新人只在花墙前站着（蓝图 3.1）；后厅没有新人
    if cfg.has("couple"):
        _couple()
        var cf: Vector2 = Vector2(cfg["couple"][0], cfg["couple"][1])
        obstacles.append({"ellipse": [cf.x, cf.y, COUPLE_FOOT.x, COUPLE_FOOT.y]})
    _npcs()
    _sign_mark()
    var t0 := Time.get_ticks_msec()
    cfg["walk_grid"] = compute_grid(cfg, obstacles, GRID_CELL, CLEAR)
    print("[suqi] %s 能走的格子算了 %d 毫秒" % [str(cfg.get("title", "迎宾院")), Time.get_ticks_msec() - t0])
    _walk_grid()
    _player(preset, nickname)
    # 大门开了才有的那圈金光：借宴会厅的出口光圈，放在 gate 上（大门开没开由 main 管）。布局里 exit_mark 可以换点，没有这个点就不放
    var mark_id := str(cfg.get("exit_mark", "gate"))
    if points.has(mark_id):
        door = points[mark_id]["pos"]
        door_r = points[mark_id]["r"]
    _exit_mark()
    cam = Camera2D.new()
    cam.limit_left = 0
    cam.limit_top = 0
    cam.limit_right = int(cfg["size"][0])
    cam.limit_bottom = int(cfg["size"][1])
    cam.position_smoothing_enabled = true
    cam.position_smoothing_speed = 6.0
    add_child(cam)
    _fit_zoom()
    get_viewport().size_changed.connect(_fit_zoom)
    reset_to(SPAWN)

## 到了（进场、从宴会厅回来）：记下这时站在哪些点里面，这些点要先走出去一次才会触发
func reset_to(p: Vector2) -> void:
    super(p)
    for id in points:
        inside_spot[id] = pos.distance_to(points[id]["pos"]) < float(points[id]["r"])
    if bool(inside_spot.get("sign_in", false)) and sign_mark != null:
        sign_mark.visible = false

func _process(dt: float) -> void:
    super(dt)
    _breathe()
    for id in points:
        var now: bool = pos.distance_to(points[id]["pos"]) < float(points[id]["r"])
        if now != bool(inside_spot.get(id, false)):
            inside_spot[id] = now
            spot.emit(id, now)
            if id == "sign_in" and now and sign_mark != null:
                sign_mark.visible = false   # B20：走到桌子跟前了，看见了，记号收起来，别一直杵着
    if sign_mark != null and not sign_needed:
        sign_mark.visible = false
    if sign_mark != null and sign_mark.visible:
        breathe_ring(sign_mark, t)
    _point_sign_arrow()

## 签到台出了屏幕，屏幕边上（往里收 40 像素）放个小箭头指着它；签到台进了屏幕就收
func _point_sign_arrow() -> void:
    if sign_arrow == null:
        return
    if sign_mark == null or not sign_mark.visible or cam == null or cam.zoom.x <= 0.0:
        sign_arrow.visible = false
        return
    var vs := get_viewport().get_visible_rect().size / cam.zoom
    var c := cam.get_screen_center_position()
    var view := Rect2(c - vs * 0.5, vs)
    var target: Vector2 = sign_mark.position
    var inner := view.grow(-40.0)
    if view.grow(-10.0).has_point(target):
        sign_arrow.visible = false
        return
    sign_arrow.visible = true
    sign_arrow.position = Vector2(clampf(target.x, inner.position.x, inner.end.x), clampf(target.y, inner.position.y, inner.end.y))
    sign_arrow.rotation = (target - sign_arrow.position).angle()
    sign_arrow.modulate.a = 0.7 + sin(t * 5.0) * 0.3

## B20（体验第一轮，04 报告「新娘妈妈叫你签到，签到台在屏幕外，没有任何东西指出在哪」）：
## 给签到台头顶挂一圈会跳的金光，和大门那圈金光（layered_hall.gd _exit_mark）同一个颜色、同一个画法，
## 只是挂在头顶不是踩在脚下。走到桌子跟前一次以后就收起来（见上面 _process、reset_to）
func _sign_mark() -> void:
    if not points.has("sign_in"):
        return
    var p: Vector2 = points["sign_in"]["pos"]
    sign_mark = ring_mark(24.0, 24.0 * 0.55)   # 空心会呼吸的圈（体验第二轮 新 3，原来是一块实心橘色，像污渍）
    sign_mark.position = p + Vector2(0, -70)
    sign_mark.z_index = 4
    add_child(sign_mark)
    # 签到台出了屏幕：屏幕边上出一个小箭头指着它（B20，04 复看：桌子在屏幕外时记号也在屏幕外，等于没有）
    sign_arrow = Polygon2D.new()
    sign_arrow.polygon = PackedVector2Array([Vector2(16, 0), Vector2(-10, -11), Vector2(-4, 0), Vector2(-10, 11)])
    sign_arrow.color = Color(1.0, 0.88, 0.45)
    var outline := Line2D.new()
    outline.points = PackedVector2Array([Vector2(16, 0), Vector2(-10, -11), Vector2(-4, 0), Vector2(-10, 11), Vector2(16, 0)])
    outline.width = 2.0
    outline.default_color = Color(0.2, 0.12, 0.08)
    sign_arrow.add_child(outline)
    sign_arrow.z_index = 8
    sign_arrow.scale = Vector2(1.6, 1.6)   # 截图看原大小太小，放大一点
    sign_arrow.visible = false
    add_child(sign_arrow)

## 物件名那层也算：自己的名字碰到它就让开、贴屏幕边就往里收（体验 B3、B4）
func _tag_holders() -> Array:
    var out := super()
    if labels != null:
        out.append(labels)
    return out

## 铺底图：布局写了 base 用它，没写找布局旁边的 base.png；都没有就是灰盒。图不是画布大小的，拉到画布大小（进包前该对好尺寸）
func base_path() -> String:
    if base_path_override != "":
        return base_path_override
    if cfg.has("base"):
        return str(cfg["base"])
    return layout_path.get_base_dir() + "/base.png"

func _base(parent: Node2D) -> void:
    var path := base_path()
    var tex: Texture2D = null
    if path.begins_with("res://"):
        if ResourceLoader.exists(path):
            tex = Canvas.texture(path)
    elif FileAccess.file_exists(path):
        var img := Image.load_from_file(path)
        if img != null:
            tex = ImageTexture.create_from_image(img)
    if tex == null:
        return
    var sp := Sprite2D.new()
    sp.name = "base"
    sp.texture = tex
    sp.centered = false
    sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    var want := Vector2(float(cfg["size"][0]), float(cfg["size"][1]))
    var have := Vector2(tex.get_width(), tex.get_height())
    if have != want:
        print("[suqi] %s 底图 %s 不是画布大小 %s，拉到画布大小" % [str(cfg.get("title", "")), have, want])
        sp.scale = want / have
    parent.add_child(sp)
    base_on = true
    print("[suqi] %s 铺了底图 %s" % [str(cfg.get("title", "")), path])

## 人现在在不在某个点的半径里（main 判断按钮该不该出）
func in_spot(id: String) -> bool:
    return bool(inside_spot.get(id, false))

## 点的位置（合影时把人吸到站位上用）
func spot_pos(id: String) -> Vector2:
    return points[id]["pos"] if points.has(id) else Vector2.ZERO

# ---------- 画灰盒 ----------
func _flat(parent: Node2D, it: Dictionary) -> void:
    match str(it.get("type", "")):
        "rect":
            parent.add_child(_poly(_rect_pts(it["rect"]), Color(str(it["color"]))))
        "label":
            _label(str(it["text"]), Vector2(float(it["x"]), float(it["y"])))

func _item(it: Dictionary) -> void:
    var kind := str(it.get("type", ""))
    var foot := 0.0
    var holder := Node2D.new()
    match kind:
        "box":
            var r: Array = it["rect"]
            var x0 := float(r[0]); var y0 := float(r[1]); var x1 := float(r[2]); var y1 := float(r[3])
            var h := float(it["h"])
            foot = y1
            # 斜俯视没有透视：顶面是占地往上挪 h，正面是顶面下沿到地面这一条
            holder.add_child(_poly(_rect_pts([x0, y1 - h, x1, y1]), Color(str(it["front"])), foot))
            holder.add_child(_poly(_rect_pts([x0, y0 - h, x1, y1 - h]), Color(str(it["top"])), foot))
            for d in it.get("deco", []):
                holder.add_child(_poly(_rect_pts(d["rect"]), Color(str(d["color"])), foot))
            if bool(it.get("flowers", false)):
                _flowers(holder, x0, y1 - h, x1, y1, foot)
            if it.has("xi"):
                # 花墙上的金色「囍」：唯一允许的字（ASSETS 第 0 节），引擎渲染；底下垫个红圆，不然在花里看不清
                holder.add_child(_poly(_ellipse_pts(float(it["xi"][0]), float(it["xi"][1]), 34.0, 34.0, 24), Color("#b0322a"), foot))
                var xl := Label.new()
                xl.text = "囍"
                xl.add_theme_font_override("font", font)
                xl.add_theme_font_size_override("font_size", 48)
                xl.add_theme_color_override("font_color", Color("#d4af37"))
                xl.size = Vector2(60, 60)
                xl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                xl.position = Vector2(float(it["xi"][0]) - 30.0, float(it["xi"][1]) - 30.0 - foot)
                holder.add_child(xl)
            if bool(it.get("block", true)):
                obstacles.append({"rect": [x0, y0, x1, y1]})
        "cyl":
            var cx := float(it["x"]); var cy := float(it["y"])
            var rx := float(it["rx"]); var ry := float(it["ry"]); var h2 := float(it["h"])
            foot = float(it.get("foot", cy + ry))   # 放在别的东西上面的（后厅砖灶上的大锅）给个更靠前的着地线，排在底座后面画
            holder.add_child(_poly(_cyl_side(cx, cy, rx, ry, h2), Color(str(it["front"])), foot))
            holder.add_child(_poly(_ellipse_pts(cx, cy - h2, rx, ry), Color(str(it["top"])), foot))
            obstacles.append({"ellipse": [cx, cy, rx, ry]})
        "tree":
            var tx := float(it["x"]); var ty := float(it["y"]); var tr := float(it["r"])
            foot = ty
            var trunk := Color(str(it.get("trunk", "#6d4a38")))
            var leaf := Color(str(it.get("leaf", "#4f7a4a")))
            var leaf2 := Color(str(it.get("leaf2", "#6a9a5c")))
            holder.add_child(_poly(_rect_pts([tx - 7, ty - 46, tx + 7, ty]), trunk, foot))
            holder.add_child(_poly(_ellipse_pts(tx, ty - 46 - tr * 0.7, tr, tr * 0.85), leaf, foot))
            holder.add_child(_poly(_ellipse_pts(tx - tr * 0.25, ty - 52 - tr * 0.9, tr * 0.55, tr * 0.45), leaf2, foot))
            if bool(it.get("droop", false)):
                # 柳树（蓝图 3.5 湖边）：树冠下面垂几条柳条
                var rngw := RandomNumberGenerator.new()
                rngw.seed = int(tx * 13 + ty)
                for i in 7:
                    var dx := rngw.randf_range(-tr * 0.95, tr * 0.95)
                    var top := ty - 46 - tr * 0.5 + absf(dx) * 0.25
                    var len_w := rngw.randf_range(tr * 0.5, tr * 1.1)
                    holder.add_child(_poly(_rect_pts([tx + dx - 1.5, top, tx + dx + 1.5, top + len_w]), leaf2, foot))
            obstacles.append({"ellipse": [tx, ty, 14.0, 8.0]})
        "image":
            foot = float(it["y"])
            var s := Sprite2D.new()
            s.texture = Canvas.texture(str(it["path"]))
            s.centered = false
            s.offset = Vector2(-float(it["anchor"][0]), -float(it["anchor"][1]))
            s.position = Vector2(float(it["x"]), 0.0)
            s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
            holder.add_child(s)
            obstacles.append({"ellipse": [float(it["x"]), foot, float(it["ellipse"][0]), float(it["ellipse"][1])]})
        "tripod":
            var px := float(it["x"]); var py := float(it["y"])
            foot = py
            for lx in [-12.0, 0.0, 12.0]:
                holder.add_child(_poly(PackedVector2Array([Vector2(px - 1, py - 56 - foot), Vector2(px + 1, py - 56 - foot),
                    Vector2(px + lx + 1.5, py - (4.0 if lx == 0.0 else 0.0) - foot), Vector2(px + lx - 1.5, py - (4.0 if lx == 0.0 else 0.0) - foot)]), Color("#2c2438")))
            holder.add_child(_poly(_rect_pts([px - 14, py - 78, px + 14, py - 56]), Color("#6d4a38"), foot))
            holder.add_child(_poly(_rect_pts([px - 6, py - 74, px + 6, py - 62]), Color("#1e1a2a"), foot))
            obstacles.append({"ellipse": [px, py, float(it["ellipse"][0]), float(it["ellipse"][1])]})
        "beam":
            foot = float(it["foot"])
            holder.add_child(_poly(_rect_pts([it["x0"], it["top"], it["x1"], float(it["top"]) + float(it["thick"])]), Color(str(it["color"])), foot))
        "poly":
            # 随便一块多边形（草坪滑梯的滑道），点是画布上的绝对坐标；block 给了才挡路（[x0,y0,x1,y1]）
            foot = float(it["foot"])
            var pts := PackedVector2Array()
            for v in it["pts"]:
                pts.append(Vector2(float(v[0]), float(v[1])))
            holder.add_child(_poly(pts, Color(str(it["color"])), foot))
            if it.has("block"):
                obstacles.append({"rect": it["block"]})
        "puffs":
            # 几团半透明的圆（后厅大锅冒的气，蓝图 3.3 用户故事「大锅在冒气」），着地线跟着锅走，不挡路
            foot = float(it["y"])
            for e in it["e"]:
                holder.add_child(_poly(_ellipse_pts(float(e[0]), float(e[1]), float(e[2]), float(e[3]), 14), Color(str(it.get("color", "#ffffff66"))), foot))
    holder.position = Vector2(0.0, foot)
    holder.name = str(it.get("id", kind))
    if base_on and not bool(it.get("keep_on_base", false)):
        holder.free()   # 有底图：这件东西画在图里了，只留上面算好的挡人占地。布局里标了 keep_on_base 的（后厅大锅冒的气）照旧画
    else:
        world.add_child(holder)
    if it.has("label"):
        var lb: Dictionary = it["label"]
        var lx2 := _item_center_x(it)
        _label(str(lb["text"]), Vector2(lx2, foot + float(lb.get("dy", -40))))

static func _item_center_x(it: Dictionary) -> float:
    if it.has("rect"):
        return (float(it["rect"][0]) + float(it["rect"][2])) * 0.5
    if it.has("x0"):
        return (float(it["x0"]) + float(it["x1"])) * 0.5
    return float(it.get("x", 0.0))

## 花：一排小圆点（占位），画在正面上
func _flowers(holder: Node2D, x0: float, y0: float, x1: float, y1: float, foot: float) -> void:
    var cols := [Color("#e8746a"), Color("#f2a7c3"), Color("#f4f1ea"), Color("#c0392b")]
    var rng := RandomNumberGenerator.new()
    rng.seed = int(x0 * 7 + y0)
    var n := int((x1 - x0) * (y1 - y0) / 260.0)
    for i in n:
        var c := Vector2(rng.randf_range(x0 + 4, x1 - 4), rng.randf_range(y0 + 4, y1 - 4))
        holder.add_child(_poly(_ellipse_pts(c.x, c.y, 4.0, 3.5, 8), cols[i % cols.size()], foot))

## NPC（占位，代码画的像素人，sprites.gd 的 COURT_NPCS、BACKHALL_NPCS）：不写名字（01 9/19）。
## sit 为 true 的坐着（后厅麻将桌的长辈）：和宴会厅坐着的人一样只画上半身，下沿在椅位点上；坐着的默认不挡路（桌椅挡），
## block 为 true 才也挡（麻将桌边的长辈：不然人能从他们身上穿过去）
func _npcs() -> void:
    for n in cfg.get("npcs", []):
        var id := str(n["id"])
        var look_cfg: Dictionary = Spr.npc_look(str(n.get("look", id)))
        var s := Sprite2D.new()
        s.texture = ImageTexture.create_from_image(Spr.sheet_of(look_cfg))
        s.hframes = 9
        var fl: Dictionary = Spr.PROC_ANIM[str(n.get("face", "down"))]
        s.flip_h = bool(fl["flip"])
        s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        s.centered = true
        var sit := bool(n.get("sit", false))
        if sit:
            var keep := floorf(32.0 * SIT_KEEP)
            s.hframes = 1
            s.region_enabled = true
            s.region_rect = Rect2(float(fl["idle"]) * 16.0, 0.0, 16.0, keep)
            s.offset = Vector2(0, -keep * 0.5)
        else:
            s.frame = int(fl["idle"])
            s.offset = Vector2(0, -16.0)
        var at := Vector2(float(n["x"]), float(n["y"]))
        var k := _px_h(at.y) / 32.0 * float(n.get("size", 1.0))   # size：小孩按大人的几成高（草坪 0.65）
        s.scale = Vector2(k, k)
        s.position = at
        s.name = "npc_" + id
        s.set_meta("base_offset", s.offset)
        s.set_meta("breath_phase", float(npc_nodes.size()) * 1.7)
        world.add_child(s)
        npc_nodes[id] = s
        if not sit or bool(n.get("block", false)):
            obstacles.append({"ellipse": [at.x, at.y, NPC_FOOT.x, NPC_FOOT.y]})

## NPC 呼吸（阿鱼 9/24：人物都不动，看着怪）：每个人身子隔两三秒轻轻一起一伏，不到一个像素格，各人错开，
## 以后画布里新加的 NPC 自动都有。GPT 交了带待机帧的人物图以后，换成真的待机动画
const BREATH_SPEED := 2.4
const BREATH_AMP := 0.6
func _breathe() -> void:
    for id in npc_nodes:
        var s: Sprite2D = npc_nodes[id]
        if not is_instance_valid(s) or not s.has_meta("base_offset"):
            continue
        var b: Vector2 = s.get_meta("base_offset")
        s.offset = b + Vector2(0.0, sin(t * BREATH_SPEED + float(s.get_meta("breath_phase"))) * BREATH_AMP)

## NPC 在哪（对话、指路时 main 要用）
func npc_pos(id: String) -> Vector2:
    return (npc_nodes[id] as Sprite2D).position if npc_nodes.has(id) else Vector2.ZERO

## 体验第二轮 新 1、新 4（01 9/24）：东西的名字牌（亭子、大门口、宴会楼、回忆册……）不再一直挂在图上——底图有了真画，
## 东西一眼认得出，走近时出的按钮上写清楚就够了（阿鱼 9/23：图上别叠字）。**只留出口牌**（去哪、回哪、通到别处的门和小径），
## 做成小木牌的样子：暖褐底、米白字、没有金边，和屏幕上 HUD 那套深底金边的按钮拉开，不会被当成按钮
const EXIT_WORDS := ["后门", "楼门", "西小径", "东小径", "大门"]
static func is_exit_label(text: String) -> bool:
    return text.begins_with("去") or text.begins_with("回") or text in EXIT_WORDS

func _label(text: String, at: Vector2) -> void:
    if not is_exit_label(text):
        return
    var l := Label.new()
    l.text = text
    name_plate(l, Color("#f3e6c8"))
    var sb := l.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
    sb.bg_color = Color(0.36, 0.23, 0.13, 0.85)   # 小木牌
    l.add_theme_stylebox_override("normal", sb)
    l.position = at - l.size * 0.5
    labels.add_child(l)

## foot 不是 0 时，点的 y 减掉 foot（放进原点在着地线上的 holder 里）
func _poly(pts: PackedVector2Array, col: Color, foot := 0.0) -> Polygon2D:
    var p := Polygon2D.new()
    if foot != 0.0:
        var moved := PackedVector2Array()
        for v in pts:
            moved.append(v - Vector2(0.0, foot))
        pts = moved
    p.polygon = pts
    p.color = col
    return p

static func _rect_pts(r) -> PackedVector2Array:
    var x0 := float(r[0]); var y0 := float(r[1]); var x1 := float(r[2]); var y1 := float(r[3])
    return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

static func _ellipse_pts(cx: float, cy: float, rx: float, ry: float, n := 20) -> PackedVector2Array:
    var out := PackedVector2Array()
    for i in n:
        var a := TAU * float(i) / float(n)
        out.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
    return out

## 圆桌的侧面：顶面椭圆的下半圈，往下拉 h 到地面
static func _cyl_side(cx: float, cy: float, rx: float, ry: float, h: float) -> PackedVector2Array:
    var out := PackedVector2Array()
    for i in 11:
        var a := PI * float(i) / 10.0
        out.append(Vector2(cx + cos(a) * rx, cy - h + sin(a) * ry))
    for i in range(10, -1, -1):
        var a := PI * float(i) / 10.0
        out.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
    return out

# ---------- 能走的格子（开场现算，灰盒用；和 tools/build_layered.py 同一个规则） ----------
## 在 walk 多边形里、离每块占地 clear 像素以外，再从进场点走一遍，走不到的角落也算不能走。
## 返回宴会厅 scene.json 里 walk_grid 那个样子，交给 layered_hall._walk_grid()
static func compute_grid(c: Dictionary, obs: Array, cell: int, clear: float) -> Dictionary:
    var w := int(c["size"][0])
    var h := int(c["size"][1])
    var cols_n := int(ceil(float(w) / cell))
    var rows_n := int(ceil(float(h) / cell))
    var ok := PackedByteArray()
    ok.resize(cols_n * rows_n)
    var polys: Array = []
    for poly in c.get("walk", []):
        var pts := PackedVector2Array()
        for v in poly:
            pts.append(Vector2(float(v[0]), float(v[1])))
        polys.append(pts)
    for j in rows_n:
        var y := (j + 0.5) * cell
        for i in cols_n:
            var x := (i + 0.5) * cell
            for pts in polys:
                if Geometry2D.is_point_in_polygon(Vector2(x, y), pts):
                    ok[j * cols_n + i] = 1
                    break
    # 每块占地只查它四周那几格（手机上逐格比所有东西太慢）
    for o in obs:
        var bb := _obs_box(o, clear)
        var i0 := maxi(int(floor(bb.position.x / cell)), 0)
        var i1 := mini(int(ceil(bb.end.x / cell)), cols_n - 1)
        var j0 := maxi(int(floor(bb.position.y / cell)), 0)
        var j1 := mini(int(ceil(bb.end.y / cell)), rows_n - 1)
        for j in range(j0, j1 + 1):
            for i in range(i0, i1 + 1):
                if ok[j * cols_n + i] == 1 and _blocked((i + 0.5) * cell, (j + 0.5) * cell, [o], clear):
                    ok[j * cols_n + i] = 0
    # 从进场点灌水，灌不到的格子不算
    var seen := PackedByteArray()
    seen.resize(cols_n * rows_n)
    var sx := int(float(c["spawn"][0]) / cell)
    var sy := int(float(c["spawn"][1]) / cell)
    var stack: Array[int] = []
    if ok[sy * cols_n + sx] == 1:
        seen[sy * cols_n + sx] = 1
        stack.append(sy * cols_n + sx)
    while not stack.is_empty():
        var idx: int = stack.pop_back()
        var ci := idx % cols_n
        var cj := idx / cols_n
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var ni: int = ci + d.x
            var nj: int = cj + d.y
            if ni < 0 or nj < 0 or ni >= cols_n or nj >= rows_n:
                continue
            var n := nj * cols_n + ni
            if ok[n] == 1 and seen[n] == 0:
                seen[n] = 1
                stack.append(n)
    var rows_out: Array = []
    for j in rows_n:
        var line := ""
        for i in cols_n:
            line += "1" if seen[j * cols_n + i] == 1 else "0"
        rows_out.append(line)
    return {"cell": cell, "cols": cols_n, "rows": rows_out}

static func _obs_box(o: Dictionary, clear: float) -> Rect2:
    if o.has("rect"):
        var r: Array = o["rect"]
        return Rect2(float(r[0]) - clear, float(r[1]) - clear, float(r[2]) - float(r[0]) + clear * 2.0, float(r[3]) - float(r[1]) + clear * 2.0)
    var e: Array = o["ellipse"]
    var rx := float(e[2]) + clear
    var ry := float(e[3]) + clear
    return Rect2(float(e[0]) - rx, float(e[1]) - ry, rx * 2.0, ry * 2.0)

static func _blocked(x: float, y: float, obs: Array, clear: float) -> bool:
    for o in obs:
        if o.has("rect"):
            var r: Array = o["rect"]
            if x >= float(r[0]) - clear and x <= float(r[2]) + clear and y >= float(r[1]) - clear and y <= float(r[3]) + clear:
                return true
        else:
            var e: Array = o["ellipse"]
            var dx := (x - float(e[0])) / (float(e[2]) + clear)
            var dy := (y - float(e[1])) / (float(e[3]) + clear)
            if dx * dx + dy * dy < 1.0:
                return true
    return false
