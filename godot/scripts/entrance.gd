extends "res://scripts/layered_hall.gd"
## 罗曼山庄 · 迎宾院（蓝图 3.1，灰盒，01 9/19 派）：全部代码画的占位，没有图（落地灯笼复用宴会厅积木）。
## 走路、寻路、摇杆、镜头、人都沿用宴会厅那一套（layered_hall.gd；蓝图 §6：六块画布共用），这里只重写「搭场景」：
## 照 assets/layered/scene_luoman_entrance/layout.json 画地面、红毯、大门、楼门、签到桌……能走的格子开场时按布局现算
## （灰盒没有 build_layered.py 那一步；GPT 出 A05 底图和积木以后换成宴会厅那样的 scene.json，这份灰盒整个换掉）。
## 交互点：走进、走出半径各发一次 spot(id, 进没进)。刚到这块画布时人要是正好站在某个点里，先走出去一次才算（不会来回弹）
## 后厅（backhall.gd，蓝图 3.3）也是这一套，只换 layout_path：布局里有 couple 才摆新人，exit_mark 说金光圈放在哪个点上
signal spot(id: String, inside: bool)
signal talk_requested(id: String)
signal edge_bump(dir: String)       # 走到头了（往没路的那边顶、或者点了画布外头）：dir 是 up/down/left/right，main 弹一句（10/4 连图）   # 点了一位能说话的 NPC、走到他跟前了：main 开对话框（lounge_ui.gd，台词走对话插件）

const LAYOUT := "res://assets/layered/scene_luoman_entrance/layout.json"
var layout_path := LAYOUT      # 这块画布的布局；后厅在 _init 里换成自己的
const GRID_CELL := 12
const CLEAR := 12.0            # 离东西多远算挡住，像素（和宴会厅拼装脚本一样）
const NPC_FOOT := Vector2(12, 6)    # 站着的 NPC 占地（椭圆半宽、半高），人不穿过去
const COUPLE_FOOT := Vector2(40, 10)
const TREE_TRUNK := 0.36           # 给了 h 的树：树干占整棵高的几成（gen_specs_court.py 用同一个数）

var points: Dictionary = {}    # id -> {pos, r}
var inside_spot: Dictionary = {}   # id -> 现在人在不在这个点的半径里
var npc_nodes: Dictionary = {}     # id -> Sprite2D
## 能说话的 NPC（10/4 接对话插件 Dialogue Manager）：布局里给 NPC 写一个 dialogue（.dialogue 文件路径），他就能点、能聊，哪块画布都一样。
## id -> {id, foot, head, dialogue, title（名字牌上的称呼）, code（对话框、身份卡用哪张人物图）, approach（玩家走到哪开聊）}
var talkers: Dictionary = {}
var pending_talker := ""
var bump_armed := true            # 走到头那句：顶住弹一次，走开 BUMP_REARM 再回来才再弹
var bump_at := Vector2.ZERO
var bump_still := 0.0
var bump_last := Vector2.ZERO
const BUMP_REARM := 60.0
const BUMP_HOLD := 0.35           # 推着摇杆原地不动多久算顶住了
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
const CourtLife = preload("res://scripts/court_life.gd")
const LMPeople = preload("res://scripts/lm_people.gd")
var court_life                 # 迎宾院里走动的客人、新娘爸妈和摄影师的小动作（court_life.gd，01 E 10/2）；别的画布没有

