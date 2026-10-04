extends SceneTree
## 验收：55 桌大厅灰盒（01 D 9/29 派：不等 GPT 的图，照摆位底图 v3.2 的摆位表做进游戏）。和第 44 版厅并存，调试开关切：
## 0 第 52 版起默认就是 55 桌厅，本机开关文件旧的「0」照默认走、「44」还认；1 切过去：主桌 + T1～T54 共 55 张、画布宽 1536（长跟着摆位表，10/2 起排法 C 2091）、没横幅 LED、桌下不铺地毯、每桌 NPC 9～10；
## 2 550 把椅子都走得到、东侧门走得到；3 镜头跟人、手指拖着看、拖到边上停；
## 4 第一次进厅镜头从大门滑到自己那桌、人站在桌边；以后进厅直接站自己桌边；5 从后厅回来站东侧门里边；
## 6 认桌：自己那桌一直挂牌、走近哪桌亮哪桌（牌上只写桌号和游戏名）、其余不挂；
## 7 故事卡：没故事的桌不出卡，有故事的出「这桌的故事」、卡上不列谁坐；7b 主桌普通 10 座：8 位家里人、1、2 号留给阿鱼和 Toretto、走近能聊聊（阿鱼 9/29 出阁宴）；
## 8 假服务端：回 55 张（主桌 MAIN 带 main）、主桌换不进去、桌号椅子号不对拒；
## 9 席上功能在 55 桌厅里都能用：坐下、换桌、看人、敬酒、翻簿子、主桌悄悄话、添礼金、添菜、菜单册；
## 10 切回第 44 版一切照旧，第三档「照效果图」也还能切
## 用法：Godot --headless --path . --script res://tools/test_hall_big.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const LayeredHall = preload("res://scripts/layered_hall.gd")

var m
var started := false
var ok := true

func _initialize() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))   # 别带着上回的开关
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

func frames(n: int) -> void:
    for i in n:
        await process_frame

## 连连看（T1）、川菜消消乐（T3）、小菜合大菜（T5）各开一次：外壳在、换了皮（GPT 边框、顶栏、金币 v2）、开局有棋盘，关上
func _try_games() -> bool:
    var all_ok := true
    for tid in _one_table_per_game():
        var g: Dictionary = load("res://scripts/games/game_config.gd").game_for_table(tid)
        # 04 v7 新 1：干杯插图正在放的时候开游戏，插图要先收掉，不盖在游戏上
        m._play_toast(0, 1, "测试插图")
        await frames(1)
        var had_toast: bool = is_instance_valid(m.toast_scene)
        m._open_game(tid)
        await frames(2)
        var gh = m.game_host
        var toast_gone: bool = not is_instance_valid(m.toast_scene)
        # 玩着的时候来的插图排队，不放
        m._play_toast(0, 1, "玩着来的插图")
        await frames(1)
        var queued: bool = not is_instance_valid(m.toast_scene) and m.toast_queue.size() >= 1
        var ok1: bool = is_instance_valid(gh) and gh.skin and gh.get_node_or_null("skin_frame") != null \
            and gh.panel.get_node_or_null("skin_topbar") != null and gh.panel.get_node_or_null("skin_coin") != null
        if is_instance_valid(gh):
            gh._start()
            await frames(3)
            ok1 = ok1 and gh.game != null and is_instance_valid(gh.game) and gh.game.skin
            gh._close()
            await frames(2)
        var replayed: bool = is_instance_valid(m.toast_scene)   # 关了游戏接着放排着的那张
        if is_instance_valid(m.toast_scene):
            m.toast_scene.queue_free()
            m.toast_scene = null
        m.toast_queue.clear()
        ok1 = ok1 and had_toast and toast_gone and queued and replayed
        print("    %s %s：%s（插图 开游戏前在放 %s、开游戏收掉 %s、玩着来的排队 %s、关了接着放 %s）" % [tid, g.get("id", ""), "好" if ok1 else "不行", had_toast, toast_gone, queued, replayed])
        all_ok = all_ok and ok1
    return all_ok

## 三个游戏各挑一张桌：第 44 版厅是 T1、T3、T5；55 桌厅按今天的分法，每个游戏挑排在最前的那张
func _one_table_per_game() -> Array:
    var Cfg = load("res://scripts/games/game_config.gd")
    if Cfg.daily.is_empty():
        return ["T1", "T3", "T5"]
    var out: Array = []
    for gid in ["lianliankan", "match3", "g2048"]:
        for t in m.hall.cfg["tables"]:
            if str(Cfg.daily.get(str(t["id"]), "")) == gid:
                out.append(str(t["id"]))
                break
    return out

## 这桌的 NPC：坐着的宾客、让座后正在走的、站在桌边的
func _npc_at(h, tid: String) -> Dictionary:
    var out := {"sit": [], "walk": [], "stay": []}
    for g in h.life.guests:
        if g.table == tid:
            out["sit"].append(g.key)
    for w in h.life.waiters:
        if w.kind == "reseat" and w.table == tid:
            out["walk" if w.state == "walk" else "stay"].append(w)
    return out

func _occ_image(h, id: String) -> String:
    for o in h.cfg["occluders"]:
        if str(o["id"]) == id:
            return str(o["image"])
    return ""

## 站到某张桌某把椅子跟前（和 test_banquet_menu 一样的站法），点「坐这儿」
func sit(h, tid: String, no: int) -> void:
    var t: Dictionary = h._table_cfg(tid)
    var c: Vector2 = h.chair_world(t, no)
    h.reset_to(h._stand_spot(c, h._seat_center(t)))
    await frames(1)
    m.near_seat_info = {"table_id": tid, "chair_no": no}
    m.sit_target = {"table_id": tid, "chair_no": no}
    m.sit_confirming = true
    m._on_sit_pressed()
    await create_timer(0.4).timeout

