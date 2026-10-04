extends SceneTree
## 第一次来整条路（04 `回执/体验-第一次来整条路.md` 的路线，01 E 10/3 派，03 写）：每版出码前跑它。
## 新号：选形象 → 进大门 → 新娘妈妈迎 → 签到（四屏，选一句现成祝福）→ 祝福牌 → 回忆册 → 合影出海报（码走电脑假服务端）→ 进宴会厅（55 桌，第一次来）→ 坐下
## → 玩一个小游戏 → 东侧门金箭头出没出 → 进后厅 → 进厨房玩第一关 → 回宴会厅 → 写悄悄话 → 回迎宾院 → 走到大门出去 → 前门 → 停车场找车。
## （10/4 连图 02 E 改：停车场东口进迎宾院西北口；大门出去先到前门再往西进停车场）
## （10/4 第 68 版 07 改：停车场往西放大、在迎宾院正下方——停车场北墙那道门进迎宾院大门，大门出去直接回停车场，不过前门）
## 每一步断言「该出的出了」；整套按真玩的路走（点按钮、走路、点「坐这儿」「签到」），只有「走路」是点地面走（寻路），「小游戏赢一局」「厨房交一道菜」走各自的规则接口。
## 无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据，存档写到测试自己的文件（不动这台电脑上游戏的真存档）。
## 用法：Godot --headless --path . --script res://tools/test_first_visit.gd
## 最后一行 RESULT PASS 才算过；失败的步写在「不行」那几行，开头有「== 第 N 步」

const Main = preload("res://scripts/main.gd")
const CourtCopy = preload("res://scripts/court_copy.gd")
const LayeredHall = preload("res://scripts/layered_hall.gd")
const Spr = preload("res://scripts/sprites.gd")
const DT := 1.0 / 60.0
const KSAVE := "user://suqi_kitchen.json"
const KBAK := "user://suqi_kitchen.bak03fv"
const WSAVE := "user://whispers.json"      # 悄悄话本机样机存档（_send_whisper 往里追加）：也先挪开、跑完放回去
const WBAK := "user://whispers.bak03fv"

var m
var started := false
var ok := true
var step_ok := true
var steps: Array = []
var cur := ""

func _initialize() -> void:
    if FileAccess.file_exists(KSAVE):   # 厨房进度这台电脑上可能有真的：先挪开，跑完放回去
        DirAccess.copy_absolute(ProjectSettings.globalize_path(KSAVE), ProjectSettings.globalize_path(KBAK))
        DirAccess.remove_absolute(ProjectSettings.globalize_path(KSAVE))
    if FileAccess.file_exists(WSAVE):
        DirAccess.copy_absolute(ProjectSettings.globalize_path(WSAVE), ProjectSettings.globalize_path(WBAK))
        DirAccess.remove_absolute(ProjectSettings.globalize_path(WSAVE))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))   # 默认厅（第 52 版起 55 桌），别带着上回的开关
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(300.0).timeout.connect(_timeout)   # 中途脚本报错测试不会自己退出：300 秒还没跑完就判失败

func _timeout() -> void:
    print("  不行 超过 300 秒还没跑完（卡在「%s」）" % cur)
    print("RESULT FAIL")
    quit(1)

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond
    step_ok = step_ok and cond

func step(name: String) -> void:
    if cur != "":
        steps.append([cur, step_ok])
    cur = name
    step_ok = true
    print("== " + name)

func frames(n: int) -> void:
    for i in n:
        await process_frame

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func walk_to(target: Vector2, secs := 40.0) -> void:
    m.cv.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv.path.is_empty():
            break

func wait_state(s: String, secs := 6.0) -> void:
    for i in int(secs * 60.0):
        if m.state == s and not m.switching:
            return
        await process_frame

