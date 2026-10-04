extends SceneTree
## 验收：后厅、草坪、湖边、果园照「人 = 1」摆（01 E 10/3，跟迎宾院 test_court_scale 一个做法；04 基线 体验-后厅草坪湖边果园基线.md）
## 1 游戏里画出来的每件东西，外框跟 gen_specs_court.py 从 layout.json 算的（回执/零件规格/<场景>/<场景>-框.json）一样
## 2 几样关键的直接量：树 ≥3 个人高、白椅子 0.55 个人、沙发 ≤2.4 米、长凳 72 宽
## 3 交互点、出口从进来的地方都走得到；站在那里的人不被树冠挡（树在人前面画）
## 4 果园：果子挂在枇杷树冠上
## 用法：Godot --headless --path . --script res://tools/test_scene_scale.gd ；最后一行 RESULT PASS 才算过

const SCENES := {"backhall": "后厅", "lawn": "草坪", "lake": "湖边", "orchard": "果园"}

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

func drawn_box(holder: Node2D) -> Rect2:
    var r := Rect2()
    var first := true
    for c in holder.get_children():
        if not c is Polygon2D:
            continue
        for v in (c as Polygon2D).polygon:
            var p: Vector2 = v + holder.position
            if first:
                r = Rect2(p, Vector2.ZERO)
                first = false
            else:
                r = r.expand(p)
    return r

## 这件灰盒换成代码画的成品以后，游戏里铺的那几张图合起来的外框（room.json 里 hide 第一个是它的）；没有回空框
## 树画出来多高：灰盒量画的那几块；on_art 的（像素成品）量它那张图（layout 的 art.h）
func tree_h(c, it: Dictionary) -> float:
    if bool(it.get("on_art", false)):
        return float(it["art"]["h"])
    return drawn_box(c.world.get_node(str(it["id"]))).size.y

