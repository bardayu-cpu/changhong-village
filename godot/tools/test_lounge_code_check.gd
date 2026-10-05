extends SceneTree
## 休息间四位代码小人（build57 b8a63dc 第 61 版，02 766e527）的功能测试（01 G 10/4 派，03 写）。不改游戏代码；存档指到临时文件。跟 02 的 test_lounge_people 第 7 段不重复，独立再核：
##   1 四位坐着：画的是代码小人图集（16×2 格、一比一）、放坐姿格（朝向对应的两格呼吸）、脚点对、头顶气泡挂在头上
##   2 跟谁说话谁站起来放说话格（朝下）、说完坐回去放回坐姿
##   3 叔叔起身走一圈：坐够了 → 离座 → 唱片机前站待机 → 电视前站待机 → 走回来 → 坐下；走路四个方向都出现过且放的是该方向的走路格；站着放待机格；
##     他走开时座位还是他的：sit() 不让坐、near_seat() 不指它；一圈 120 秒内走完
##   4 点叠在一起的两个人，算前面那个（脚点靠下的）
##   5 比例：四位代码小人的图集量出来站着、坐着多高多宽，对照 GPT 同一位的宾客图和玩家（人 = 84）
##   6 麻将室西北角：37 件补了 clear 6，绿植 mj_plant_nw、2 号桌北边椅子 mj2_chair_n、茶凳 mj_stand_2 跟前走得到
## 用法：Godot --headless --path . --script res://tools/test_lounge_code_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
const IDS := ["lounge_09", "lounge_10", "lounge_05", "lounge_06"]
const CODES := {"lounge_09": "CODE-GUEST-09", "lounge_10": "CODE-GUEST-10", "lounge_05": "CODE-GUEST-05", "lounge_06": "CODE-GUEST-06"}

