extends SceneTree
## 果园进游戏（orchard01 4754615）的功能测试（01 F 10/3 派，03 写）。不改游戏代码；存档指到临时文件，不动这台电脑上的真存档。
##   1 走路：从三个口（进场 (768,1076)、回草坪的口 (768,1136)、收购处点 (980,1122)）摇杆走到每个能站的点（每隔 36 像素取一个）、四个交互点、四位农夫旁边；孤岛、被圈掉的角落
##   2 有果没果：14 块地（8 垄 + 6 树）各自计时——错开收（每块隔 7 秒）、在好几个时刻逐块对「该不该熟」；没熟（含青果那段）是没果那张；收一种只动那一种
##   3 换图不跳：每块地「有果」「没果」两张——位置、偏移、大小、排前后的线一样，差出来的像素只是果子（颜色是草莓红、枇杷黄）
##   4 画的框和挡人的框：37 件 art_box 对游戏里铺的图一样；排前后的线（图的着地线）= 挡人占地的下沿；能站的格子里有没有落在「画出来的东西的地面范围里」的（人走进图里）
## 用法：Godot --headless --path . --script res://tools/test_orchard_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const Ent = preload("res://scripts/entrance.gd")
const DT := 1.0 / 60.0
const STUCK_SECS := 2.0
const MAX_LEG := 120.0

var m
var started := false
var ok := true
var o

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(560.0).timeout.connect(func():
        print("RESULT FAIL 560 秒没跑完（卡住了）")
        quit(1))

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func reenter() -> void:
    if m.state != "orchard":
        m._show_canvas("orchard")
        m._goto("orchard")
    o.walking_enabled = true
    o.stick = Vector2.ZERO

func walk(target: Vector2) -> Dictionary:
    reenter()
    var path: Array = o.find_path(o.pos, target)
    if path.is_empty():
        return {"ok": false, "err": "寻路没路"}
    o.path.clear()
    var wi := 0
    var best := INF
    var noprog := 0.0
    var total := 0.0
    while wi < path.size():
        var wp: Vector2 = path[wi]
        var d: Vector2 = wp - o.pos
        if d.length() < 3.0:
            wi += 1
            best = INF
            noprog = 0.0
            continue
        o.stick = d.normalized()
        o._process(DT)
        total += DT
        if m.state != "orchard":
            o.stick = Vector2.ZERO
            return {"ok": true, "secs": total, "exit_fired": true}
        var nd: float = (wp - o.pos).length()
        if nd < best - 0.5:
            best = nd
            noprog = 0.0
        else:
            noprog += DT
        if noprog >= STUCK_SECS or total > MAX_LEG:
            o.stick = Vector2.ZERO
            return {"ok": false, "err": "卡住", "at": o.pos, "wp": wp, "secs": total}
    o.stick = Vector2.ZERO
    return {"ok": true, "secs": total}

func cell_free(i: int, j: int) -> bool:
    return i >= 0 and j >= 0 and i < o.cols and j < o.rows and o.walk[j * o.cols + i] == 1

func showing(p: Dictionary) -> String:
    var r: bool = (p["ripe"] as Node2D).visible
    var b: bool = (p["bare"] as Node2D).visible
    if r and not b:
        return "有果"
    if b and not r:
        return "没果"
    return "乱（有果 %s 没果 %s）" % [str(r), str(b)]

func is_fruit(c: Color, kind: String) -> bool:
    if c.a8 == 0:
        return false
    var r := c.r8
    var g := c.g8
    var bl := c.b8
    if kind == "strawberry":
        return r > 140 and g < 100 and bl < 110
    return r > 190 and g > 120 and g < 215 and bl < 110

