extends SceneTree
## 验收：化妆间单独成一间屋（进屋像进宴会厅，01 H 10/4 派；docs/进屋像进宴会厅-玩家说明-v0.1.md v0.2 第 1 节）。无界面跑整个 main.gd，手机屏 540×960。
##   1 进屋：后厅走廊走进化妆间门口（to_makeup）→ 整屏换成化妆间、站在南门里边；画面上方出「化妆间」，屋名框不压人
##   2 屋里：每件家具跟前都走得到（GPT 整间版 10/5：角落里 3 件摆件走不到，写在已知清单里，只守「不再多」）；从南门走到北边化妆台、两个站点、换装点都走得通（过道宽度归 test_room01_check 管，
##      那条是按「最宽那条路的最窄处 ≥ 1.5 米」量的）；站点（化妆师 1、2，化妆助理走一圈的两个）都能站
##   （10/5 03 改：布局换成 GPT 整间版——540×960、出生点 (270,844)、站点和家具全换了，原来按旧 C 档写死的坐标、三条竖过道都不存在了）
##   3 出屋：南门出去回到后厅走廊化妆间门口外 (1363,790)，站着不弹回去
## 三档（--tier=少/中/多）都要过：先 python3 godot/tools/layout_court/make_makeup_room.py --tier=X 再跑这个
## 用法：Godot --headless --path . --script res://tools/test_makeup_room.gd     最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
## GPT 整间版（makeup-gpt-1）里走不到跟前的角落摆件：花座 vase_stand_2 夹在梳妆台和花瓶之间、圆墩 pouf_w、单人椅 armchair_e 在屋子南边两个角上（上面坐着静坐的替身），都不是互动的东西；只守「不再多」
const KNOWN_FAR := ["vase_stand_2", "pouf_w", "armchair_e"]

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
    var wall_s: Array = []
    for it0 in r.cfg["items"]:
        if str(it0["id"]).begins_with("wall_s"):
            wall_s.append(it0["rect"])
    var gap_x0 := 0.0
    var gap_x1 := 9999.0
    var wall_y0 := 9999.0
    for rc0 in wall_s:
        wall_y0 = minf(wall_y0, float(rc0[1]))
        if float(rc0[2]) < float(r.cfg["size"][0]) * 0.5:   # 屋子中线（化妆间 1.25 倍 675 宽，不再写死 270）
            gap_x0 = maxf(gap_x0, float(rc0[2]))   # 西边那段南墙的东端
        else:
            gap_x1 = minf(gap_x1, float(rc0[0]))   # 东边那段南墙的西端
    check("站在南门里边 %s（门洞 x %.0f～%.0f、南墙 y %.0f：站在门洞中间、在南墙北边 100 像素以内）" % [r.pos, gap_x0, gap_x1, wall_y0], r.pos == r.arrival_from("backhall") and r.pos.x > gap_x0 and r.pos.x < gap_x1 and r.pos.y < wall_y0 and r.pos.y > wall_y0 - 100.0)
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
        if str(it["id"]).begins_with("nostand_"):
            continue   # 第二轮划的「站进去头肩会被盖住」那几溜：不是家具
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
    var far_new: Array = far.filter(func(x): return not KNOWN_FAR.has(str(x)))
    check("每件家具跟前都走得到（走不到的 %s；已知的 %s 不算，新的 %s）" % [far, KNOWN_FAR, far_new], far_new.is_empty())
    # 走得通：南门 → 新娘跟前（北边化妆台）、两个站点、换装点（A* 路径真走到）
    var reach_bad: Array = []
    var bride_at := Vector2(193, 179)   # 新娘跟前：照布局里新娘的 approach（化妆间 1.25 倍以后不再写死）
    for n0 in r.cfg.get("npcs", []):
        if str(n0.get("id", "")) == "bride" and n0.has("approach"):
            bride_at = Vector2(float(n0["approach"][0]), float(n0["approach"][1]))
    var goals: Array = [["新娘跟前", bride_at], ["换装点", r.points["dress"]["pos"]]]
    for s0 in r.cfg.get("stand_points", []):
        if str(s0["id"]).begins_with("makeup_artist"):
            continue   # 化妆师自己站 / 坐的家，人在那儿占着，不是给玩家走到的点
        goals.append([str(s0["id"]), Vector2(float(s0["x"]), float(s0["y"]))])
    for g in goals:
        var pth: Array = r.find_path(r.pos, g[1])
        if pth.is_empty() or (pth[pth.size() - 1] as Vector2).distance_to(g[1]) > 16.0:
            reach_bad.append(str(g[0]))
    check("从南门走得到新娘跟前、换装点和每个站点（共 %d 处，走不到的 %s）" % [goals.size(), reach_bad], reach_bad.is_empty())
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
    var want_ids := ["makeup_artist_1", "makeup_artist_2", "stand_mk_gown", "stand_mk_red"]
    check("站点（化妆师 1、2，化妆助理走一圈的两个）都在、都能站或者正站着她（不行的 %s）" % [st_bad], st_bad.is_empty() and st_ids == want_ids)

    print("3 出屋")
    await walk_to(r.spot_pos("to_backhall"))
    check("南门出去回到后厅走廊化妆间门口外 %s" % b.pos, m.state == "backhall" and b.pos == Vector2(1363, 790))
    tick(60)
    check("站着 60 帧不弹回化妆间", m.state == "backhall")

    DirAccess.remove_absolute("user://test_makeup_room_court.json")
    DirAccess.remove_absolute("user://test_makeup_room_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