func build(preset: int, nickname: String, f: Font) -> void:
    me_marks = false   # 找自己的圈和倒三角只在宴会厅（01 E 10/2）
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
        # to：这个口通哪块画布（10/4 连图：口都写在布局里，main 照这个切）；arrive：从那块过来站哪（不写就照口往里走 70 像素）；
        # say：走进去说一句（还没做的地方，话在 assets/areas/lines.json 那个 key）
        var ar: Array = p.get("arrive", [])
        points[str(p["id"])] = {"pos": Vector2(float(p["x"]), float(p["y"])), "r": float(p["r"]), "to": str(p.get("to", "")),
            "arrive": Vector2(float(ar[0]), float(ar[1])) if ar.size() == 2 else Vector2.ZERO, "say": str(p.get("say", "")),
            "via": str(p.get("via", ""))}
    SPAWN = Vector2(cfg["spawn"][0], cfg["spawn"][1])
    _arrow_signs()
    _keep_signs_off_people()
    couple_armed = false   # 迎宾院没有新人桌，新人只在花墙前站着（蓝图 3.1）；后厅没有新人
    if cfg.has("couple"):
        _couple()
        var cf: Vector2 = Vector2(cfg["couple"][0], cfg["couple"][1])
        obstacles.append({"ellipse": [cf.x, cf.y, COUPLE_FOOT.x, COUPLE_FOOT.y]})
    _npcs()
    _pixel_art(flat)
    for s in cfg.get("signs", []):   # 门口的名字牌（后厅三间，阿鱼 10/3），见 layered_hall.room_sign
        room_sign(str(s["text"]), Vector2(float(s["x"]), float(s["y"])), float(s.get("foot", -1.0)))
    _sign_mark()
    var t0 := Time.get_ticks_msec()
    cfg["walk_grid"] = compute_grid(cfg, obstacles, GRID_CELL, CLEAR)
    print("[suqi] %s 能走的格子算了 %d 毫秒" % [str(cfg.get("title", "迎宾院")), Time.get_ticks_msec() - t0])
    _walk_grid()
    _player(preset, nickname)
    if layout_path == LAYOUT:
        court_life = CourtLife.new()
        add_child(court_life)
        court_life.setup(self)
    # 大门开了才有的那圈金光：借宴会厅的出口光圈，放在 gate 上（大门开没开由 main 管）。布局里 exit_mark 可以换点，没有这个点就不放
    var mark_id := str(cfg.get("exit_mark", "gate"))
    if points.has(mark_id):
        door = points[mark_id]["pos"]
        door_r = points[mark_id]["r"]
    _exit_mark()
    Ambient.attach(self, str(cfg.get("scene", "")), cfg.get("items", []))   # 场景动效（湖面波光、小船起伏…照 data/ambient.json；Ambient 是 layered_hall 里引的），05 10/4
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
    _bump_tick(dt)
    if pending_talker != "" and path.is_empty():
        var tid := pending_talker
        pending_talker = ""
        if talkers.has(tid) and pos.distance_to(talker_approach(tid)) <= 34.0:
            face = _face_for((talkers[tid]["foot"] as Vector2) - pos)
            talk_requested.emit(tid)
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
    point_edge_arrow(sign_arrow, sign_mark.position if sign_mark != null else Vector2.ZERO, sign_mark != null and sign_mark.visible)

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
    sign_arrow = edge_arrow()
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
                # clear：这件四周让多宽才算挡住，默认 CLEAR；化妆间东西多、道窄（06 照脚底让 6 摆的），那 32 件在布局里写 6
                obstacles.append({"rect": [x0, y0, x1, y1], "clear": float(it["clear"])} if it.has("clear") else {"rect": [x0, y0, x1, y1]})
        "cyl":
            var cx := float(it["x"]); var cy := float(it["y"])
            var rx := float(it["rx"]); var ry := float(it["ry"]); var h2 := float(it["h"])
            foot = float(it.get("foot", cy + ry))   # 放在别的东西上面的（后厅砖灶上的大锅）给个更靠前的着地线，排在底座后面画
            holder.add_child(_poly(_cyl_side(cx, cy, rx, ry, h2), Color(str(it["front"])), foot))
            holder.add_child(_poly(_ellipse_pts(cx, cy - h2, rx, ry), Color(str(it["top"])), foot))
            obstacles.append({"ellipse": [cx, cy, rx, ry]})
        "tree":
            var tx := float(it["x"]); var ty := float(it["y"])
            foot = ty
            var trunk := Color(str(it.get("trunk", "#6d4a38")))
            var leaf := Color(str(it.get("leaf", "#4f7a4a")))
            var leaf2 := Color(str(it.get("leaf2", "#6a9a5c")))
            var tg := tree_geom(it)
            var crx: float = tg["rx"]
            var cry: float = tg["ry"]
            var ccy: float = tg["cy"]
            holder.add_child(_poly(_rect_pts([tx - tg["trunk_w"], tg["trunk_top"], tx + tg["trunk_w"], ty]), trunk, foot))
            holder.add_child(_poly(_ellipse_pts(tx, ccy, crx, cry), leaf, foot))
            holder.add_child(_poly(_ellipse_pts(tx - crx * 0.25, ccy - cry * 0.25, crx * 0.55, cry * 0.53), leaf2, foot))
            if bool(it.get("droop", false)):
                # 柳树（蓝图 3.5 湖边）：树冠下面垂几条柳条
                var rngw := RandomNumberGenerator.new()
                rngw.seed = int(tx * 13 + ty)
                for i in 7:
                    var dx := rngw.randf_range(-crx * 0.95, crx * 0.95)
                    var top := ccy + cry * 0.4 + absf(dx) * 0.25 * cry / maxf(1.0, crx)
                    var len_w := rngw.randf_range(cry * 0.6, cry * 1.3)
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
    if (base_on and not bool(it.get("keep_on_base", false))) or bool(it.get("on_art", false)):
        holder.free()   # 有底图：这件东西画在图里了，只留上面算好的挡人占地。布局里标了 keep_on_base 的（后厅大锅冒的气）照旧画
                        # on_art：只有半块画布铺了像素成品（10/4 湖边东半边），画在图层里的那几件也只留占地
    else:
        world.add_child(holder)
    if it.has("label"):
        var lb: Dictionary = it["label"]
        var lx2 := _item_center_x(it) + float(lb.get("dx", 0))
        _label(str(lb["text"]), Vector2(lx2, foot + float(lb.get("dy", -40))))

