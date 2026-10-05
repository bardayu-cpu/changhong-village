extends SceneTree
## 第 66 版湖边西半边接图，03 自己重测（01 G 10/4 派，不改游戏代码；不看 02 的 test_lake_west，另起量法）：
##   1 方向：西门（南墙 x 768）跟东门（x 2304）左右对称（两个 x 加起来 = 画布宽）；西门去果园、东门去后花园；果园去湖边的口在北边、
##     过去站西门里边，反过来果园北口里边；从西门到果园再回来、从东门到后花园再回来，一趟一回都走通
##   2 摇杆走（不是点地面寻路）：从西门里边一口气走到码头尽头（船夫跟前）、半岛亭子前沿、湖尽头小石台、西边长凳站点、两个钓鱼位旁、东边长凳站点、东头亭子前沿、东门；
##     再从东门走回西门；卡住 2 秒算失败
##   3 东西接缝（x 1500～1572）：y 800～1020 每隔 12 像素一行，从 x 1400 直着往东推摇杆走到 x 1700、再走回来：每行要么全走通，要么被家具挡住（量出挡在哪）；
##     最宽的那条石板路（y 835～860）整条必须通
##   4 两张长凳：走进去出「坐下」、点了坐在凳子上朝湖、再点站回站点；坐着的时候按钮变「起来」
##   5 船夫：点他走到跟前开对话框，两句话照 boatman_1.dialogue 一字不差，说完收、能走；再点一次还能开
## 用法：Godot --headless --path . --script res://tools/test_lake_west_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
const SAVE := "user://test_lakecheck_court.json"

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(250.0).timeout.connect(func():
        print("RESULT FAIL 250 秒没跑完")
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

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func settle() -> void:
    for i in 60:
        if not m.switching:
            break
        await process_frame

func go_canvas(k: String) -> void:
    m.switching = false
    m._show_canvas(k)
    m._goto(k)
    m.cv.walking_enabled = true
    m.cv.stick = Vector2.ZERO
    m.cv.path.clear()

## 摇杆照寻路拐点一步步走（同 test_lake_chain 的走法）：卡住 2 秒算失败；切了画布也算（走进口子了）
func stick_walk(c, target: Vector2) -> Dictionary:
    var path: Array = c.find_path(c.pos, target)
    if path.is_empty():
        return {"ok": false, "err": "寻路没路"}
    c.path.clear()
    var wi := 0
    var best := INF
    var noprog := 0.0
    var total := 0.0
    while wi < path.size():
        var wp: Vector2 = path[wi]
        var d: Vector2 = wp - c.pos
        if d.length() < 3.0:
            wi += 1
            best = INF
            noprog = 0.0
            continue
        c.stick = d.normalized()
        tick(1)
        total += DT
        if m.cv != c:
            c.stick = Vector2.ZERO
            return {"ok": true, "secs": total, "left": true}
        var nd: float = (wp - c.pos).length()
        if nd < best - 0.5:
            best = nd
            noprog = 0.0
        else:
            noprog += DT
        if noprog >= 2.0 or total > 200.0:
            c.stick = Vector2.ZERO
            return {"ok": false, "err": "卡住", "at": c.pos, "wp": wp}
    c.stick = Vector2.ZERO
    return {"ok": true, "secs": total}

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    var f := FileAccess.open(SAVE, FileAccess.WRITE)
    f.store_string(JSON.stringify({"welcomed": true, "signed_in": true}))
    f.close()
    m.court_save.local_path = SAVE
    m.court_save.load_local()
    m.games_save.local_path = "user://test_lakecheck_games.json"
    m.cloud.fake_no_news = true
    m.nickname = "小李"
    m.ensure_canvas("lake")
    m.ensure_canvas("orchard")
    m.ensure_canvas("garden")
    await m._enter_court()
    m.dialog.visible = false
    var k = m.lake
    var o = m.orchard
    var g = m._canvas_by("garden")
    var W := float(k.cfg["size"][0])

    print("1 方向")
    var west: Vector2 = k.points["to_orchard"]["pos"]
    var east: Vector2 = k.points["to_garden"]["pos"]
    check("西门 %s 跟东门 %s 左右对称（x 加起来 %.0f = 画布宽 %.0f）、都开在南墙" % [str(west), str(east), west.x + east.x, W], absf(west.x + east.x - W) < 1.0 and absf(west.y - east.y) < 1.0 and west.y > 1040.0)
    check("西门去果园、东门去后花园", str(k.points["to_orchard"]["to"]) == "orchard" and str(k.points["to_garden"]["to"]) == "garden")
    var olake: Vector2 = o.points["to_lake"]["pos"]
    var osz := Vector2(float(o.cfg["size"][0]), float(o.cfg["size"][1]))
    check("果园去湖边的口 %s 在果园北边（y %.0f < 画布高的 40%%）" % [str(olake), olake.y], olake.y < osz.y * 0.4)
    # 西门 → 果园 → 回
    go_canvas("lake")
    k.reset_to(k.arrival_at("to_orchard"))
    tick(3)
    var r1 := stick_walk(k, west)
    await settle()
    check("从西门里边走进西门，到了果园（%s）、站在果园北口里边（%s，离口 %.0f）" % [m.state, str(o.pos), o.pos.distance_to(olake)], m.state == "orchard" and o.pos.distance_to(olake) > 30.0 and o.pos.distance_to(olake) < 140.0 and o._free(o.pos))
    tick(60)
    check("站 60 帧不弹回去", m.state == "orchard")
    var r2 := stick_walk(o, olake)
    await settle()
    check("从果园北口走回湖边，站在西门里边（%s）" % str(k.pos), m.state == "lake" and k.pos.distance_to(west) > 36.0 and k.pos.distance_to(west) < 140.0)
    tick(60)
    check("站 60 帧不弹回去", m.state == "lake")
    # 东门 → 后花园 → 回
    k.reset_to(k.arrival_at("to_garden"))
    tick(3)
    var r3 := stick_walk(k, east)
    await settle()
    var gl: Vector2 = g.points["to_lake"]["pos"]
    check("东门去后花园（%s）、站在后花园北口里边（离口 %.0f）" % [m.state, g.pos.distance_to(gl)], m.state == "garden" and g.pos.distance_to(gl) > 30.0 and g.pos.distance_to(gl) < 140.0)
    tick(60)
    var r4 := stick_walk(g, gl)
    await settle()
    check("后花园北口走回湖边，站在东门里边", m.state == "lake" and k.pos.distance_to(east) > 30.0 and k.pos.distance_to(east) < 140.0)

    print("2 摇杆走：西门 → 各处 → 东门 → 回西门")
    var fishers: Array = []
    for n in k.cfg["npcs"]:
        if str(n["id"]).begins_with("fisher"):
            fishers.append([str(n["id"]), k.nearest_free(Vector2(float(n["x"]), float(n["y"])) + Vector2(0, 30))])
    var bm: Vector2 = k.talker_approach("boatman_1")
    var legs := [["码头尽头（船夫跟前）", bm], ["半岛亭子前沿", k.spot_pos("pavilion_w")], ["湖尽头小石台", k.spot_pos("lake_end")],
        ["西边长凳站点", k.benches["bench_w"]["stand"]]]
    for fs in fishers:
        legs.append(["钓鱼位 " + str(fs[0]), fs[1]])
    legs.append(["东边长凳站点", k.benches["bench"]["stand"]])
    legs.append(["东头亭子前沿", k.spot_pos("pavilion")])
    var bad_legs: Array = []
    var total := 0.0
    for lg in legs:
        go_canvas("lake")
        k.reset_to(k.arrival_at("to_orchard"))
        tick(3)
        var t: Vector2 = lg[1]
        var r := stick_walk(k, t)
        var d: float = k.pos.distance_to(t)
        total += float(r.get("secs", 0.0))
        # 再从那儿走回西门里边
        var rb := stick_walk(k, k.arrival_at("to_orchard"))
        var db: float = k.pos.distance_to(k.arrival_at("to_orchard"))
        print("    %s %s：去 %s（%.1f 秒，离 %.0f），回 %s（离 %.0f）" % [lg[0], str(t), "通" if r["ok"] else str(r), float(r.get("secs", 0.0)), d, "通" if rb["ok"] else str(rb), db])
        if not (r["ok"] and d < 16.0 and rb["ok"] and db < 16.0):
            bad_legs.append(str(lg[0]))
    check("%d 处都从西门走得到、走得回（走不通：%s）" % [legs.size(), str(bad_legs)], bad_legs.is_empty())
    go_canvas("lake")
    k.reset_to(k.arrival_at("to_orchard"))
    tick(3)
    var rw := stick_walk(k, east)
    await settle()
    var full_ok: bool = m.state == "garden"
    check("从西门里边一口气走到东门、切到后花园（%.1f 秒）" % float(rw.get("secs", 0.0)), rw["ok"] and full_ok)
    go_canvas("lake")
    k.reset_to(k.arrival_at("to_garden"))
    tick(3)
    var rw2 := stick_walk(k, west)
    await settle()
    check("从东门里边一口气走回西门、切到果园（%.1f 秒）" % float(rw2.get("secs", 0.0)), rw2["ok"] and m.state == "orchard")

    print("3 东西接缝")
    go_canvas("lake")
    var seam_fail: Array = []
    var other_block: Array = []
    var rows_total := 0
    var rows_pass := 0
    for yy in range(800, 1021, 12):
        var yv := float(yy) + 6.0
        var start := Vector2(1400.0, yv)
        if not k._free(start) or not k._free(Vector2(1700.0, yv)):
            continue
        rows_total += 1
        var pass_both := true
        var stopped := Vector2.ZERO
        for dirv in [1.0, -1.0]:
            k.reset_to(Vector2(1400.0 if dirv > 0 else 1700.0, yv))
            tick(2)
            k.stick = Vector2(dirv, 0)
            var want: float = 1700.0 if dirv > 0 else 1400.0
            for i in int(8.0 / DT):
                tick(1)
                if (dirv > 0 and k.pos.x >= want - 2.0) or (dirv < 0 and k.pos.x <= want + 2.0):
                    break
            k.stick = Vector2.ZERO
            if absf(k.pos.x - want) > 3.0:
                pass_both = false
                stopped = k.pos
        if pass_both:
            rows_pass += 1
        elif stopped.x >= 1500.0 and stopped.x <= 1572.0:
            seam_fail.append("y %d 被挡在接缝上 %s" % [yy, str(stopped)])
        else:
            other_block.append("y %d 挡在 %s" % [yy, str(stopped)])
    print("    接缝处每 12 像素一行，两头都能站的 %d 行里直着走通的 %d 行；被挡在接缝（x 1500～1572）上的：%s；被灌木、石灯挡在别处的：%s" % [rows_total, rows_pass, str(seam_fail), str(other_block)])
    var road_ok := true
    for yy in [822.0, 834.0, 846.0]:
        k.reset_to(Vector2(1400.0, yy))
        tick(2)
        k.stick = Vector2(1, 0)
        for i in int(8.0 / DT):
            tick(1)
            if k.pos.x >= 1698.0:
                break
        k.stick = Vector2.ZERO
        if k.pos.x < 1698.0:
            road_ok = false
    check("石板路（y 822、834、846）从 x 1400 直着推到 x 1700 整条通（接缝 x 1536 没有断）", road_ok)
    check("没有一行被挡在接缝（x 1500～1572）上（量了 %d 行，%d 行通，%d 行被别处的灌木、石灯挡着）" % [rows_total, rows_pass, other_block.size()], seam_fail.is_empty() and rows_total >= 10)

    print("4 两张长凳")
    var ui = m.lake_ui
    for bid in ["bench_w", "bench"]:
        var bn: Dictionary = k.benches[bid]
        go_canvas("lake")
        k.reset_to(k.arrival_at("to_orchard"))
        tick(3)
        var rr := stick_walk(k, k.spot_pos(bid))
        tick(3)
        var shown: String = ui.act_btn.text
        check("%s：走到凳子旁出「坐下」按钮（%s）" % [bid, shown], ui.act_btn.visible and shown == "坐下" and k.bench_id == bid)
        ui._on_act()
        tick(50)
        check("%s：坐在凳子上 %s（该 %s）、朝湖（%s）、按钮变「起来」（%s）" % [bid, str(k.pos), str(bn["seat"]), k.face, ui.act_btn.text], k.seated and k.pos == bn["seat"] and k.face == "up" and ui.act_btn.text != "坐下")
        ui._on_act()
        tick(50)
        check("%s：起来站回 %s（该 %s）、按钮变回「坐下」" % [bid, str(k.pos), str(bn["stand"])], not k.seated and k.pos == bn["stand"] and ui.act_btn.text == "坐下")

    print("5 船夫")
    var want_lines: Array = []
    for ln in FileAccess.get_file_as_string("res://assets/lake/dialogue/boatman_1.dialogue").split("\n"):
        if ln.begins_with("船夫: "):
            want_lines.append(ln.substr(4))
    for round_i in 2:
        go_canvas("lake")
        k.reset_to(k.arrival_at("to_orchard"))
        tick(3)
        var head: Vector2 = k.talkers["boatman_1"]["head"]
        k.tap(k.get_viewport().get_canvas_transform() * (head + Vector2(0, 30)))
        for i in 2400:
            tick(1)
            if m.lounge_ui.talk_box.visible:
                break
        for i in 30:
            await process_frame
            if m.lounge_ui.line_raw != "":
                break
        var seen: Array = []
        for i in 8:
            if not m.lounge_ui.talk_box.visible:
                break
            seen.append(str(m.lounge_ui.line_raw))
            m.lounge_ui.next_line()
            for j in 12:
                await process_frame
        # 导出包里 .dialogue 原文件读不到（包里只有导入好的资源）：那种情况只要求说了两句、都有字
        var same: bool = (seen == want_lines) if not want_lines.is_empty() else (seen.size() == 2 and str(seen[0]) != "" and str(seen[1]) != "")
        check("第 %d 次点船夫：说了 %s，跟台词文件 %s 一字不差，名牌「%s」，说完收、能走" % [round_i + 1, str(seen), str(want_lines), m.lounge_ui.name_label.text], same and not m.lounge_ui.talk_box.visible and k.walking_enabled)

    DirAccess.remove_absolute(SAVE)
    DirAccess.remove_absolute("user://test_lakecheck_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
