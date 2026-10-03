extends SceneTree
## 验收：代码画的果园进了游戏、跟样板一样（01 画，阿鱼 10/3「能」；tools/pixel_art/orchard.py）
## 1 背景、51 张立着的图都铺上，左上角、着地线跟 room.json 一样；1 倍、不插值；带编号的灰盒都藏了，挡人的占地还在
## 2 有果没果按地块换：每条垄、每棵树各自显示一张（熟了有果、没熟没果，没有青果那一档）；收了一种，另一种不动
## 3 硬边、这块画布 ≤ 64 色
## 4 手机竖屏 540×960 下镜头 1 倍
## 5 收购处那行名字挪到布篷上的空招牌（游戏里不显示，图上不叠字）；摊子、垄、树的框照画出来的（art_box）
## 用法：Godot --headless --path . --script res://tools/test_pixel_orchard.gd ；最后一行 RESULT PASS 才算过

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
    m.orchard_save.local_path = "user://test_pixel_orchard.json"   # 不动这台电脑上的真存档
    m.orchard_save.plots = {}
    m.orchard_save.basket = {}
    m.games_save.local_path = "user://test_pixel_orchard_games.json"
    m.ensure_canvas("orchard")
    var o = m.orchard
    o.fake_now = 1_789_876_799.0
    var paths: Array = o.cfg.get("pixel_art", [])
    check("果园布局写了 pixel_art（%s）" % [paths], paths.size() == 1)
    print("1 铺上了、位置对")
    var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(paths[0])))
    var bgn: Sprite2D = null
    for c in o.get_children():
        if c is Node2D and (c as Node).get_node_or_null("px_background_orchard") != null:
            bgn = (c as Node).get_node("px_background_orchard")
    check("背景铺了（%s）" % [bgn.position if bgn else null], bgn != null and bgn.position == Vector2.ZERO
        and bgn.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and bgn.scale == Vector2.ONE)
    var cols := {}
    _colors(str(man["background"]["png"]), cols)
    # 背景铺满整块画布、一个透明像素都没有（样板在 y 255 漏过一整行，游戏里透出灰盒的绿线，10/3 补上）
    var bimg := (load(str(man["background"]["png"])) as Texture2D).get_image()
    if bimg.is_compressed():
        bimg.decompress()
    var holes := 0
    for y in bimg.get_height():
        for x in range(0, bimg.get_width(), 4):
            if bimg.get_pixel(x, y).a8 == 0:
                holes += 1
    check("背景 %s 铺满整块画布、没有透明的洞（%d 处）" % [bimg.get_size(), holes], bimg.get_size() == Vector2i(o.cfg["size"][0], o.cfg["size"][1]) and holes == 0)
    var bad: Array = []
    for p in man["props"]:
        var s: Sprite2D = o.world.get_node_or_null(NodePath(str(p["id"])))
        if s == null:
            bad.append("%s 没铺" % p["id"])
            continue
        var tl: Vector2 = s.position + s.offset
        if tl != Vector2(p["x"], p["y"]) or s.position.y != float(p["foot"]) or s.scale != Vector2.ONE \
                or s.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
            bad.append("%s 左上 %s 着地 %s" % [p["id"], tl, s.position.y])
        _colors(str(p["png"]), cols)
    check("%d 张都铺了、左上角和着地线跟 room.json 一样（不对的 %s）" % [man["props"].size(), bad.slice(0, 4)], bad.is_empty() and man["props"].size() == 51)
    var shown: Array = []
    for it in o.cfg["items"]:
        if str(it.get("part", "")).begins_with("OR-"):
            var g = o.world.get_node_or_null(NodePath(str(it["id"])))
            if g != null and g.visible:
                shown.append(it["id"])
    check("带编号的灰盒都藏了（还露着的 %s）" % [shown], shown.is_empty())
    check("灰盒的小圆点果子没画（%d 块地都用图）" % o.plots.size(), o.plots.size() == 14 and o.plots.all(func(p): return p.has("ripe") and (p["dots"] as Array).is_empty()))
    for id in ["shop_stall", "cart", "ridge_3"]:
        var it2: Dictionary = (o.cfg["items"] as Array).filter(func(x): return str(x.get("id")) == id)[0]
        var r: Array = it2["rect"]
        check("%s 的占地 %s 照旧挡人" % [id, r], not o._free(Vector2((float(r[0]) + float(r[2])) * 0.5, (float(r[1]) + float(r[3])) * 0.5)))
    for id in o.points:
        var pt: Vector2 = o.points[id]["pos"]
        var path: Array = o.find_path(o.SPAWN, pt)
        check("%s 走得到" % id, not path.is_empty() and (path[path.size() - 1] as Vector2).distance_to(pt) <= float(o.points[id]["r"]))

    print("2 有果没果按地块换")
    _age(o, 1e6)
    check("都熟了：14 块地都是有果那张", _showing(o, true) == 14 and _showing(o, false) == 0)
    o.farm["sell_mode"] = "manual"
    o.harvest("strawberry")
    o.refresh_fruit()
    check("收了草莓：8 条垄换成没果、6 棵树还有果（垄没果 %d、树有果 %d）" % [_showing(o, false, "strawberry"), _showing(o, true, "loquat")],
        _showing(o, false, "strawberry") == 8 and _showing(o, true, "strawberry") == 0 and _showing(o, true, "loquat") == 6)
    o.fake_now += o.grow_secs() * 0.6
    o.refresh_fruit()
    check("长到六成（以前的青果）：还是没果那张", _showing(o, false, "strawberry") == 8)
    o.fake_now += o.grow_secs() * 0.5
    o.refresh_fruit()
    check("到点熟了：垄又换回有果", _showing(o, true, "strawberry") == 8)
    m.orchard_save.mark_plot("ridge_2", o.now())
    o.refresh_fruit()
    check("一块地各算各的：只有 ridge_2 刚收是没果", _showing(o, false, "strawberry") == 1 and not (o.world.get_node("px_ridge_2_fruit") as Node2D).visible)

    print("3 硬边、颜色数")
    check("果园的图只有全透明和不透明、一共 %d 色（≤ 64）" % cols.size(), not cols.has("半透明") and cols.size() <= 64)

    print("4 镜头 1 倍")
    m._switch_canvas("lawn")
    m._switch_canvas("orchard")
    for i in 60:
        await process_frame
        if m.state == "orchard" and not m.switching:
            break
    o._fit_zoom()
    check("手机 540×960 下果园镜头 %s" % o.cam.zoom, o.cam.zoom == Vector2.ONE)

    print("5 收购处的名字、框")
    var stall: Dictionary = (o.cfg["items"] as Array).filter(func(x): return str(x.get("id")) == "shop_stall")[0]
    var at := Vector2((float(stall["rect"][0]) + float(stall["rect"][2])) * 0.5, float(stall["rect"][3]) + float(stall["label"]["dy"]))
    check("「山庄收购处」挪到空招牌上（%s，招牌 x 948～1012、y 902～920）" % at, Rect2(948, 902, 64, 18).has_point(at))
    var lab_shown := false
    for l in o.labels.get_children():
        if l is Label and (l as Label).text == "山庄收购处":
            lab_shown = true
    check("游戏里不显示这行字（图上不叠字）", not lab_shown)
    check("摊子的框照画出来的 179×188（%s）" % [stall.get("art_box")], (stall.get("art_box", []) as Array).map(func(v): return int(v)) == [889, 901, 1068, 1089])
    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)

func _age(o, age: float) -> void:
    for p in o.plots:
        m.orchard_save.mark_plot(p["id"], o.now() - age)
    o.refresh_fruit()

## 几块地正显示有果（fruit=true）/ 没果那张；有果没果两张不能同时露、也不能都藏
func _showing(o, fruit: bool, kind := "") -> int:
    var n := 0
    for p in o.plots:
        if kind != "" and p["kind"] != kind:
            continue
        var r: bool = (p["ripe"] as Node2D).visible
        var b: bool = (p["bare"] as Node2D).visible
        if r == b:
            return -1
        if r == fruit:
            n += 1
    return n

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
