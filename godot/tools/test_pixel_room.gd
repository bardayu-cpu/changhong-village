extends SceneTree
## 验收：代码画的像素房间进了游戏、跟样板一样（阿鱼 10/3 定的画法，docs/罗曼山庄画风.md 第 0 节；后厅休息间、化妆间）
## 1 布局写了 pixel_art 的画布：背景、每件家具都铺上了，左上角、着地线、图的大小跟 room.json 一样；1 倍、不插值
## 2 hide 里的灰盒藏了，但挡人的占地还在（新补的琴叶榕、衣帽架也挡人）；交互点照样走得到
## 3 图是硬边（每个像素要么全透明要么不透明），整间加起来不超过 64 色
## 4 手机竖屏 540×960 下镜头是 1 倍（不缩到 0.9375，像素不会掉行）
## 5 lounge 那句还是【待补】：走进去不出按钮
## 6 化妆间的人用定稿宾客当替身（新娘坐、两位化妆师站），位置照布局（凳子对齐也照布局算，不写死坐标：10/5 化妆间换成 GPT 整间版，布局全换了）；（10/4 起原来那间封起来：门洞挡上、铺那面墙）
## 7 化妆间自己的像素整间（GPT 整间版 61 张）：背景、每件都铺上了、左上角和着地线跟 room.json 一样、1 倍不插值；颜色 ≤ 64、没有半透明
## 用法：Godot --headless --path . --script res://tools/test_pixel_room.gd ；最后一行 RESULT PASS 才算过

const CourtCopy = preload("res://scripts/court_copy.gd")
var m
var started := false
var ok := true