## 代码画的像素成品（阿鱼 10/3 定：新场景照 01 版休息间的标准用代码画，docs/罗曼山庄画风.md 第 0 节；脚本在 tools/pixel_art/）：
## 布局里写了 "pixel_art": [room.json…] 就铺上——背景（墙、地板、地毯、墙上挂的）盖在灰盒地面上；每件家具一张图，
## 左上角放在 (x, y)、按着地线 foot 跟人排前后；hide 里的灰盒藏掉（挡人的占地、走路的格子照旧）。
## 1 倍颗粒、不插值（像素硬边）。没写 pixel_art 的画布照旧是灰盒
func _pixel_art(flat: Node2D) -> void:
    for path in cfg.get("pixel_art", []):
        var man = JSON.parse_string(FileAccess.get_file_as_string(str(path)))
        if not man is Dictionary:
            continue
        var bgd: Dictionary = man["background"]
        var bg := Sprite2D.new()
        bg.texture = Canvas.texture(str(bgd["png"]))
        bg.centered = false
        bg.position = Vector2(float(bgd["x"]), float(bgd["y"]))
        bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        bg.name = "px_background_" + str(path).get_base_dir().get_file()
        flat.add_child(bg)
        for p in man["props"]:
            for id in p.get("hide", []):
                var old := world.get_node_or_null(NodePath(str(id)))
                if old != null:
                    old.visible = false
            var s := Sprite2D.new()
            s.texture = Canvas.texture(str(p["png"]))
            s.centered = false
            s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            s.position = Vector2(float(p["x"]), float(p["foot"]))
            s.offset = Vector2(0.0, float(p["y"]) - float(p["foot"]))
            s.name = str(p["id"])
            world.add_child(s)

## 铺了像素成品的画布，镜头放大倍数取整到 1（原来按画布高 1024 缩到 0.9375）：1 个美术像素正好 1 个画布像素，
## 手机上再整倍放大（1080 宽的屏正好 2 倍），像素不会一行宽一行窄、也不会掉行。画布高比屏高只多 64，镜头跟着人走，看不出少了什么
func _fit_zoom() -> void:
    super()
    if cfg.has("pixel_art") and cam.zoom.x > 0.85 and cam.zoom.x < 1.0:
        cam.zoom = Vector2.ONE

## 一棵树画在哪（画树、果园往树上挂果子共用；tools/layout_court/gen_specs_court.py 照同一个算法量框）：
## 给了 h（整棵多高）、w（树冠多宽）的：树干占下面 TREE_TRUNK，上面是树冠，顶正好在 y - h（10/3 照「人 = 1」）；
## 老写法只给 r 的照旧（树干 46 高，树冠半径 r）。回 {trunk_top, trunk_w, cy, rx, ry, top}
static func tree_geom(it: Dictionary) -> Dictionary:
    var ty := float(it["y"])
    if it.has("h"):
        var th := float(it["h"])
        var trunk_h := th * TREE_TRUNK
        var crx := float(it.get("w", th * 0.53)) * 0.5
        var cry := (th - trunk_h) * 0.5
        return {"trunk_top": ty - trunk_h - 6.0, "trunk_w": 8.0, "cy": ty - trunk_h - cry, "rx": crx, "ry": cry, "top": ty - th}
    var r := float(it.get("r", 30.0))
    return {"trunk_top": ty - 46.0, "trunk_w": 7.0, "cy": ty - 46.0 - r * 0.7, "rx": r, "ry": r * 0.85, "top": ty - 46.0 - r * 1.55}

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
        if n.has("dialogue") and not n.has("code_char"):
            var sd: Dictionary = n.get("standin", {})
            var foot := Vector2(float(n["x"]), float(n["y"]))
            var h: float = float(sd["rows"]) + (foot.y - float(sd.get("bottom", foot.y))) if sd.has("rows") else (52.0 if bool(n.get("sit", false)) else 84.0)
            add_talker(id, foot, h, str(n["dialogue"]), str(n.get("title", "")), str(n.get("portrait", sd.get("code", ""))))
        if n.has("code_char"):
            continue   # 01 画的代码小人（休息间四位，10/4）：lounge_life.gd 画、管动作
        if n.has("standin") and _standin(n):
            continue
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