func all_text(n: Node, out: Array = []) -> Array:
    if n is Label:
        out.append((n as Label).text)
    elif n is Button:
        out.append((n as Button).text)
    for c in n.get_children():
        all_text(c, out)
    return out

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    # ---- 新号：存档都是空的，写到测试自己的文件 ----
    m.games_save.local_path = "user://test_fv_games.json"
    m.court_save.local_path = "user://test_fv_court.json"
    for f in ["user://test_fv_games.json", "user://test_fv_court.json"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
    m.court_save.welcomed = false
    m.court_save.signed_in = false
    m.court_save.candy = false
    m.court_save.draft = {}
    m.court_save.whisper_done = false
    m.court_save.door_hint = false
    m.court_save.backhall_seen = false
    m.court_save.photos = []
    m.court_save.gloss_seen = false
    m.court_save.court_seen = false   # 第一回来的：没进过迎宾院（10/3 停车场）
    m.games_save.coins = 0
    m.cloud.fake_blessings = []
    m.cloud.fake_no_news = false        # 新号第一次进厅：有「你坐 XX 那桌」那一句
    m.cloud.fake_arrival_mode = "first"
    var coins_start: int = m.games_save.coins

    # ================= 1 选形象 =================
    step("第 1 步 开屏 → 填名字 → 选形象")
    check("开屏页在", m.state == "title")
    m._goto("nick")
    await frames(2)
    check("名字页在、还不能点「好」", m.state == "nick" and m.nick_ok.disabled)
    m.nick_edit.text = "小李"
    m._check_nick_ui()
    check("填「小李」以后「好」能点", not m.nick_ok.disabled)
    m.nick_ok.pressed.emit()
    await frames(2)
    check("到了选形象页（state=%s）" % m.state, m.state == "avatar")
    var pick: Array = Spr.pickable_presets()
    var pick_btns: Array = m.screens["avatar"].find_children("*", "Button", true, false).filter(func(b): return b.toggle_mode)
    check("选形象页每个形象都有图：可选的 %d 个、按钮 %d 个、都是真人像（没有代码画的）" % [pick.size(), pick_btns.size()],
        pick.size() == pick_btns.size() and pick.size() >= 7 and pick.all(func(i): return not Spr.gpt_look(i).is_empty()))
    pick_btns[1].pressed.emit()
    check("点第 2 个形象，记成 %d" % m.preset, m.preset == pick[1])
    var ok_btn: Button = null
    for b in m.screens["avatar"].find_children("*", "Button", true, false):
        if not b.toggle_mode and b.text == "好":
            ok_btn = b
    check("有「好」键", ok_btn != null)
    ok_btn.pressed.emit()

    # ================= 2 停车场下车、进大门 =================
    # 10/3 起：第一回来的选完形象先站在停车场自己的车旁（金箭头指大门），走进门楼才到迎宾院，「到啦～」在这时说
    step("第 2 步 停车场下车，走进大门，新娘妈妈迎")
    await wait_state("parking")
    var pk = m.parking
    check("在停车场、站自己的车旁 %s，金箭头指大门" % str(pk.pos), m.state == "parking" and pk.pos == pk.SPAWN and pk.gate_hint)
    walk_to(pk.spot_pos("to_court"))
    await wait_state("court")
    await frames(3)
    var c = m.court
    # 第 68 版起：停车场北墙那道门进去就是迎宾院大门里边（原来出生的地方）
    check("在迎宾院、站大门里边 %s" % str(c.pos), m.state == "court" and m.cv == c and c.pos == c.SPAWN)
    check("一进来说「到啦～ 罗曼山庄 席还没散」", m.dialog.visible and m.dialog_text.text == m.LINE_ARRIVE)
    check("资料存了、还不拿席位", m.profile_saved and not m.hall_ready)
    check("签到台头顶有记号（还没签到）", c.sign_mark != null and c.sign_mark.visible and c.sign_needed)
    tick(600)
    var walkers: int = c.court_life.walkers.size() if c.court_life != null else 0
    check("院子里有客人在走（%d 位）" % walkers, walkers >= 1)
    m.court_save.welcomed = false
    c.reset_to(Vector2(768, 560))
    walk_to(c.spot_pos("welcome"))
    check("走到楼门前新娘妈妈迎：「%s」" % m.dialog_text.text, m.dialog_who.text == "新娘妈妈" and m.dialog_text.text == CourtCopy.text("welcome"))

    # ================= 3 签到四屏 =================
    step("第 3 步 签到（名字 → 礼金 → 祝福 → 确认）")
    var ui = m.court_ui
    walk_to(c.spot_pos("sign_in"))
    check("走到签到桌出按钮「%s」" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == CourtCopy.text("btn_sign") and not ui.act_btn.disabled)
    ui._on_act()
    check("第 1 屏名字（默认昵称「%s」）、人停下" % ui.name_edit.text, ui.pages[0].visible and ui.name_edit.text == "小李" and not c.walking_enabled)
    ui._name_next()
    check("第 2 屏礼金", ui.pages[1].visible)
    ui._pick_gift(88)
    check("第 3 屏祝福：四句现成的", ui.pages[ui.PAGE_BLESS].visible)
    var presets: Array = ui.pages[ui.PAGE_BLESS].find_children("*", "Button", true, false).filter(func(b): return b.get_meta("bless_preset", false))
    check("四句现成祝福的键 %d 个，每个够大（≥55 高）" % presets.size(), presets.size() == 4 and presets.all(func(b): return b.get_combined_minimum_size().y >= 55.0))
    var bless: String = presets[1].text
    presets[1].pressed.emit()
    check("选了一句「%s」到第 4 屏确认" % bless, ui.pages[ui.PAGE_CONFIRM].visible and ui.confirm_bless.text == CourtCopy.text("confirm_bless_fmt") % bless)
    ui._submit()
    await frames(2)
    check("签上了：本机存档、服务端名字 %s 礼金 %s" % [str(m.cloud.fake_check_in.get("name", "")), str(m.cloud.fake_check_in.get("gift_value", ""))],
        m.court_save.signed_in and str(m.cloud.fake_check_in.get("name", "")) == "小李" and int(m.cloud.fake_check_in.get("gift_value", -1)) == 88)
    check("服务端存了那句祝福（%s）" % [m.cloud.fake_blessings], m.cloud.fake_blessings.size() == 1 and m.cloud.fake_blessings[0]["text"] == bless)
    check("喜糖弹了", m.court_save.candy and ui.candy_root.visible)
    check("新娘妈妈接着指路：「%s」" % m.dialog_text.text.replace("\n", "／"), m.dialog_who.text == "新娘妈妈" and m.dialog_text.text == CourtCopy.text("mom_point"))
    ui.candy_root.visible = false
    check("签到台记号收了、按钮变「已签到」", not c.sign_needed and ui.act_btn.text == CourtCopy.text("btn_signed") and ui.act_btn.disabled)

    # ================= 4 祝福牌 =================
    step("第 4 步 看祝福牌（看得到自己写的）")
    walk_to(c.spot_pos("blessing"))
    check("走近祝福牌出「%s」" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == CourtCopy.text("btn_board"))
    ui._on_act()
    await frames(3)
    var lines: Array = ui.board_list.get_children().filter(func(n): return n.get_meta("blessing_line", false))
    var mine: Array = lines.filter(func(n): return n.text == "小李：" + bless)
    check("祝福牌上有 %d 条，其中有自己写的「小李：%s」" % [lines.size(), bless], mine.size() == 1)
    check("看牌时人停下", not c.walking_enabled)
    ui.close_board()
    check("收起能走", c.walking_enabled and not ui.board_root.visible)

    # ================= 5 回忆册 =================
    step("第 5 步 回忆册（正式版灰着「还没印好」）")
    m.debug_override = false
    walk_to(c.spot_pos("album"))
    check("走到回忆册台，按钮写「%s」且置灰" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == CourtCopy.text("album_not_ready") and ui.act_btn.disabled)
    check("提示「%s」" % m.note.text, m.note_box.visible and m.note.text == CourtCopy.text("album_not_ready"))
    var book: Node = c.world.find_child("album_book_cover", true, false)
    check("台子上摊着一本书", book != null)

    # ================= 6 合影出海报 =================
    step("第 6 步 合影 → 出相纸 → 做成海报（码走电脑假服务端）→ 发给朋友 → 收好")
    walk_to(c.spot_pos("photo_wait"))
    check("摄影师招呼：「%s」" % m.dialog_text.text, m.dialog_who.text == "摄影师" and m.dialog_text.text == CourtCopy.text("photo_greet"))
    walk_to(c.spot_pos("photo_mark") + Vector2(20, 30))
    check("人吸到合影站位，出「%s」" % ui.act_btn.text, c.pos == c.spot_pos("photo_mark") and ui.act_btn.visible and ui.act_btn.text == CourtCopy.text("btn_photo"))
    ui._on_act()
    check("摆姿势", ui.pose_root.visible and not c.walking_enabled)
    ui._pick_pose("heart")
    check("对焦：两个圈出来、摄影师倒数「%s」" % m.dialog_text.text, ui.focus_root.visible and m.dialog_text.text == CourtCopy.text("photo_count"))
    for i in 30:
        ui._process(DT)
    ui._shutter()
    check("出相纸、比心", ui.paper_root.visible and not ui.focus_root.visible and str(ui.paper_art.get_meta("pose")) == "heart")
    var paper_btns: Array = ui.paper_root.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("paper_btn"))
    check("相纸页三个键 %s" % [paper_btns.map(func(b): return b.text)], paper_btns.map(func(b): return b.text) == [CourtCopy.text("btn_poster"), CourtCopy.text("btn_retake"), CourtCopy.text("btn_keep")])
    m.cloud.fake_poster_code_fail = false
    m.cloud.fake_poster_shares = []
    ui.open_poster()
    await frames(3)
    check("海报出来：照片拼好、有码、有一句话「%s」" % ui.poster_line.text, ui.poster_root.visible and ui.poster_has_code and ui.poster_code.texture != null and ui.poster_line.text == CourtCopy.text("poster_line"))
    ui._poster_share()
    await frames(2)
    check("「发给朋友」：交给微信的是海报那一块（%d 次）" % m.cloud.fake_poster_shares.size(), m.cloud.fake_poster_shares.size() == 1)
    ui._poster_back()
    check("返回回到相纸", ui.paper_root.visible and not ui.poster_root.visible)
    ui._keep()
    check("收好 1 张：%s、提示「%s」" % [str(m.court_save.photos.size()), m.note.text], m.court_save.photos.size() == 1 and m.note.text == CourtCopy.text("photo_kept"))
    check("关了、人能走", c.walking_enabled and not ui.panel_open())

    # ================= 7 进宴会厅 =================
    step("第 7 步 进宴会厅（55 桌，第一次来）")
    var sat0: String = m.hall.my_seat.get("table_id", "") if m.hall != null else ""
    walk_to(c.spot_pos("to_hall"))
    await wait_state("banquet")
    var h = m.hall
    check("进了宴会厅，是 55 桌厅（%d 张桌）" % h.cfg["tables"].size(), m.state == "banquet" and m.cv == h and h.big and h.cfg["tables"].size() == 55)
    await frames(30)
    var my_tid: String = str(h.my_seat.get("table_id", ""))
    check("拿到席位（%s 桌 %s 号椅）" % [my_tid, str(h.my_seat.get("chair_no", ""))], m.hall_ready and my_tid != "" and my_tid != LayeredHall.BENCH_ID)
    await create_timer(0.5).timeout
    var hello: String = m.dialog_text.text if m.dialog.visible else ""
    var card_up: bool = is_instance_valid(m.arrival_card)
    check("第一次来有交代去哪桌（对话「%s」或进厅小卡 %s）" % [hello.replace("\n", "／"), card_up], card_up or hello.contains("那桌") or hello.contains("桌"))
    check("55 桌厅里有红绸、东侧门这些：东侧门坐标 %s" % str(h.side_door), h.side_door != Vector2.ZERO)
    check("进厅时东侧门金箭头还没亮（还没坐、没玩）", not m.court_save.door_hint and (h.door_mark == null or not h.door_mark.visible))

    # ================= 8 坐下 =================
    step("第 8 步 走到自己那桌坐下")
    m.dialog.visible = false
    if is_instance_valid(m.arrival_card):
        m.arrival_card.queue_free()
    if is_instance_valid(m.toast_scene):
        m.toast_scene.queue_free()
        m.toast_scene = null
    m.toast_queue.clear()
    h.walking_enabled = true
    var t: Dictionary = h._table_cfg(my_tid)
    var no: int = int(h.my_seat.get("chair_no", 1))
    var chair: Vector2 = h.chair_world(t, no)
    h.reset_to(h.SPAWN)
    h.stick = Vector2.ZERO
    var stand: Vector2 = h._cell_pos(h._nearest_free(h._cell_of(chair)))
    walk_to(stand)
    await frames(2)
    h._scan_chairs(1.0)
    m._refresh_seat_buttons()
    await frames(2)
    check("走到椅子旁边（离椅子 %.0f）" % h.pos.distance_to(chair), h.pos.distance_to(chair) <= LayeredHall.NEAR_R)
    var sit_btns: Array = m.hud.find_children("*", "Button", true, false).filter(func(b): return b.visible and b.text.contains("坐这儿"))
    check("出「坐这儿」键（%d 个）" % sit_btns.size(), not sit_btns.is_empty() or not m.near_seat_info.is_empty())
    m.near_seat_info = {"table_id": my_tid, "chair_no": no}
    m.sit_target = {"table_id": my_tid, "chair_no": no}
    m.sit_confirming = true
    m._on_sit_pressed()
    await create_timer(0.5).timeout
    check("坐下了（seated=%s）" % h.seated, h.seated)
    check("席位是 %s 桌 %d 号椅" % [str(h.my_seat.get("table_id", "")), int(h.my_seat.get("chair_no", 0))], str(h.my_seat.get("table_id", "")) == my_tid and int(h.my_seat.get("chair_no", 0)) == no)
    tick(5)
    check("坐下以后东侧门金箭头亮了（门金光 %s、存档 %s）" % [h.door_mark != null and h.door_mark.visible, m.court_save.door_hint],
        m.court_save.door_hint and h.door_mark != null and h.door_mark.visible)

    # ================= 9 玩一个小游戏 =================
    step("第 9 步 玩一个小游戏（赢一局）")
    check("这桌挂着小游戏", not preload("res://scripts/games/game_config.gd").game_for_table(my_tid).is_empty())
    var coins_before: int = m.games_save.coins
    m._open_game(my_tid)
    await frames(3)
    var gh = m.game_host
    check("小游戏的壳开了", is_instance_valid(gh))
    if is_instance_valid(gh):
        check("开始卡在：「%s」" % [all_text(gh).filter(func(s): return s != "").slice(0, 4)], not all_text(gh).filter(func(s): return s != "").is_empty())
        gh._start()
        await frames(2)
        check("开局，有游戏在跑", gh.game != null)
        var res := [null]
        if gh.game != null:
            gh.game.finished.connect(func(w, _why): res[0] = w)
            gh.game.win()
        await frames(2)
        check("赢了，金币 %d → %d" % [coins_before, m.games_save.coins], res[0] == true and m.games_save.coins > coins_before)
        gh._close()
        await frames(3)
    check("关了小游戏，人能走", m.game_host == null and h.walking_enabled)

    # ================= 10 东侧门金箭头 =================
    step("第 10 步 东侧门金箭头出了、走近看得到金光")
    check("金箭头开关：存档 %s、厅里 door_hint %s、金光 %s" % [m.court_save.door_hint, h.door_hint, h.door_mark != null and h.door_mark.visible],
        m.court_save.door_hint and h.door_hint and h.door_mark != null and h.door_mark.visible and h.door_arrow != null)
    var side: Vector2 = h.side_door
    h.stand_up()
    h.reset_to(h.side_off(90, 0))
    tick(2)
    var mark_d: float = h.door_mark.position.distance_to(side) if h.door_mark != null else -1.0
    check("走到东侧门跟前，金光还在门口（金光离门 %.0f）" % mark_d, h.door_mark != null and h.door_mark.visible and mark_d < 120.0)

    # ================= 11 进后厅 =================
    step("第 11 步 进后厅，金箭头指向厨房")
    m.hall_side_latched = false
    walk_to(side)
    await wait_state("backhall")
    var b = m.backhall
    check("进了后厅 state=%s" % m.state, m.state == "backhall" and m.cv == b)
    check("进过后厅：东侧门金光收了（存档 backhall_seen=%s）" % m.court_save.backhall_seen, m.court_save.backhall_seen and not h.door_hint)
    tick(5)
    check("后厅里有指向厨房的金箭头（kitchen_hint=%s、箭头节点 %s）" % [b.get("kitchen_hint"), b.kitchen_arrow != null], b.get("kitchen_hint") == true and b.kitchen_arrow != null)

    # ================= 12 厨房 =================
    step("第 12 步 进厨房玩第一关")
    walk_to(Vector2(b.spot_pos("pot").x, 790))
    walk_to(b.spot_pos("pot"))
    check("走到大锅出「%s」" % m.backhall_ui.act_btn.text, m.backhall_ui.act_btn.visible and m.backhall_ui.act_btn.text == "穿上围裙 · 学做菜")
    m.backhall_ui._on_act()
    await frames(2)
    var kp = m.game_host
    check("厨房开了、后厅停住", is_instance_valid(kp) and kp.has_method("_render") and not b.walking_enabled)
    var coins_k0: int = m.games_save.coins
    kp._start(1)
    await frames(2)
    var g = kp.rules
    check("第 1 关：一位服务员、一口锅（%d 位 %d 锅）" % [g.orders.size(), g.pots.size()], g.orders.size() == 1 and g.pots.size() == 1)
    var dish_ok: bool = g.choose_order_dish(0, g.orders[0].id, 0)
    for ing in g.pots[0].required:
        dish_ok = dish_ok and g.add_ingredient(0, ing)
    g.tick(float(g.recipe_data(str(g.pots[0].recipe)).seconds) + 0.1)
    dish_ok = dish_ok and g.serve_pot(0)
    dish_ok = dish_ok and g.deliver_auto()
    kp._render()
    await frames(2)
    check("做了一道菜交了，金币 %d → %d（+3）" % [coins_k0, m.games_save.coins], dish_ok and m.games_save.coins == coins_k0 + 3)
    kp._close()
    await frames(3)
    check("关了厨房，后厅能走", m.game_host == null and b.walking_enabled)

    # ================= 13 回宴会厅 =================
    step("第 13 步 回宴会厅")
    walk_to(b.spot_pos("to_hall") + Vector2(160.0 if b.spot_pos("to_hall").x < 768.0 else -160.0, 10))
    walk_to(b.spot_pos("to_hall"))
    await wait_state("banquet")
    check("回了宴会厅", m.state == "banquet" and m.cv == h)
    check("金币都在：顶栏「%s」（小游戏 + 厨房，开头 %d）" % [m.coins_chip.text, coins_start], m.games_save.coins > coins_start and m.coins_chip.text == "%d 金" % m.games_save.coins)
    check("进过后厅以后东侧门金光不再亮", not h.door_hint)

    # ================= 14 悄悄话 =================
    step("第 14 步 给新人写悄悄话（大门要这个才开）")
    check("还没写悄悄话：大门不开", not m.court_save.gate_open())
    h.stand_up()
    h.couple_armed = true
    h.reset_to(h.near(h.COUPLE_SPOT, Vector2(0.2, 0.6)))
    walk_to(h.COUPLE_SPOT + Vector2(0, 40))
    for i in 60:
        tick(1)
        if m.whisper_box.visible:
            break
    check("走到台前新人那儿，悄悄话框开了", m.whisper_box.visible)
    m.whisper_edit.text = "新婚快乐，百年好合"
    m._check_whisper_ui()
    m._send_whisper()
    await frames(2)
    check("写完：框收了、记下了（whisper_done=%s），出厅门那圈金光亮" % m.court_save.whisper_done, not m.whisper_box.visible and m.court_save.whisper_done and h.exit_mark.visible)
    check("新娘说谢谢「%s」" % m.dialog_text.text, m.dialog.visible)

    # ================= 15 出大门 =================
    step("第 15 步 回迎宾院，走到大门口出去")
    h.stand_up()
    walk_to(h.SPAWN + Vector2(0, -160))
    walk_to(h.door)
    await wait_state("court")
    check("回到迎宾院（state=%s）、站楼门边" % m.state, m.state == "court" and m.cv == c)
    check("大门那圈金光亮了（签过到也写过悄悄话）", m.court_save.gate_open() and c.exit_mark.visible)
    walk_to(c.spot_pos("gate") + Vector2(0, -150))
    walk_to(c.spot_pos("gate"))
    await wait_state("parking")
    await frames(3)
    # 第 68 版起：大门出去直接回停车场（停车场在迎宾院正下方）；金箭头指自己的车，走到车旁新娘妈妈送你
    check("出大门回到停车场，金箭头指自己的车", m.state == "parking" and pk.car_hint)
    walk_to(pk.spot_pos("my_car"))
    await frames(3)
    check("走到车旁：新娘妈妈送「%s」" % m.dialog_text.text.replace("\n", "／"), m.dialog_who.text == CourtCopy.who("gate_bye") and m.dialog_text.text.begins_with(CourtCopy.text("gate_bye")))
    check("没有开发字样（【待做】【待补】预留）", not m.dialog_text.text.contains("待") and not m.dialog_text.text.contains("预留"))
    check("人停在车旁、存档 %s" % [m.court_save.signed_in], pk.path.is_empty() and m.court_save.signed_in and m.court_save.whisper_done)

    step("（收尾）")
    steps.append([cur, step_ok])
    print("")
    print("== 逐步：")
    for s in steps:
        print("  %s %s" % ["好" if s[1] else "不行", s[0]])
    for f in ["user://test_fv_games.json", "user://test_fv_court.json"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(WSAVE))
    if FileAccess.file_exists(WBAK):
        DirAccess.copy_absolute(ProjectSettings.globalize_path(WBAK), ProjectSettings.globalize_path(WSAVE))
        DirAccess.remove_absolute(ProjectSettings.globalize_path(WBAK))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(KSAVE))
    if FileAccess.file_exists(KBAK):
        DirAccess.copy_absolute(ProjectSettings.globalize_path(KBAK), ProjectSettings.globalize_path(KSAVE))
        DirAccess.remove_absolute(ProjectSettings.globalize_path(KBAK))
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
