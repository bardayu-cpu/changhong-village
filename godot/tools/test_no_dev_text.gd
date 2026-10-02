extends SceneTree
## 验收：玩家看得见的地方没有开发字样（01 E 10/3：「【待补】【待做】预留 占位」一律不出）
## 照截图预设把能去的地方走一遍——迎宾院几屏、宴会厅（进厅、主桌前、席面菜单点开没简介那道）、后厅四间、草坪、湖边亭子、
## 果园收和卖、出大门那屏——每到一处把整个画面里看得见的字（Label、Button、RichTextLabel）扫一遍
## 用法：Godot --headless --path . --script res://tools/test_no_dev_text.gd ；最后一行 RESULT PASS 才算过

const BAD := ["【待", "待补", "待做", "预留", "占位"]
const SHOTS := ["court", "court_sign_bless", "court_poster", "court_album_far", "arrive_card", "big_main",
    "backhall_dress", "backhall_lounge", "backhall_mahjong", "backhall_pot", "lawn", "lake_pavilion", "lake_bench",
    "orchard_pick", "orchard_sold", "end"]

var m
var started := false
var ok := true

func _initialize() -> void:
    m = load("res://scripts/main.gd").new()
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

func scan(n: Node, out: Array) -> void:
    var t := ""
    if n is Label or n is Button or n is RichTextLabel:
        if (n as CanvasItem).is_visible_in_tree():
            t = str(n.get("text"))
    if t != "":
        for b in BAD:
            if t.contains(b):
                out.append("%s「%s」" % [n.name, t.replace("\n", "／")])
                break
    for c in n.get_children():
        scan(c, out)

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    var found := {}
    for s in SHOTS:
        if not m.has_method("_setup_shot"):
            break
        await m._setup_shot(s)
        for i in 20:
            await process_frame
        var bad: Array = []
        scan(get_root(), bad)
        if s == "big_main" and m.chat_btn.visible:
            m.chat_btn.emit_signal("pressed")   # 主桌家里人跟前出了「聊聊」就点一下
            await process_frame
            scan(get_root(), bad)
        if s == "arrive_card" and m.banquet_ui != null:
            m.banquet_ui.open_menu()             # 席面菜单点开没简介的那道
            m.banquet_ui._tap_dish("金牌玉女瓜")
            await process_frame
            scan(get_root(), bad)
            m.banquet_ui.close()
        found[s] = bad
        check("%s：看得见的字里没有开发字样 %s" % [s, bad], bad.is_empty())
    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)
