extends SceneTree
## 验收：罗曼山庄迎宾院（蓝图 3.1，灰盒，01 9/19 派）。无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据。
## 第一段：能走的格子连通、交互点都走得到、随机点地面不踩进占地；刚到一块画布时站在出口里不会来回弹；
##         迎宾院 ↔ 宴会厅来回走，席位、金币这些状态还在；西小径去湖边（9/20 起）、东小径去草坪（9/19 起）
## 第二段：新娘妈妈只迎一次；签到面板名字 → 礼金 → 确认，名字校验、礼金夹上限、断网留草稿、签完一串（爸爸收礼、喜糖、妈妈指路）、
##         重进只显示「已签到」、本机存档；名字被服务端判敏感词退回第一页
## 第三段：回忆册正式版置灰「还没印好」、调试版能打开占位屏并回到原地；摄影师招呼；合影吸到站位、姿势 → 对焦 → 相纸、
##         再拍一张、收好最多 3 张旧的顶掉、算了不留东西
## 第四段：休息区老人一句乐山话（只一个方言词、是二档标了可用的、像素字显示得出）、方言词第一次自动弹普通话、点说话框再看；大门：没写悄悄话不理人、写了没签到新娘妈妈提醒、
##         写了也签了才开（金圈）、走到门口「镇上的路还没修好 下次带你去」人停下、不进结束页；本机存档
## 用法：Godot --headless --path . --script res://tools/test_entrance.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const CourtCopy = preload("res://scripts/court_copy.gd")
const CourtSave = preload("res://scripts/court_save.gd")
const CourtUI = preload("res://scripts/court_ui.gd")
const DT := 1.0 / 60.0
## 《乐山话 v0.2》词表（写法去掉空格）。一档直接用、不解释；二档第一次自动出翻译、点一下出普通话，标了可用的只有阿鱼给的两个。
## 老人那句要第一次弹普通话（蓝图 3.1），所以得用二档可用的词（03 9/19 测出原来用一档词对不上）；语气词「哈」「嘛」到处在用，不算
const TIER1 := ["安逸", "巴适", "好好吃", "要得", "莫得", "啥子", "咋个", "晓得", "巴巴适适", "摆龙门阵", "走赶场", "耍", "巴倒"]
const TIER2_OK := ["楼卜", "翘jio儿"]
const TIER2_ALL := ["楼卜", "翘jio儿", "海椒", "谷子", "茶铺子", "卡卡角角", "警格导", "干狮猴儿", "招财咡", "麻螂咡", "蝻蝻"]

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    m.hall_variant_once = ""   # 这套测的是第 44 版 12 桌厅（第 52 版起默认 55 桌，第 44 版留着）；只这一次，不写本机开关
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

## 手动推几帧：当前画布走路、main 管切画布（不等真的帧，跑得快、结果稳定）
func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

## 走到某点（点地面的走法），最多走 secs 秒；到了或者路走完就停
## 从停车场走回迎宾院（10/3 起大门外是停车场）：走到门楼门洞
func back_to_court() -> void:
    if m.state != "parking":
        return
    var pk = m.parking
    walk_to(pk.spot_pos("to_court") + Vector2(0, 90))
    walk_to(pk.spot_pos("to_court"))
    tick(5)

func walk_to(target: Vector2, secs := 20.0) -> void:
    m.cv.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv.path.is_empty():
            break

