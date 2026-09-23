extends Control
## 迎宾院的界面（蓝图 3.1，灰盒，01 9/19 派）：走近交互点时底部冒出的按钮、签到面板（名字 → 礼金 → 确认）、喜糖弹窗、
## 回忆册、花墙合影（姿势 → 对焦 → 相纸）。
## main.gd 管走路、切画布、说话框和提示框；迎宾院自己的事在这里，要说话、提示、调云函数都回到 main（_say、_note、cloud）。
## 字都在 assets/entrance/lines.json（court_copy.gd 读），这里不写死

signal panel_changed(open: bool)   # 面板开、关：main 据此让人停下、能走

const Copy = preload("res://scripts/court_copy.gd")
const Tiles = preload("res://scripts/games/tiles.gd")
const Spr = preload("res://scripts/sprites.gd")
## 回忆册的两分钟剪辑（六张图六句话，阿鱼给）到了没有。没到：正式版「翻开」置灰、提示「还没印好」（世界观 1.1），
## 调试版照样能打开占位屏（01 9/19 定）。阿鱼给了图和句子、剪辑做好以后改成 true
const CLIP_READY := false
const POSES := ["stand", "wave", "heart"]   # 蓝图 3.1：站好、招手、比心
const RING_PERIOD := 1.6   # 两个对焦圈一靠一离多久，秒
const GIFTS := [0, 66, 88, 188]    # 蓝图 3.1：不送、66、88、188，再加「自己填」
const GIFT_MAX := 9999             # 自己填的上限，超了按上限（蓝图 3.1 异常表）
const NAME_MAX := 12
const CANDY_SECS := 2.5
const RED_ERR := Color("#E8746A")
const MUTED := Color("#b1a6ba")
const GOLD1 := Color("#f4d97a")
const PAPER := Color("#efe6d8")

var m                      # main.gd
var font: Font
var save                   # court_save.gd
var act_btn: Button        # 底部按钮：签到 / 已签到 ……（走进交互点半径才出，蓝图 3.1 交互说明）
var act_id := ""
var sign_root: Control
var pages: Array = []      # 0 名字、1 礼金、2 确认
var name_edit: LineEdit
var name_err: Label
var name_count: Label
var gift_custom_row: HBoxContainer
var gift_edit: LineEdit
var confirm_name: Label
var confirm_gift: Label
var confirm_ok: Button
var gift_back_btn: Button   # B19：礼金卡「返回」，次一级
var confirm_back_btn: Button   # B19：确认卡「返回」，次一级
var focus_hint_panel: PanelContainer   # C1：合影提示字的底框
var sign_name := ""
var sign_gift := 0
var busy := false          # 签到请求在路上
var candy_root: Control
var candy_token := 0
var pose_root: Control     # 合影第 1 步：摆个姿势
var focus_root: Control    # 第 2 步：两个对焦圈靠拢时点一下（早了晚了都不算失败）
var ring_a: Panel
var ring_b: Panel
var focus_t := 0.0
var paper_root: Control    # 第 3 步：相纸（用节点拼出来的「照片」，不读显卡截图），再拍一张 / 收好
var paper_art: Control
var flash: ColorRect
var photo_pose := ""

func setup(main_ref, f: Font, s) -> void:
    m = main_ref
    font = f
    save = s
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    act_btn = Button.new()
    act_btn.visible = false
    act_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    act_btn.offset_top = -170
    act_btn.offset_bottom = -120
    act_btn.offset_left = -220
    act_btn.offset_right = 220
    act_btn.pressed.connect(_on_act)
    add_child(act_btn)
    _build_sign()
    _build_candy()
    _build_photo()

## 有面板开着（开着时人不能走）
func panel_open() -> bool:
    return sign_root.visible or candy_root.visible or pose_root.visible or focus_root.visible or paper_root.visible

## 离开迎宾院（进宴会厅、回开场）：按钮、面板都收起来
func hide_all() -> void:
    act_id = ""
    act_btn.visible = false
    if sign_root.visible:
        _close_sign()
    candy_root.visible = false
    if pose_root.visible or focus_root.visible or paper_root.visible:
        _close_photo()