# ---------- 连图（10/4）：口通哪、到了站哪、走到头提示、牌子别盖人 ----------
## 从 src 那块画布过来，站哪：这边通 src 的那个口写了 arrive 就站那，不然从口往画布里走 70 像素、找最近能站的点。没有通 src 的口回 ZERO
func arrival_from(src: String) -> Vector2:
    for id in points:
        var pt: Dictionary = points[id]
        if str(pt["to"]) != src:
            continue
        if pt["arrive"] != Vector2.ZERO:
            return pt["arrive"]
        return _land(pt)
    return Vector2.ZERO

## 站在这块的 id 那个口里边（对面通这块的口不止一个时，main 照对面那个口写的 via 找到这里）
func arrival_at(id: String) -> Vector2:
    if not points.has(id):
        return Vector2.ZERO
    var pt: Dictionary = points[id]
    return pt["arrive"] if pt["arrive"] != Vector2.ZERO else _land(pt)

## 从口往里走，找第一个能站、又在这个口的圈外头的点（落在圈里的话一到就算「已经在口里」，走不出去也走不回来）
func _land(pt: Dictionary) -> Vector2:
    var p: Vector2 = pt["pos"]
    var dir := _inward(p) - p
    for k in [1.0, 1.4, 1.8, 2.4, 3.0]:
        var q := nearest_free(p + dir * k)
        if q != Vector2.ZERO and q.distance_to(p) > float(pt["r"]) + 6.0:
            return q
    return nearest_free(p + dir)

## 口往画布里走 70 像素（口挨着哪条边，就往对面走）
func _inward(p: Vector2) -> Vector2:
    var sz: Array = cfg["size"]
    var w := float(sz[0])
    var h := float(sz[1])
    var d := {Vector2(1, 0): p.x, Vector2(-1, 0): w - p.x, Vector2(0, 1): p.y, Vector2(0, -1): h - p.y}
    var best := Vector2(0, 1)
    var bd := INF
    for k in d:
        if float(d[k]) < bd:
            bd = float(d[k])
            best = k
    return p + best * 70.0

## 会站人的地方：出生点、每个口上、从口进来站的点、布局里的 from_*
func _people_spots() -> Array:
    var spots: Array = [SPAWN]
    for id in points:
        if str(points[id]["to"]) != "":
            spots.append(points[id]["pos"])
            spots.append(points[id]["arrive"] if points[id]["arrive"] != Vector2.ZERO else _inward(points[id]["pos"]))
    for k in cfg:
        if str(k).begins_with("from_"):
            spots.append(Vector2(float(cfg[k][0]), float(cfg[k][1])))
    return spots

## 这块牌子会不会盖住站人的地方（人身子按 40×90 算，比 _keep_signs_off_people 的 32×84 宽一点，跟 03 的测试一样）
func _covers_people(r: Rect2) -> bool:
    for s in _people_spots():
        if r.intersects(Rect2((s as Vector2).x - 20.0, (s as Vector2).y - 90.0, 40.0, 90.0)):
            return true
    return false

## 「去…」牌子别盖住站在口上、落点上、出生点上的人（03 测第 60、61 版报的 9 处，01 G 定这件里改）：
## 牌子跟人身子（宽 32、高 84）叠上了，就把牌子挪到那人头顶上面；挪到画布顶还叠，就挪到人右边
func _keep_signs_off_people() -> void:
    var spots: Array = _people_spots()
    for l in labels.get_children():
        if not l is Control:
            continue
        for pass_i in 4:
            var hit := false
            for s in spots:
                var body := Rect2((s as Vector2).x - 16.0, (s as Vector2).y - 84.0, 32.0, 84.0)
                var r := Rect2(l.position, l.size)
                if r.intersects(body):
                    hit = true
                    var up: float = (s as Vector2).y - 84.0 - l.size.y - 6.0
                    if up >= 2.0:
                        l.position.y = up
                    else:
                        l.position.x = (s as Vector2).x + 22.0
            if not hit:
                break