## 站到某张桌的桌边（占地椭圆外面一点、能走的格子上），让厅里扫一遍「走近了哪桌」
func stand_near(h, tid: String) -> void:
    var t: Dictionary = h._table_cfg(tid)
    var c: Vector2i = h._nearest_free(h._cell_of(Vector2(float(t["x"]), float(t["y"]) + float(t["ry"]) + 20.0)))
    h.reset_to(h._cell_pos(c))
    h._scan_chairs(1.0)
    await frames(1)

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true

    print("0 第 52 版起默认就是 55 桌大厅（阿鱼 10/1 定）")
    check("assets/hall.json 默认开", m.hall55_on())
    check("一打开搭的就是 55 桌厅：%d 张桌" % m.hall.cfg["tables"].size(), m.hall.big and m.hall.cfg["tables"].size() == 55)
    check_flag_default()

    print("1 切到 55 桌大厅灰盒")
    await m._enter_banquet()
    await create_timer(0.5).timeout
    await m._set_hall55(true)
    await create_timer(0.5).timeout
    var h = m.hall
    var tabs: Array = h.cfg["tables"]
    # 厅多长跟着摆位表走（10/2 起排法 C，2091；不写死），这里只看宽 1536、比北边、南边两张背景（各 1024）加起来长
    check("是 55 桌大厅：%d 张桌、画布 %s" % [tabs.size(), h.cfg["size"]], h.big and tabs.size() == 55
        and int(h.cfg["size"][0]) == 1536 and int(h.cfg["size"][1]) >= 2048)
    check("还在宴会厅", m.state == "banquet" and m.cv == h)
    var ids: Array = []
    for t in tabs:
        ids.append(str(t["id"]))
    var want: Array = ["MAIN"]
    for i in range(1, 55):
        want.append("T%d" % i)
    check("桌号：主桌 MAIN + T1～T54（主桌排第一个、带 main）", ids == want and bool(tabs[0].get("main", false)))
    var mt: Dictionary = h._table_cfg("MAIN")
    var t1: Dictionary = h._table_cfg("T1")
    var t2: Dictionary = h._table_cfg("T2")
    # 排法 C（阿鱼 10/2）：主桌在第 1 排红毯西边第一张（这一排西边别的位让给礼物堆）；T1、T2 也在第 1 排（东边，离红毯近的先编号）
    # 打乱的几档（SUQI55_MESS）一排不再一条直线：「也在第 1 排」算前后差不到半排（60）
    var row0_west_closer := false
    for t in tabs:
        if float(t["y"]) == float(mt["y"]) and float(t["x"]) < 768.0 and float(t["x"]) > float(mt["x"]):
            row0_west_closer = true
    var first_row := true
    for t in tabs:
        if float(t["y"]) < float(mt["y"]):
            first_row = false
    check("主桌 %s 在第 1 排红毯西边第一张；T1 %s、T2 %s 也在第 1 排" % [Vector2(mt["x"], mt["y"]), Vector2(t1["x"], t1["y"]), Vector2(t2["x"], t2["y"])],
        first_row and float(mt["x"]) < 768.0 and not row0_west_closer and absf(float(t1["y"]) - float(mt["y"])) < 60.0 and absf(float(t2["y"]) - float(mt["y"])) < 60.0)
    check("没有横幅和 LED 屏（阿鱼 9/28）", h.signs == null)
    var rugs := 0
    for s in h.life.get_children():
        if s is Sprite2D and (s as Sprite2D).texture != null and str((s as Sprite2D).texture.resource_path).contains("amb_rug"):
            rugs += 1
    check("桌下不铺地毯（%d 块）" % rugs, rugs == 0)
    check("NPC 宾客 %d 个（每桌 9～10，主桌是家里人 8 位）" % h.life.guests.size(), h.life.guests.size() >= 54 * 9 + 8 - 10 and h.life.guests.size() <= 54 * 10 + 8)
    check("主桌就是普通 10 座：占地 %s×%s、%d 把椅子" % [mt["rx"], mt["ry"], LayeredHall.seats_of(mt)],
        int(mt["rx"]) == int(t1["rx"]) and int(mt["ry"]) == int(t1["ry"]) and LayeredHall.seats_of(mt) == 10)
    check("服务员 %d 个" % h.life.waiters.size(), h.life.waiters.size() == 6)
    var sa: Dictionary = h._seat_abs(t1)
    var sm: Dictionary = h._seat_abs(mt)
    check("座位圈照 GPT v2 桌子零件里的椅子量：普通桌 %s、主桌 %s" % [sa, sm], not sa.is_empty() and float(sa["rx"]) == 63.0 and float(sa["ry"]) == 50.0
        and float(sm["rx"]) == 75.0 and float(sm["ry"]) == 57.0)
    check("桌子占地照椅子外沿 146×100：T1 %s×%s" % [t1["rx"], t1["ry"]], int(t1["rx"]) == 73 and int(t1["ry"]) == 50)
    check("桌子用 GPT v2 零件：T1 %s、主桌 %s" % [_occ_image(h, "T1"), _occ_image(h, "主桌")],
        _occ_image(h, "T1").ends_with("art_table.png") and _occ_image(h, "主桌").ends_with("art_table_main.png"))
    check("长凳不另画（色块里有），坐的人排在凳面上 %.0f～%.0f y %.0f" % [h.bench_x0, h.bench_x1, h.bench_y], not h.bench_draw and h.bench_x1 > h.bench_x0)
    # 遮挡：桌子色块的落地线就是占地中心；栏杆、大门画在所有人前面
    var bad_foot: Array = []
    for o in h.cfg["occluders"]:
        var nm := str(o["id"])
        var t: Dictionary = h._table_cfg("MAIN" if nm == "主桌" else nm)
        if not t.is_empty() and int(o["foot"]) != int(t["y"]):
            bad_foot.append(nm)
    check("桌子图按落地线排前后（对不上的 %s）" % [bad_foot], bad_foot.is_empty())

    print("2 每把椅子都走得到")
    var bad: Array = []
    for t in tabs:
        for no in range(1, LayeredHall.seats_of(t) + 1):
            var p: Vector2 = h.chair_world(t, no)
            var c: Vector2i = h._nearest_free(h._cell_of(p))
            var d: float = h._cell_pos(c).distance_to(p)
            if d > 80.0 or h.find_path(h.SPAWN, h._cell_pos(c)).is_empty():
                bad.append("%s:%d(%.0f)" % [t["id"], no, d])
    check("走不到的椅子（550 把里）%s" % [bad], bad.is_empty())
    var n_chairs := 0
    for c in h.chairs:
        n_chairs += 1
    check("厅里一共 %d 把椅子（主桌 10 + 54×10）" % n_chairs, n_chairs == 550)
    check("东侧门走得到", not h.find_path(h.SPAWN, h.side_off(20, 0)).is_empty())
    check("主桌悄悄话那块（台阶前）走得到", not h.find_path(h.SPAWN, h.COUPLE_SPOT).is_empty())
    var bench_c: Vector2i = h._nearest_free(h._cell_of(h.bench_pos(0, 1)))
    check("长凳跟前走得到（离凳面 %.0f）" % h._cell_pos(bench_c).distance_to(h.bench_pos(0, 1)),
        h._cell_pos(bench_c).distance_to(h.bench_pos(0, 1)) < 60.0 and not h.find_path(h.SPAWN, h._cell_pos(bench_c)).is_empty())

    print("3 镜头")
    h.reset_to(h.SPAWN)
    await frames(3)
    var vh: float = m.get_viewport().get_visible_rect().size.y / h.cam.zoom.y
    check("在大门口：镜头贴着厅底（中心 y %.0f）" % h.cam.position.y, h.cam.position.y > float(h.cfg["size"][1]) - vh * 0.5 - 30.0)
    var mid: Vector2 = h._cell_pos(h._nearest_free(h._cell_of(Vector2(700, 1500))))
    h.reset_to(mid)
    await frames(3)
    check("人在厅中间：镜头跟到 y %.0f（人 %.0f）" % [h.cam.position.y, mid.y], absf(h.cam.position.y - mid.y) < 5.0)
    h.pan_cam(Vector2(0, 400))     # 手指往下拖：看上面
    await frames(2)
    check("往下拖，镜头往上挪（偏 %.0f）" % h.cam_pan.y, h.cam_pan.y < -100.0)
    h.pan_cam(Vector2(0, 20000))
    await frames(2)
    check("拖到顶就停（镜头中心 y %.0f，不小于半屏 %.0f）" % [h.pos.y + h.cam_pan.y, vh * 0.5], h.pos.y + h.cam_pan.y >= vh * 0.5 - 1.0)
    h.pan_cam(Vector2(-20000, 0))
    var vw: float = m.get_viewport().get_visible_rect().size.x / h.cam.zoom.x
    check("左右拖也停在边上", h.pos.x + h.cam_pan.x <= float(h.cfg["size"][0]) - vw * 0.5 + 1.0)

    print("4 进厅站哪")
    m.cloud.fake_me = {"table_id": "", "chair_no": 0}   # 当第一次来：服务端现分座
    for k in m.cloud.fake_seats:
        m.cloud.fake_seats[k] = (m.cloud.fake_seats[k] as Array).filter(func(s): return s["openid"] != "fake_me")
    m.cloud.fake_arrival_mode = "first"
    m.cloud.fake_no_news = false
    await m._enter_banquet()
    await frames(3)
    check("第一次进厅：先站大门口 %s" % h.pos, h.pos.distance_to(h.SPAWN) < 1.0)
    await create_timer(1.6).timeout   # 门口站 0.8 秒，镜头滑 2.4 秒：滑到一半看一眼
    var chair: Vector2 = h._my_chair_pos()
    var cam_mid: Vector2 = h.cam.position
    check("镜头在路上：%s（人 %s）" % [cam_mid, h.pos], chair != Vector2.ZERO and h.pos.distance_to(chair) < 60.0
        and cam_mid.distance_to(h.pos) > 100.0 and cam_mid.y > h.pos.y)
    await create_timer(2.5).timeout
    check("滑到了：人站自己桌边 %s（椅子 %s，%s），镜头在人身上（差 %.0f）" % [h.pos, chair, h.my_seat, h.cam.position.distance_to(h.pos)],
        h.pos.distance_to(chair) < 60.0 and h._free(h.pos) and h.cam.position.distance_to(h.pos) < 40.0)
    m.cloud.fake_arrival_mode = "card"
    m.cloud.fake_no_news = true
    await m._enter_banquet()
    await create_timer(1.5).timeout
    chair = h._my_chair_pos()
    check("以后进厅：直接站到自己桌边 %s（椅子 %s，差 %.0f）" % [h.pos, chair, h.pos.distance_to(chair)],
        chair != Vector2.ZERO and h.pos.distance_to(chair) < 60.0 and h._free(h.pos))

    print("5 从后厅回来")
    await m._switch_canvas("backhall")
    await create_timer(1.5).timeout
    await m._switch_canvas("banquet")
    await create_timer(1.5).timeout
    check("站在东侧门里边 %s（门 %s）" % [h.pos, h.side_door], h.pos.distance_to(h.side_door) < 90.0 and h._free(h.pos))

    print("6 认桌：自己那桌一直挂牌，走近哪桌亮哪桌")
    var mine := str(h.my_seat.get("table_id", ""))
    check("认桌开着、%d 张桌都有牌（先藏着）" % h.table_signs.size(), h.sign_near and h.table_signs.size() == 55)
    await stand_near(h, "T40")
    var shown: Array = []
    for tid in h.table_signs:
        if h._sign_shown(str(tid)):
            shown.append(tid)
    check("站在 T40 边上：该挂的 %s（自己 %s）" % [shown, mine], shown.size() == 2 and shown.has("T40") and shown.has(mine))
    await frames(2)
    var on_screen: Array = []
    for tid in h.table_signs:
        if (h.table_signs[tid] as Label).visible:
            on_screen.append(tid)
    on_screen.erase(mine)   # 自己那桌一直挂着（这会儿在屏幕上面，看不见）
    check("别的桌没挂牌，只亮 T40：%s" % [on_screen], on_screen == ["T40"])
    check("牌上先写桌号：%s" % (h.table_signs["T40"] as Label).text, (h.table_signs["T40"] as Label).text.begins_with("40 号桌"))
    var s40: Label = h.table_signs["T40"]
    var t40: Dictionary = h._table_cfg("T40")
    var sc40: Vector2 = s40.position + s40.size * 0.5
    check("桌牌挂在桌子下沿（牌子中心 %s，桌心 %s，往下 %.0f），不压桌面" % [sc40, Vector2(t40["x"], t40["y"]), sc40.y - float(t40["y"])],
        absf(sc40.y - float(t40["y"]) - 55.0) < 2.0 and absf(sc40.x - float(t40["x"])) < 2.0 and s40.position.y > float(t40["y"]) + float(t40["ry"]) - 20.0)
    var my_sign: Label = h.table_signs[mine]
    check("自己那桌：%s（只写桌号和游戏名，不写「XX那桌」，宽 %.0f）" % [my_sign.text, my_sign.size.x],
        my_sign.text.begins_with(LayeredHall.table_label(mine)) and not my_sign.text.contains("那桌") and my_sign.size.x < 270.0)   # 原来带「老王那桌」334 宽；v8 起每桌按日期分游戏，最长「54 号桌 · 川菜消消乐」约 262
    await stand_near(h, "T50")
    await frames(2)   # 牌子每帧还要过一遍「在不在屏幕里」，那一遍不能把没走近的桌又亮出来
    check("走到 T50：T40 的牌收了、T50 亮了", not (h.table_signs["T40"] as Label).visible and (h.table_signs["T50"] as Label).visible
        and h._sign_shown(mine))
    await stand_near(h, mine)
    await frames(2)
    check("回到自己那桌：自己的牌亮着", (h.table_signs[mine] as Label).visible)
    check("主桌叫「主桌」", LayeredHall.table_label("MAIN") == "主桌" and LayeredHall.table_label("T12") == "12 号桌")

    print("7 故事卡：没故事的桌不出卡（阿鱼 9/29）")
    check("现在一段故事都没有（assets/table_stories.json）", Main.load_stories(Main.STORIES_PATH).is_empty() and m.stories.is_empty())
    await stand_near(h, "T1")
    m.near_table_id = "T1"
    m._refresh_seat_buttons()
    check("走到 T1 桌边：出翻簿子，不出故事卡按钮", m.book_btn.visible and not m.story_btn.visible)
    m._open_story_card("T1")
    check("硬点也打不开（没故事）", not m.story_open)
    m.stories = {"T1": "这桌是阿鱼的高中同学（测试用的一句）"}
    m._refresh_seat_buttons()
    check("有故事的桌出「这桌的故事」", m.story_btn.visible and m.story_btn.text == "这桌的故事")
    check("按钮单独在底下那排上面，不挤进那排", m.story_btn.offset_bottom <= m.book_btn.offset_top - 8.0
        and m.story_btn.offset_left >= -270.0 and m.story_btn.offset_right <= 270.0)
    m.story_btn.emit_signal("pressed")
    await frames(2)
    check("点开了故事卡，人走不了", m.story_open and is_instance_valid(m.story_card) and not h.walking_enabled)
    var texts: Array = []
    for l in m.story_card.find_children("*", "Label", true, false):
        texts.append((l as Label).text)
    check("卡上只有桌号和故事，不列谁坐（不写座次表）：%s" % [texts], texts == ["1 号桌", "这桌是阿鱼的高中同学（测试用的一句）"])
    m._close_story_card()
    await frames(1)
    check("关上了，人能走", not m.story_open and h.walking_enabled)
    m.stories = {}

    print("7b 主桌：8 位家里人，1、2 号留给阿鱼和 Toretto（出阁宴）")
    var want_fam := ["爸爸", "妈妈", "外公", "外婆", "爷爷", "奶奶", "弟弟", "弟妹"]
    var fam_titles: Array = []
    for k in h.life.family_tags:
        fam_titles.append((h.life.family_tags[k] as Label).text)
    var all_there := true
    for w in want_fam:
        all_there = all_there and fam_titles.has(w)
    check("8 位家里人坐在主桌、各有称呼牌：%s" % [fam_titles], fam_titles.size() == 8 and all_there)
    var fam_on_main := 0
    for g in h.life.guests:
        if g.table == "MAIN":
            fam_on_main += 1
    check("主桌上的 NPC 就是这 8 位（%d），没有随机宾客" % fam_on_main, fam_on_main == 8)
    var cards: Dictionary = h.life.reserved_cards
    var card_txt: Array = []
    for k in ["MAIN:1", "MAIN:2"]:
        if cards.has(k):
            card_txt.append((cards[k] as Label).text)
    var c1pos: Vector2 = h.chair_world(mt, 1)
    check("1、2 号空椅上摆着小红座签 %s" % [card_txt], card_txt == ["阿鱼", "Toretto"]
        and absf((cards["MAIN:1"] as Label).position.x + (cards["MAIN:1"] as Label).size.x * 0.5 - c1pos.x) < 2.0)
    check("1、2 号留给阿鱼、Toretto 本人（没来就空着）", not h.life.npc_taken.has("MAIN:1") and not h.life.npc_taken.has("MAIN:2")
        and h.life.conf["family"]["reserved"] == {"1": "阿鱼", "2": "Toretto"})
    var tag13: Label = h.life.family_tags["MAIN:10"]
    var chair13: Vector2 = h.chair_world(mt, 10)
    check("称呼挂在人头上（外婆，椅子 %s，牌子 %s）" % [chair13, tag13.position], tag13.text == "外婆"
        and absf(tag13.position.x + tag13.size.x * 0.5 - chair13.x) < 2.0 and tag13.position.y < chair13.y - 30.0)
    # 走到外婆那把椅子跟前：不冒「坐这儿」
    h.reset_to(h._cell_pos(h._nearest_free(h._cell_of(chair13 + Vector2(-30, 0)))))
    h._scan_chairs(1.0)
    await frames(1)
    check("走到家里人椅子跟前不冒「坐这儿」（最近的椅子 %s）" % [m.near_seat_info], not str(m.near_seat_info.get("table_id", "")).begins_with("MAIN"))
    # 1、2 号空椅子：别人走到跟前也不冒「坐这儿」（01 D 9/29）；阿鱼、Toretto 本人（mainSeatOk）才冒
    var c1: Vector2 = h.chair_world(mt, 1)
    h.reset_to(h._cell_pos(h._nearest_free(h._cell_of(c1 + Vector2(0, -36)))))
    h._scan_chairs(1.0)
    await frames(1)
    check("别人站在主桌 1 号空椅子跟前：不冒「坐这儿」（%s，mainSeatOk %s）" % [m.near_seat_info, h.main_seat_ok],
        not h.main_seat_ok and not str(m.near_seat_info.get("table_id", "")).begins_with("MAIN"))
    h.main_seat_ok = true   # 当自己是阿鱼本人（服务端 enterHall 回 mainSeatOk: true）
    h._scan_chairs(1.0)
    await frames(1)
    check("阿鱼本人站在那儿：冒 1 号「坐这儿」（%s）" % [m.near_seat_info], str(m.near_seat_info.get("table_id", "")) == "MAIN" and int(m.near_seat_info.get("chair_no", 0)) == 1)
    h.main_seat_ok = false
    h._scan_chairs(1.0)
    await frames(1)
    # 阿鱼本人坐上 1 号：那张座签收掉，2 号的还在
    var card1: Label = h.life.reserved_cards["MAIN:1"]
    h.apply_change("MAIN", 1, "vip_ayu_test")
    await frames(2)
    check("阿鱼本人坐上 1 号：1 号座签收了，2 号还在", not is_instance_valid(card1) and h.life.reserved_cards.has("MAIN:2") and not h.life.reserved_cards.has("MAIN:1"))
    h.stand_up()
    h.seat_taken.erase("MAIN:1")
    # 称呼走近谁亮谁：11 块一起挂会叠成一摞
    h.reset_to(h._cell_pos(h._nearest_free(h._cell_of(chair13 + Vector2(0, -40)))))
    h.life._family_near()
    await frames(2)
    var lit: Array = []
    for k in h.life.family_tags:
        if (h.life.family_tags[k] as Label).visible:
            lit.append((h.life.family_tags[k] as Label).text)
    check("站在外婆跟前：只亮外婆 %s" % [lit], lit == ["外婆"])
    m._refresh_seat_buttons()
    check("外婆的话还是【待补】：底下不冒「和外婆聊聊」（01 E 10/3：开发字样不给玩家看）", not m.chat_btn.visible and m.family_line("外婆", m.main_lines_path) == "")
    var tmp_lines := "user://test_main_table_lines.json"
    var fw := FileAccess.open(tmp_lines, FileAccess.WRITE)
    fw.store_string(JSON.stringify({"lines": {"外婆": "测试：外婆这句"}}))
    fw.close()
    var keep_path: String = m.main_lines_path
    m.main_lines_path = tmp_lines   # 照写好了的样子测（不动文件）
    m._refresh_seat_buttons()
    check("写好了：底下冒「%s」" % m.chat_btn.text, m.chat_btn.visible and m.chat_btn.text == "和外婆聊聊")
    m.chat_btn.emit_signal("pressed")
    await frames(1)
    check("点了说一句：%s：%s" % [m.dialog_who.text, m.said_raw], m.dialog.visible and m.dialog_who.text == "外婆" and m.said_raw == "测试：外婆这句")
    m.main_lines_path = keep_path
    var dad: Vector2 = h.chair_world(mt, 5)
    h.reset_to(h._cell_pos(h._nearest_free(h._cell_of(dad + Vector2(20, 35)))))
    h.life._family_near()
    await frames(2)
    lit.clear()
    for k in h.life.family_tags:
        if (h.life.family_tags[k] as Label).visible:
            lit.append((h.life.family_tags[k] as Label).text)
    check("走到爸爸那边：换成亮爸爸 %s" % [lit], lit == ["爸爸"])
    await stand_near(h, "T20")
    h.life._family_near()
    await frames(2)
    lit.clear()
    for k in h.life.family_tags:
        if (h.life.family_tags[k] as Label).visible:
            lit.append((h.life.family_tags[k] as Label).text)
    check("走远了一个都不挂 %s" % [lit], lit.is_empty())
    m._refresh_seat_buttons()
    check("走远了「聊聊」也收了", not m.chat_btn.visible)
    await m._set_hall55(false)
    await create_timer(0.3).timeout
    m.near_table_id = "T1"
    m._refresh_seat_buttons()
    check("第 44 版厅里没有故事卡按钮", not m.story_btn.visible and m.hall.life.family_tags.is_empty())
    await m._set_hall55(true)
    await create_timer(0.5).timeout
    h = m.hall

    print("8 假服务端")
    var got := {}   # 回话塞进字典（匿名函数改不了外面的局部变量）
    m.cloud.call_fn("enterHall", {}, func(r): got["enter"] = r)
    m.cloud.call_fn("changeSeat", {"tableId": "T55", "chairNo": 1}, func(r): got["t55"] = r)
    m.cloud.call_fn("changeSeat", {"tableId": "T54", "chairNo": 11}, func(r): got["c11"] = r)
    m.cloud.call_fn("changeSeat", {"tableId": "MAIN", "chairNo": 3}, func(r): got["main"] = r)
    m.cloud.call_fn("changeSeat", {"tableId": "MAIN", "chairNo": 11}, func(r): got["m14"] = r)
    await create_timer(1.0).timeout
    var et: Array = got.get("enter", {}).get("data", {}).get("tables", [])
    check("55 桌厅回 mainSeatOk（电脑上的「我」不是本人：%s）" % got.get("enter", {}).get("data", {}).get("mainSeatOk", "没回"),
        got.get("enter", {}).get("data", {}).get("mainSeatOk", null) == false)
    check("回 55 张桌、第一张是主桌", et.size() == 55 and str(et[0]["id"]) == "MAIN" and bool(et[0].get("main", false)))
    check("T55、11 号椅都拒：%s %s" % [got.get("t55", {}).get("reason", ""), got.get("c11", {}).get("reason", "")],
        got.get("t55", {}).get("reason", "") == "bad_request" and got.get("c11", {}).get("reason", "") == "bad_request")
    check("主桌 3 号换不进去：%s；11 号没有这把：%s" % [got.get("main", {}).get("reason", ""), got.get("m14", {}).get("reason", "")],
        got.get("main", {}).get("reason", "") == "main_table_only_family" and got.get("m14", {}).get("reason", "") == "bad_request")

    print("9 席上功能")
    var feat := {}
    await sit(h, "T20", 3)
    feat["坐下"] = str(h.my_seat.get("table_id", "")) == "T20" and int(h.my_seat.get("chair_no", 0)) == 3 and h.seated
    check("坐下：T20 3 号 %s" % h.my_seat, feat["坐下"])
    await sit(h, "T33", 7)
    feat["换桌"] = str(h.my_seat.get("table_id", "")) == "T33" and m.note.text == "坐好了"
    check("换桌：换到 T33 7 号 %s，顶上「%s」" % [h.my_seat, m.note.text], feat["换桌"])
    await sit(h, "MAIN", 3)
    check("换到主桌：不让，顶上「%s」，还坐 T33" % m.note.text, m.note.text == "主桌是阿鱼家里人坐的" and str(h.my_seat.get("table_id", "")) == "T33")
    m._open_person_card("fake_wang")
    feat["看人"] = m.card_open and m.person_card.visible and m.person_card_name.text == "老王"
    check("看人：老王的卡片", feat["看人"])
    m.cloud.fake_toasts_today.clear()
    m._on_toast_pressed()
    await create_timer(0.4).timeout
    feat["敬酒"] = m.cloud.fake_toasts_today.has("fake_wang") and not m.card_open
    check("敬酒：服务端收到敬老王、卡片收了（顶上「%s」）" % m.note.text, feat["敬酒"])
    if is_instance_valid(m.toast_scene):
        m.toast_scene.closing = m.toast_scene.t
    m.toast_queue.clear()
    await create_timer(3.0).timeout   # 等老王举杯那 2.8 秒放完（厅拆掉时它的定时器还在，会报一句「Lambda capture freed」，只调试切厅时有）
    m._open_book_panel("T33")
    await create_timer(0.4).timeout
    feat["翻簿子"] = m.book_open and m.book_table == "T33"
    check("翻簿子：T33 的簿子开了", feat["翻簿子"])
    m._close_book_panel()
    await frames(1)
    h.stand_up()
    h.couple_armed = true
    h.reset_to(h.COUPLE_SPOT + Vector2(0, 30))
    await frames(3)
    feat["主桌悄悄话"] = m.whisper_box.visible
    check("主桌悄悄话：走到台阶前，写悄悄话的框出来", feat["主桌悄悄话"])
    m.games_save.coins = 50
    m._refresh_gift_row()
    var gift0: int = m.games_save.gift_coins
    m._give_gift(10)
    feat["添礼金"] = m.gift_row.visible and m.games_save.gift_coins == gift0 + 10 and m.games_save.coins == 40
    check("添礼金：添 10 金，礼金 %d → %d、手上 %d" % [gift0, m.games_save.gift_coins, m.games_save.coins], feat["添礼金"])
    m.whisper_box.visible = false
    h.walking_enabled = true
    await sit(h, "T33", 7)
    m.games_save.coins = 100
    m.banquet_ui.open_add()
    m.banquet_ui._tap_add("豆腐脑")
    feat["添菜"] = m.games_save.coins == 60 and h.life.ordered_total("T33") >= 1
    check("添菜：扣 40（剩 %d）、T33 记了一单，顶上「%s」" % [m.games_save.coins, m.note.text], feat["添菜"])
    m.banquet_ui.close()
    m.banquet_ui.open_menu()
    feat["菜单册"] = m.banquet_ui.panel_open() and m.banquet_ui.list_box.get_child_count() > 0
    check("菜单册：打开有菜", feat["菜单册"])
    feat["小游戏"] = await _try_games()
    check("三个小游戏在 55 桌厅里都开得了、换了 GPT 外壳", feat["小游戏"])
    m.banquet_ui.close()
    await frames(1)
    var broken: Array = []
    for k in feat:
        if not feat[k]:
            broken.append(k)
    print("  接不上的席上功能：%s" % [broken])

    print("11 v8：每桌一个小游戏（按北京日期）、开席后哪桌都能坐（NPC 让座去空椅或站桌边）")
    var Cfg = load("res://scripts/games/game_config.gd")
    var gcount := {}
    var none: Array = []
    for t in tabs:
        var gid := str(Cfg.game_for_table(str(t["id"])).get("id", ""))
        if gid == "":
            none.append(str(t["id"]))
        gcount[gid] = int(gcount.get(gid, 0)) + 1
    check("54 张普通桌都有游戏、主桌不挂（没有的 %s），三个游戏各 %s 桌" % [none, gcount], none == ["MAIN"] and gcount.size() == 4
        and int(gcount.get("lianliankan", 0)) == 18 and int(gcount.get("match3", 0)) == 18 and int(gcount.get("g2048", 0)) == 18)
    var day0: String = Cfg.daily_day
    check("按北京日期：今天是 %s" % day0, day0 == Cfg.beijing_day(Time.get_unix_time_from_system()))
    # 北京日期的边界：UTC 15:59 是北京 23:59，UTC 16:00 就是北京第二天 0:00
    var u := int(Time.get_unix_time_from_datetime_string("2026-09-30T15:59:00"))
    check("UTC 9/30 15:59 → 北京 %s；16:00 → %s" % [Cfg.beijing_day(u), Cfg.beijing_day(u + 60)],
        Cfg.beijing_day(u) == "2026-09-30" and Cfg.beijing_day(u + 60) == "2026-10-01")
    var ids54: Array = ids.filter(func(x): return x != "MAIN")
    var p1: Dictionary = Cfg.daily_plan(ids54, ["lianliankan", "match3", "g2048"], "2026-09-30")
    var p2: Dictionary = Cfg.daily_plan(ids54, ["lianliankan", "match3", "g2048"], "2026-09-30")
    var p3: Dictionary = Cfg.daily_plan(ids54, ["lianliankan", "match3", "g2048"], "2026-10-01")
    var diff := 0
    for k in p1:
        if p1[k] != p3[k]:
            diff += 1
    check("同一天算两遍一样；换一天 %d 桌不一样；今天进厅分的就是这张" % diff, p1 == p2 and diff >= 20
        and (day0 != "2026-09-30" or Cfg.daily == p1))
    # 9/30 这天的分法写死几张：换了引擎版本、换了手机，算出来也得是这个（种子、洗牌都是自己写的整数算法）
    print("    9/30：T1 %s、T2 %s、T27 %s、T54 %s" % [p1["T1"], p1["T2"], p1["T27"], p1["T54"]])
    var bad_sign: Array = []
    for t in tabs:
        var tid := str(t["id"])
        var l = h.table_signs.get(tid)
        var want_txt := "主桌" if tid == "MAIN" else "%s · %s" % [LayeredHall.table_label(tid), Cfg.title(Cfg.game_for_table(tid))]
        if l == null or not is_instance_valid(l) or (l as Label).text != want_txt:
            bad_sign.append(tid)
    check("桌牌都写「N 号桌 · 游戏名」、主桌只写「主桌」（不对的 %s），如 %s" % [bad_sign, (h.table_signs["T12"] as Label).text], bad_sign.is_empty())
    # 坐下以后底下那颗「玩·XX」按今天这桌分到的游戏
    await sit(h, "T12", 1)
    m._refresh_seat_buttons()
    check("坐 T12：按钮「%s」" % m.play_btn.text, m.play_btn.visible and m.play_btn.text == "玩·" + Cfg.title(Cfg.game_for_table("T12")))
    # 开席：坐到 NPC 宾客坐着的椅子上，它走去这桌别的空椅子坐下
    h.life.relatives.set_force("feast")
    h.life.relatives._apply_mode(true)
    var tid_s := ""
    var key_s := ""
    for tt in ["T40", "T41", "T42", "T43", "T44", "T45", "T46", "T47"]:
        var n: Dictionary = _npc_at(h, tt)
        if n["sit"].size() > 0 and n["sit"].size() < 10 and h.life.free_chair(tt, "") > 0:
            tid_s = tt
            key_s = str(n["sit"][0])
            break
    var n0: int = _npc_at(h, tid_s)["sit"].size()
    var free_no: int = h.life.free_chair(tid_s, key_s)
    await sit(h, tid_s, int(key_s.get_slice(":", 1)))
    var n1: Dictionary = _npc_at(h, tid_s)
    check("开席，坐到 %s（NPC 坐着）：坐上了 %s，那位站起来往 %d 号空椅走（在走 %d 位）" % [key_s, h.my_seat, free_no, n1["walk"].size()],
        str(h.my_seat.get("table_id", "")) == tid_s and int(h.my_seat.get("chair_no", 0)) == int(key_s.get_slice(":", 1))
        and n1["walk"].size() == 1 and n1["walk"][0].key == "%s:%d" % [tid_s, free_no] and h.life.npc_taken.has("%s:%d" % [tid_s, free_no]))
    await create_timer(8.0).timeout
    var n2: Dictionary = _npc_at(h, tid_s)
    check("8 秒后坐下了：这桌坐着的 NPC %d → %d，没人在走、没人出门" % [n0, n2["sit"].size()],
        n2["sit"].size() == n0 and n2["walk"].is_empty() and n2["sit"].has("%s:%d" % [tid_s, free_no]) and not n2["sit"].has(key_s))
    # 坐满的桌（10 位 NPC）：让座的那位站到桌边
    var tid_f := ""
    for t in tabs:
        var tt := str(t["id"])
        if tt != "MAIN" and _npc_at(h, tt)["sit"].size() == 10:
            tid_f = tt
            break
    await sit(h, tid_f, 5)
    await create_timer(6.0).timeout
    var nf: Dictionary = _npc_at(h, tid_f)
    var stand_ok := false
    if nf["stay"].size() == 1:
        var w = nf["stay"][0]
        var tc: Dictionary = h._table_cfg(tid_f)
        stand_ok = h._free(w.pos) and w.pos.distance_to(Vector2(float(tc["x"]), float(tc["y"]))) < float(tc["rx"]) + 90.0
    check("坐满的 %s：坐到 5 号，那位站到桌边（坐着 %d、站着 %d，站的地方能走、贴着桌）" % [tid_f, nf["sit"].size(), nf["stay"].size()],
        str(h.my_seat.get("table_id", "")) == tid_f and nf["sit"].size() == 9 and stand_ok)
    # 亲友那桌：坐到亲友开席的椅子上，亲友换椅子或站桌边（亲友的测试 test_relatives 细测）
    # 亲友开席是从厅里各处走回座位的（排法 C 里 T7 离他们开席前转的地方远，第一位 10 秒左右才坐下）：
    # 等到有一位坐下再测，最多等 30 秒；不在某一刻碰运气
    var rel = null
    for i in 300:
        for r in h.life.relatives.rels:
            if r.table == "T7" and r.chair > 0 and r.state == "sit":
                rel = r
                break
        if rel != null:
            break
        await create_timer(0.1).timeout
    if rel != null:
        var rk: String = "%s:%d" % [rel.table, rel.chair]
        await sit(h, "T7", rel.chair)
        check("开席坐到亲友 %s 的 %s：坐上了，%s %s" % [rel.title, rk, rel.title, ("换到 %d 号" % rel.chair) if rel.chair > 0 else "这桌没空椅，站到桌边"],
            str(h.my_seat.get("table_id", "")) == "T7" and "%s:%d" % [rel.table, rel.chair] != rk)
    else:
        check("T7 有坐着的亲友", false)
    await sit(h, "MAIN", 5)
    check("主桌照旧只给阿鱼、Toretto：顶上「%s」" % m.note.text, m.note.text == "主桌是阿鱼家里人坐的" and str(h.my_seat.get("table_id", "")) == "T7")
    h.life.relatives.set_force("")

    await _signs_v8v9(h)

    print("10 切回第 44 版")
    await m._set_hall55(false)
    await create_timer(0.5).timeout
    check("回到 12 桌厅：%d 张桌" % m.hall.cfg["tables"].size(), not m.hall.big and m.hall.cfg["tables"].size() == 12 and m.hall.signs == null)
    check("假服务端也回 12 张、不带主桌", m.cloud.fake_tables == 12 and m.cloud.fake_table_ids.is_empty())
    check("切回的是第 44 版那套（场景 scene_roman_banquet、贺礼堆在舞台左边地上 (410, 302)）",
        str(m.hall.cfg["scene"]) == "scene_roman_banquet" and m.hall.life._vec(m.hall.life.conf["gifts"]) == Vector2(410, 302))
    check("第 44 版厅不按日期分：1～6 号桌照旧，7 号没有", load("res://scripts/games/game_config.gd").daily.is_empty()
        and str(m.GameCfg.game_for_table("T1").get("id", "")) == "lianliankan" and m.GameCfg.game_for_table("T7").is_empty())
    check("第 44 版厅里三个小游戏照样开得了、换了 GPT 外壳", await _try_games())
    check("第 44 版的座位圈、长凳、桌牌照旧", m.hall.seat_dy == LayeredHall.SEAT_DY and m.hall.seat_rx == LayeredHall.SEAT_RX
        and m.hall.bench_draw and m.hall.bench_y == LayeredHall.BENCH_Y and not m.hall.sign_near and m.hall.table_signs.is_empty())
    await m._set_hall_variant("v11")
    await create_timer(0.5).timeout
    check("第三档还能切：场景 %s、%d 张桌" % [m.hall.cfg["scene"], m.hall.cfg["tables"].size()],
        str(m.hall.cfg["scene"]) == "scene_roman_banquet_v11" and m.hall.cfg["tables"].size() == 12 and not m.hall.big)
    await m._set_hall_variant("")
    await create_timer(0.3).timeout
    check("切回第 44 版", str(m.hall.cfg["scene"]) == "scene_roman_banquet" and m.hall_variant() == "")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)