## 走进、走出交互点（main 的 _on_court_spot 转过来）
func spot(id: String, inside: bool) -> void:
    if not id in ["sign_in", "album", "photo_mark"]:
        return
    if inside:
        act_id = id
        _refresh_act()
        act_btn.visible = true
        if id == "album" and not can_open_album():
            m._note(Copy.text("album_not_ready"), 2.5)
        if id == "photo_mark":
            # 合影站位：人吸过去（蓝图 3.1 交互说明「合影时人吸附到站位」）；在半径里照样能小幅挪
            m.court.path.clear()
            m.court.pos = m.court.spot_pos("photo_mark")
            m.court.face = "down"
    elif act_id == id:
        act_id = ""
        act_btn.visible = false

## 从别的界面（回忆册剪辑）回到迎宾院：人还站在交互点里的，把按钮补出来
func refresh_spots() -> void:
    for id in ["sign_in", "album", "photo_mark"]:
        if m.court.in_spot(id):
            act_id = id
            _refresh_act()
            act_btn.visible = true
            return

## 回忆册能不能翻开：剪辑到了，或者调试版
func can_open_album() -> bool:
    return CLIP_READY or m.is_debug()

func _refresh_act() -> void:
    match act_id:
        "sign_in":
            # 重进山庄不重复签到，签到桌只显示「已签到」（蓝图 3.1 交互说明）
            act_btn.text = Copy.text("btn_signed") if save.signed_in else Copy.text("btn_sign")
            act_btn.disabled = save.signed_in
        "album":
            # C4：灰着的时候别写「翻开」——按钮点不动，字直接说清楚为什么
            var ready := can_open_album()
            act_btn.text = Copy.text("btn_album") if ready else Copy.text("album_not_ready")
            act_btn.disabled = not ready
        "photo_mark":
            act_btn.text = Copy.text("btn_photo")
            act_btn.disabled = false

func _on_act() -> void:
    match act_id:
        "sign_in":
            open_sign()
        "album":
            if can_open_album():
                m.open_clip()
        "photo_mark":
            start_photo()

# ---------- 签到面板：名字 → 礼金 → 确认（蓝图 3.1） ----------
func _panel(width := 460.0) -> Array:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.visible = false
    var dim := ColorRect.new()
    dim.color = Color(0.06, 0.03, 0.06, 0.55)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(dim)
    var cc := CenterContainer.new()
    cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(cc)
    var p := PanelContainer.new()
    p.custom_minimum_size = Vector2(width, 0)
    cc.add_child(p)
    var holder := VBoxContainer.new()
    p.add_child(holder)
    add_child(root)
    return [root, holder]