## 走到头：推着摇杆原地不动 BUMP_HOLD 秒，往推的那边一步不在能走的范围里（不是被桌子挡，是到了边）→ 弹一句
func _bump_tick(dt: float) -> void:
    if not bump_armed and pos.distance_to(bump_at) > BUMP_REARM:
        bump_armed = true
    if stick.length() < 0.5 or not walking_enabled or seated:
        bump_still = 0.0
        bump_last = pos
        return
    if pos.distance_to(bump_last) > 0.5:
        bump_still = 0.0
        bump_last = pos
        return
    bump_still += dt
    if bump_still >= BUMP_HOLD and bump_armed:
        var d := _dir_name(stick)
        if not in_walk(pos + stick.normalized() * 30.0):
            _bump(d)

## 点了能走的范围外头（水、墙外、画布边外），往那边弹一句
func _tap_bump(target: Vector2) -> void:
    if bump_armed and not in_walk(target) and target.distance_to(pos) > 40.0:
        var near_exit := false
        for id in points:
            if str(points[id]["to"]) != "" and target.distance_to(points[id]["pos"]) < float(points[id]["r"]) + 40.0:
                near_exit = true
        if not near_exit:
            _bump(_dir_name(target - pos))

func _bump(d: String) -> void:
    bump_armed = false
    bump_at = pos
    edge_bump.emit(d)

static func _dir_name(v: Vector2) -> String:
    if absf(v.x) > absf(v.y):
        return "right" if v.x > 0.0 else "left"
    return "down" if v.y > 0.0 else "up"

## 这一点在布局的能走范围（walk 那几块多边形）里不在（家具挡不挡不管）
func in_walk(p: Vector2) -> bool:
    for poly in cfg.get("walk", []):
        var pts := PackedVector2Array()
        for v in poly:
            pts.append(Vector2(float(v[0]), float(v[1])))
        if Geometry2D.is_point_in_polygon(p, pts):
            return true
    return false

# ---------- 能说话的 NPC（对话插件，10/4） ----------
## 登一位能说话的：脚点、人画出来多高（点他身上哪块算点到他）、台词文件、称呼、人物图
func add_talker(id: String, foot: Vector2, height: float, dialogue: String, title: String, code: String) -> void:
    talkers[id] = {"id": id, "foot": foot, "head": foot - Vector2(0, height), "dialogue": dialogue, "title": title, "code": code}

## 玩家走到哪开聊：他脚前一步最近的空地（第一次要时才找，搭画布那会儿能走的格子还没算）
func talker_approach(id: String) -> Vector2:
    var tk: Dictionary = talkers[id]
    if not tk.has("approach"):
        tk["approach"] = nearest_free((tk["foot"] as Vector2) + Vector2(0, 30))
    return tk["approach"]

## 画布上这一点点到了哪位能说话的（叠在一起算前面那个）
func talker_at(at: Vector2) -> String:
    var best := ""
    var by := -INF
    for id in talkers:
        var tk: Dictionary = talkers[id]
        var r := Rect2(tk["head"].x - 18.0, tk["head"].y, 36.0, (tk["foot"] as Vector2).y - (tk["head"] as Vector2).y)
        if r.grow(4.0).has_point(at) and (tk["foot"] as Vector2).y > by:
            by = (tk["foot"] as Vector2).y
            best = id
    return best

## 去跟他说话：已经在跟前直接开聊，不然走过去，到了再开（_process）
func request_talker(id: String) -> void:
    if not talkers.has(id):
        return
    var ap: Vector2 = talker_approach(id)
    if pos.distance_to(ap) <= 34.0:
        face = _face_for((talkers[id]["foot"] as Vector2) - pos)
        talk_requested.emit(id)
        return
    pending_talker = id
    go_to(ap)

## 离 p 最近的能站的点（72 像素内，4 像素一格找）；找不到回 Vector2.ZERO
func nearest_free(p: Vector2) -> Vector2:
    var best := Vector2.ZERO
    var bd := INF
    for dy in range(-72, 73, 4):
        for dx in range(-72, 73, 4):
            var d := Vector2(dx, dy).length()
            if d < bd and _free(p + Vector2(dx, dy)):
                bd = d
                best = p + Vector2(dx, dy)
    return best