## 11b（04 v8v9 新 1、新 2）：放在自己的函数里，变量名不跟 run() 里的撞
func _signs_v8v9(h) -> void:
    print("11b 04 v8v9：「坐这儿」出来时这桌牌子一定亮、主桌聊聊出来时「主桌」亮；牌子离屏幕边留 8 像素")
    h.stand_up()
    await frames(1)
    # 找一把：站在它外侧那一步，离椅子在 NEAR_R 以内，但离桌边超过原来亮牌的 60（04 说的「能坐、牌没亮」那一圈）
    var gap_spot := Vector2.ZERO
    var gap_tid := ""
    for tid in ["T30", "T31", "T34", "T35", "T22", "T23"]:
        var tc: Dictionary = h._table_cfg(tid)
        for no in range(1, LayeredHall.seats_of(tc) + 1):
            var cw: Vector2 = h.chair_world(tc, no)
            # 椅子四周一圈圈找（10/2 起桌子后面那几把起身往桌头横着退，不再只顺着「往外退」那一条线找）
            for ang in range(0, 360, 15):
                for rr in range(30, int(LayeredHall.NEAR_R) - 4, 4):
                    var gp: Vector2 = cw + Vector2.from_angle(deg_to_rad(float(ang))) * float(rr)
                    if h._free(gp) and h._table_edge_dist(tc, gp) > 64.0 and _nearest_chair_is(h, gp, cw):
                        gap_spot = gp
                        gap_tid = tid
                        break
                if gap_tid != "":
                    break
            if gap_tid != "":
                break
        if gap_tid != "":
            break
    check("找到「能坐、离桌边超过 60」的站位 %s（%s）" % [gap_spot, gap_tid], gap_tid != "")
    h.reset_to(gap_spot)
    h.cam.reset_smoothing()
    await frames(3)   # 镜头先跟过去（牌子出了屏幕是不挂的）
    h._scan_chairs(1.0)
    h._keep_tags_on_screen()
    await frames(1)
    var gap_sign: Label = h.table_signs.get(gap_tid)
    check("「坐这儿」对着 %s（near_key %s、翻簿子那圈 %s），%s 的牌亮着：%s" % [gap_tid, h.near_key, h.table_near_key, gap_tid, gap_sign.visible],
        h.near_key.begins_with(gap_tid + ":") and h.table_near_key != gap_tid and gap_sign.visible)
    # 主桌：站到外婆（10 号）椅子外侧，「和外婆聊聊」的那一位亮起来，「主桌」牌也亮
    var mtc: Dictionary = h._table_cfg("MAIN")
    var gm: Vector2 = h.chair_world(mtc, 10)
    h.reset_to(h._stand_spot(gm, h._seat_center(mtc)))
    h.cam.reset_smoothing()
    await frames(3)
    h._scan_chairs(1.0)
    h.life._family_near()
    h._keep_tags_on_screen()
    await frames(1)
    var main_sign: Label = h.table_signs.get("MAIN")
    check("站在外婆跟前（亮的是 %s），「主桌」牌亮着：%s" % [h.life.family_lit, main_sign.visible], h.life.family_lit != "" and main_sign.visible and main_sign.text == "主桌")
    # 贴屏幕右边：让自己那桌（一直亮）的牌子本来的位置跨过屏幕右边——人往西站，屏幕右边正好落在牌子中点往右 50，
    # 牌子要往里收，收完右边离屏幕边至少 8 像素
    # 红毯东边最靠红毯那一列（排法改了列的 x 跟着变，不写死），挑一张在 y 1000 往南的
    var east_x := INF
    for t in h.cfg["tables"]:
        if float(t["x"]) > 768.0:
            east_x = minf(east_x, float(t["x"]))
    var east := ""
    for t in h.cfg["tables"]:
        if str(t["id"]) != "MAIN" and float(t["x"]) == east_x and float(t["y"]) > 1000.0:
            east = str(t["id"])
            break
    await sit(h, east, 1)   # 先坐到红毯东边最靠红毯那列的一张，镜头往西挪的时候它的牌子会碰到屏幕右边
    h.stand_up()
    var mine: Label = h.table_signs[str(h.my_seat.get("table_id", ""))]
    var home_mid: float = float(mine.get_meta("home", mine.position.x)) + mine.size.x * 0.5
    var half: float = float(h.get_viewport().get_visible_rect().size.x) * 0.5 / h.cam.zoom.x
    var stand: Vector2 = h._cell_pos(h._nearest_free(h._cell_of(Vector2(home_mid + 50.0 - half, mine.position.y + 40.0))))
    h.reset_to(stand)
    h.cam.reset_smoothing()
    await frames(3)
    h._scan_chairs(1.0)
    h._keep_tags_on_screen()
    await frames(1)
    var vp: Viewport = h.get_viewport()
    var ct: Transform2D = vp.get_canvas_transform()
    var vw := float(vp.get_visible_rect().size.x)
    var worst := INF
    var shown := 0
    for k in h.table_signs:
        var l: Label = h.table_signs[k]
        if not l.visible:
            continue
        shown += 1
        var lx: float = (ct * l.global_position).x
        var rx: float = (ct * (l.global_position + l.size)).x
        worst = minf(worst, minf(lx, vw - rx))
    var mine_r: float = vw - (ct * (mine.global_position + mine.size)).x
    var pulled: bool = absf(mine.position.x - float(mine.get_meta("home", mine.position.x))) > 1.0
    check("坐 %s，自己那桌的牌本来跨出屏幕右边，往里收了（%s），右边离屏幕边 %.1f 像素；亮着的牌 %d 块，离屏幕左右边最近 %.1f（要 ≥ %.0f）" % [east, pulled, mine_r, shown, worst, LayeredHall.TAG_EDGE],
        east != "" and pulled and mine.visible and shown >= 1 and worst >= LayeredHall.TAG_EDGE - 0.6)

