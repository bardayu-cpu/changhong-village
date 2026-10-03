extends SceneTree
## 验收：对话插件 Dialogue Manager 4.1 接进休息间（01 F 10/4 派，阿鱼点头下的 v4.1.0）。无界面跑整个 main.gd。
##   1 插件在：DialogueManager 单例有、奶奶那份 .dialogue 导入成 DialogueResource
##   2 点奶奶 → 走过去 → 对话框（外观还是第 59 版那个：名字牌、左边人物图、点一下下一句），台词从 .dialogue 来，[#标签] 换人物图
##   3 问到「你是哪边的客人呀？」出三个选项；有选项时点对话框不往下走；挑第二个 → 走那一支 → 接着说完收、能走
##   4 再说一遍挑第一个 → 走另一支
##   5 没写 dialogue 的（爷爷）照旧念 lounge.json 的 talk
##   6 别的画布也能挂（01 G 10/4：任何 NPC 挂一个 .dialogue 就能用）：给迎宾院休息区的老人挂一份，屏幕上点他 → 走过去 → 同一个对话框、
##     走插件、有选项 → 说完迎宾院又能走
## 用法：Godot --headless --path . --script res://tools/test_lounge_dialogue.gd     最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
const PATH := "res://assets/backhall/dialogue/lounge_09.dialogue"

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

## 等插件把下一句给过来（它里面有 await）
func settle() -> void:
    for i in 6:
        await process_frame
    tick(1)

## 点奶奶、走过去、等对话框出第一句
func talk_to_grandma() -> void:
    b.reset_to(Vector2(504, 470))
    tick(2)
    life.request_talk("lounge_09")
    for i in int(20.0 / DT):
        tick(1)
        if ui.talk_box.visible:
            break
    await settle()

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_dm_court.json"
    m.games_save.local_path = "user://test_dm_games.json"
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    await process_frame
    b = m.backhall
    b.walking_enabled = true
    life = b.lounge
    ui = m.lounge_ui
    tick(2)
    ui.attach(life)

    print("1 插件")
    var dm = get_root().get_node_or_null("DialogueManager")
    var res = load(PATH) if ResourceLoader.exists(PATH) else null
    check("DialogueManager 单例在、奶奶那份 .dialogue 导入了（%s）" % [res], dm != null and res != null)

    print("2 点奶奶")
    await talk_to_grandma()
    check("对话框、名字牌「%s」、走插件" % ui.name_label.text, ui.talk_box.visible and ui.name_plate.visible and ui.name_label.text == "奶奶" and ui.dm_res != null)
    check("第一句「%s」用笑的图（%s）" % [ui.line_label.text, ui.portrait.get_meta("pose")], ui.line_label.text == "哎呀，你来啦" and str(ui.portrait.get_meta("pose")) == "smile")
    var s09: Sprite2D = b.npc_nodes["lounge_09"]
    check("奶奶站起来放说话格（第 %d 格）" % s09.frame, s09.frame == 18 or s09.frame == 19)
    ui.next_line()
    await settle()
    check("第二句「%s」用说话的图（%s）" % [ui.line_label.text, ui.portrait.get_meta("pose")], ui.line_label.text == "坐嘛，这沙发软和得很" and str(ui.portrait.get_meta("pose")) == "talk")
    ui.next_line()
    await settle()

    print("3 选项")
    var opts: Array = ui.choices.get_children().map(func(x): return (x as Button).text)
    check("问「%s」出三个选项 %s" % [ui.line_label.text, opts], ui.line_label.text == "你是哪边的客人呀？" and ui.choices.visible and opts == ["新娘那边的", "新郎那边的", "先不说"])
    ui.next_line()
    await settle()
    check("有选项时点对话框不往下走", ui.line_label.text == "你是哪边的客人呀？" and ui.choices.visible)
    (ui.choices.get_child(1) as Button).pressed.emit()
    await settle()
    check("挑「新郎那边的」→「%s」用惊讶的图（%s），选项收了" % [ui.line_label.text, ui.portrait.get_meta("pose")],
        ui.line_label.text == "欢迎欢迎，路上辛苦了" and str(ui.portrait.get_meta("pose")) == "surprise" and not ui.choices.visible)
    ui.next_line()
    await settle()
    check("接着「%s」" % ui.line_label.text, ui.line_label.text == "喝口茶，歇一下再去吃席")
    ui.next_line()
    await settle()
    check("说完对话框收了、又能走", not ui.talk_box.visible and not ui.choices.visible and b.walking_enabled and life.talking == "")

    print("4 再说一遍挑第一个")
    await talk_to_grandma()
    ui.next_line()
    await settle()
    ui.next_line()
    await settle()
    (ui.choices.get_child(0) as Button).pressed.emit()
    await settle()
    check("挑「新娘那边的」→「%s」" % ui.line_label.text, ui.line_label.text == "那我们是一家人嘛，多坐会儿")
    ui.close_talk()

    print("5 爷爷照旧")
    life.request_talk("lounge_10")
    for i in int(20.0 / DT):
        tick(1)
        if ui.talk_box.visible:
            break
    await settle()
    check("爷爷不走插件，念 lounge.json 的第一句「%s」" % ui.line_label.text, ui.talk_box.visible and ui.dm_res == null
        and ui.line_label.text == str(life.data["people"]["lounge_10"]["talk"][0]["text"]))
    ui.close_talk()

    print("6 别的画布上的 NPC 挂 .dialogue")
    await m._enter_court()
    m.dialog.visible = false
    var c = m.court
    var elder: Sprite2D = c.npc_nodes["elder"]
    c.add_talker("elder", elder.position, 52.0, PATH, "老人", "LM-GUEST-10")   # 布局里写 dialogue、title、portrait 也是走这里
    c.reset_to(Vector2(560, 640))
    tick(2)
    var at: Vector2 = elder.position + Vector2(0, -26)
    c.tap(c.get_viewport().get_canvas_transform() * at)
    for i in int(20.0 / DT):
        tick(1)
        if ui.talk_box.visible:
            break
    await settle()
    check("迎宾院点老人：走过去、同一个对话框、名字牌「%s」、插件第一句「%s」" % [ui.name_label.text, ui.line_label.text],
        ui.talk_box.visible and ui.dm_res != null and ui.line_label.text == "哎呀，你来啦" and not c.walking_enabled)
    for k in 8:
        if not ui.talk_box.visible:
            break
        if ui.choices.visible:
            (ui.choices.get_child(2) as Button).pressed.emit()
        else:
            ui.next_line()
        await settle()
    check("一路说完（挑了「先不说」）对话框收了、迎宾院又能走", not ui.talk_box.visible and c.walking_enabled and m.state == "court")

    DirAccess.remove_absolute("user://test_dm_court.json")
    DirAccess.remove_absolute("user://test_dm_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