func tap(screen: Vector2) -> void:
    if walking_enabled and not talkers.is_empty():
        var id := talker_at(get_viewport().get_canvas_transform().affine_inverse() * screen)
        if id != "":
            request_talker(id)
            return
    pending_talker = ""
    if walking_enabled:
        _tap_bump(get_viewport().get_canvas_transform().affine_inverse() * screen)
    super(screen)

## 替身（10/3 化妆间起）：布局里写了 standin 的人，拿定稿宾客的图当替身（以后换 GPT 画的）——
## code 哪张图、frame 第几格（0 朝前、4 朝左、8 朝右、12 背影）；坐着的给 rows（只留上面几行，下半截让凳子挡住）和 bottom（图底落在哪一行，凳面）。
## 按脚点 (x, y) 跟家具排前后，1 倍、不插值。图不在（没跑 bake_used.py）回 false，照旧画代码小人
func _standin(n: Dictionary) -> bool:
    var sd: Dictionary = n["standin"]
    var l: Dictionary = LMPeople.look(str(sd["code"]))
    if l.is_empty():
        return false
    var fw := int(l["fw"])
    var fh := int(l["fh"])
    var hf := int(l["hframes"])
    var fr := int(sd.get("frame", 0))
    var rows := int(sd.get("rows", fh))
    var at := Vector2(float(n["x"]), float(n["y"]))
    var s := Sprite2D.new()
    s.texture = l["tex"]
    s.centered = false
    s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    s.region_enabled = true
    s.region_rect = Rect2(float((fr % hf) * fw), float((fr / hf) * fh), float(fw), float(rows))
    s.position = at
    s.offset = Vector2(-fw / 2.0, float(sd.get("bottom", at.y)) - at.y - float(rows))
    s.name = "npc_" + str(n["id"])
    s.set_meta("base_offset", s.offset)
    s.set_meta("breath_phase", float(npc_nodes.size()) * 1.7)
    world.add_child(s)
    npc_nodes[str(n["id"])] = s
    if not bool(n.get("sit", false)) or bool(n.get("block", false)):
        obstacles.append({"ellipse": [at.x, at.y, NPC_FOOT.x, NPC_FOOT.y]})
    return true

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

## 换了形象（每回进院子 main 都会设一遍）：院子里的客人重摆一拨，不跟玩家撞脸
func set_look(preset: int, nickname: String) -> void:
    super(preset, nickname)
    if court_life != null:
        court_life.reseed(court_life.rng.randi())

## 截图、测试用：院子里的人按固定种子重摆，再快进 secs 秒（每回出来一样）
func settle_people(seed_n: int, secs: float) -> void:
    if court_life == null:
        return
    court_life.reseed(seed_n)
    var n := int(secs * 30.0)
    for i in n:
        court_life.step(1.0 / 30.0)

## NPC 在哪（对话、指路时 main 要用）
func npc_pos(id: String) -> Vector2:
    return (npc_nodes[id] as Sprite2D).position if npc_nodes.has(id) else Vector2.ZERO

## 体验第二轮 新 1、新 4（01 9/24）：东西的名字牌（亭子、大门口、宴会楼、回忆册……）不再一直挂在图上——底图有了真画，
## 东西一眼认得出，走近时出的按钮上写清楚就够了（阿鱼 9/23：图上别叠字）。**只留出口牌**（去哪、回哪、通到别处的门和小径），
## 做成小木牌的样子：暖褐底、米白字、没有金边，和屏幕上 HUD 那套深底金边的按钮拉开，不会被当成按钮
const EXIT_WORDS := ["后门", "楼门", "西小径", "东小径", "大门"]
const NOT_EXIT := ["回忆册"]   # 「回」字开头但不是出口（03 第 43 版回归查出来的）
static func is_exit_label(text: String) -> bool:
    if text in NOT_EXIT:
        return false
    return text.begins_with("去") or text.begins_with("回") or text in EXIT_WORDS

func _label(text: String, at: Vector2) -> void:
    if not is_exit_label(text):
        return
    var l := Label.new()
    l.text = text
    l.set_meta("sign", text)   # 牌子上原来的字（加箭头前），_arrow_signs 照它找口
    name_plate(l, Color("#f3e6c8"))
    var sb := l.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
    sb.bg_color = Color(0.36, 0.23, 0.13, 0.85)   # 小木牌
    l.add_theme_stylebox_override("normal", sb)
    l.position = at - l.size * 0.5
    labels.add_child(l)