## 本机开关文件：第 52 版以前切过第 44 版的手机记的是「0」，照默认走 55 桌；第 52 版起切第 44 版记「44」，还认
func check_flag_default() -> void:
    var path := ProjectSettings.globalize_path(Main.HALL55_FLAG)
    for c in [["0", "55"], ["44", ""], ["v11", "v11" if "v11" in Main.hall_variants() else "55"], ["55", "55"], ["1", "55"]]:
        var f := FileAccess.open(Main.HALL55_FLAG, FileAccess.WRITE)
        f.store_string(c[0])
        f.close()
        check("开关文件写「%s」→ 宴会厅「%s」（实际「%s」）" % [c[0], c[1], m.hall_variant()], m.hall_variant() == c[1])
    # 开关只管记下它的那一版码（01 E 10/2）：版本号对不上、或者是改之前没带版本号的，都照默认 55 桌
    var keep_tag: String = m.build_tag
    m.build_tag = "1002-1334"
    for c in [["44@1002-1334", ""], ["44@0930-2200", "55"], ["44", "55"], ["55@1002-1334", "55"]]:
        var f := FileAccess.open(Main.HALL55_FLAG, FileAccess.WRITE)
        f.store_string(c[0])
        f.close()
        check("这一版 %s：开关文件写「%s」→ 宴会厅「%s」（实际「%s」）" % [m.build_tag, c[0], c[1], m.hall_variant()], m.hall_variant() == c[1])
    m.build_tag = keep_tag
    DirAccess.remove_absolute(path)


## 这个点离得最近的椅子就是 cw（不然「坐这儿」会对着别桌的椅子）
func _nearest_chair_is(h, gp: Vector2, cw: Vector2) -> bool:
    var best := INF
    var best_pos := Vector2.ZERO
    for c in h.chairs:
        var d: float = gp.distance_to(c["pos"])
        if d < best:
            best = d
            best_pos = c["pos"]
    return best_pos.distance_to(cw) < 0.5
