extends SceneTree
## 验收：五块画布读占位底图（01 9/24：这轮 GPT 画整张占位底图，不抠图）。
## 每块画布：造一张假底图（user:// 下），用它再搭一遍，和游戏里原来那块灰盒比——
## 底图铺上了、拉到画布大小；灰盒的地面和摆设不再画（大锅冒的气、物件名照旧）；**走路格子、交互点、出生点一格不差**；
## 没图的照旧灰盒。另外造一张尺寸不对的，确认会拉到画布大小
## 用法：Godot --headless --path . --script res://tools/test_canvas_base.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
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

func fake_base(w: int, h: int, path: String) -> void:
    var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.fill(Color("#8a6e4b"))
    img.save_png(path)

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    var canvases := {"迎宾院": m.court, "后厅": m.backhall, "草坪": m.lawn, "湖边": m.lake, "果园": m.orchard}
    for title in canvases:
        var ref = canvases[title]
        print(title)
        # 拿同一块画布搭两遍：一遍强制灰盒（指到一张不存在的图），一遍铺假底图，两遍比。
        # 游戏里那块可能已经铺了真底图（9/24 起迎宾院、草坪），不能拿它当灰盒的参照
        var old = load(ref.get_script().resource_path).new()
        old.base_path_override = "user://no_such_base.png"
        root.add_child(old)
        old.build(0, "小李", m.font)
        check("强制灰盒那遍没铺图", not old.base_on)
        var w := int(old.cfg["size"][0])
        var h := int(old.cfg["size"][1])
        var path := "user://test_base_%s.png" % old.layout_path.get_base_dir().get_file()
        fake_base(w, h, path)
        var c = load(ref.get_script().resource_path).new()
        c.base_path_override = path
        root.add_child(c)
        c.build(0, "小李", m.font)
        var sp: Sprite2D = null
        for n in c.get_children():
            for k in n.get_children():
                if k.name == "base":
                    sp = k
        check("铺上了底图 %dx%d" % [w, h], c.base_on and sp != null and sp.scale == Vector2.ONE)
        check("走路格子一格不差", c.cfg["walk_grid"] == old.cfg["walk_grid"])
        check("交互点一个不差（%d 个）" % c.points.size(), str(c.points) == str(old.points))
        check("出生点、出口金圈不变", c.SPAWN == old.SPAWN and c.door == old.door)
        var shapes := 0
        for n in c.world.get_children():
            var nm := str(n.name)
            # 留下的只该是：人、NPC、迎宾院走动的客人（walker_）、新人、大锅冒的气（steam）、草坪的小孩和喜多和球、果园地里的果子（玩法里会变的）
            if not (nm.begins_with("npc_") or nm.begins_with("walker_") or nm == "steam" or n == c.player or nm.begins_with("couple") or n is Sprite2D
                    or nm in ["xiduo", "ball"] or (title == "果园" and nm.begins_with("@Node2D"))):
                shapes += 1
        if shapes > 2:
            var names := {}
            for n in c.world.get_children():
                names[str(n.name).rstrip("0123456789@_")] = true
            print("    剩下的：", names.keys())
        check("灰盒摆设不再画（剩 %d 件）" % shapes, shapes <= 2)
        check("物件名那层字照旧（%d 个）" % c.labels.get_child_count(), c.labels.get_child_count() == old.labels.get_child_count())
        # 真底图接进来的那几块（9/24 迎宾院、草坪）：游戏里那块就是铺了图的，走路格子和灰盒一样
        if ref.base_on:
            check("游戏里这块铺了真底图，走路格子和灰盒一样", ref.cfg["walk_grid"] == old.cfg["walk_grid"])
        old.queue_free()
        c.queue_free()
        await process_frame
    # 尺寸不对的图：拉到画布大小
    print("尺寸不对")
    fake_base(768, 640, "user://test_base_small.png")
    var c2 = load(m.lake.get_script().resource_path).new()
    c2.base_path_override = "user://test_base_small.png"
    root.add_child(c2)
    c2.build(0, "小李", m.font)
    var sp2: Sprite2D = null
    for n in c2.get_children():
        for k in n.get_children():
            if k.name == "base":
                sp2 = k
    check("768x640 拉到 1536x1280", sp2 != null and sp2.scale.is_equal_approx(Vector2(2, 2)))
    c2.queue_free()
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
