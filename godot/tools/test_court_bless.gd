extends SceneTree
## 验收：迎宾院第一件——签到加祝福 + 引导（01 E 10/2，docs/迎宾院-玩家说明-v1.md、04 基线第六节）
## 1 签到四屏：名字 → 礼金 → 祝福 → 确认；四句现成的一点就用；自己写 1～30 字；可以跳过
## 2 自己写的被敏感词拦：回到祝福那屏说「换个说法吧」，名字、礼金不丢；改了再交能签上
##   词库过了、微信内容安全（msgSecCheck）不过的，也走这条路
## 3 祝福公开：签到桌旁的祝福牌走近出「看祝福」，新的在上面；没人写时说「还没人写」
## 4 签完新娘妈妈那句带上回忆册和花墙（还是一句）；进门金箭头、拦门照旧（test_entrance 守着）
## 5 回忆册摊开一本书（色块），走近之前就看得见；面板开着把「点地面走路」藏起来
## 6 默认形象：不再用老的 chr_guest03
## 用法：Godot --headless --path . --script res://tools/test_court_bless.gd ；最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const CourtCopy = preload("res://scripts/court_copy.gd")
const Spr = preload("res://scripts/sprites.gd")

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

func frames(n: int) -> void:
    for i in n:
        await process_frame

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.games_save.local_path = "user://test_court_bless_games.json"
    m.court_save.local_path = "user://test_court_bless_court.json"
    m.court_save.welcomed = true
    m.court_save.signed_in = false
    m.court_save.candy = true
    m.court_save.draft = {}
    m.nickname = "小李"
    m.cloud.fake_blessings = []
    await m._enter_court()
    m.dialog.visible = false
    var ui = m.court_ui
    var c = m.court

    print("1 签到四屏")
    c.reset_to(c.spot_pos("sign_in"))
    ui.spot("sign_in", true)
    ui.open_sign()
    check("第一屏名字", ui.pages[0].visible)
    ui._name_next()
    ui._pick_gift(88)
    check("礼金以后到祝福那屏（第 3 屏）", ui.pages[ui.PAGE_BLESS].visible and ui.pages.size() == 4)
    var presets: Array = ui.pages[ui.PAGE_BLESS].find_children("*", "Button", true, false).filter(func(b): return b.get_meta("bless_preset", false))
    var texts: Array = presets.map(func(b): return b.text)
    check("四句现成的：%s" % [texts], texts == [CourtCopy.text("bless_1"), CourtCopy.text("bless_2"), CourtCopy.text("bless_3"), CourtCopy.text("bless_4")])
    var big := presets.all(func(b): return b.get_combined_minimum_size().y >= 55.0)
    check("现成那几句的按钮够大（≥55 高，长辈好点）", big)
    ui._open_bless_custom()
    ui.bless_edit.text = "喜".repeat(31)
    ui._bless_custom_done()
    check("自己写 31 字：%s" % ui.bless_err.text, ui.bless_err.text == CourtCopy.text("err_bless_long") and ui.pages[ui.PAGE_BLESS].visible)
    ui.bless_edit.text = "   "
    ui._bless_custom_done()
    check("自己写空的：%s" % ui.bless_err.text, ui.bless_err.text == CourtCopy.text("err_bless_empty"))

    print("2 敏感词")
    ui.bless_edit.text = "祝你们测试敏感"
    ui._bless_custom_done()
    check("自己写的到确认页：%s" % ui.confirm_bless.text, ui.pages[ui.PAGE_CONFIRM].visible and ui.confirm_bless.text == CourtCopy.text("confirm_bless_fmt") % "祝你们测试敏感")
    ui._submit()
    check("被拦：回到祝福那屏「%s」、原话还在、名字礼金不丢（%s，%d）" % [ui.bless_err.text, ui.sign_name, ui.sign_gift],
        ui.pages[ui.PAGE_BLESS].visible and ui.bless_err.text == "换个说法吧" and ui.bless_edit.text == "祝你们测试敏感"
        and ui.sign_name == "小李" and ui.sign_gift == 88 and not m.court_save.signed_in)
    ui.bless_edit.text = "祝你们测试安全"
    ui._bless_custom_done()
    ui._submit()
    check("微信内容安全不过：也回祝福那屏「%s」、原话还在、没签上" % ui.bless_err.text,
        ui.pages[ui.PAGE_BLESS].visible and ui.bless_err.text == "换个说法吧" and ui.bless_edit.text == "祝你们测试安全"
        and ui.sign_name == "小李" and not m.court_save.signed_in and m.cloud.fake_blessings.is_empty())
    ui.bless_edit.text = "早点生个娃，我来当干妈"
    ui._bless_custom_done()
    ui._submit()
    check("改了再交签上了，服务端存了祝福（%s）" % [m.cloud.fake_blessings], m.court_save.signed_in and m.cloud.fake_blessings.size() == 1
        and m.cloud.fake_blessings[0]["text"] == "早点生个娃，我来当干妈" and m.cloud.fake_blessings[0]["name"] == "小李")

    print("4 签完新娘妈妈那句")
    var mom := CourtCopy.text("mom_point")
    check("「%s」带上回忆册、花墙，还是一句（每行 ≤16 字）" % mom.replace("\n", "／"),
        mom.contains("回忆册") and mom.contains("花墙") and Array(mom.split("\n")).all(func(l): return l.length() <= 16))
    m.dialog.visible = false
    ui.candy_root.visible = false

    print("1b 跳过")
    var n0: int = m.cloud.fake_blessings.size()
    m.court_save.signed_in = false
    ui._refresh_act()
    ui.open_sign()
    ui._name_next()
    ui._pick_gift(0)
    ui._pick_bless("")
    check("跳过：确认页「%s」" % ui.confirm_bless.text, ui.confirm_bless.text == CourtCopy.text("confirm_bless_none"))
    ui._submit()
    check("跳过照样签上、不多一条祝福", m.court_save.signed_in and m.cloud.fake_blessings.size() == n0)
    m.dialog.visible = false
    ui.candy_root.visible = false

    print("3 祝福牌")
    c.reset_to(c.spot_pos("blessing"))
    ui.spot("blessing", true)
    check("走近祝福牌出「%s」" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == CourtCopy.text("btn_board"))
    m.cloud.fake_blessings.push_front({"name": "阿花", "text": CourtCopy.text("bless_3")})
    ui._on_act()
    await frames(2)
    var lines: Array = ui.board_list.get_children().filter(func(n): return n.get_meta("blessing_line", false))
    check("祝福牌 %d 条、新的在上面（%s）" % [lines.size(), lines[0].text if not lines.is_empty() else ""],
        lines.size() == 2 and lines[0].text == "阿花：" + CourtCopy.text("bless_3") and not c.walking_enabled)
    check("面板开着「点地面走路」藏起来", not m.hint.visible)
    ui.close_board()
    check("收起能走", c.walking_enabled and not ui.board_root.visible)
    m.cloud.fake_blessings = []
    ui.open_board()
    await frames(2)
    check("没人写：「%s」" % ui.board_status.text, ui.board_status.text == CourtCopy.text("board_empty"))
    ui.close_board()

    print("5 回忆册认得出")
    var book: Node = c.world.find_child("album_book_cover", true, false)
    var pages_l: Node = c.world.find_child("album_book_left", true, false)
    check("回忆册台子上摊开一本书（书皮、两页）", book != null and pages_l != null)
    m.hint_done = false
    ui.start_photo()
    check("合影摆姿势、对焦时「点地面走路」藏起来", not m.hint.visible)
    ui._close_photo()
    check("合影收了「点地面走路」回来（还没走过的）", m.hint.visible)

    print("6 默认形象")
    check("形象 2 不再用老的 chr_guest03（没有罗曼山庄宾客的图就是代码画的：%s）" % [Spr.gpt_look(2).get("code", "代码画的")],
        not ResourceLoader.exists("res://assets/characters/chr_guest03.png") and str(Spr.gpt_look(2).get("code", "")) in ["", "LM-GUEST-03"])

    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_court_bless_games.json"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_court_bless_court.json"))
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
