extends SceneTree
## 验收：湖边西半边接图（01 G 10/4 派；样板 godot/回执/样板间-湖边西半边/，01 画、01 G 收下）。无界面跑整个 main.gd。
##   1 布局：西半边换成像素成品（两张图都铺了、西半边的东西都标 on_art）、西门在南墙 x 768 去果园、没有 to_parking / 第 65 版西头尽头那个口
##   2 能走：从西头月亮门里边，真走（点地面那种）到码头船夫跟前、半岛亭子前沿、西边长凳、湖尽头小石台、两个钓鱼位旁边、东半边长凳
##   3 两张长凳都能坐：走进 bench / bench_w 出「坐下」，坐上去在那张凳子上、朝湖，点「起来」站回那张的站点
##   4 码头船夫：点他走到跟前、开对话框（台词待校对），说完收、能走
##   5 西门出去到果园、果园那头回来站在西门里边
## 用法：Godot --headless --path . --script res://tools/test_lake_west.gd     最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0

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

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func walk_to(target: Vector2, secs := 40.0) -> void:
    var c = m.cv
    c.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv != c or c.path.is_empty():
            break
    for i in 60:
        if not m.switching:
            break
        await process_frame

## 真走过去：到了离目标多远
func reach(k, target: Vector2) -> float:
    k.reset_to(k.FROM_ORCHARD)
    tick(2)
    await walk_to(target)
    return k.pos.distance_to(target)

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.cloud.fake_no_news = true
    m.nickname = "小李"
    m.court_save.local_path = "user://test_lake_west_court.json"
    m.games_save.local_path = "user://test_lake_west_games.json"
    m.ensure_canvas("lake")
    m.ensure_canvas("orchard")
    await m._enter_court()
    m.dialog.visible = false
    var k = m.lake
    m._show_canvas("lake")
    m._goto("lake")
    k.walking_enabled = true

    print("1 布局")
    var arts: Array = k.cfg.get("pixel_art", [])
    check("两张像素图都铺了 %s" % [arts], arts.size() == 2 and arts[0].contains("lake_west") and arts[1].contains("lake_east")
        and k.find_child("px_background_lake_west", true, false) != null and k.find_child("px_background_lake_east", true, false) != null)
    var west_gray := 0
    for it in k.cfg["items"]:
        var cx: float = (float(it["rect"][0]) + float(it["rect"][2])) * 0.5 if it.has("rect") else float(it.get("x", it.get("x0", 0)))
        if cx < 1536.0 and not bool(it.get("on_art", false)):
            west_gray += 1
    check("西半边的东西都画在图里了（还画灰盒的 %d 件）" % west_gray, west_gray == 0)
    check("西门在南墙 x 768 去果园 %s" % k.points.get("to_orchard", {}).get("pos", "没有"),
        k.points.has("to_orchard") and k.points["to_orchard"]["pos"] == Vector2(768, 1066) and str(k.points["to_orchard"]["to"]) == "orchard")
    var gone: bool = not k.points.has("to_parking") and not k.cfg.has("from_parking")
    for id in k.points:
        if (k.points[id]["pos"] as Vector2).x < 60.0 and str(k.points[id]["to"]) != "":
            gone = false
    check("没有 to_parking / from_parking、西头尽头那个口也去掉了", gone)
    check("东头月亮门去后花园照旧", k.points.has("to_garden") and str(k.points["to_garden"]["to"]) == "garden")

    print("2 能走（从西门里边真走过去）")
    var bm: Vector2 = k.talker_approach("boatman_1") if k.talkers.has("boatman_1") else Vector2.ZERO
    var fishers: Array = []
    for n in k.cfg["npcs"]:
        if str(n["id"]).begins_with("fisher") and float(n["x"]) < 1536.0:
            fishers.append(k.nearest_free(Vector2(float(n["x"]), float(n["y"])) + Vector2(0, 30)))
    var targets := {"码头船夫跟前": bm, "半岛亭子前沿": k.spot_pos("pavilion_w"), "西边长凳站点": k.benches["bench_w"]["stand"],
        "湖尽头小石台": k.spot_pos("lake_end"), "东半边长凳站点": k.benches["bench"]["stand"]}
    for i in fishers.size():
        targets["钓鱼位 %d 旁边" % (i + 1)] = fishers[i]
    for name in targets:
        var t: Vector2 = targets[name]
        var d: float = await reach(k, t) if t != Vector2.ZERO else 999.0
        check("%s %s：走到离它 %.0f 像素" % [name, t, d], t != Vector2.ZERO and d < 16.0)
    check("两个钓鱼位都找到了（%d）" % fishers.size(), fishers.size() == 2)

    print("3 两张长凳都能坐")
    var ui = m.lake_ui
    for bid in ["bench_w", "bench"]:
        var bn: Dictionary = k.benches[bid]
        k.reset_to(k.FROM_ORCHARD)
        tick(2)
        await walk_to(k.spot_pos(bid))
        tick(2)
        check("%s：走进去出「%s」" % [bid, ui.act_btn.text], ui.act_btn.visible and ui.act_btn.text == "坐下" and k.bench_id == bid)
        ui._on_act()
        tick(40)
        check("%s：坐在那张凳子上 %s、朝湖" % [bid, k.pos], k.seated and k.pos == bn["seat"] and k.face == "up")
        ui._on_act()
        tick(40)
        check("%s：起来站回那张的站点 %s" % [bid, k.pos], not k.seated and k.pos == bn["stand"])

    print("4 码头船夫")
    k.reset_to(k.FROM_ORCHARD)
    tick(2)
    check("船夫挂了对话", k.talkers.has("boatman_1"))
    var head: Vector2 = k.talkers["boatman_1"]["head"] if k.talkers.has("boatman_1") else Vector2.ZERO
    k.tap(k.get_viewport().get_canvas_transform() * (head + Vector2(0, 30)))
    for i in 1800:
        tick(1)
        if m.lounge_ui.talk_box.visible:
            break
    await process_frame
    for i in 30:
        await process_frame
        if m.lounge_ui.line_raw != "":
            break
    check("点船夫走到跟前开对话：「%s」，站在 %s" % [m.lounge_ui.line_raw, k.pos],
        m.lounge_ui.talk_box.visible and m.lounge_ui.name_label.text == "船夫" and m.lounge_ui.line_raw != "" and k.pos.distance_to(bm) < 16.0)
    for i in 6:
        m.lounge_ui.next_line()
        for j in 10:
            await process_frame
        if not m.lounge_ui.talk_box.visible:
            break
    check("说完收了、能走", not m.lounge_ui.talk_box.visible and k.walking_enabled)

    print("5 西门 ↔ 果园")
    k.reset_to(k.FROM_ORCHARD + Vector2(0, -60))
    tick(2)
    await walk_to(k.spot_pos("to_orchard"))
    check("西门出去到了果园（%s）" % m.state, m.state == "orchard")
    var o = m.orchard
    tick(60)
    await walk_to(o.spot_pos("to_lake"))
    check("果园东口回湖边，站在西门里边 %s" % k.pos, m.state == "lake" and k.pos == k.arrival_from("orchard") and k.pos.distance_to(Vector2(768, 1066)) < 80.0)

    DirAccess.remove_absolute("user://test_lake_west_court.json")
    DirAccess.remove_absolute("user://test_lake_west_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
