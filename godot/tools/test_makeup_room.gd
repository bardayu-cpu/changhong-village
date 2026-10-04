extends SceneTree
## 验收：化妆间单独成一间屋（进屋像进宴会厅，01 H 10/4 派；docs/进屋像进宴会厅-玩家说明-v0.1.md v0.2 第 1 节）。无界面跑整个 main.gd，手机屏 540×960。
##   1 进屋：后厅走廊走进化妆间门口（to_makeup）→ 整屏换成化妆间、站在南门里边；画面上方出「化妆间」，屋名框不压人
##   2 屋里：每件家具跟前都走得到；三条竖过道（衣架和中岛之间、中岛和东边衣架之间、东边衣架和贴墙那列之间）从北到南都 ≥ 2 格宽、一路通
##      （03 报过原来首饰中岛两边只有一格宽）；给 07 留的站点（化妆师 1、2，递东西）都能站
##   3 出屋：南门出去回到后厅走廊化妆间门口外 (1363,790)，站着不弹回去
## 三档（--tier=少/中/多）都要过：先 python3 godot/tools/layout_court/make_makeup_room.py --tier=X 再跑这个
## 用法：Godot --headless --path . --script res://tools/test_makeup_room.gd     最后一行 RESULT PASS 才算过

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

func walk_to(target: Vector2, secs := 25.0) -> void:
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

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.cloud.fake_no_news = true
    m.nickname = "小李"
    m.court_save.local_path = "user://test_makeup_room_court.json"
    m.games_save.local_path = "user://test_makeup_room_games.json"
    m.ensure_canvas("backhall")
    m.ensure_canvas("makeup")
    await m._enter_court()
    m.dialog.visible = false
    var b = m.backhall
    var r = m.areas["makeup"]
    print("档：%s %s" % [r.cfg.get("tier", "?"), r.cfg.get("tier_counts", {})])

    print("1 进屋")
    m._show_canvas("backhall")
    m._goto("backhall")
    b.walking_enabled = true
    b.reset_to(Vector2(1363, 790))
    tick(3)
    await walk_to(b.spot_pos("to_makeup"))
    check("走进化妆间门口整屏换进屋（%s）" % m.state, m.state == "makeup" and m.cv == r and r.visible and not b.visible)
    check("站在南门里边 %s" % r.pos, r.pos == r.arrival_from("backhall") and r.pos.y > 880.0)
    await process_frame
    check("画面上方出屋名「%s」" % m.room_title.text, m.room_title_box.visible and m.room_title.text == "化妆间")
    # 屋名框不压人：玩家自己、屋里的人（新娘、两位化妆师）都不叠（手机 540×960）
    var xf: Transform2D = r.get_viewport().get_canvas_transform()
    var nb: Rect2 = m.room_title_box.get_global_rect()
    var ppl: Dictionary = {"自己": r.pos}
    for nid in r.npc_nodes:
        ppl[nid] = (r.npc_nodes[nid] as Node2D).position
    var cover: Array = []
    for nid in ppl:
        var f: Vector2 = xf * (ppl[nid] as Vector2)
        var hd: Vector2 = xf * ((ppl[nid] as Vector2) - Vector2(0, 84))
        if nb.intersects(Rect2(Vector2(f.x - 20.0, hd.y), Vector2(40.0, f.y - hd.y))):
            cover.append(nid)
    check("屋名框 %s 不压人（盖住的 %s；查了 %d 位）" % [nb, cover, ppl.size()], cover.is_empty() and ppl.size() >= 4)
    await create_timer(m.ROOM_TITLE_SECS + 0.3).timeout
    check("一两秒后屋名收了", not m.room_title_box.visible)
    tick(60)
    check("站着 60 帧不弹回走廊", m.state == "makeup")

    print("2 屋里")
    var far: Array = []
    for it in r.cfg["items"]:
        if not it.has("rect") or str(it["id"]).begins_with("wall_") or str(it["id"]).begins_with("person_") or str(it["id"]).begins_with("mirror_"):
            continue
        var rc: Array = it["rect"]
        var near := false
        for yy in range(int(rc[1]) - 30, int(rc[3]) + 31, 6):
            for xx in range(int(rc[0]) - 30, int(rc[2]) + 31, 6):
                if r._free(Vector2(xx, yy)):
                    var path: Array = r.find_path(r.pos, Vector2(xx, yy))
                    if not path.is_empty() and (path[path.size() - 1] as Vector2).distance_to(Vector2(xx, yy)) < 12.0:
                        near = true
                        break
            if near:
                break
        if not near:
            far.append(it["id"])
    check("每件家具跟前都走得到（走不到的 %s）" % [far], far.is_empty())
    var lanes := {"衣架和中岛之间": [132.0, 184.0], "中岛和东边衣架之间": [268.0, 320.0], "东边衣架和贴墙那列之间": [434.0, 492.0]}
    var lane_bad: Array = []
    for nm in lanes:
        var xs: Array = lanes[nm]
        for y in range(260, 830, 12):
            var row_ok := 0
            for x in range(int(xs[0]), int(xs[1]) + 1, 12):
                if r._free(Vector2(x, y)):
                    row_ok += 1
            if row_ok < 2:
                lane_bad.append("%s y %d 只有 %d 格" % [nm, y, row_ok])
                break
    check("三条竖过道从北到南都 ≥ 2 格宽（不够的 %s）" % [lane_bad], lane_bad.is_empty())
    var st_bad: Array = []
    var st_ids: Array = []
    for s in r.cfg.get("stand_points", []):
        var p := Vector2(float(s["x"]), float(s["y"]))
        st_ids.append(str(s["id"]))
        # 10/4 02 F 搬人以后化妆师 1、2 就站在自己那个点上（她们自己挡着），这种算对；别的点要空着能站
        var taken := false
        for nid in r.npc_nodes:
            taken = taken or (r.npc_nodes[nid] as Node2D).position.distance_to(p) < 2.0
        if not taken and (r.nearest_free(p) == Vector2.ZERO or r.nearest_free(p).distance_to(p) > 20.0):
            st_bad.append(str(s["id"]))
    var want_ids := ["makeup_artist_1", "makeup_artist_2", "handoff", "stand_mk_closet", "stand_mk_gown"]
    check("站点（化妆师 1、2、递东西，化妆助理走一圈的两个）都在、都能站或者正站着她（不行的 %s）" % [st_bad], st_bad.is_empty() and st_ids == want_ids)

    print("3 出屋")
    await walk_to(r.spot_pos("to_backhall"))
    check("南门出去回到后厅走廊化妆间门口外 %s" % b.pos, m.state == "backhall" and b.pos == Vector2(1363, 790))
    tick(60)
    check("站着 60 帧不弹回化妆间", m.state == "backhall")

    DirAccess.remove_absolute("user://test_makeup_room_court.json")
    DirAccess.remove_absolute("user://test_makeup_room_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