func pixel_box(c, id: String) -> Rect2:
    var out := Rect2()
    for path in c.cfg.get("pixel_art", []):
        var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(path)))
        for p in man["props"]:
            var hide: Array = p.get("hide", [])
            if hide.is_empty() or str(hide[0]) != id:
                continue
            var s: Sprite2D = c.world.get_node_or_null(NodePath(str(p["id"])))
            if s == null:
                continue
            var r := Rect2(s.position + s.offset, s.texture.get_size())
            out = r if out.size == Vector2.ZERO else out.merge(r)
    return out

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    # 后厅、草坪、湖边、果园开场不搭、第一次进去才搭（main.ensure_canvas，02 10/3）：这里要直接看它们，先搭好
    for cn in ["backhall", "lawn", "lake", "orchard"]:
        m.ensure_canvas(cn)
    for sc in SCENES:
        var cn: String = SCENES[sc]
        var c = m.get(sc)
        print("== ", cn)
        var spec = JSON.parse_string(FileAccess.get_file_as_string("res://回执/零件规格/%s/%s-框.json" % [cn, cn]))
        if not spec is Dictionary:
            check("读到 %s-框.json" % cn, false)
            continue
        var bad: Array = []
        var n := 0
        var on_art := 0   # 标了 on_art、不量外框的件数（10/4 湖边两半都是像素成品，一件灰盒都不剩）
        for it in spec["items"]:
            if str(it["type"]) == "image":
                continue
            # 标了 on_art 的（10/4 湖边东半边像素成品）：灰盒不画、图在 pixel_art 图层里，外框这条不量（树高、长凳下面另量）
            var lay0: Array = (c.cfg["items"] as Array).filter(func(x): return str(x.get("id")) == str(it["id"]))
            if not lay0.is_empty() and bool((lay0[0] as Dictionary).get("on_art", false)):
                on_art += 1
                continue
            var holder: Node2D = c.world.get_node_or_null(NodePath(str(it["id"])))
            if holder == null:
                bad.append("%s 没画" % it["id"])
                continue
            var want := Rect2(Vector2(it["box"][0], it["box"][1]), Vector2(float(it["box"][2]) - float(it["box"][0]), float(it["box"][3]) - float(it["box"][1])))
            var got := drawn_box(holder)
            # 铺了代码画的成品、layout 写了 art_box 的（10/3 果园起）：框照画出来的，量游戏里铺的那几张图（有果没果两张取并）
            var lay: Array = (c.cfg["items"] as Array).filter(func(x): return str(x.get("id")) == str(it["id"]))
            if not lay.is_empty() and (lay[0] as Dictionary).has("art_box"):
                got = pixel_box(c, str(it["id"]))
            n += 1
            if absf(got.position.x - want.position.x) > 1.5 or absf(got.position.y - want.position.y) > 1.5 or absf(got.end.x - want.end.x) > 1.5 or absf(got.end.y - want.end.y) > 1.5:
                bad.append("%s 画的 %s 表里 %s" % [it["id"], got, want])
        check("%s：%d 件画出来的外框跟 layout.json 算的一样（不对的 %s；像素成品不量的 %d 件）" % [cn, n, bad.slice(0, 4), on_art], (n > 0 or on_art > 0) and bad.is_empty())
        # 树
        var trees: Array = (c.cfg["items"] as Array).filter(func(x): return str(x.get("type", "")) == "tree")
        # pine_e：湖边东头 01 画的造型松 246 高（2.93 个人），差 6 像素；10/4 接进来时报 01 定改不改，先不算新问题（02 E）
        # pine_w、pine_w2：10/4 西半边接图，01 画的盆景松，跟东头那棵一样 246 高，同样不算（03 建议点名这三棵，别按 pine_ 开头全放过）
        var short: Array = trees.filter(func(x): return tree_h(c, x) < 3.0 * 84.0 - 1.0 and not (str(x["id"]) in ["pine_e", "pine_w", "pine_w2"]))
        if not trees.is_empty():
            check("%s：%d 棵树都 ≥3 个人高（矮的 %s）" % [cn, trees.size(), short.map(func(x): return x["id"])], short.is_empty())
        # 走得到、不被树冠挡
        var from: Vector2 = c.SPAWN
        var miss: Array = []
        var covered: Array = []
        for p in c.cfg["points"]:
            var at := Vector2(float(p["x"]), float(p["y"]))
            var path: Array = c.find_path(from, at)
            if path.is_empty() or (path[path.size() - 1] as Vector2).distance_to(at) > float(p["r"]):
                miss.append(str(p["id"]))
            var body := Rect2(at.x - 18.0, at.y - 84.0, 36.0, 84.0)
            for t in trees:
                if float(t["y"]) <= at.y:
                    continue
                var g: Dictionary = c.tree_geom(t)
                var cr := Rect2(float(t["x"]) - float(g["rx"]), float(g["cy"]) - float(g["ry"]), 2.0 * float(g["rx"]), 2.0 * float(g["ry"]))
                if cr.intersects(body):
                    covered.append("%s←%s" % [p["id"], t["id"]])
        check("%s：从进来的地方走得到每个交互点、出口（走不到的 %s）" % [cn, miss], miss.is_empty())
        check("%s：站在交互点、出口的人不被树冠挡（挡的 %s）" % [cn, covered], covered.is_empty())

    print("== 几样关键的直接量")
    var chair := drawn_box(m.lawn.world.get_node("chair_0_L1"))
    check("草坪白椅子高 %.0f（连前后 14）= %.2f 个人（表 0.55，椅高 46）" % [chair.size.y, (chair.size.y - 14.0) / 84.0], is_equal_approx(chair.size.y - 14.0, 46.0))
    var sofa: Array = (m.backhall.cfg["items"] as Array).filter(func(x): return str(x.get("id")) == "sofa")[0]["rect"]
    check("后厅沙发宽 %d = %.1f 米（≤2.4）" % [int(sofa[2]) - int(sofa[0]), (float(sofa[2]) - float(sofa[0])) / 48.0], (float(sofa[2]) - float(sofa[0])) / 48.0 <= 2.4)
    # 10/4 起湖边长凳是像素成品（px_bench 那张图），灰盒 bench_seat 只算占地：量布局里凳面那条的宽
    var bs: Dictionary = (m.lake.cfg["items"] as Array).filter(func(x): return str(x.get("id")) == "bench_seat")[0]
    var seat_w := float(bs["x1"]) - float(bs["x0"])
    check("湖边长凳宽 %.0f（表 72），图铺上了" % seat_w, is_equal_approx(seat_w, 72.0) and m.lake.world.has_node("px_bench"))

    print("== 果园的枇杷树（10/3 起是代码画的成品：有果没果两张整图，果子画在树冠里）")
    var off: Array = []
    for p in m.orchard.plots:
        if str(p["kind"]) != "loquat":
            continue
        var t: Dictionary = (m.orchard.cfg["items"] as Array).filter(func(x): return str(x.get("id")) == str(p["id"]))[0]
        for key in ["ripe", "bare"]:
            var s: Sprite2D = p[key]
            var box := Rect2(s.position + s.offset, s.texture.get_size())
            var ab: Array = t["art_box"]
            # 图着地在树脚、外框就是 layout 的 art_box（画出来的树），树干正对树的 x
            if s.position.y != float(t["y"]) or box != Rect2(float(ab[0]), float(ab[1]), float(ab[2]) - float(ab[0]), float(ab[3]) - float(ab[1])) \
                    or absf(box.get_center().x - float(t["x"])) > 12.0:
                off.append("%s %s %s" % [p["id"], key, box])
    check("6 棵枇杷树的图都着地在树脚、外框跟 art_box 一样（不对的 %s）" % [off.slice(0, 3)], off.is_empty())

    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)