func run() -> void:
    # 进厅小卡那一套（有人敬过就先放干杯插图、放完才能走）这里不看，关掉，免得一进厅走路被插图挡住
    m.cloud.fake_no_news = true
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await process_frame
    var c = m.court
    # 小游戏存档、迎宾院存档都写到测试自己的文件，别写进这台电脑上游戏的真存档
    m.games_save.local_path = "user://test_entrance_games.json"
    m.court_save.local_path = "user://test_entrance_court.json"
    m.court_save.welcomed = false
    m.court_save.signed_in = false
    m.court_save.candy = false
    m.court_save.draft = {}

    # 1. 格子：进场点能站；十个有半径的交互点从进场点都走得到
    print("1 迎宾院的格子和交互点")
    var g: Dictionary = c.cfg["walk_grid"]
    check("进场点能站 %s" % str(c.SPAWN), c._free(c.SPAWN))
    check("交互点 11 个（10/2 加了祝福牌）", c.points.size() == 11 and c.points.has("blessing"))
    check("B20 签到台记号：一开始亮着", c.sign_mark != null and c.sign_mark.visible)
    for id in c.points:
        var p: Vector2 = c.points[id]["pos"]
        var path: Array = c.find_path(c.SPAWN, p)
        var end: Vector2 = path[path.size() - 1] if not path.is_empty() else c.SPAWN
        check("%s 走得到（离点 %.1f，半径 %.0f）" % [id, end.distance_to(p), c.points[id]["r"]], end.distance_to(p) < float(c.points[id]["r"]))

    # 2. 随机点 40 个能站的地方：都走得到，一步都不踩进挡住的格子
    print("2 随机点地面")
    var rng := RandomNumberGenerator.new()
    rng.seed = 31
    var tried := 0
    var reach := 0
    var stepped_in := 0
    c.walking_enabled = true
    while tried < 40:
        var t := Vector2(rng.randf_range(0, 1536), rng.randf_range(0, 1024))
        if not c._free(t):
            continue
        tried += 1
        c.reset_to(c.SPAWN)
        c.go_to(t)
        for f in 2400:
            c._process(DT)
            if not c._free(c.pos):
                stepped_in += 1
                break
            if c.path.is_empty():
                break
        if c.pos.distance_to(t) < 6.0:
            reach += 1
    check("试 40 个，走到 %d 个，踩进占地 %d 次" % [reach, stepped_in], reach == 40 and stepped_in == 0)

    # 3. 刚到时站在出口里（进场点就在大门的范围里）：不发；走出去再走回来才发
    print("3 刚到站在出口里不弹")
    var got: Array = []
    var cb := func(id, inside): got.append([id, inside])
    c.spot.connect(cb)
    c.reset_to(c.spot_pos("gate"))
    for i in 30:
        c._process(DT)
    check("站在大门里 30 帧不发", got.is_empty() and c.in_spot("gate"))
    c.go_to(c.spot_pos("gate") + Vector2(0, -150))
    for i in 300:
        c._process(DT)
    c.go_to(c.spot_pos("gate"))
    for i in 300:
        c._process(DT)
    check("走出去再回来：先发出、再发进 %s" % str(got.filter(func(e): return e[0] == "gate")),
        got.has(["gate", false]) and got.has(["gate", true]))
    c.spot.disconnect(cb)

    # 4. 正式流程：选完形象从迎宾院大门进来，先存资料，还不拿席位
    print("4 进山庄")
    m.nickname = "小李"
    await m._enter_court()
    check("在迎宾院 state=%s" % m.state, m.state == "court" and m.cv == c and c.visible and not m.hall.visible)
    check("宴会厅停着", m.hall.process_mode == Node.PROCESS_MODE_DISABLED)
    check("站在大门口 %s" % str(c.pos), c.pos == c.SPAWN)
    check("资料存了、还没拿席位", m.profile_saved and not m.hall_ready)
    check("大门口说「到啦～ 罗曼山庄 席还没散」", m.dialog.visible and m.dialog_text.text == m.LINE_ARRIVE)

    # 5. 走到楼门进宴会厅：站在厅门口，拿到席位；朝向不变
    print("5 楼门进宴会厅")
    walk_to(c.spot_pos("to_hall"))
    check("进了宴会厅 state=%s" % m.state, m.state == "banquet" and m.cv == m.hall and m.hall.visible and not c.visible)
    check("站在厅门口 %s" % str(m.hall.pos), m.hall.pos == m.hall.SPAWN)
    check("朝向没变（往楼门走是朝上）%s" % m.hall.face, m.hall.face == "up")
    check("拿到席位 %s" % str(m.hall.my_seat), m.hall_ready and str(m.hall.my_seat.get("table_id", "")) == "T1")

    # 6. 刚进厅就站在门口：不会马上弹回迎宾院
    print("6 厅门不来回弹")
    tick(60)
    check("站在厅门口 60 帧还在宴会厅", m.state == "banquet")

    # 7. 换个座、手上有金币，出厅门回迎宾院，再进来：都还在
    print("7 来回走状态还在")
    # 换座走正常的路：服务端换成功（T2 的 5 号空着；4 号假数据里小李坐着）再本地坐过去
    var sat := {}
    m.cloud.call_fn("changeSeat", {"tableId": "T2", "chairNo": 5}, func(r): sat["r"] = r)
    check("换座成功 %s" % str(sat.get("r", {})), bool(sat.get("r", {}).get("ok", false)))
    m.hall.apply_change("T2", 5, m.cloud.openid())
    # 金币也走正常的路：通关给 50 金，存进服务端（进厅时服务端的存档说了算，没存上的本机改动会先推上去）
    var coins0: int = m.games_save.coins
    m.games_save.clear_level("g2048", 1, 50)
    m.hall.stand_up()
    walk_to(m.hall.SPAWN + Vector2(0, -160))
    walk_to(m.hall.door)
    check("出厅门回到迎宾院 state=%s" % m.state, m.state == "court" and m.cv == c)
    check("站在 (768,260) %s" % str(c.pos), c.pos == Vector2(768, 260))
    tick(60)
    check("站在楼门边 60 帧不弹回宴会厅", m.state == "court")
    walk_to(c.spot_pos("to_hall") + Vector2(0, 150))
    walk_to(c.spot_pos("to_hall"))
    check("又进了宴会厅", m.state == "banquet")
    check("座位还在 %s" % str(m.hall.my_seat), str(m.hall.my_seat.get("table_id", "")) == "T2" and int(m.hall.my_seat.get("chair_no", 0)) == 5)
    check("金币还在 %d（原来 %d，通关加 50）" % [m.games_save.coins, coins0], m.games_save.coins == coins0 + 50)
    check("NPC 宾客还在", m.hall.life != null and not m.hall.npc_taken.is_empty())

    # 8. 西小径去湖边（9/20 任务 9 起）、东小径去草坪（9/19 任务 8 起），从那边回来都站在对应的口边上
    print("8 东西小径")
    walk_to(m.hall.SPAWN + Vector2(0, -160))
    walk_to(m.hall.door)
    walk_to(c.spot_pos("to_lake"))
    check("西小径到了湖边 state=%s" % m.state, m.state == "lake")
    walk_to(m.lake.spot_pos("to_entrance"))
    check("湖边东口回到迎宾院、站在西小径边 %s" % str(c.pos), m.state == "court" and c.pos == Vector2(100, 520))
    walk_to(c.spot_pos("to_lawn"), 30.0)
    check("东小径进了草坪 state=%s" % m.state, m.state == "lawn")
    walk_to(m.lawn.spot_pos("to_entrance"))
    check("草坪西南口回到迎宾院、站在东小径边 %s" % str(c.pos), m.state == "court" and c.pos == Vector2(1440, 780))

    await part2(c)
    await part3(c)
    await part4(c)

    DirAccess.remove_absolute("user://test_entrance_games.json")
    DirAccess.remove_absolute("user://test_entrance_court.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)

## 第二段：迎宾、签到、喜糖
func part2(c) -> void:
    var ui = m.court_ui
    var sv = m.court_save
    # 9. 新娘妈妈只迎一次（进山庄往楼门走时已经迎过了）：再走进 welcome 不说话
    print("9 新娘妈妈迎一次")
    check("往楼门走时迎过了", sv.welcomed)
    sv.welcomed = false
    c.reset_to(Vector2(768, 560))
    walk_to(c.spot_pos("welcome"))
    check("第一次走进来：%s 说「%s」" % [m.dialog_who.text, m.dialog_text.text],
        m.dialog_who.text == "新娘妈妈" and m.dialog_text.text == CourtCopy.text("welcome"))
    m.dialog_text.text = ""
    walk_to(Vector2(768, 560))
    walk_to(c.spot_pos("welcome"))
    check("再走进来不说了", m.dialog_text.text == "")

    # 10. 走到签到桌前出「签到」，点开是名字页，默认带昵称，人停下
    print("10 签到面板")
    walk_to(c.spot_pos("sign_in"))
    check("按钮「%s」" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == CourtCopy.text("btn_sign") and not ui.act_btn.disabled)
    check("B20 走到桌子跟前了，记号收起来", not c.sign_mark.visible)
    ui._on_act()
    check("面板开了，第一页，名字默认「%s」" % ui.name_edit.text, ui.sign_root.visible and ui.pages[0].visible and ui.name_edit.text == "小李")
    check("开着面板人不能走", not c.walking_enabled)

    # 11. 名字：空的、太长、字体里没有的字
    print("11 名字校验")
    ui.name_edit.text = ""
    ui._name_next()
    check("空的：%s" % ui.name_err.text, ui.name_err.text == CourtCopy.text("err_name_empty") and ui.pages[0].visible)
    ui.name_edit.text = "一二三四五六七八九十一二三"
    ui._name_next()
    check("13 个字：%s" % ui.name_err.text, ui.name_err.text == CourtCopy.text("err_name_long") and ui.pages[0].visible)
    check("12 个字可以", ui.check_name("一二三四五六七八九十一二") == "")
    check("一个字也可以（签到名 1～12 字）", ui.check_name("李") == "")
    ui.name_edit.text = "小李"
    ui._name_next()
    check("好的名字进礼金页", ui.pages[1].visible and ui.sign_name == "小李")

    # 12. 礼金：自己填夹到 0～9999；选 88
    print("12 礼金")
    check("自己填 12345 按上限 9999", CourtUI.clamp_gift("12345") == 9999)
    check("自己填 0 可以、空的不行", CourtUI.clamp_gift("0") == 0 and CourtUI.clamp_gift("") == -1)
    ui._open_custom()
    ui.gift_edit.text = "12345"
    ui._custom_done()
    check("自己填 12345 记成 9999、到祝福那屏（01 E 10/2：名字 → 礼金 → 祝福 → 确认）", ui.pages[ui.PAGE_BLESS].visible and ui.sign_gift == 9999)
    ui._show_page(1)
    ui._pick_gift(88)
    ui._pick_bless(CourtCopy.text("bless_2"))
    check("选 88：%s / %s" % [ui.confirm_name.text, ui.confirm_gift.text],
        ui.confirm_gift.text == CourtCopy.text("confirm_gift_fmt") % "88" and ui.confirm_name.text == CourtCopy.text("confirm_name_fmt") % "小李")
    var note_ok := false
    for ch in ui.pages[ui.PAGE_CONFIRM].get_children():
        if ch is Label and ch.text == CourtCopy.text("confirm_note"):
            note_ok = true
    check("确认页写着「只是游戏里的记录」", note_ok)

    # 12b. B19：礼金卡、确认卡上「返回」不再是最大最抢眼的按钮，往前走的那个更大
    print("12b B19 按钮主次")
    check("礼金卡「返回」缩成次一级（不撑满一行、字小一号）",
        ui.gift_back_btn.size_flags_horizontal == Control.SIZE_SHRINK_CENTER and ui.gift_back_btn.get_theme_font_size("font_size") < 24)
    check("确认卡「好」比「返回」大（%d > %d），「返回」缩成次一级" % [ui.confirm_ok.get_theme_font_size("font_size"), ui.confirm_back_btn.get_theme_font_size("font_size")],
        ui.confirm_ok.get_theme_font_size("font_size") > ui.confirm_back_btn.get_theme_font_size("font_size")
        and ui.confirm_back_btn.size_flags_horizontal == Control.SIZE_SHRINK_CENTER)

    # 13. 断网：「没连上 再试一下」，本机留草稿，关了再开直接回到确认页
    print("13 断网留草稿")
    m.cloud.fake_fail_next = "network"
    ui._submit()
    check("提示：%s" % m.note.text, m.note_box.visible and m.note.text == m.REASONS["network"])
    check("没签上、留了草稿 %s" % str(sv.draft), not sv.signed_in and str(sv.draft.get("name", "")) == "小李" and int(sv.draft.get("gift", -1)) == 88)
    ui._close_sign()
    check("关了面板能走", c.walking_enabled)
    ui.open_sign()
    check("再开直接到确认页，还是 88、祝福还在", ui.pages[ui.PAGE_CONFIRM].visible and ui.confirm_gift.text == CourtCopy.text("confirm_gift_fmt") % "88"
        and ui.confirm_bless.text == CourtCopy.text("confirm_bless_fmt") % CourtCopy.text("bless_2"))

    # 14. 签上：爸爸收礼，喜糖只弹一次，妈妈指路；服务端存下名字和礼金
    print("14 签好了")
    ui._submit()
    check("签上了、草稿清掉", sv.signed_in and sv.draft.is_empty())
    check("服务端存了 %s" % str(m.cloud.fake_check_in), str(m.cloud.fake_check_in.get("name", "")) == "小李" and int(m.cloud.fake_check_in.get("gift_value", -1)) == 88)
    check("面板关了、能走", not ui.sign_root.visible and c.walking_enabled)
    check("喜糖：%s" % str(ui.candy_root.visible), sv.candy and ui.candy_root.visible)
    check("最后新娘妈妈指路：%s「%s」" % [m.dialog_who.text, m.dialog_text.text],
        m.dialog_who.text == "新娘妈妈" and m.dialog_text.text == CourtCopy.text("mom_point"))
    ui.candy_root.visible = false

    # 15. 签过了：按钮「已签到」、点不开
    print("15 已签到")
    check("按钮「%s」、置灰" % ui.act_btn.text, ui.act_btn.text == CourtCopy.text("btn_signed") and ui.act_btn.disabled)
    ui.open_sign()
    check("点不开", not ui.sign_root.visible)

    # 16. 本机存档：重进山庄接着上次的
    print("16 本机存档")
    var again := CourtSave.new()
    again.local_path = sv.local_path
    again.load_local()
    check("迎过、签过、喜糖都记着", again.welcomed and again.signed_in and again.candy and again.draft.is_empty())

    # 17. 名字被服务端判敏感词：退回第一页，显示原因
    print("17 名字过敏感词")
    sv.signed_in = false
    ui._refresh_act()
    ui.open_sign()
    ui.name_edit.text = "测试敏感"
    ui._name_next()
    ui._pick_gift(66)
    ui._pick_bless("")
    ui._submit()
    check("退回第一页：%s" % ui.name_err.text, ui.pages[0].visible and ui.name_err.text == m.REASONS["sensitive"] and not sv.signed_in)
    ui._close_sign()
    sv.signed_in = true



## 第三段：回忆册、合影
func part3(c) -> void:
    var ui = m.court_ui
    var sv = m.court_save
    # 18. 回忆册：剪辑没到，正式版「翻开」置灰、提示「还没印好」
    print("18 回忆册")
    m.debug_override = false
    walk_to(c.spot_pos("album") + Vector2(0, 120))
    walk_to(c.spot_pos("album"))
    # C4：灰着的时候按钮直接写「还没印好」，不再是点不动的「翻开」
    check("按钮「%s」置灰" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == CourtCopy.text("album_not_ready") and ui.act_btn.disabled)
    check("提示：%s" % m.note.text, m.note_box.visible and m.note.text == CourtCopy.text("album_not_ready"))
    ui._on_act()
    check("点不开", m.state == "court")
    # 调试版能打开占位屏；「继续」回到迎宾院，人站在原地，按钮还在
    m.debug_override = true
    walk_to(c.spot_pos("album") + Vector2(0, 120))
    walk_to(c.spot_pos("album"))
    var at: Vector2 = c.pos
    check("调试版按钮能点", not ui.act_btn.disabled)
    ui._on_act()
    check("打开剪辑占位屏 state=%s" % m.state, m.state == "clip" and m.screens["clip"].visible and not m.hud.visible)
    m._close_clip()
    check("回到迎宾院原地 %s" % str(c.pos), m.state == "court" and c.pos == at and c.walking_enabled)
    check("按钮还在", ui.act_btn.visible and ui.act_btn.text == CourtCopy.text("btn_album"))
    m.debug_override = false

    # 19. 摄影师招呼：走到地毯前说一句，同一次在院里不重复
    print("19 摄影师招呼")
    walk_to(c.spot_pos("photo_wait"))
    check("%s：%s" % [m.dialog_who.text, m.dialog_text.text], m.dialog_who.text == "摄影师" and m.dialog_text.text == CourtCopy.text("photo_greet"))
    m.dialog_text.text = ""
    walk_to(c.spot_pos("photo_wait") + Vector2(0, 120))
    walk_to(c.spot_pos("photo_wait"))
    check("再走过来不重复", m.dialog_text.text == "")

    # 20. 合影站位：人吸过去，出「拍一张」
    print("20 合影")
    walk_to(c.spot_pos("photo_mark") + Vector2(20, 30))
    check("吸到站位 %s" % str(c.pos), c.pos == c.spot_pos("photo_mark"))
    check("按钮「%s」" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == CourtCopy.text("btn_photo"))
    ui._on_act()
    check("摆姿势，人停下", ui.pose_root.visible and not c.walking_enabled and not ui.act_btn.visible)
    ui._pick_pose("wave")
    check("对焦圈出来，摄影师倒数：%s" % m.dialog_text.text, ui.focus_root.visible and m.dialog_text.text == CourtCopy.text("photo_count"))
    # C1：「两个圈对上的时候点一下」不再是压在场景上的光字，有深色底、金边
    var hint_sb: StyleBox = ui.focus_hint_panel.get_theme_stylebox("panel")
    check("合影提示字有底框（深色底、金边）%s" % str(hint_sb),
        hint_sb is StyleBoxFlat and (hint_sb as StyleBoxFlat).bg_color.a > 0.5 and (hint_sb as StyleBoxFlat).border_width_left >= 2)
    var p0: Vector2 = ui.ring_a.position
    for i in 30:
        ui._process(DT)
    check("两个圈在动", ui.ring_a.position != p0)
    ui._shutter()
    check("出相纸，招手", ui.paper_root.visible and not ui.focus_root.visible and str(ui.paper_art.get_meta("pose")) == "wave")
    ui._retake()
    check("再拍一张：回到摆姿势", ui.pose_root.visible and not ui.paper_root.visible)
    ui._pick_pose("heart")
    ui._shutter()
    ui._keep()
    check("收好 1 张（比心）%s" % str(sv.photos), sv.photos.size() == 1 and str(sv.photos[0]["pose"]) == "heart")
    check("提示：%s" % m.note.text, m.note.text == CourtCopy.text("photo_kept"))
    check("关了、能走、按钮回来", not ui.panel_open() and c.walking_enabled and ui.act_btn.visible)

    # 21. 最多留 3 张，旧的顶掉
    print("21 最多 3 张")
    for pose in ["stand", "wave", "stand"]:
        ui._on_act()
        ui._pick_pose(pose)
        ui._shutter()
        ui._keep()
    var poses: Array = sv.photos.map(func(ph): return str(ph["pose"]))
    check("留 3 张 %s，最早那张比心顶掉了" % str(poses), poses == ["stand", "wave", "stand"])
    var again := CourtSave.new()
    again.local_path = sv.local_path
    again.load_local()
    check("本机存档里也是 3 张", again.photos.size() == 3)

    # 22. 算了：不留东西，人能走
    print("22 不拍了")
    ui._on_act()
    ui._close_photo()
    check("什么都没多、能走", sv.photos.size() == 3 and c.walking_enabled and not ui.panel_open())



## 第四段：休息区、大门
func part4(c) -> void:
    var sv = m.court_save
    # 23. 休息区：老人一句，方言词第一次自动弹普通话；同一次不重复；再来不自动弹，点说话框能看
    print("23 休息区")
    var line := CourtCopy.text("elder")
    var gloss := CourtCopy.text("elder_gloss")
    var word := gloss.split("：")[0]
    check("方言词「%s」是二档标了可用的，这句里只出现一次" % word, word in TIER2_OK and line.count(word) == 1)
    var others := []
    for w in TIER1 + TIER2_ALL:
        if w != word and line.contains(w):
            others.append(w)
    check("这句没有别的方言词 %s" % [others], others.is_empty())
    var missing := []
    for s in [line, gloss]:
        for i in s.length():
            if not m.font.has_char(s.unicode_at(i)):
                missing.append(s[i])
    check("像素字都显示得出（有 jio 这几个字母）%s" % [missing], missing.is_empty())
    sv.gloss_seen = false
    m.rest_heard = false
    m.note.text = ""
    walk_to(c.spot_pos("rest") + Vector2(0, 120))
    walk_to(c.spot_pos("rest"))
    check("%s：%s" % [m.dialog_who.text, m.dialog_text.text], m.dialog_who.text == "老人" and m.dialog_text.text == CourtCopy.text("elder"))
    check("第一次自动弹普通话：%s" % m.note.text, m.note_box.visible and m.note.text == CourtCopy.text("elder_gloss") and sv.gloss_seen)
    m.dialog_text.text = ""
    walk_to(c.spot_pos("rest") + Vector2(0, 120))
    walk_to(c.spot_pos("rest"))
    check("同一次再走过来不重复", m.dialog_text.text == "")
    m.rest_heard = false   # 当成下回再来
    m.note.text = ""
    walk_to(c.spot_pos("rest") + Vector2(0, 120))
    walk_to(c.spot_pos("rest"))
    check("再来：老人照说，不自动弹", m.dialog_text.text == CourtCopy.text("elder") and m.note.text == "")
    var tapev := InputEventMouseButton.new()
    tapev.button_index = MOUSE_BUTTON_LEFT
    tapev.pressed = true
    m.dialog.gui_input.emit(tapev)
    check("点说话框出普通话：%s" % m.note.text, m.note.text == CourtCopy.text("elder_gloss"))

    # 24. 大门：还没写悄悄话，没有金圈；10/3 起大门外是停车场：走到门口就出去（不拦着），不说话、停车场里不指车
    print("24 大门没开")
    sv.whisper_done = false
    sv.signed_in = true
    m._update_gate()
    m.note.text = ""
    m.dialog_text.text = ""
    check("没金圈", not c.exit_mark.visible)
    walk_to(c.spot_pos("gate") + Vector2(0, -200))
    walk_to(c.spot_pos("gate"))
    check("走到门口出到停车场（%s）、不说话（提醒那句【待补】不出）、不指车" % m.state,
        m.state == "parking" and m.note.text == "" and m.dialog_text.text == "" and not m.parking.car_hint)
    back_to_court()

    # 25. 写了悄悄话没签到：大门没金圈，新娘妈妈提醒先签个到；10/3 起不拦着，照样出到停车场、不指车
    print("25 写了没签到")
    sv.whisper_done = true
    sv.signed_in = false
    m._update_gate()
    check("没金圈", not c.exit_mark.visible)
    walk_to(c.spot_pos("gate") + Vector2(0, -200))
    walk_to(c.spot_pos("gate"))
    check("%s：%s；照样出到停车场、不指车" % [m.dialog_who.text, m.dialog_text.text],
        m.dialog_who.text == "新娘妈妈" and m.dialog_text.text == CourtCopy.text("gate_not_signed") and m.state == "parking" and not m.parking.car_hint)
    m.dialog.visible = false
    m.dialog_text.text = ""
    back_to_court()

    # 26. 真走一遍：签过到，进厅写悄悄话，出来大门开了；10/3 起走出大门回停车场，金箭头指自己的车，走到车旁新娘妈妈送你，不进结束页
    print("26 写完悄悄话出大门")
    sv.signed_in = true
    sv.whisper_done = false
    var wpath := "user://whispers.json"
    var had := FileAccess.file_exists(wpath)
    var old_w := FileAccess.get_file_as_string(wpath) if had else ""
    walk_to(c.spot_pos("to_hall") + Vector2(0, 150))
    walk_to(c.spot_pos("to_hall"))
    check("进了宴会厅", m.state == "banquet")
    m.hall.couple_armed = true
    walk_to(m.hall.COUPLE_SPOT, 30.0)
    check("走到新人桌，写悄悄话的框开了", m.whisper_box.visible)
    m.whisper_edit.text = "新婚快乐"
    m._send_whisper()
    check("写完：本机记下、厅门亮", sv.whisper_done and m.hall.exit_mark.visible)
    # 01 9/23：写完悄悄话新人先道谢，不再马上「吃好了？走」往外赶
    check("写完新人先道谢：%s" % m.dialog_text.text, m.dialog.visible and m.dialog_text.text == m.LINE_THANKS and not m.dialog_text.text.contains("走"))
    walk_to(m.hall.SPAWN + Vector2(0, -160))
    walk_to(m.hall.door)
    check("回到迎宾院，大门亮金圈", m.state == "court" and c.exit_mark.visible)
    m.note.text = ""
    m.dialog_text.text = ""
    walk_to(c.spot_pos("gate"), 30.0)
    check("走出大门回到停车场、门口不说话（%s）、金箭头指自己的车" % m.state, m.state == "parking" and m.dialog_text.text == "" and m.parking.car_hint)
    var pk = m.parking
    walk_to(pk.spot_pos("my_car"), 30.0)
    # 01 9/23：出大门改成新娘妈妈送你——一句送别，一句明天回来能看到什么；回忆册现在是灰的，不提。10/3 起挪到自己车旁说
    var bye: String = m.dialog_text.text
    check("车旁新娘妈妈送你：%s" % bye.replace("\n", " / "), m.dialog.visible and m.dialog_who.text == "新娘妈妈"
        and bye == CourtCopy.text("gate_bye") + "\n" + CourtCopy.text("gate_tomorrow") and not bye.contains("回忆册"))
    check("不再说路没修好", not bye.contains("路还没修好") and not m.note.text.contains("路还没修好"))
    check("人停在车旁、还在停车场、箭头收了", pk.path.is_empty() and m.state == "parking" and pk.in_spot("my_car") and not pk.car_hint)
    tick(60)
    check("站着不动，没进结束页", m.state == "parking" and not m.screens["end"].visible)
    back_to_court()
    if had:
        var wf := FileAccess.open(wpath, FileAccess.WRITE)
        wf.store_string(old_w)
        wf.close()
    else:
        DirAccess.remove_absolute(wpath)

    # 26b. 签到选「不送」：新娘爸爸说「人来了就好」（03 9/19 指出这一支原来没断言）；确认页写「礼金：不送」
    print("26b 选不送")
    sv.signed_in = false
    m.court_ui._refresh_act()
    m.court_ui.open_sign()
    m.court_ui.name_edit.text = "小李"
    m.court_ui._name_next()
    m.court_ui._pick_gift(0)
    m.court_ui._pick_bless("")
    check("确认页：%s" % m.court_ui.confirm_gift.text, m.court_ui.confirm_gift.text == CourtCopy.text("confirm_gift_fmt") % CourtCopy.text("gift_none"))
    m.say_log.clear()
    m.court_ui._submit()
    check("新娘爸爸说「%s」%s" % [CourtCopy.text("dad_no_gift"), str(m.say_log)],
        m.say_log.has(["新娘爸爸", CourtCopy.text("dad_no_gift")]) and not m.say_log.has(["新娘爸爸", CourtCopy.text("dad_thanks")]))
    check("服务端存的礼金是 0", int(m.cloud.fake_check_in.get("gift_value", -1)) == 0 and sv.signed_in)
    m.court_ui.candy_root.visible = false

    # 26c. 换了手机（本机没签到记录）：进山庄存资料时服务端回签过了，签到桌只显示「已签到」（第五段）
    print("26c 换手机")
    sv.signed_in = false
    sv.candy = false
    m.cloud.fake_check_in = {"name": "小李", "gift_value": 88}
    m._save_profile()
    check("本机补记签过到、喜糖当收过了", sv.signed_in and sv.candy)
    walk_to(c.spot_pos("sign_in") + Vector2(0, 120))
    walk_to(c.spot_pos("sign_in"))
    check("签到桌只显示「已签到」", m.court_ui.act_btn.visible and m.court_ui.act_btn.text == CourtCopy.text("btn_signed") and m.court_ui.act_btn.disabled)

    # 27. 本机存档
    print("27 本机存档")
    var again := CourtSave.new()
    again.local_path = sv.local_path
    again.load_local()
    check("写过悄悄话、弹过普通话都记着", again.whisper_done and again.gloss_seen and again.gate_open())