func load_img(path: String) -> Image:
    var img := (load(path) as Texture2D).get_image()
    if img.is_compressed():
        img.decompress()
    img.convert(Image.FORMAT_RGBA8)
    return img

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.orchard_save.local_path = "user://test_orchard_check.json"
    m.orchard_save.plots = {}
    m.orchard_save.basket = {}
    m.games_save.local_path = "user://test_orchard_check_games.json"
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.ensure_canvas("orchard")
    m._show_canvas("orchard")
    m._goto("orchard")
    o = m.orchard
    o.save = m.orchard_save
    o.farm["sell_mode"] = "manual"
    o.walking_enabled = true
    var t_start := Time.get_ticks_msec()
    var T0 := 1_789_876_800.0

    # ---------- 1 走路 ----------
    print("1 走路")
    var starts := {"进场 (768,1076)": Vector2(768, 1076), "回草坪的口 (768,1136)": Vector2(768, 1136), "收购处点 (980,1122)": Vector2(980, 1122)}
    var targets: Array = []
    var free_n := 0
    for j in o.rows:
        for i in o.cols:
            if cell_free(i, j):
                free_n += 1
                var cp := Vector2((i + 0.5) * o.cell, (j + 0.5) * o.cell)
                if int(cp.x) % 36 < 12 and int(cp.y) % 36 < 12:
                    targets.append(cp)
    # 孤岛、被圈掉的角落：在走路范围里、没被任何占地挡、却不能站的格子
    var polys: Array = []
    for poly in o.cfg["walk"]:
        var pts := PackedVector2Array()
        for v in poly:
            pts.append(Vector2(float(v[0]), float(v[1])))
        polys.append(pts)
    var pockets: Array = []
    for j in o.rows:
        for i in o.cols:
            var cp := Vector2((i + 0.5) * o.cell, (j + 0.5) * o.cell)
            var inside := false
            for pts in polys:
                if Geometry2D.is_point_in_polygon(cp, pts):
                    inside = true
            if inside and not cell_free(i, j) and not Ent._blocked(cp.x, cp.y, o.obstacles, Ent.CLEAR):
                pockets.append(cp)
    print("    能站的格子 %d 个（每格 %d 像素）；走路范围里没被占地挡、却被圈掉不能站的 %d 格 %s" % [free_n, int(o.cell), pockets.size(), str(pockets.slice(0, 6))])
    check("没有被圈掉的角落", pockets.is_empty())
    var bad := 0
    var n_walk := 0
    var worst := 0.0
    for sk in starts:
        for t in targets:
            reenter()
            o.reset_to(starts[sk])
            var r := walk(t)
            n_walk += 1
            worst = maxf(worst, float(r.get("secs", 0.0)))
            if not (r["ok"] and ((o.pos - t).length() <= 14.0 or r.get("exit_fired", false))):
                bad += 1
                if bad <= 10:
                    print("    不通：%s → %s %s 站在 %s" % [sk, str(t), str(r), str(o.pos)])
    print("    三个口 × %d 个点 = %d 趟，最长一趟 %.1f 秒" % [targets.size(), n_walk, worst])
    check("三个口走到每个能站的点（不卡住、到得了）", bad == 0)
    var bad2 := 0
    for id in o.points:
        var pt: Vector2 = o.points[id]["pos"]
        for sk in starts:
            reenter()
            o.reset_to(starts[sk])
            var r := walk(pt)
            var near: bool = (o.pos - pt).length() <= float(o.points[id]["r"]) or r.get("exit_fired", false)
            if not (r["ok"] and near):
                bad2 += 1
                print("    交互点不通：%s → %s %s" % [sk, id, str(r)])
    check("四个交互点从三个口都走得到（进到半径里）", bad2 == 0)
    var bad3 := 0
    for n in o.cfg["npcs"]:
        var at := Vector2(float(n["x"]), float(n["y"]))
        var best := Vector2.ZERO
        var bd := INF
        for j in o.rows:
            for i in o.cols:
                if cell_free(i, j):
                    var cp := Vector2((i + 0.5) * o.cell, (j + 0.5) * o.cell)
                    var d := cp.distance_to(at)
                    if d < bd:
                        bd = d
                        best = cp
        reenter()
        o.reset_to(Vector2(768, 1076))
        var r := walk(best)
        var arrived: bool = (o.pos - best).length() <= 14.0
        print("    %s 站在 %s：最近能站的格 %s（%.0f 像素）%s" % [n["id"], str(at), str(best), bd, "走到" if (r["ok"] and arrived) else "走不到 " + str(r)])
        if not (r["ok"] and arrived) or bd > 60.0:
            bad3 += 1
    check("四位农夫旁边（60 像素内最近的格子）走得到", bad3 == 0)

    # ---------- 2 有果没果 ----------
    print("2 有果没果：14 块地各自计时")
    var ids: Array = []
    for p in o.plots:
        ids.append(p["id"])
    check("14 块地、都有两张图（%d）" % o.plots.size(), o.plots.size() == 14 and o.plots.all(func(p): return p.has("ripe") and p.has("bare")))
    o.fake_now = T0
    o.save.plots = {}
    o.refresh_fruit()
    check("没收过的地当早就熟了：14 块都是有果", o.plots.all(func(p): return showing(p) == "有果"))
    var grow: float = o.grow_secs()
    var marks := {}
    var bad_state := 0
    for i in ids.size():
        o.fake_now = T0 + i * 7.0
        o.save.mark_plot(ids[i], o.now())
        marks[ids[i]] = o.now()
        o.refresh_fruit()
        for p in o.plots:
            var expect_ripe: bool = (not marks.has(p["id"])) or (o.now() - float(marks[p["id"]]) >= grow)
            var s := showing(p)
            if s != ("有果" if expect_ripe else "没果"):
                bad_state += 1
                print("    不对：时刻 +%.0f 秒 %s 显示 %s，应该 %s" % [o.now() - T0, p["id"], s, "有果" if expect_ripe else "没果"])
    check("错开收：每收一块，只有这块变没果，别的不动（%d 处不对）" % bad_state, bad_state == 0)
    var last_mark: float = T0 + (ids.size() - 1) * 7.0
    var probe_times := [T0 + 100.0, T0 + 150.0, last_mark + grow * 0.49, last_mark + grow * 0.51, T0 + grow - 1.0, T0 + grow, T0 + grow + 6.9, T0 + grow + 7.0, T0 + grow + 20.0, T0 + grow + 7.0 * 13 - 0.1, T0 + grow + 7.0 * 13, T0 + grow + 500.0]
    var bad_t := 0
    for t in probe_times:
        o.fake_now = t
        o.refresh_fruit()
        var ripe_n := 0
        for p in o.plots:
            var expect: bool = (t - float(marks[p["id"]])) >= grow
            if expect:
                ripe_n += 1
            if showing(p) != ("有果" if expect else "没果"):
                bad_t += 1
                print("    不对：+%.1f 秒 %s 显示 %s，应该 %s" % [t - T0, p["id"], showing(p), "有果" if expect else "没果"])
        print("    +%.1f 秒：熟了 %d 块" % [t - T0, ripe_n])
    check("好几个时刻逐块对：没熟（含青果那段）是没果、到点才换有果、各块各的点（%d 处不对）" % bad_t, bad_t == 0)
    # 收：只收熟了的、只动这一种
    o.fake_now = T0 + grow + 7.0 * 3 + 0.5     # 前 4 块（ridge_0～ridge_3）熟了
    o.refresh_fruit()
    var got: int = o.harvest("strawberry")
    check("只收熟了的：这时 4 垄熟了，收到 %d 份" % got, got == 4)
    var after_harvest: bool = true
    for p in o.plots:
        var s := showing(p)
        var idx: int = ids.find(p["id"])
        if p["kind"] == "strawberry":
            if s != "没果":
                after_harvest = false
        else:
            if s != "没果":      # 树都还在 T0 + 8..13 个 7 秒标过，这时没熟
                after_harvest = false
    check("收完：这 4 垄重新计时变没果，别的垄、树没被动", after_harvest)
    o.fake_now += grow - 1.0
    o.refresh_fruit()
    var still_bare := 0
    for p in o.plots:
        if p["id"] in ["ridge_0", "ridge_1", "ridge_2", "ridge_3"] and showing(p) == "没果":
            still_bare += 1
    check("收完差 1 秒不到点：这 4 垄还是没果（%d）" % still_bare, still_bare == 4)
    o.fake_now += 2.0
    o.refresh_fruit()
    var back_n := 0
    for p in o.plots:
        if p["id"] in ["ridge_0", "ridge_1", "ridge_2", "ridge_3"] and showing(p) == "有果":
            back_n += 1
    check("过了点：这 4 垄换回有果（%d）" % back_n, back_n == 4)

    # ---------- 3 换图不跳 ----------
    print("3 换图不跳：有果、没果两张（按各自在画布上的位置叠起来比，每张图是裁到自己不透明的那块，左上角可以差 1～2 像素）")
    var art_of := {}
    for it in o.cfg["items"]:
        if it.has("art_box"):
            art_of[str(it["id"])] = it["art_box"]
    var bad_sil := 0
    var bad_box2 := 0
    var lines: Array = []
    for p in o.plots:
        var a: Sprite2D = p["ripe"]
        var b: Sprite2D = p["bare"]
        var ia := load_img((a.texture as Texture2D).resource_path)
        var ib := load_img((b.texture as Texture2D).resource_path)
        var ta: Vector2i = Vector2i(a.position + a.offset)
        var tb: Vector2i = Vector2i(b.position + b.offset)
        var x0: int = mini(ta.x, tb.x)
        var y0: int = mini(ta.y, tb.y)
        var x1: int = maxi(ta.x + ia.get_width(), tb.x + ib.get_width())
        var y1: int = maxi(ta.y + ia.get_height(), tb.y + ib.get_height())
        var diff_alpha := 0
        var diff_color := 0
        var minx := 99999
        var miny := 99999
        var maxx := -1
        var maxy := -1
        var ra := Rect2i(99999, 99999, 0, 0)
        var bba := [99999, 99999, -1, -1]
        var bbb := [99999, 99999, -1, -1]
        for y in range(y0, y1):
            for x in range(x0, x1):
                var ca := Color(0, 0, 0, 0)
                var cb := Color(0, 0, 0, 0)
                var xa := x - ta.x
                var ya := y - ta.y
                if xa >= 0 and ya >= 0 and xa < ia.get_width() and ya < ia.get_height():
                    ca = ia.get_pixel(xa, ya)
                var xb := x - tb.x
                var yb := y - tb.y
                if xb >= 0 and yb >= 0 and xb < ib.get_width() and yb < ib.get_height():
                    cb = ib.get_pixel(xb, yb)
                if ca.a8 > 0:
                    bba = [mini(bba[0], x), mini(bba[1], y), maxi(bba[2], x), maxi(bba[3], y)]
                if cb.a8 > 0:
                    bbb = [mini(bbb[0], x), mini(bbb[1], y), maxi(bbb[2], x), maxi(bbb[3], y)]
                if ca.a8 != cb.a8:
                    diff_alpha += 1
                elif ca != cb:
                    diff_color += 1
                else:
                    continue
                minx = mini(minx, x)
                miny = mini(miny, y)
                maxx = maxi(maxx, x)
                maxy = maxi(maxy, y)
        var edge_dev := 0
        for k in 4:
            edge_dev = maxi(edge_dev, absi(int(bba[k]) - int(bbb[k])))
        var ab: Array = art_of.get(str(p["id"]), [])
        var in_art: bool = ab.size() == 4 and minx >= int(ab[0]) - 1 and miny >= int(ab[1]) - 1 and maxx <= int(ab[2]) + 1 and maxy <= int(ab[3]) + 1
        lines.append("    %s：叠起来差 %d 个像素（透明度不同 %d）；外形最大偏差 %d 像素；差的范围 (%d,%d)～(%d,%d)，%s画出来的框 %s" % [p["id"], diff_alpha + diff_color, diff_alpha, edge_dev, minx, miny, maxx, maxy, "在" if in_art else "**超出**", str(ab)])
        if diff_alpha > 60 or edge_dev > 2:
            bad_sil += 1
        if not in_art:
            bad_box2 += 1
    for l in lines:
        print(l)
    check("两张图叠起来外形一样（透明度不同 ≤ 60 个像素 = 只有果子凸出来的那点，外形边缘偏差 ≤ 2 像素；%d 块不是）" % bad_sil, bad_sil == 0)
    check("差的像素都在画出来的框里（%d 块超出）" % bad_box2, bad_box2 == 0)

    # ---------- 4 画的框和挡人的框 ----------
    print("4 画的框和挡人的框")
    var n_art := 0
    var bad_box := 0
    var bad_foot := 0
    var rows_out: Array = []
    var in_front: Array = []     # 人站在图的着地线南边（人在前），脚底下却是图的不透明像素：人踩在画出来的东西上
    var behind_n := 0
    var behind_items := {}
    for it in o.cfg["items"]:
        if not it.has("art_box"):
            continue
        n_art += 1
        var ab: Array = it["art_box"]
        var id := str(it["id"])
        var spr: Sprite2D = o.world.get_node_or_null(NodePath("px_%s" % id))
        if spr == null:
            spr = o.world.get_node_or_null(NodePath("px_%s_fruit" % id))
        if spr == null and id.begins_with("scarecrow"):
            spr = o.world.get_node_or_null(NodePath("px_scarecrow"))
        if spr == null:
            rows_out.append("    没找到图：%s" % id)
            continue
        var tl: Vector2 = spr.position + spr.offset
        var br: Vector2 = tl + spr.texture.get_size()
        var dev := [tl.x - float(ab[0]), tl.y - float(ab[1]), br.x - float(ab[2]), br.y - float(ab[3])]
        if dev.any(func(v): return absf(v) > 1.0):
            bad_box += 1
            rows_out.append("    框对不上图：%s art_box %s 图 %s～%s" % [id, str(ab), str(tl), str(br)])
        var foot_block := 0.0
        if it.has("rect"):
            foot_block = float(it["rect"][3])
        elif it.has("y"):
            foot_block = float(it["y"])
        if absf(spr.position.y - foot_block) > 1.0:
            bad_foot += 1
            rows_out.append("    排前后的线跟占地下沿不一样：%s 图着地线 %.0f、占地下沿 %.0f（差 %.0f）" % [id, spr.position.y, foot_block, spr.position.y - foot_block])
        # 能站的格子的中心落在这张图的不透明像素上：人在后（脚在着地线北边）= 脚被图挡住；人在前（着地线南边）= 人踩在图上
        var img := load_img((spr.texture as Texture2D).resource_path)
        for j in o.rows:
            for i in o.cols:
                if not cell_free(i, j):
                    continue
                var cp := Vector2((i + 0.5) * o.cell, (j + 0.5) * o.cell)
                var lx := int(cp.x - tl.x)
                var ly := int(cp.y - tl.y)
                if lx < 0 or ly < 0 or lx >= img.get_width() or ly >= img.get_height():
                    continue
                if img.get_pixel(lx, ly).a8 == 0:
                    continue
                if cp.y > spr.position.y:
                    in_front.append([id, cp])
                else:
                    behind_n += 1
                    behind_items[id] = int(behind_items.get(id, 0)) + 1
    for l in rows_out:
        print(l)
    print("    写了 art_box 的 %d 件；框对不上图 %d 件；排前后的线对不上占地下沿 %d 件" % [n_art, bad_box, bad_foot])
    check("art_box 都跟游戏里铺的图一样（≤1 像素）", bad_box == 0)
    print("    人站在这些件后面时脚被图挡住的格子 %d 个（%d 件，树、摊子、稻草人、篱笆、垄这些后面站人本来就是这样）" % [behind_n, behind_items.size()])
    print("    脚被图挡住的格子按件：%s" % str(behind_items))
    print("    人在图的着地线南边、脚底下却是图的不透明像素的格子：%d 个 %s" % [in_front.size(), str(in_front.slice(0, 8))])
    check("没有人站在图前面（着地线南边）却踩在图的不透明像素上", in_front.is_empty())
    print("  共 %.1f 秒" % ((Time.get_ticks_msec() - t_start) / 1000.0))
    print("RESULT " + ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)