func _lbl(text: String, size := 24, color := PAPER, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.horizontal_alignment = align
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l

func _btn(text: String, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.pressed.connect(cb)
    return b

## B19（迎宾院礼金卡、确认卡「返回」比往前走的按钮还大还显眼）：次一级按钮，字小一号、
## 边框淡、不撑满一行——往前走的那个照旧用主题给的红金主色，不用另外改
func _btn_secondary(text: String, cb: Callable) -> Button:
    var b := _btn(text, cb)
    b.add_theme_font_size_override("font_size", 20)
    b.add_theme_color_override("font_color", MUTED)
    b.add_theme_color_override("font_hover_color", PAPER)
    b.add_theme_color_override("font_pressed_color", PAPER)
    b.add_theme_stylebox_override("normal", m._sb(Color(0.106, 0.078, 0.133, 0.5), MUTED, 1, 6, 10))
    b.add_theme_stylebox_override("hover", m._sb(Color(0.106, 0.078, 0.133, 0.5), PAPER, 1, 6, 10))
    b.add_theme_stylebox_override("pressed", m._sb(Color(0.106, 0.078, 0.133, 0.6), PAPER, 1, 6, 10))
    b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    return b

func _page(holder: VBoxContainer) -> VBoxContainer:
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 14)
    holder.add_child(v)
    pages.append(v)
    return v

func _row(children: Array, sep := 10) -> HBoxContainer:
    var r := HBoxContainer.new()
    r.add_theme_constant_override("separation", sep)
    for c in children:
        r.add_child(c)
    return r

func _grow(c: Control) -> Control:
    c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return c

func _build_sign() -> void:
    var pr := _panel()
    sign_root = pr[0]
    var holder: VBoxContainer = pr[1]
    # 第 1 页：名字（默认带昵称，可改，1～12 字）
    var p0 := _page(holder)
    p0.add_child(_lbl(Copy.text("sign_name_title"), 24, GOLD1))
    name_edit = LineEdit.new()
    name_edit.max_length = NAME_MAX * 2   # 按字素数校验（和昵称一样），这里放宽一点，边打边数
    name_edit.text_changed.connect(func(_t): _check_name_ui())
    p0.add_child(name_edit)
    name_err = _lbl("", 24, RED_ERR)
    _grow(name_err)
    name_count = _lbl("0/12", 24, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
    name_count.autowrap_mode = TextServer.AUTOWRAP_OFF
    p0.add_child(_row([name_err, name_count]))
    p0.add_child(_row([_grow(_btn(Copy.text("btn_cancel"), _close_sign)), _grow(_btn(Copy.text("btn_next"), _name_next))]))
    # 第 2 页：礼金（游戏里的记录，不收费、不扣币）
    var p1 := _page(holder)
    p1.add_child(_lbl(Copy.text("gift_title"), 24, GOLD1))
    p1.add_child(_lbl(Copy.text("gift_hint"), 24, MUTED))
    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    for g in GIFTS:
        var b := _grow(_btn(Copy.text("gift_none") if g == 0 else str(g), _pick_gift.bind(g)))
        grid.add_child(b)
    grid.add_child(_grow(_btn(Copy.text("gift_custom"), _open_custom)))
    p1.add_child(grid)
    gift_edit = LineEdit.new()
    gift_edit.placeholder_text = Copy.text("gift_custom_placeholder")
    gift_edit.max_length = 6
    gift_edit.text_changed.connect(_filter_digits)
    gift_custom_row = _row([_grow(gift_edit), _btn(Copy.text("btn_ok"), _custom_done)])
    gift_custom_row.visible = false
    p1.add_child(gift_custom_row)
    gift_back_btn = _btn_secondary(Copy.text("btn_back"), func(): _show_page(0))
    p1.add_child(gift_back_btn)
    # 第 3 页：确认，写明「只是游戏里的记录」
    var p2 := _page(holder)
    p2.add_child(_lbl(Copy.text("confirm_title"), 24, GOLD1))
    confirm_name = _lbl("")
    p2.add_child(confirm_name)
    confirm_gift = _lbl("")
    p2.add_child(confirm_gift)
    p2.add_child(_lbl(Copy.text("confirm_note"), 24, MUTED))
    confirm_ok = _btn(Copy.text("btn_ok"), _submit)
    confirm_ok.add_theme_font_size_override("font_size", 28)   # B19：往前走的那个做大
    confirm_back_btn = _btn_secondary(Copy.text("btn_back"), func(): _show_page(1))
    p2.add_child(_row([confirm_back_btn, _grow(confirm_ok)]))

func _show_page(i: int) -> void:
    for k in pages.size():
        pages[k].visible = (k == i)
    if i == 1:
        gift_custom_row.visible = false
        gift_edit.text = ""

func open_sign() -> void:
    if save.signed_in or busy or sign_root.visible:
        return
    # 默认带昵称；上次断网没交上的，接着用草稿
    sign_name = str(save.draft.get("name", m.nickname))
    sign_gift = int(save.draft.get("gift", 0))
    name_edit.text = sign_name
    _check_name_ui()
    _show_page(2 if save.draft.has("name") else 0)
    if save.draft.has("name"):
        _fill_confirm()
    sign_root.visible = true
    panel_changed.emit(true)

func _close_sign() -> void:
    sign_root.visible = false
    panel_changed.emit(false)

## 名字校验：空的、太长、字体里没有的字。返回要显示的提示，空字符串是可以
func check_name(raw: String) -> String:
    var s: String = m._normalize(raw)
    if s == "":
        return Copy.text("err_name_empty")
    if m._graphemes(s) > NAME_MAX:
        return Copy.text("err_name_long")
    for i in s.length():
        if not font.has_char(s.unicode_at(i)):
            return Copy.text("err_name_glyph")
    return ""

func _check_name_ui() -> void:
    var s: String = m._normalize(name_edit.text)
    name_count.text = "%d/12" % m._graphemes(s)
    var r := check_name(name_edit.text)
    # 空着的时候先不报错，按「下一步」再说（和起昵称一样）
    name_err.text = "" if s == "" else r

func _name_next() -> void:
    var r := check_name(name_edit.text)
    if r != "":
        name_err.text = r
        return
    sign_name = m._normalize(name_edit.text)
    _show_page(1)

func _pick_gift(g: int) -> void:
    sign_gift = g
    _fill_confirm()
    _show_page(2)

func _open_custom() -> void:
    gift_custom_row.visible = true
    gift_edit.grab_focus()

func _filter_digits(t: String) -> void:
    var d := ""
    for i in t.length():
        var c := t.unicode_at(i)
        if c >= 48 and c <= 57:
            d += char(c)
    if d != t:
        gift_edit.text = d
        gift_edit.caret_column = d.length()

## 自己填：非负整数，超上限按上限（蓝图 3.1）
static func clamp_gift(text: String) -> int:
    if text.strip_edges() == "":
        return -1
    return clampi(int(text), 0, GIFT_MAX)

func _custom_done() -> void:
    var g := clamp_gift(gift_edit.text)
    if g < 0:
        return
    _pick_gift(g)

func _fill_confirm() -> void:
    confirm_name.text = Copy.text("confirm_name_fmt") % sign_name
    confirm_gift.text = Copy.text("confirm_gift_fmt") % (Copy.text("gift_none") if sign_gift == 0 else str(sign_gift))

## 交签到：名字和礼金一起存进服务端自己那条住民记录（蓝图 2.4），名字过敏感词（服务端判）
func _submit() -> void:
    if busy:
        return
    busy = true
    confirm_ok.disabled = true
    print("[suqi] 签到 礼金 ", sign_gift)
    m.cloud.call_fn("saveProfile", {"check_in_name": sign_name, "gift_value": sign_gift}, _on_signed)

func _on_signed(r: Dictionary) -> void:
    busy = false
    confirm_ok.disabled = false
    var reason := str(r.get("reason", ""))
    if bool(r.get("ok", false)):
        save.signed_in = true
        save.draft = {}
        save.save()
        _close_sign()
        _refresh_act()
        m._update_gate()   # 写过悄悄话、这会儿才签到的：大门现在开
        print("[suqi] 签到 好了")
        after_sign()
        return
    if reason == "sensitive" or reason == "reserved":
        # 名字被服务端拦了：回到第 1 页，显示原因（和起昵称一样的两句）
        name_err.text = m._reason_text(r, "签到")
        _show_page(0)
        return
    # 断网：提示「没连上 再试一下」，本机留草稿，停在确认页可以再点「好」（蓝图 3.1 异常表）
    save.draft = {"name": sign_name, "gift": sign_gift}
    save.save()
    m._note(m._reason_text(r, "签到"), 3.0)

## 签完：新娘爸爸收下礼金说一句，新娘妈妈递喜糖（只弹一次「喜糖收好了」），再指回忆册和花墙（蓝图 3.1 用户故事）
func after_sign() -> void:
    var dad_key := "dad_thanks" if sign_gift > 0 else "dad_no_gift"
    m._say(Copy.text(dad_key), -1.0, Copy.who(dad_key))
    if not m.fast:
        await get_tree().create_timer(1.4).timeout
    if not save.candy:
        save.candy = true
        save.save()
        await candy_popup()
    m._say(Copy.text("mom_point"), -1.0, Copy.who("mom_point"))

# ---------- 喜糖弹窗：签到后只弹一次（蓝图 3.1：阶段 1 没有背包） ----------
func _build_candy() -> void:
    candy_root = Control.new()
    candy_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    candy_root.visible = false
    var dim := Button.new()   # 点哪都收
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for st in ["normal", "hover", "pressed", "focus"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.06, 0.03, 0.06, 0.35)
        dim.add_theme_stylebox_override(st, sb)
    dim.pressed.connect(func(): candy_root.visible = false)
    candy_root.add_child(dim)
    var cc := CenterContainer.new()
    cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    candy_root.add_child(cc)
    var p := PanelContainer.new()
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.custom_minimum_size = Vector2(300, 0)   # 不给宽度的话，自动换行的字会被挤成一列
    cc.add_child(p)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    v.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_child(v)
    var tc := CenterContainer.new()
    tc.custom_minimum_size = Vector2(0, 72)
    tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var tile := Tiles.dish_tile(10, 64, font, 24)   # 10 号菜牌是「糖」（minigames.json 的 tiles），占位
    tile.custom_minimum_size = Vector2(64, 64)
    tc.add_child(tile)
    v.add_child(tc)
    var l := _lbl(Copy.text("candy"), 36, GOLD1, HORIZONTAL_ALIGNMENT_CENTER)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(l)
    add_child(candy_root)

## 弹出来，点一下或者 CANDY_SECS 秒后收；收了才返回（截图、测试的 fast 模式不等）
func candy_popup() -> void:
    candy_token += 1
    var my := candy_token
    candy_root.visible = true
    print("[suqi] 喜糖收好了")
    if m.fast:
        return
    var t := 0.0
    while candy_root.visible and t < CANDY_SECS:
        await get_tree().process_frame
        t += get_process_delta_time()
    if my == candy_token:
        candy_root.visible = false

# ---------- 花墙合影：摆姿势 → 对焦圈靠拢时点一下 → 相纸（蓝图 3.1） ----------
func _build_photo() -> void:
    # 第 1 步：摆个姿势
    var pr := _panel(420.0)
    pose_root = pr[0]
    var ph: VBoxContainer = pr[1]
    var pv := VBoxContainer.new()
    pv.add_theme_constant_override("separation", 14)
    ph.add_child(pv)
    pv.add_child(_lbl(Copy.text("pose_title"), 24, GOLD1))
    var pr_row: Array = []
    for pose in POSES:
        pr_row.append(_grow(_btn(Copy.text("pose_" + pose), _pick_pose.bind(pose))))
    pv.add_child(_row(pr_row))
    pv.add_child(_btn(Copy.text("btn_cancel"), _close_photo))
    # 第 2 步：对焦。整屏都能点，点哪都算按快门
    focus_root = Control.new()
    focus_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    focus_root.visible = false
    var shoot := Button.new()
    shoot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for st in ["normal", "hover", "pressed", "focus"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.03, 0.02, 0.04, 0.35)
        shoot.add_theme_stylebox_override(st, sb)
    shoot.pressed.connect(_shutter)
    focus_root.add_child(shoot)
    ring_a = _ring(Color("#f4d97a"))
    ring_b = _ring(Color("#f4f1ea"))
    focus_root.add_child(ring_a)
    focus_root.add_child(ring_b)
    # C1（体验第一轮，阿鱼 9/23 加派）：「两个圈对上的时候点一下」原来是没底板的光字，压在场景上看不清。
    # 照对白框／顶上提示框一样的底框：深色底、金边，别再是光字
    focus_hint_panel = PanelContainer.new()
    focus_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    focus_hint_panel.offset_left = -240
    focus_hint_panel.offset_right = 240
    focus_hint_panel.offset_top = -260
    focus_hint_panel.offset_bottom = -220
    focus_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var hint_sb := StyleBoxFlat.new()
    hint_sb.bg_color = Color(0.106, 0.078, 0.133, 0.94)
    hint_sb.border_color = GOLD1
    hint_sb.set_border_width_all(2)
    hint_sb.set_corner_radius_all(6)
    hint_sb.content_margin_left = 14; hint_sb.content_margin_right = 14
    hint_sb.content_margin_top = 8; hint_sb.content_margin_bottom = 8
    focus_hint_panel.add_theme_stylebox_override("panel", hint_sb)
    var hint := _lbl(Copy.text("focus_hint"), 24, GOLD1, HORIZONTAL_ALIGNMENT_CENTER)
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    focus_hint_panel.add_child(hint)
    focus_root.add_child(focus_hint_panel)
    add_child(focus_root)
    # 第 3 步：相纸
    var pp := _panel(440.0)
    paper_root = pp[0]
    var paper_holder: VBoxContainer = pp[1]
    var pv2 := VBoxContainer.new()
    pv2.add_theme_constant_override("separation", 14)
    paper_holder.add_child(pv2)
    var paper := PanelContainer.new()
    var psb := StyleBoxFlat.new()
    psb.bg_color = Color("#f4f1ea")
    psb.set_content_margin_all(12)
    psb.content_margin_bottom = 36   # 相纸下沿留白厚一点，像拍立得
    paper.add_theme_stylebox_override("panel", psb)
    paper_art = Control.new()
    paper_art.custom_minimum_size = Vector2(380, 250)
    paper_art.clip_contents = true
    paper.add_child(paper_art)
    var pc := CenterContainer.new()
    pc.add_child(paper)
    pv2.add_child(pc)
    pv2.add_child(_row([_grow(_btn(Copy.text("btn_retake"), _retake)), _grow(_btn(Copy.text("btn_keep"), _keep))]))
    # 快门一闪
    flash = ColorRect.new()
    flash.color = Color(1, 1, 1, 0)
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(flash)

func _ring(col: Color) -> Panel:
    var r := Panel.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0, 0, 0, 0)
    sb.border_color = col
    sb.set_border_width_all(4)
    sb.set_corner_radius_all(60)
    r.add_theme_stylebox_override("panel", sb)
    r.size = Vector2(120, 120)
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return r

## 开始合影：先摆姿势。人停下
func start_photo() -> void:
    if panel_open():
        return
    act_btn.visible = false
    pose_root.visible = true
    panel_changed.emit(true)

func _pick_pose(pose: String) -> void:
    photo_pose = pose
    pose_root.visible = false
    focus_t = 0.0
    _place_rings()
    focus_root.visible = true
    m._say(Copy.text("photo_count"), -1.0, Copy.who("photo_count"))

func _process(dt: float) -> void:
    if focus_root != null and focus_root.visible:
        focus_t += dt
        _place_rings()

## 两个圈从两边往中间靠、再分开，来回走（蓝图 3.1：靠拢时点一下）
func _place_rings() -> void:
    var vp := get_viewport_rect().size
    var k := (1.0 - cos(focus_t * TAU / RING_PERIOD)) * 0.5   # 0 分开、1 对上
    var gap := lerpf(130.0, 0.0, k)
    var c := Vector2(vp.x * 0.5, vp.y * 0.42)
    ring_a.position = c + Vector2(-gap, 0) - ring_a.size * 0.5
    ring_b.position = c + Vector2(gap, 0) - ring_b.size * 0.5

## 按快门：什么时候点都算（早了晚了都不算失败），闪一下，出相纸
func _shutter() -> void:
    if not focus_root.visible:
        return
    focus_root.visible = false
    m.dialog.visible = false
    _compose_paper(photo_pose, m.preset)
    paper_root.visible = true
    print("[suqi] 合影 姿势 ", photo_pose)
    if m.fast:
        return
    flash.color.a = 0.9
    var tw := create_tween()
    tw.tween_property(flash, "color:a", 0.0, 0.35)

## 相纸上的「照片」：花墙、金囍、新人合照、自己的样子和姿势，全用节点拼（占位；不读显卡截图，蓝图 §6）
func _compose_paper(pose: String, preset: int) -> void:
    for c in paper_art.get_children():
        c.queue_free()
    var w := paper_art.custom_minimum_size.x
    var h := paper_art.custom_minimum_size.y
    paper_art.add_child(_rect(Rect2(0, 0, w, h), Color("#a8c48a")))
    paper_art.add_child(_rect(Rect2(0, h - 34, w, 34), Color("#c0392b")))   # 合影地毯
    var rng := RandomNumberGenerator.new()
    rng.seed = 319
    var cols := [Color("#e8746a"), Color("#f2a7c3"), Color("#f4f1ea"), Color("#c0392b")]
    for i in 70:
        paper_art.add_child(_rect(Rect2(rng.randf_range(4, w - 10), rng.randf_range(4, h - 44), 6, 5), cols[i % cols.size()]))
    var xi_bg := Panel.new()
    var xsb := StyleBoxFlat.new()
    xsb.bg_color = Color("#b0322a")
    xsb.set_corner_radius_all(30)
    xi_bg.add_theme_stylebox_override("panel", xsb)
    xi_bg.position = Vector2(w * 0.5 - 30, 10)
    xi_bg.size = Vector2(60, 60)
    paper_art.add_child(xi_bg)
    var xi := _lbl("囍", 48, Color("#d4af37"), HORIZONTAL_ALIGNMENT_CENTER)
    xi.autowrap_mode = TextServer.AUTOWRAP_OFF
    xi.position = Vector2(w * 0.5 - 30, 4)
    xi.size = Vector2(60, 60)
    paper_art.add_child(xi)
    # 新人：现有合照原图（HANDOFF §0.5），不重画
    var cp := TextureRect.new()
    cp.texture = load("res://assets/couple.png")
    cp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    cp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
    var ch := 170.0
    var cw := ch * float(cp.texture.get_width()) / float(cp.texture.get_height())
    cp.size = Vector2(cw, ch)
    cp.position = Vector2(w * 0.58, h - 22 - ch)
    paper_art.add_child(cp)
    # 自己：选的形象，朝前站着那一帧，放大；姿势是占位的小记号（招手画一只手，比心画一颗心）
    var me := TextureRect.new()
    me.texture = _front_frame(preset)
    me.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    me.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    me.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
    var mh := 160.0
    me.size = Vector2(mh * 0.5, mh)
    var mx := w * 0.3
    me.position = Vector2(mx, h - 18 - mh)
    paper_art.add_child(me)
    var hand_col := Color("#f1c9a1")
    match pose:
        "wave":
            paper_art.add_child(_rect(Rect2(mx + mh * 0.5 + 2, h - 18 - mh + 18, 10, 14), hand_col))
            paper_art.add_child(_rect(Rect2(mx + mh * 0.5 + 16, h - 18 - mh + 14, 3, 10), Color("#2c1f1c")))
            paper_art.add_child(_rect(Rect2(mx + mh * 0.5 + 22, h - 18 - mh + 20, 3, 10), Color("#2c1f1c")))
        "heart":
            paper_art.add_child(_heart(Vector2(mx + mh * 0.25, h - 18 - mh * 0.55), 12.0))
    paper_art.set_meta("pose", pose)

func _rect(r: Rect2, col: Color) -> ColorRect:
    var c := ColorRect.new()
    c.position = r.position
    c.size = r.size
    c.color = col
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return c

## 一颗心（两个圆加一个三角），比心的记号
func _heart(at: Vector2, r: float) -> Control:
    var holder := Control.new()
    holder.position = at
    holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var poly := Polygon2D.new()
    var pts := PackedVector2Array()
    for i in 12:
        var a := PI + PI * float(i) / 11.0
        pts.append(Vector2(-r * 0.5, 0) + Vector2(cos(a), sin(a)) * r * 0.55)
    for i in 12:
        var a := PI + PI * float(i) / 11.0
        pts.append(Vector2(r * 0.5, 0) + Vector2(cos(a), sin(a)) * r * 0.55)
    pts.append(Vector2(0, r * 1.2))
    poly.polygon = pts
    poly.color = Color("#e8424a")
    holder.add_child(poly)
    return holder

## 形象朝前站着那一帧（和看人卡片一样的取法）
func _front_frame(preset: int) -> Texture2D:
    var p := preset if preset >= 0 and preset <= 7 else 0
    var gl := Spr.gpt_look(p)
    if gl.is_empty():
        return Spr.portrait(p, 3)
    var at := AtlasTexture.new()
    at.atlas = gl["tex"]
    at.region = Rect2(int(gl["anim"]["down"]["idle"]) * int(gl["frame_w"]), 0, gl["frame_w"], gl["frame_h"])
    return at

func _retake() -> void:
    paper_root.visible = false
    pose_root.visible = true

## 收好：本机记一张（最多 3 张，旧的顶掉），关掉，人能走
func _keep() -> void:
    save.keep_photo(photo_pose, m.preset)
    print("[suqi] 相纸收好了 共 ", save.photos.size(), " 张")
    _close_photo()
    m._note(Copy.text("photo_kept"), 2.0)

func _close_photo() -> void:
    pose_root.visible = false
    focus_root.visible = false
    paper_root.visible = false
    panel_changed.emit(false)
    if m.court.in_spot("photo_mark") and m.state == "court":
        act_id = "photo_mark"
        _refresh_act()
        act_btn.visible = true

