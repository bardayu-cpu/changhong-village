extends Control
## 迎宾院的界面（蓝图 3.1，灰盒，01 9/19 派）：走近交互点时底部冒出的按钮、签到面板（名字 → 礼金 → 确认）、喜糖弹窗。
## main.gd 管走路、切画布、说话框和提示框；迎宾院自己的事在这里，要说话、提示、调云函数都回到 main（_say、_note、cloud）。
## 字都在 assets/entrance/lines.json（court_copy.gd 读），这里不写死

signal panel_changed(open: bool)   # 面板开、关：main 据此让人停下、能走

const Copy = preload("res://scripts/court_copy.gd")
const Tiles = preload("res://scripts/games/tiles.gd")
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
var sign_name := ""
var sign_gift := 0
var busy := false          # 签到请求在路上
var candy_root: Control
var candy_token := 0

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

## 有面板开着（开着时人不能走）
func panel_open() -> bool:
    return sign_root.visible or candy_root.visible

## 离开迎宾院（进宴会厅、回开场）：按钮、面板都收起来
func hide_all() -> void:
    act_id = ""
    act_btn.visible = false
    if sign_root.visible:
        _close_sign()
    candy_root.visible = false

## 走进、走出交互点（main 的 _on_court_spot 转过来）
func spot(id: String, inside: bool) -> void:
    if id != "sign_in":
        return
    if inside:
        act_id = id
        _refresh_act()
        act_btn.visible = true
    elif act_id == id:
        act_id = ""
        act_btn.visible = false

func _refresh_act() -> void:
    match act_id:
        "sign_in":
            # 重进山庄不重复签到，签到桌只显示「已签到」（蓝图 3.1 交互说明）
            act_btn.text = Copy.text("btn_signed") if save.signed_in else Copy.text("btn_sign")
            act_btn.disabled = save.signed_in

func _on_act() -> void:
    match act_id:
        "sign_in":
            open_sign()

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
    p1.add_child(_btn(Copy.text("btn_back"), func(): _show_page(0)))
    # 第 3 页：确认，写明「只是游戏里的记录」
    var p2 := _page(holder)
    p2.add_child(_lbl(Copy.text("confirm_title"), 24, GOLD1))
    confirm_name = _lbl("")
    p2.add_child(confirm_name)
    confirm_gift = _lbl("")
    p2.add_child(confirm_gift)
    p2.add_child(_lbl(Copy.text("confirm_note"), 24, MUTED))
    confirm_ok = _btn(Copy.text("btn_ok"), _submit)
    p2.add_child(_row([_grow(_btn(Copy.text("btn_back"), func(): _show_page(1))), _grow(confirm_ok)]))

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
