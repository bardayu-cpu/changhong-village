extends SceneTree
## 验收：代码画的像素房间进了游戏、跟样板一样（阿鱼 10/3 定的画法，docs/罗曼山庄画风.md 第 0 节；先是后厅休息间）
## 1 布局写了 pixel_art 的画布：背景、每件家具都铺上了，左上角、着地线、图的大小跟 room.json 一样；1 倍、不插值
## 2 hide 里的灰盒藏了，但挡人的占地还在（新补的琴叶榕、衣帽架也挡人）；交互点照样走得到
## 3 图是硬边（每个像素要么全透明要么不透明），整间加起来不超过 64 色
## 4 手机竖屏 540×960 下镜头是 1 倍（不缩到 0.9375，像素不会掉行）
## 5 lounge 那句还是【待补】：走进去不出按钮
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
                var n = (c as Node).get_node_or_null("px_background")
                if n != null:
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
    # 不照 room.json 的 hide 清单查（清单漏写就查不出来）：休息间里每件带零件编号的灰盒（隔墙、前沿矮墙除外）都得藏掉，不然灰盒跟像素图叠在一起
    var shown: Array = []
    for it in b.cfg["items"]:
        if not str(it.get("part", "")).begins_with("BH-") or not it.has("rect"):
            continue
        var cx := (float(it["rect"][0]) + float(it["rect"][2])) * 0.5
        var cy := float(it["rect"][3])
        if cx > 341.0 and cx < 667.0 and cy < 684.0:
            var g = b.world.get_node_or_null(NodePath(str(it["id"])))
            if g != null and g.visible:
                shown.append(it["id"])
    check("休息间里带编号的灰盒都藏了（还露着的 %s）" % [shown], shown.is_empty())
    print("2 挡人的占地还在")
    for id in ["fiddle_fig", "coat_rack", "sofa_back", "record_player"]:
        var it: Dictionary = (b.cfg["items"] as Array).filter(func(x): return str(x.get("id")) == id)[0]
        var r: Array = it["rect"]
        var mid := Vector2((float(r[0]) + float(r[2])) * 0.5, (float(r[1]) + float(r[3])) * 0.5)
        check("%s 的占地 %s 人走不进去" % [id, r], not b._free(mid))
    for id in ["lounge", "to_hall", "to_lawn"]:
        var pt: Vector2 = b.points[id]["pos"]
        var path: Array = b.find_path(b.SPAWN, pt)
        check("%s 走得到" % id, not path.is_empty() and (path[path.size() - 1] as Vector2).distance_to(pt) <= float(b.points[id]["r"]))
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