## 路牌加箭头（10/4 第 68 版，阿鱼：「每一个导向导航的位置，比如说去果园去什么的，往哪个方向走，你要用在那个箭头前面去标注一下。
## 比如向上走……箭头指向上方在前面，如果是向下走，向右走，你就把它放在字的后面，然后箭头指向右，不然的话我都不知道往哪儿走」）：
##   箭头＝玩家在屏幕上往哪边走能到那个口：口在画布哪条边（离哪条边最近）就指哪边。往上「↑ 去果园」、往左「← 去草坪」放字前（往左 01 定跟往上一样），
##   往右「去停车场 →」、往下「去前门 ↓」放字后。字体自带箭头字，跟牌子的字同一个风格。房间门口写名字的牌子（room_sign）不加
## 牌子认哪个口：先照字认（「去喷泉广场」→ 通 plaza 的口，同名有几个取最近的）；认不出（「楼门」「后门」这种）取离牌子最近的出口（写了 to 的口，或迎宾院大门 gate）
const SIGN_NAMES := {"court": ["迎宾院"], "plaza": ["喷泉广场"], "parking": ["停车场"], "banquet": ["宴会厅", "宴会楼"], "lawn": ["草坪"],
    "lake": ["湖边"], "orchard": ["果园"], "backhall": ["后厅"], "kids": ["儿童乐园"], "shop": ["小卖部"], "rest2": ["休息厅 2"],
    "wkitchen": ["西餐厨房"], "garden": ["后花园"], "frontgate": ["前门"], "backgate": ["后门"]}

## 这块牌子指的是哪个口（回口的画布坐标；认不出回 ZERO）
func sign_target(text: String, at: Vector2) -> Vector2:
    var name := text.trim_prefix("去").trim_prefix("回")
    var best := Vector2.ZERO
    var bd := INF
    for id in points:
        var to := str(points[id]["to"])
        if to != "" and name in SIGN_NAMES.get(to, []):
            var d: float = at.distance_to(points[id]["pos"])
            if d < bd:
                bd = d
                best = points[id]["pos"]
    if best != Vector2.ZERO:
        return best
    for id in points:
        if str(points[id]["to"]) != "" or id == "gate":
            var d: float = at.distance_to(points[id]["pos"])
            if d < bd:
                bd = d
                best = points[id]["pos"]
    return best

func _hits_placed(l: Label, placed: Array) -> bool:
    return _hits_placed_at(Rect2(l.position, l.size), placed)

func _hits_placed_at(r: Rect2, placed: Array) -> bool:
    for o in placed:
        if r.grow(3.0).intersects(Rect2((o as Label).position, (o as Label).size)):
            return true
    return false

## 口朝哪边：up / down / left / right。布局里口写了 dir 就照它（草坪「去果园 B」在北边西头角上，离画布左边比上边近，写了 up）；
## 不然看口离画布哪条边最近
func edge_of(p: Vector2) -> String:
    for pt in cfg.get("points", []):
        if Vector2(float(pt["x"]), float(pt["y"])) == p and pt.has("dir"):
            return str(pt["dir"])
    var sz: Array = cfg["size"]
    var d := {"up": p.y, "down": float(sz[1]) - p.y, "left": p.x, "right": float(sz[0]) - p.x}
    var best := "down"
    for k in d:
        if float(d[k]) < float(d[best]):
            best = k
    return best

const SIGN_ARROW := {"up": "↑", "down": "↓", "left": "←", "right": "→"}
static func arrow_text(text: String, dir: String) -> String:
    var a: String = SIGN_ARROW.get(dir, "")
    if a == "":
        return text
    return a + " " + text if dir == "up" or dir == "left" else text + " " + a

## 牌子摆哪（第 68 版小修，04：「去小卖部 ↓」往下走是绿篱，口其实在左边；01：阿鱼最在意箭头指得准）：照箭头直走就到口——
##   上下的口：牌子在口正前方，往画布里 SIGN_AHEAD（在从口进来站的人头顶外头，不盖人）；左右的口：牌子在口那条线紧下面一点、往里 SIGN_SIDE_IN；
##   同一个口有两块牌（迎宾院大门：「大门」「去停车场」）依次往里排。布局里写的牌子位置只用来认是哪块牌，摆位照这个规矩算
const SIGN_AHEAD := 180.0
const SIGN_SIDE_IN := 74.0
const SIGN_SIDE_DOWN := 34.0
const DIR_V := {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}

