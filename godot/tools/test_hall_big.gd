extends SceneTree
## 验收：55 桌大厅灰盒（01 D 9/29 派：不等 GPT 的图，照摆位底图 v3.2 的摆位表做进游戏）。和第 44 版厅并存，调试开关切：
## 0 默认还是第 44 版 12 桌厅；1 切过去：主桌 + T1～T54 共 55 张、画布 1536×2691（摆位 v5：家具照 d 的大小）、没横幅 LED、桌下不铺地毯、每桌 NPC 9～10；
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

    print("0 默认还是第 44 版 12 桌厅")
    check("assets/hall.json 默认关", not m.hall55_on())
    check("搭的是 12 桌厅：%d 张桌" % m.hall.cfg["tables"].size(), not m.hall.big and m.hall.cfg["tables"].size() == 12)
    check("12 桌厅的座位圈、长凳还是原来的常数", m.hall.seat_dy == LayeredHall.SEAT_DY and m.hall.bench_x0 == LayeredHall.BENCH_X0
        and m.hall.bench_draw and not m.hall.sign_near)

    print("1 切到 55 桌大厅灰盒")
    await m._enter_banquet()
    await create_timer(0.5).timeout
    await m._set_hall55(true)
    await create_timer(0.5).timeout
    var h = m.hall
    var tabs: Array = h.cfg["tables"]
    check("是 55 桌大厅：%d 张桌、画布 %s" % [tabs.size(), h.cfg["size"]], h.big and tabs.size() == 55
        and int(h.cfg["size"][0]) == 1536 and int(h.cfg["size"][1]) == 2691)
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
    check("主桌 %s、T1 %s、T2 %s 都在第一排，T1、T2 红毯一边一张" % [Vector2(mt["x"], mt["y"]), Vector2(t1["x"], t1["y"]), Vector2(t2["x"], t2["y"])],
        float(t1["y"]) == float(mt["y"]) and float(t2["y"]) == float(mt["y"]) and (float(t1["x"]) - 768.0) * (float(t2["x"]) - 768.0) < 0.0)
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
    check("座位圈照 v5 色块桌（170×112 占地）：普通桌 %s、主桌 %s" % [sa, sm], not sa.is_empty() and float(sa["rx"]) == 70.0 and float(sa["ry"]) == 46.0
        and float(sm["rx"]) == 70.0)
    check("桌子占地放大到 170×112（照 d）：T1 %s×%s" % [t1["rx"], t1["ry"]], int(t1["rx"]) == 85 and int(t1["ry"]) == 56)
    check("桌子先用色块（GPT 重画 170 宽的还没交）：T1 %s、主桌 %s" % [_occ_image(h, "T1"), _occ_image(h, "主桌")],
        _occ_image(h, "T1").contains("/gb_") and _occ_image(h, "主桌").contains("/gb_"))
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
    check("东侧门走得到", not h.find_path(h.SPAWN, h.side_door + Vector2(-20, 0)).is_empty())
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
        my_sign.text.begins_with(LayeredHall.table_label(mine)) and not my_sign.text.contains("那桌") and my_sign.size.x < 240.0)   # 原来带「老王那桌」334 宽
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
    check("底下冒「%s」" % m.chat_btn.text, m.chat_btn.visible and m.chat_btn.text == "和外婆聊聊")
    m.chat_btn.emit_signal("pressed")
    await frames(1)
    check("点了说一句（占位）：%s：%s" % [m.dialog_who.text, m.dialog_text.text], m.dialog.visible and m.dialog_who.text == "外婆" and m.dialog_text.text == "【待补】")
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
    m.banquet_ui.close()
    await frames(1)
    var broken: Array = []
    for k in feat:
        if not feat[k]:
            broken.append(k)
    print("  接不上的席上功能：%s" % [broken])

    print("10 切回第 44 版")
    await m._set_hall55(false)
    await create_timer(0.5).timeout
    check("回到 12 桌厅：%d 张桌" % m.hall.cfg["tables"].size(), not m.hall.big and m.hall.cfg["tables"].size() == 12 and m.hall.signs == null)
    check("假服务端也回 12 张、不带主桌", m.cloud.fake_tables == 12 and m.cloud.fake_table_ids.is_empty())
    check("默认的宴会厅是第 44 版那套（场景 scene_roman_banquet、贺礼堆在舞台左边地上 (410, 302)）",
        str(m.hall.cfg["scene"]) == "scene_roman_banquet" and m.hall.life._vec(m.hall.life.conf["gifts"]) == Vector2(410, 302))
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