func _initialize() -> void:
    m = load("res://scripts/main.gd").new()
    m.fast = true
    get_root().add_child(m)

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.ensure_canvas("backhall")
    m.ensure_canvas("makeup")
    var b = m.backhall
    var paths: Array = b.cfg.get("pixel_art", [])
    check("后厅布局写了 pixel_art（%s）" % [paths], not paths.is_empty())
    print("1 铺上了、位置对")
    var cols := {}
    for path in paths:
        var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(path)))
        var bgn: Sprite2D = null
        for c in b.get_children():
            if c is Node2D:
                for n in (c as Node).get_children():
                    if n is Sprite2D and str(n.name).begins_with("px_background") and (n as Sprite2D).texture.resource_path == str(man["background"]["png"]):
                        bgn = n
        check("背景铺了，左上角 %s" % [bgn.position if bgn else null], bgn != null and bgn.position == Vector2(man["background"]["x"], man["background"]["y"])
            and bgn.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and bgn.scale == Vector2.ONE)
        _colors(str(man["background"]["png"]), cols)
        var bad: Array = []
        for p in man["props"]:
            var s: Sprite2D = b.world.get_node_or_null(NodePath(str(p["id"])))
            if s == null:
                bad.append("%s 没铺" % p["id"])
                continue
            var top_left: Vector2 = s.position + s.offset
            var tex: Texture2D = load(str(p["png"]))
            if top_left != Vector2(p["x"], p["y"]) or s.position.y != float(p["foot"]) or s.texture.get_size() != tex.get_size() \
                    or s.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST or s.scale != Vector2.ONE:
                bad.append("%s 左上 %s 着地 %s" % [p["id"], top_left, s.position.y])
            for id in p["hide"]:
                var g = b.world.get_node_or_null(NodePath(str(id)))
                if g == null or g.visible:
                    bad.append("灰盒 %s 没藏" % id)
            _colors(str(p["png"]), cols)
        check("%d 件家具都铺了、左上角和着地线跟 room.json 一样、灰盒藏了（不对的 %s）" % [man["props"].size(), bad.slice(0, 4)], bad.is_empty() and man["props"].size() > 0)
    # 不照 room.json 的 hide 清单查（清单漏写就查不出来）：铺了像素图的那几间里，每件带零件编号的灰盒（隔墙、前沿矮墙除外）都得藏掉，不然灰盒跟像素图叠在一起
    var shown: Array = []
    var ranges: Array = []
    for path in paths:
        var mr: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(path)))["room"]
        ranges.append([float(mr["x0"]) + 10.0, float(mr["x1"])])
    for it in b.cfg["items"]:
        if not str(it.get("part", "")).begins_with("BH-") or not it.has("rect"):
            continue
        var cx := (float(it["rect"][0]) + float(it["rect"][2])) * 0.5
        var cy := float(it["rect"][3])
        var inside := false
        for rr in ranges:
            inside = inside or (cx > float(rr[0]) and cx < float(rr[1]))
        if inside and cy < 684.0:
            var g = b.world.get_node_or_null(NodePath(str(it["id"])))
            if g != null and g.visible:
                shown.append(it["id"])
    check("铺了像素图的那几间里带编号的灰盒都藏了（还露着的 %s）" % [shown], shown.is_empty())
    print("2 挡人的占地还在")
    for id in ["fiddle_fig", "coat_rack", "sofa_back", "record_player", "mk_island", "mk_closet_cn", "mk_screen", "mk_sofa"]:
        var it: Dictionary = (b.cfg["items"] as Array).filter(func(x): return str(x.get("id")) == id)[0]
        var r: Array = it["rect"]
        var mid := Vector2((float(r[0]) + float(r[2])) * 0.5, (float(r[1]) + float(r[3])) * 0.5)
        check("%s 的占地 %s 人走不进去" % [id, r], not b._free(mid))
    for id in ["lounge", "to_makeup", "to_hall", "to_lawn"]:   # 10/4 原来那间化妆室封起来（02 F），dress 在里面走不到了，换成走廊里的化妆间门口
        var pt: Vector2 = b.points[id]["pos"]
        var path: Array = b.find_path(b.SPAWN, pt)
        check("%s 走得到" % id, not path.is_empty() and (path[path.size() - 1] as Vector2).distance_to(pt) <= float(b.points[id]["r"]))
    print("2c 休息间第三版（阿鱼 10/3「第三版可以」，蓝沙发换米白、棋桌换小茶几）")
    var ids: Array = (b.cfg["items"] as Array).map(func(x): return str(x.get("id", "")))
    check("行李箱拿掉了、棋桌换成小茶几", not ids.has("luggage_1") and not ids.has("luggage_2") and not ids.has("go_table") and ids.has("west_table"))
    var sp: Array = (b.cfg.get("stand_points", []) as Array).map(func(x): return str(x["id"]))
    # 10/4 07：麻将室、化妆间 NPC 走动加了 4 个站点（stand_mj_*、stand_mk_*），一样只是站人、不是交互点
    check("唱片机前、电视前两个站人点记下了（%s），站点都不做玩法（不是交互点）" % [sp], sp.slice(0, 2) == ["stand_record", "stand_tv"] and sp.all(func(x): return not b.points.has(x)))
    # 走路格子只留从进场点灌得到的格子：一件东西四周 24 像素里有能站的格子，就是从门口走得到它跟前
    var far: Array = []
    var n_l := 0
    for it in b.cfg["items"]:
        if str(it.get("type")) != "box" or not it.has("rect") or str(it["id"]).begins_with("wall") or str(it["id"]).begins_with("front"):
            continue
        var r: Array = it["rect"]
        if float(r[0]) < 869.0 or float(r[2]) > 1195.0:   # 休息间两道隔墙之间（10/4 方案 C 平移 +528）
            continue
        n_l += 1
        var near := false
        for yy in range(int(r[1]) - 24, int(r[3]) + 25, 6):
            for xx in range(int(r[0]) - 24, int(r[2]) + 25, 6):
                if b._free(Vector2(xx, yy)):
                    near = true
                    break
            if near:
                break
        if not near:
            far.append(it["id"])
    check("休息间 %d 件，从门口都走得到跟前（走不到的 %s）" % [n_l, far], n_l == 30 and far.is_empty())
    print("3 硬边、颜色数")
    check("整间的图只有全透明和不透明、一共 %d 色（≤ 64）" % cols.size(), not cols.has("半透明") and cols.size() <= 64)
    print("4 镜头 1 倍")
    m._switch_canvas("backhall")
    for i in 60:
        await process_frame
        if m.state == "backhall" and not m.switching:
            break
    b._fit_zoom()
    check("手机 540×960 下后厅镜头 %s（铺了像素图的画布取 1 倍）" % b.cam.zoom, b.cam.zoom == Vector2.ONE)
    print("5 lounge 那句没定不出按钮")
    check("lounge 那句还是【待补】", CourtCopy.placeholder(CourtCopy.text("lounge", CourtCopy.BACKHALL)))
    m.backhall_ui.spot("lounge", true)
    check("走进休息间不出按钮", not m.backhall_ui.act_btn.visible)
    m.backhall_ui.spot("lounge", false)
    print("6 化妆间的替身（10/4 02 F 从后厅长条搬进单独那间化妆间，跟凳子对齐）")
    var mk = m.areas["makeup"]
    var want := {}   # 照布局写的位置（凳子对齐在布局里已经算好：新娘脚点 = 凳脚 +1）
    for nn in mk.cfg["npcs"]:
        if str(nn["id"]) in ["bride", "makeup_1", "makeup_2"]:
            want[str(nn["id"])] = [float(nn["x"]), float(nn["y"]), bool(nn.get("sit", false))]
    check("布局里写了新娘、化妆师、化妆助理三位的位置（%s）" % [want], want.size() == 3)
    var badp: Array = []
    for id in want:
        var s: Sprite2D = mk.npc_nodes.get(id)
        var w: Array = want[id]
        if s == null or s.position != Vector2(w[0], w[1]) or not s.region_enabled or not (s.texture is AtlasTexture):
            badp.append(id)
        if b.npc_nodes.has(id):
            badp.append(id + " 还在后厅")
    check("新娘、化妆师、化妆助理在化妆间用定稿宾客的图当替身、站在布局写的地方，后厅长条里没了（不对的 %s）" % [badp], badp.is_empty())
    var bride: Sprite2D = mk.npc_nodes.get("bride")
    var bnpc: Dictionary = {}
    for nn2 in mk.cfg["npcs"]:
        if str(nn2["id"]) == "bride":
            bnpc = nn2
    var stool_foot := -1.0
    for it in mk.cfg["items"]:
        if str(it["id"]).begins_with("stool") and float(it["rect"][0]) - 4.0 <= float(bnpc.get("x", -1)) and float(bnpc.get("x", -1)) <= float(it["rect"][2]) + 4.0:
            stool_foot = float(it["rect"][3])
    var rows := float((bnpc.get("standin", {}) as Dictionary).get("rows", 60))
    var want_bottom := stool_foot - 16.0
    check("新娘坐着：只留上面 %d 行，图底落在凳面 y %.0f（她坐的那张化妆凳凳脚 %.0f 往上 16，跟旧屋一样）" % [int(rows), want_bottom, stool_foot], bride != null and stool_foot > 0.0 and bride.region_rect.size.y == rows and is_equal_approx(bride.position.y + bride.offset.y + rows, want_bottom))
    # 10/4 原来那间化妆室封起来（02 F）：门洞挡上，走廊里看是一面墙一扇关着的门；门口 to_makeup 换进单独那间（test_makeup_room 测）
    check("原来那间化妆室的门洞 (1363, 690) 挡上了", not b._free(Vector2(1363, 690)))
    var door_wall: Array = (b.world.get_children() as Array).filter(func(n): return str(n.name) == "px_makeup_door_wall")
    check("封起来的那面墙铺上了、着地线 696（走廊里的人在它前面）", door_wall.size() == 1 and (door_wall[0] as Node2D).position.y == 696.0)
    print("7 化妆间自己的像素整间")
    var mkpaths: Array = mk.cfg.get("pixel_art", [])
    check("化妆间布局写了 pixel_art（%s）" % [mkpaths], not mkpaths.is_empty())
    var cols2 := {}
    for path in mkpaths:
        var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(path)))
        var bgn: Sprite2D = null
        for c in mk.get_children():
            if c is Node2D:
                for n in (c as Node).get_children():
                    if n is Sprite2D and str(n.name).begins_with("px_background") and (n as Sprite2D).texture.resource_path == str(man["background"]["png"]):
                        bgn = n
        check("化妆间背景铺了，左上角 %s" % [bgn.position if bgn else null], bgn != null and bgn.position == Vector2(man["background"]["x"], man["background"]["y"])
            and bgn.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and bgn.scale == Vector2.ONE)
        _colors(str(man["background"]["png"]), cols2)
        var bad7: Array = []
        for p in man["props"]:
            var s7: Sprite2D = mk.world.get_node_or_null(NodePath(str(p["id"])))
            if s7 == null:
                bad7.append("%s 没铺" % p["id"])
                continue
            var tl: Vector2 = s7.position + s7.offset
            var tex7: Texture2D = load(str(p["png"]))
            if tl != Vector2(p["x"], p["y"]) or s7.position.y != float(p["foot"]) or s7.texture.get_size() != tex7.get_size() \
                    or s7.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST or s7.scale != Vector2.ONE:
                bad7.append("%s 左上 %s 着地 %s" % [p["id"], tl, s7.position.y])
            for id in p["hide"]:
                var g7 = mk.world.get_node_or_null(NodePath(str(id)))
                if g7 == null or g7.visible:
                    bad7.append("灰盒 %s 没藏" % id)
            _colors(str(p["png"]), cols2)
        check("化妆间 %d 件家具都铺了、左上角和着地线跟 room.json 一样、1 倍不插值（不对的 %s）" % [man["props"].size(), bad7.slice(0, 4)], bad7.is_empty() and man["props"].size() >= 50)
    # 不拿 room.json 对 room.json（上面那条节点对 room.json 是同源的，图整体偏了它查不出来）：每件图的着地线要等于布局里那件家具占地的前沿 y，图的横向中心要在占地中心 ±1 像素以内（现在量到最大差 1.0）
    var off_items: Array = []
    var layout_items := {}
    for it2 in mk.cfg["items"]:
        if it2.has("rect"):
            layout_items[str(it2["id"])] = it2["rect"]
    var n_cmp := 0
    for path in mkpaths:
        var man2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(path)))
        for p2 in man2["props"]:
            var lid := str(p2["id"]).trim_prefix("px_")
            if not layout_items.has(lid):
                off_items.append("%s 布局里没有这件" % lid)
                continue
            var rc2: Array = layout_items[lid]
            var sp2: Sprite2D = mk.world.get_node_or_null(NodePath(str(p2["id"])))
            if sp2 == null:
                continue
            n_cmp += 1
            var cxs: float = sp2.position.x + (sp2.texture.get_width() * 0.5) + sp2.offset.x
            var cxl: float = (float(rc2[0]) + float(rc2[2])) * 0.5
            if absf(sp2.position.y - float(rc2[3])) > 0.5 or absf(cxs - cxl) > 1.1:
                off_items.append("%s 着地线 %.1f（占地前沿 %.1f）、横向中心差 %.1f" % [lid, sp2.position.y, float(rc2[3]), cxs - cxl])
    check("化妆间每件图都对着布局里那件家具的占地（着地线 = 占地前沿、横向中心 ±1 像素）：比了 %d 件、对不上的 %d 件 %s" % [n_cmp, off_items.size(), str(off_items.slice(0, 3))], off_items.is_empty() and n_cmp >= 50)
    check("化妆间整间的图只有全透明和不透明、一共 %d 色（≤ 64）" % cols2.size(), not cols2.has("半透明") and cols2.size() <= 64)
    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)

## 测试在电脑上，可以读图：数颜色、看有没有半透明
func _colors(path: String, cols: Dictionary) -> void:
    var img := (load(path) as Texture2D).get_image()
    if img.is_compressed():
        img.decompress()
    img.convert(Image.FORMAT_RGBA8)
    for y in img.get_height():
        for x in img.get_width():
            var c := img.get_pixel(x, y)
            if c.a8 == 0:
                continue
            if c.a8 != 255:
                cols["半透明"] = true
                return
            cols[c.to_html(false)] = true
