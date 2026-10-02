extends SceneTree
## 验收：迎宾院第三件——合影出带码海报（01 E 10/2；迎宾院玩家说明 v1 第 3 条；可行性回执 godot/回执/迎宾院-海报-可行性.md）
## 1 相纸页三个键「做成海报」「再拍一张」「收好」，各宽 ≥140、高 ≥55
## 2 做成海报：照片 + 一句话 + 小程序码 + 「扫码进来坐坐」；字 ≥20 像素；码和字都在照片下面，不压新人
## 3 「发给朋友」：把海报那一块的位置、视口大小、自己画要的东西交给 poster.js（电脑上记下来）；发不出去说「没发出去 再试一下」
## 4 码没拿到：只有照片，说「海报没做好 先存照片吧」，照片照样能发
## 5 返回回到相纸；收起合影海报也收
## 用法：Godot --headless --path . --script res://tools/test_court_poster.gd ；最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const CourtCopy = preload("res://scripts/court_copy.gd")

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

func big_enough(b: Control) -> bool:
    var r := b.get_global_rect()
    return r.size.x >= 140.0 and r.size.y >= 55.0

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    get_root().size = Vector2i(540, 960)   # 照手机屏量键多大、海报在不在屏幕里（headless 设窗口要先等一帧）
    await frames(2)
    m.court_save.local_path = "user://test_court_poster_court.json"
    m.games_save.local_path = "user://test_court_poster_games.json"
    m.court_save.welcomed = true
    m.court_save.signed_in = true
    m.nickname = "小李"
    await m._enter_court()
    m.dialog.visible = false
    var ui = m.court_ui
    var c = m.court
    var vs: Vector2 = ui.get_viewport().get_visible_rect().size
    print("视口 ", vs)
    c.reset_to(c.spot_pos("photo_mark"))
    ui.start_photo()
    ui._pick_pose("heart")
    ui._shutter()
    await frames(3)

    print("1 相纸页三个键")
    var btns: Array = ui.paper_root.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("paper_btn"))
    var names: Array = btns.map(func(b): return "%s %s" % [b.text, b.get_global_rect().size])
    check("三个键：%s" % [names], btns.size() == 3 and btns.map(func(b): return b.text) == [CourtCopy.text("btn_poster"), CourtCopy.text("btn_retake"), CourtCopy.text("btn_keep")])
    check("各宽 ≥140、高 ≥55", btns.all(func(b): return big_enough(b)))

    print("2 做成海报")
    m.cloud.fake_poster_code_fail = false
    m.cloud.fake_poster_shares = []
    ui.open_poster()
    await frames(3)
    var card: Rect2 = ui.poster_card.get_global_rect()
    var photo: Rect2 = (ui.poster_paper_art as Control).get_global_rect()
    var code: Rect2 = (ui.poster_code as Control).get_global_rect()
    var line: Rect2 = (ui.poster_line as Control).get_global_rect()
    check("海报开着、相纸收了，照片拼好了（姿势 %s）" % ui.poster_paper_art.get_meta("pose", ""), ui.poster_root.visible and not ui.paper_root.visible and ui.poster_paper_art.get_meta("pose", "") == "heart")
    check("码到了（%s）、一句话「%s」" % [ui.poster_code.texture.get_size() if ui.poster_code.texture != null else null, ui.poster_line.text],
        ui.poster_has_code and ui.poster_code_row.is_visible_in_tree() and ui.poster_code.texture != null and ui.poster_line.text == CourtCopy.text("poster_line") and ui.poster_status.text == "")
    check("码、一句话都在照片下面不压新人（照片下沿 %.0f，字 %.0f，码 %.0f）" % [photo.end.y, line.position.y, code.position.y], line.position.y >= photo.end.y and code.position.y >= line.end.y)
    check("海报整块在屏幕里（%s）、码 ≥110 宽（%.0f）" % [card, code.size.x], Rect2(Vector2.ZERO, vs).encloses(card) and code.size.x >= 110.0)
    var small: Array = []
    for l in ui.poster_card.find_children("*", "Label", true, false):
        if l.is_visible_in_tree() and l.text.strip_edges() != "" and l.get_theme_font_size("font_size") < 20:
            small.append("%s:%d" % [l.text, l.get_theme_font_size("font_size")])
    check("海报上的字都 ≥20 像素（小的 %s）" % [small], small.is_empty())
    var scan_ok: bool = ui.poster_card.find_children("*", "Label", true, false).any(func(l): return l.text == CourtCopy.text("poster_scan") and l.is_visible_in_tree())
    check("有「%s」" % CourtCopy.text("poster_scan"), scan_ok)
    var pb: Array = ui.poster_root.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree())
    check("海报页的键（%s）各宽 ≥140、高 ≥55" % [pb.map(func(b): return b.text)], pb.size() == 2 and pb.all(func(b): return big_enough(b)))
    check("面板开着人不能走", not c.walking_enabled and ui.panel_open())

    print("3 发给朋友")
    ui._poster_share()
    await frames(2)
    var sent: Dictionary = m.cloud.fake_poster_shares[0] if not m.cloud.fake_poster_shares.is_empty() else {}
    var rr: Dictionary = sent.get("rect", {})
    check("交给 poster.js 的是海报那一块（%s）、视口 %s×%s" % [rr, sent.get("vw"), sent.get("vh")],
        not sent.is_empty() and absf(float(rr.get("x", -1)) - card.position.x) < 0.5 and absf(float(rr.get("h", -1)) - card.size.y) < 0.5 and float(sent.get("vw", 0)) == vs.x)
    var fb: Dictionary = sent.get("fallback", {})
    check("自己画的退路要的东西都带上（%s）" % [fb], fb.get("has_code") == true and int(fb.get("preset", -1)) == m.preset and fb.get("pose") == "heart" and fb.get("line") == CourtCopy.text("poster_line"))
    check("发完键能再点、没报错", not ui.poster_share_btn.disabled and ui.poster_status.text == "")
    m.cloud.fake_fail_next = "network"
    ui._poster_share()
    await frames(2)
    check("发不出去：「%s」" % ui.poster_status.text, ui.poster_status.text == CourtCopy.text("poster_share_fail") and not ui.poster_share_btn.disabled)

    print("4 码没拿到")
    ui._poster_back()
    m.cloud.fake_poster_code_fail = true
    ui.open_poster()
    await frames(3)
    check("只有照片：一句话、码都不出，说「%s」" % ui.poster_status.text,
        not ui.poster_has_code and not ui.poster_code_row.is_visible_in_tree() and not ui.poster_line.is_visible_in_tree() and ui.poster_status.text == CourtCopy.text("poster_no_code"))
    check("照片照样能发", not ui.poster_share_btn.disabled)
    m.cloud.fake_poster_shares = []
    ui._poster_share()
    await frames(2)
    var sent2: Dictionary = m.cloud.fake_poster_shares[0] if not m.cloud.fake_poster_shares.is_empty() else {}
    check("发的是只有照片那块（has_code=%s，高 %.0f 比有码的 %.0f 矮）" % [sent2.get("fallback", {}).get("has_code"), float(sent2.get("rect", {}).get("h", 0)), card.size.y],
        sent2.get("fallback", {}).get("has_code") == false and float(sent2.get("rect", {}).get("h", 9999)) < card.size.y)
    m.cloud.fake_poster_code_fail = false

    print("5 返回、收起")
    ui._poster_back()
    check("返回回到相纸", ui.paper_root.visible and not ui.poster_root.visible)
    ui.open_poster()
    await frames(2)
    ui.hide_all()
    check("离开迎宾院：海报也收", not ui.poster_root.visible and not ui.panel_open())

    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)