func _arrow_signs() -> void:
    if labels == null:
        return
    var used := {}
    var placed: Array = []
    # 先摆左右口的牌，再摆上下口的牌：叠上了上下口的牌往里退一行不吃亏（横偏还是 0），左右口的牌没处躲（后厅「← 去草坪」跟「去西餐厨房 ↓」）
    var todo: Array = []
    for l in labels.get_children():
        if not l is Label or not l.has_meta("sign"):
            continue
        var c0: Vector2 = l.position + l.size * 0.5
        var tg := sign_target(str(l.get_meta("sign")), c0)
        if tg == Vector2.ZERO:
            continue
        var dd := edge_of(tg)
        todo.append([0 if (dd == "left" or dd == "right") else 1, l, tg, dd])
    todo.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
    for item in todo:
        var l: Label = item[1]
        var target: Vector2 = item[2]
        var dir: String = item[3]
        var center: Vector2
        l.text = arrow_text(str(l.get_meta("sign")), dir)
        l.set_meta("dir", dir)
        l.set_meta("target", target)
        l.size = l.get_combined_minimum_size()
        var inward: Vector2 = -(DIR_V[dir] as Vector2)
        var n: int = int(used.get(target, 0))
        used[target] = n + 1
        if dir == "up" or dir == "down":
            center = target + inward * (SIGN_AHEAD + float(n) * (l.size.y + 6.0))
        else:
            # 左右的口：先试口那条线下面；那儿站着人（草坪去西餐厨房，进来站的点写在口下面）就挂到线上面
            # 再不行往画布里多挪一截（口上、落点上都站着人，牌子宽，横着躲开）
            var off: float = SIGN_SIDE_DOWN + float(n) * (l.size.y + 6.0)
            var tries: Array = []
            for extra in [0.0, 60.0, 120.0]:
                var inx: float = SIGN_SIDE_IN + l.size.x * 0.5 - 40.0 + extra
                tries.append(target + inward * inx + Vector2(0, off))
                tries.append(target + inward * inx - Vector2(0, off))
            center = tries[0]
            for tc in tries:
                if not _covers_people(Rect2((tc as Vector2) - l.size * 0.5, l.size)):
                    center = tc
                    break
        l.position = center - l.size * 0.5
        # 跟前面摆好的牌叠上了（广场南边四个口挨着）：上下的口沿自己的方向再往里挪一行；左右的口先换到口线另一边，不行再往里挪。横偏不变大（照箭头直走照样到口）
        if _hits_placed(l, placed) and not (dir == "up" or dir == "down"):
            var flip: Vector2 = Vector2(l.position.x, 2.0 * target.y - (l.position.y + l.size.y))
            if not _hits_placed_at(Rect2(flip, l.size), placed) and not _covers_people(Rect2(flip, l.size)):
                l.position = flip
        for pass_i in 4:
            if not _hits_placed(l, placed):
                break
            l.position += inward * ((l.size.y + 6.0) if (dir == "up" or dir == "down") else 40.0)
        placed.append(l)
        # 加了箭头牌子变宽：贴着画布边的（后厅「回宴会厅」）往里收，别出画布
        var sz: Array = cfg["size"]
        l.position.x = clampf(l.position.x, 4.0, float(sz[0]) - l.size.x - 4.0)
        l.position.y = clampf(l.position.y, 4.0, float(sz[1]) - l.size.y - 4.0)

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

static func _obs_box(o: Dictionary, clear_default: float) -> Rect2:
    var clear := float(o.get("clear", clear_default))
    if o.has("rect"):
        var r: Array = o["rect"]
        return Rect2(float(r[0]) - clear, float(r[1]) - clear, float(r[2]) - float(r[0]) + clear * 2.0, float(r[3]) - float(r[1]) + clear * 2.0)
    var e: Array = o["ellipse"]
    var rx := float(e[2]) + clear
    var ry := float(e[3]) + clear
    return Rect2(float(e[0]) - rx, float(e[1]) - ry, rx * 2.0, ry * 2.0)

static func _blocked(x: float, y: float, obs: Array, clear_default: float) -> bool:
    for o in obs:
        var clear := float(o.get("clear", clear_default))
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