var m
var started := false
var ok := true
var b
var life
var ui

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(400.0).timeout.connect(func():
        print("RESULT FAIL 400 秒没跑完")
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

func frames(n: int) -> void:
    for i in n:
        await process_frame

func tick(n: int) -> void:
    for i in n:
        b._process(DT)
        ui.sync()

func reenter() -> void:
    m.switching = false
    if m.state != "backhall":
        m._show_canvas("backhall")
        m._goto("backhall")
    b.walking_enabled = true
    b.stick = Vector2.ZERO
    if ui.is_open():
        ui.hide_all()

func walk(target: Vector2) -> Dictionary:
    var path: Array = b.find_path(b.pos, target)
    if path.is_empty():
        return {"ok": false}
    b.path.clear()
    var wi := 0
    var best := INF
    var noprog := 0.0
    var total := 0.0
    while wi < path.size():
        var wp: Vector2 = path[wi]
        var d: Vector2 = wp - b.pos
        if d.length() < 3.0:
            wi += 1
            best = INF
            noprog = 0.0
            continue
        b.stick = d.normalized()
        tick(1)
        total += DT
        var nd: float = (wp - b.pos).length()
        if nd < best - 0.5:
            best = nd
            noprog = 0.0
        else:
            noprog += DT
        if noprog >= 2.0 or total > 90.0:
            b.stick = Vector2.ZERO
            return {"ok": false}
    b.stick = Vector2.ZERO
    return {"ok": true}

func frame_ok(p: Dictionary, group: String) -> bool:
    var spr: Sprite2D = p.get("spr")
    if spr == null:
        return false
    for v in (p["frames"].get(group, []) as Array):
        if int(v) == spr.frame:     # json 里的数读进来是小数（20.0），跟整数格号比要先转
            return true
    return false

func tap_world(p: Vector2) -> void:
    b.tap(b.get_viewport().get_canvas_transform() * p)

func img_of(path: String) -> Image:
    var img := (load(path) as Texture2D).get_image()
    if img.is_compressed():
        img.decompress()
    img.convert(Image.FORMAT_RGBA8)
    return img

func bbox(img: Image, x0: int, y0: int, w: int, h: int) -> Rect2i:
    var minx := 99999
    var miny := 99999
    var maxx := -1
    var maxy := -1
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            if img.get_pixel(x, y).a8 > 0:
                minx = mini(minx, x)
                miny = mini(miny, y)
                maxx = maxi(maxx, x)
                maxy = maxi(maxy, y)
    if maxx < 0:
        return Rect2i()
    return Rect2i(minx - x0, miny - y0, maxx - minx + 1, maxy - miny + 1)

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_lcode_court.json"
    m.games_save.local_path = "user://test_lcode_games.json"
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    await frames(3)
    b = m.backhall
    life = b.lounge
    ui = m.lounge_ui
    ui.attach(life)
    for id in IDS:
        life.person(id)["wait"] = 1.0e9   # 03 收尾复核：叔叔起身倒计时按游戏时间走，机器忙时准备段被拖长、他先起身了；这里先按住，测坐姿那段（03 复现过，加了就过）
    b.walking_enabled = true
    var door := Vector2(1032, 690)   # 10/4 方案 C：后厅四间整间平移（化妆间 +1195、休息室 +528、麻将室 −144），下面的坐标照平移后的写

    print("1 四位坐着")
    var bad1: Array = []
    for id in IDS:
        var p: Dictionary = life.person(id)
        var spr = p.get("spr")
        var issues: Array = []
        if spr == null:
            bad1.append("%s 没画代码小人" % id)
            continue
        if not (spr.hframes == 16 and spr.vframes == 2 and spr.scale == Vector2.ONE and spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST):
            issues.append("图集 %dx%d 缩放 %s 滤镜 %s" % [spr.hframes, spr.vframes, str(spr.scale), spr.texture_filter])
        if str(spr.texture.resource_path).find(CODES[id]) < 0:
            issues.append("图不是 %s（%s）" % [CODES[id], spr.texture.resource_path])
        if str(p["mode"]) != "sit":
            issues.append("开场不是坐着（%s）" % p["mode"])
        if not frame_ok(p, "sit_" + str(p["face"])):
            issues.append("放的格 %d 不是坐姿格 sit_%s" % [spr.frame, p["face"]])
        if spr.position != (p["foot"] as Vector2) or p["foot"] != p["home"]:
            issues.append("脚点 %s 家 %s 图 %s" % [str(p["foot"]), str(p["home"]), str(spr.position)])
        # 气泡挂头顶。10/4 07 加了「跟别的气泡叠上就往上让（lift）」，所以分两步核（01 H 照 03 的建议定）：
        #   ① 三间屋都没别的气泡时，lift 必须是 0、正好挂在头顶上 4 像素；
        #   ② 旁边那位先冒着一句，再冒这位：x 照旧对着头，往上让的不超过 3 个气泡高
        for lf in b.lives:
            lf.frozen = true
            for oid in lf.bubbles.keys():
                lf._hide_bubble(oid)
        life.show_bubble(id, "好")
        var bub: Node2D = life.bubbles.get(id)
        var head_at: Vector2 = (p["head"] as Vector2) + Vector2(0, -4)
        if bub == null or float(bub.get_meta("lift", -1.0)) != 0.0 or not bub.position.is_equal_approx(head_at):
            issues.append("没别的气泡时没挂在头顶（%s，应在 %s）" % [str(bub.position) if bub != null else "没冒", str(head_at)])
        life._hide_bubble(id)
        var mate: String = {"lounge_09": "lounge_10", "lounge_10": "lounge_09", "lounge_05": "lounge_06", "lounge_06": "lounge_05"}[id]
        life.show_bubble(mate, "一会儿多吃两碗")
        life.show_bubble(id, "一会儿多吃两碗")
        bub = life.bubbles.get(id)
        if bub == null:
            issues.append("旁边有气泡时没冒")
        else:
            var bh: float = life.bubble_rect(bub).size.y
            var up: float = head_at.y - bub.position.y
            if not is_equal_approx(bub.position.x, head_at.x) or up < 0.0 or up > 3.0 * bh:
                issues.append("旁边有气泡时挂歪了（往上让了 %.0f，气泡高 %.0f；x %.0f 头 %.0f）" % [up, bh, bub.position.x, head_at.x])
        life._hide_bubble(id)
        life._hide_bubble(mate)
        for lf in b.lives:
            lf.frozen = false
        # 呼吸：两格轮着放
        var seen := {}
        for i in 240:
            b._process(DT)
            seen[spr.frame] = true
        if seen.size() < 2:
            issues.append("坐着不呼吸（只见到 %s）" % str(seen.keys()))
        if not issues.is_empty():
            bad1.append("%s：%s" % [id, "；".join(issues)])
    for l in bad1:
        print("    ", l)
    check("四位都是代码小人、一比一、坐姿格、脚点在座位前沿、气泡挂头上、会呼吸（%d 位有问题）" % bad1.size(), bad1.is_empty())
    var pos_expect := {"lounge_09": Vector2(1061, 270), "lounge_10": Vector2(1128, 270), "lounge_05": Vector2(932, 418), "lounge_06": Vector2(990, 418)}
    var bad_pos: Array = []
    for id in IDS:
        if (life.person(id)["home"] as Vector2).distance_to(pos_expect[id]) > 2.0:
            bad_pos.append("%s 在 %s，02 回执写 %s" % [id, str(life.person(id)["home"]), str(pos_expect[id])])
    check("四位的位置照 02 回执（方案 C 平移后：奶奶 (1061,270)、爷爷 (1128,270)、叔叔 (932,418)、阿姨 (990,418)）：%s" % str(bad_pos), bad_pos.is_empty())
    var sofa_m: Dictionary = life.seat_by_id("sofa_m")
    reenter()
    b.reset_to(door)
    walk(sofa_m["stand"])
    tick(2)
    life.sit(sofa_m)
    tick(90)
    check("北边沙发中间空着、玩家能坐进去（两头是奶奶爷爷）", b.seated and life.my_seat == "sofa_m")
    b.stand_up()
    tick(60)

    print("2 说话站起来、说完坐回去")
    var bad2: Array = []
    for id in IDS:
        reenter()
        b.reset_to(door)
        var p: Dictionary = life.person(id)
        tap_world((p["head"] as Vector2) + Vector2(0, 20))
        for i in 1800:
            tick(1)
            if ui.talk_box.visible:
                break
        var issues: Array = []
        if not (ui.talk_box.visible and ui.talk_id == id):
            bad2.append("%s 没弹对话框" % id)
            continue
        tick(30)
        if str(p["mode"]) != "talk" or not frame_ok(p, "talk") or str(p["face"]) != "down":
            issues.append("说话时 mode %s 格 %d 朝向 %s" % [p["mode"], p["spr"].frame, p["face"]])
        ui.close_talk()
        tick(60)
        # 叔叔可能已经起身走了（这时说完接着走）
        if id == "lounge_05":
            if str(p["mode"]) not in ["sit", "idle", "walk"]:
                issues.append("叔叔说完 mode %s" % p["mode"])
        else:
            if str(p["mode"]) != "sit" or not frame_ok(p, "sit_" + str(p["face"])) or (p["foot"] as Vector2) != p["home"]:
                issues.append("说完没坐回去（mode %s 脚点 %s）" % [p["mode"], str(p["foot"])])
        if not issues.is_empty():
            bad2.append("%s：%s" % [id, "；".join(issues)])
    for l in bad2:
        print("    ", l)
    check("四位：点他 → 弹框，他站起来放说话格、朝下；说完坐回去放坐姿（%d 位有问题）" % bad2.size(), bad2.is_empty())

    print("3 叔叔起身走一圈")
    reenter()
    b.reset_to(door)
    var u: Dictionary = life.person("lounge_05")
    # 先让大家回到坐着、叔叔马上起身
    for id in IDS:
        life.person(id)["mode"] = "sit"
        life.person(id)["foot"] = life.person(id)["home"]
        life.person(id)["face"] = life.person(id)["seat_face"]
        life.person(id)["legs"] = []
        life.person(id)["path"] = []
    u["wait"] = 0.1
    var faces_walk := {}
    var wrong_walk_cell := 0
    var idle_cells_ok := true
    var idle_seen := 0
    var left_seat_t := -1.0
    var back_t := -1.0
    var max_dist := 0.0
    var seat_refused := true
    var near_offers := false
    var stops: Array = []
    var last_mode := "sit"
    var sit_after := false
    var west_chair: Dictionary = life.seat_by_id("west_chair_w")
    for i in int(150.0 / DT):
        b._process(DT)
        var md := str(u["mode"])
        var fp: Vector2 = u["foot"]
        max_dist = maxf(max_dist, fp.distance_to(u["home"]))
        if md == "walk":
            faces_walk[str(u["face"])] = true
            if not frame_ok(u, str(u["face"])):
                wrong_walk_cell += 1
            if left_seat_t < 0.0:
                left_seat_t = float(i) * DT
        if md == "idle" and left_seat_t >= 0.0 and back_t < 0.0:
            idle_seen += 1
            if not frame_ok(u, "idle") and str(u["face"]) == "down":
                idle_cells_ok = false
            if idle_seen == 1 or (last_mode != "idle"):
                stops.append(fp)
        if md != "sit" and left_seat_t >= 0.0 and back_t < 0.0:
            # 他走开时：sit() 不让坐、near_seat 不指他的座位
            reenter()
            b.pos = Vector2(1000, 780)
            life.sit(west_chair)
            if b.seated:
                seat_refused = false
                b.stand_up()
        if md == "sit" and left_seat_t >= 0.0 and back_t < 0.0 and fp == u["home"]:
            back_t = float(i) * DT
            sit_after = frame_ok(u, "sit_" + str(u["face"]))
            break
        last_mode = md
    print("    起身 %.1f 秒时、走回坐下 %.1f 秒时；最远离座位 %.0f 像素；走路出现过的朝向 %s；站定的地方 %s" % [left_seat_t, back_t, max_dist, str(faces_walk.keys()), str(stops)])
    check("叔叔 150 秒里起身、走一圈、走回来坐下", left_seat_t >= 0.0 and back_t > left_seat_t)
    check("走路四个方向都出现过（%s）" % str(faces_walk.keys()), faces_walk.size() == 4)
    check("走路时放的都是该方向的走路格（放错 %d 帧）" % wrong_walk_cell, wrong_walk_cell == 0)
    check("站定放待机格（朝下）", idle_cells_ok and idle_seen > 0)
    check("站定的地方有两处（唱片机前 (952,312)、电视前 (1144,476) 附近）：%s" % str(stops), stops.size() >= 2 and stops.any(func(s): return s.distance_to(Vector2(952, 312)) < 40.0) and stops.any(func(s): return s.distance_to(Vector2(1144, 476)) < 40.0))
    check("他走开时座位还是他的：sit() 不让玩家坐", seat_refused)
    check("走回来坐下放坐姿格", sit_after)
    check("一圈 120 秒内走完（%.1f 秒）" % (back_t - left_seat_t), back_t > 0.0 and back_t - left_seat_t < 120.0)

    print("4 点叠在一起的两个人，算前面那个")
    reenter()
    b.reset_to(door)
    var a: Dictionary = life.person("lounge_05")
    var c: Dictionary = life.person("lounge_06")
    a["mode"] = "idle"
    a["foot"] = Vector2(c["foot"].x + 8.0, c["foot"].y + 8.0)
    a["legs"] = []
    a["path"] = []
    a["wait"] = 999.0
    life._head(a)
    var hit1: String = life.npc_at(Vector2(c["foot"].x + 4.0, c["foot"].y - 40.0))
    check("叔叔站到阿姨前面（脚点靠下）：点叠着的地方算叔叔（%s）" % hit1, hit1 == "lounge_05")
    a["foot"] = Vector2(c["foot"].x + 8.0, c["foot"].y - 8.0)
    life._head(a)
    var hit2: String = life.npc_at(Vector2(c["foot"].x + 4.0, c["foot"].y - 40.0))
    check("叔叔站到阿姨后面（脚点靠上）：点叠着的地方算阿姨（%s）" % hit2, hit2 == "lounge_06")
    a["foot"] = a["home"]
    a["mode"] = "sit"
    a["face"] = a["seat_face"]
    a["wait"] = 20.0
    life._head(a)

    print("5 比例（人 = 84）")
    var rows: Array = []
    var red := 0
    for id in IDS:
        var code: String = CODES[id]
        var cimg := img_of("res://assets/characters/code/chr_%s.png" % code)
        var stand := bbox(cimg, 0, 0, 64, 84)
        var idle := bbox(cimg, 0 * 64, 84, 64, 84)
        var sitd := bbox(cimg, 20 * 64 % 1024, 84 * (20 / 16), 64, 84)
        var gcode: String = str(life.data["people"][id]["code"])
        var gimg := img_of("res://assets/characters/lm/chr_%s.png" % gcode) if FileAccess.file_exists("res://assets/characters/lm/chr_%s.png" % gcode) else null
        var gh := -1
        if gimg != null:
            gh = bbox(gimg, 0, 0, 64, 84).size.y
        var json = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/code/chr_%s.json" % code))
        var hm: float = float(json.get("height_m", 0.0))
        rows.append("%s（%s）：站着 %d×%d（人=84 的 %.2f）、坐着 %d 高、json height_m %.2f；GPT 同一位 %s 站着 %d 高" % [id, code, stand.size.x, stand.size.y, float(stand.size.y) / 84.0, sitd.size.y, hm, gcode, gh])
        var ratio := float(stand.size.y) / 84.0
        if ratio >= 1.5 or ratio <= 0.5:
            red += 1
    for l in rows:
        print("    ", l)
    check("四位站着高度对「人 = 84」都在 0.5～1.5 倍里（红 %d）" % red, red == 0)

    print("6 麻将室西北角")
    var door_mj: Vector2i = b._cell_of(Vector2(696, 690))
    var reach_ok := {}
    for it in b.cfg["items"]:
        var id := str(it["id"])
        if id in ["mj_plant_nw", "mj2_chair_n", "mj_stand_2"]:
            var r: Array = it["rect"]
            var rc := Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
            var found := false
            for off in [14.0, 24.0]:
                for t in range(0, 9):
                    for cnd in [Vector2(lerpf(rc.position.x, rc.end.x, t / 8.0), rc.position.y - off), Vector2(lerpf(rc.position.x, rc.end.x, t / 8.0), rc.end.y + off), Vector2(rc.position.x - off, lerpf(rc.position.y, rc.end.y, t / 8.0)), Vector2(rc.end.x + off, lerpf(rc.position.y, rc.end.y, t / 8.0))]:
                        if b._free(cnd) and not found:
                            reenter()
                            b.reset_to(Vector2(696, 690))
                            var w := walk(cnd)
                            if w["ok"] and (b.pos - cnd).length() <= 14.0:
                                found = true
            reach_ok[id] = {"clear": it.get("clear", "默认"), "走得到跟前": found}
    print("    %s" % str(reach_ok))
    check("绿植、2 号桌北边椅子、茶凳：clear 都是 6、跟前走得到", reach_ok.size() == 3 and reach_ok.values().all(func(v): return v["走得到跟前"] and int(v["clear"]) == 6))
    var mj_clear := 0
    var mj_total := 0
    for it in b.cfg["items"]:
        if it.has("rect") and Rect2(528, 226, 336, 458).intersects(Rect2(float(it["rect"][0]), float(it["rect"][1]), float(it["rect"][2]) - float(it["rect"][0]), float(it["rect"][3]) - float(it["rect"][1]))) and not str(it["id"]).begins_with("wall_") and not str(it["id"]).begins_with("front_"):
            mj_total += 1
            if int(it.get("clear", 12)) == 6:
                mj_clear += 1
    check("麻将室 %d 件家具里 clear 6 的有 %d 件（应全是）" % [mj_total, mj_clear], mj_clear == mj_total)
    print("RESULT " + ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)
