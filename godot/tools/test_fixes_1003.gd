extends SceneTree
## 验收：第 56 版前补的几处（01 E 10/3，04「第一次来整条路」godot/回执/体验-第一次来整条路.md）
## 1 宴会厅东侧门：没进过后厅的人，进厅小卡多一行「西边侧门通后厅，厨房在那边」；第一次坐下（或玩完第一个小游戏）以后东侧门头上金光、
##   门在屏幕外时屏幕边金箭头指着；进过一次后厅都收，存在本机，重进不再出
## 2 选人只出自己有图的 7 个（没有第 7 个代码画的）；以前选了第 7 个的老号用 GUEST-05 的图顶着
## 3 出大门最后一屏没有「【待做】」；主桌家里人话还是【待补】的不冒「和 XX 聊聊」
## （4 进院金箭头不叠人：test_court_life 守着）
## 用法：Godot --headless --path . --script res://tools/test_fixes_1003.gd ；最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const Spr = preload("res://scripts/sprites.gd")
const ArrivalCard = preload("res://scripts/arrival_card.gd")
const SAVE := "user://test_fixes_1003_court.json"

var m
var started := false
var ok := true

func _initialize() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
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

func card_rows() -> Array:
    if not is_instance_valid(m.arrival_card):
        return []
    return m.arrival_card.rows_box.get_children().map(func(r): return str(r.name))

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    get_root().size = Vector2i(540, 960)
    await frames(2)

    print("2 选人")
    var btns: Array = (m.screens["avatar"] as Control).find_children("*", "Button", true, false).filter(func(b): return b.toggle_mode)
    check("选人界面 %d 个形象（要 7 个，第 7 个代码画的拿掉）、可选的 %s" % [btns.size(), Spr.pickable_presets()], btns.size() == 7 and not 6 in Spr.pickable_presets())
    var g6: Dictionary = Spr.gpt_look(6)
    check("老号选过第 7 个：用 %s 的图顶着" % g6.get("code", "代码画的"), g6.get("code", "") == "LM-GUEST-05")

    print("3 开发字样")
    var end_txt: Array = (m.screens["end"] as Control).find_children("*", "Label", true, false).map(func(l): return l.text)
    check("出大门最后一屏没有「【待」（%s）" % [end_txt], not end_txt.any(func(t): return str(t).contains("【待")))
    check("主桌家里人的话还是【待补】：回空串（不冒「聊聊」）", m.family_line("外婆", m.main_lines_path) == "")

    print("1 东侧门")
    m.court_save.local_path = SAVE
    m.court_save.door_hint = false
    m.court_save.backhall_seen = false
    m.games_save.local_path = "user://test_fixes_1003_games.json"
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    await m._enter_banquet()
    await frames(3)
    var h = m.hall
    check("东侧门在 %s" % h.side_door, h.side_door != Vector2.ZERO)
    check("还没坐过：东侧门没有金光", not h.door_hint and (h.door_mark == null or not h.door_mark.visible))
    # 进厅小卡：不是第一次、没有新鲜事，也出卡，就那一行
    m._arrive({"arrival": {"first_visit": false, "hasNews": false, "rows": []}, "names": {}})
    await frames(1)
    check("没进过后厅：进厅小卡出「%s」那一行（%s）" % [ArrivalCard.LINE_BACKHALL, card_rows()], card_rows() == ["row_backhall"])
    var lbl: Label = m.arrival_card.rows_box.get_child(0).get_child(0) if is_instance_valid(m.arrival_card) else null
    check("那行的字「%s」" % (lbl.text if lbl != null else ""), lbl != null and lbl.text == "西边侧门通后厅，厨房在那边")
    m.arrival_card.queue_free()
    m._arrive({"arrival": {"first_visit": false, "hasNews": true, "rows": [{"kind": "visit", "who": "fake_wang"}]}, "names": {"fake_wang": {"nick": "老王"}}})
    await frames(1)
    check("有新鲜事：那行排在最后（%s）" % [card_rows()], card_rows() == ["row_visit", "row_backhall"])
    m.arrival_card.queue_free()
    # 坐下以后开金光
    var t: Dictionary = h._table_cfg("T2")
    h.sit_at("T2", 5)
    m._process(0.016)
    h._process(0.016)
    check("第一次坐下以后东侧门头上金光亮了、存进本机", h.door_hint and h.door_mark != null and h.door_mark.visible and m.court_save.door_hint)
    var cam_far: bool = not Rect2(h.cam.get_screen_center_position() - Vector2(300, 520), Vector2(600, 1040)).has_point(h.side_door)
    h._process(0.016)
    check("东侧门在屏幕外（%s）：屏幕边金箭头指着它" % cam_far, (not cam_far) or h.door_arrow.visible)
    var sv = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
    check("本机存档里 door_hint 是开的", sv is Dictionary and bool(sv.get("door_hint", false)))
    # 进后厅一次：都收
    m._switch_canvas("backhall")
    for i in 90:
        await process_frame
        if m.state == "backhall" and not m.switching:
            break
    check("进了后厅（%s）：存档记下进过" % m.state, m.state == "backhall" and m.court_save.backhall_seen)
    check("东侧门金光、箭头收了", not h.door_hint and not h.door_mark.visible and not h.door_arrow.visible)
    m._arrive({"arrival": {"first_visit": false, "hasNews": false, "rows": []}, "names": {}})
    await frames(1)
    check("进过后厅：进厅小卡不再出那行（没新鲜事就不出卡）", not is_instance_valid(m.arrival_card))
    # 重进（读本机存档）：还是收着
    var cs2 = load("res://scripts/court_save.gd").new()
    cs2.local_path = SAVE
    cs2.load_local()
    check("重进读存档：进过后厅、金光已开过", cs2.backhall_seen and cs2.door_hint)
    t = t

    DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)
