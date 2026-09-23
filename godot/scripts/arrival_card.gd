extends PanelContainer
## 进厅小卡（01 9/23 派活「进厅先见人」，体验评审 0923 改法一）：以后每次进宴会厅，先弹这张卡，
## **最多三行，每行一个人一件事**：敬了你的（旁边「回敬一杯」）→ 在你这桌簿子上接了话的（旁边「翻簿子」）→ 你走后来过的；
## 人多了第三行合成「还有 N 位来过」。排哪几行、谁在前，服务端 enterHall 的 arrival.rows 已经排好（rules/banquet.js arrivalCard），
## 这里只管画。**点一下卡就收起**；也会自己收（HOLD 秒）。没有新鲜事服务端回 hasNews:false，main 根本不建这张卡。
## 顶上原来那一行「老王敬了你一杯，簿子上多了 2 句」+ 旁边的「回敬一杯」并进了这张卡（体验 B6：三层框叠在一起）

signal toast_back(openid: String, info: Dictionary)
signal open_book
signal closed

const HOLD := 15.0
const GOLD1 := Color("#f4d97a")
const PAPER := Color("#efe6d8")
const NICK_MAX := 6
## 每一行的字，新写，等阿鱼定（收在 回执/等阿鱼定的字.md）
const LINE_TOAST_1 := "%s 敬了你一杯"
const LINE_TOAST_N := "%s 敬了你 %d 杯"
const LINE_BOOK_1 := "%s 在你这桌簿子上写了一句"
const LINE_BOOK_N := "%s 在你这桌簿子上写了 %d 句"
const LINE_VISIT := "%s 你走后来过"
const LINE_MORE := "还有 %d 位来过"
const BTN_TOAST_BACK := "回敬一杯"   # 和原来提示右边那个按钮一个字
const BTN_BOOK := "翻簿子"           # 和走到桌边冒出来的按钮一个字

var font: Font
var rows_box: VBoxContainer
var left := HOLD
var people: Array[String] = []   # 卡上说到的人（main 让厅里坐着的这几位站起来朝我举杯）

func setup(p_font: Font, rows: Array, names: Dictionary) -> void:
    font = p_font
    mouse_filter = Control.MOUSE_FILTER_STOP
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.106, 0.078, 0.133, 0.94)   # 和顶上提示框一个底色、一个金边
    sb.border_color = GOLD1
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(6)
    sb.set_content_margin_all(12)
    add_theme_stylebox_override("panel", sb)
    rows_box = VBoxContainer.new()
    rows_box.add_theme_constant_override("separation", 6)
    rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(rows_box)
    for r_any in rows:
        if typeof(r_any) != TYPE_DICTIONARY:
            continue
        var r: Dictionary = r_any
        var kind := str(r.get("kind", ""))
        var who := str(r.get("who", ""))
        var n := int(r.get("count", 1))
        var info: Dictionary = names.get(who, {})
        var nick := short_nick(str(info.get("nick", "")))
        var text := ""
        var btn := ""
        match kind:
            "toast":
                text = (LINE_TOAST_1 % nick) if n <= 1 else (LINE_TOAST_N % [nick, n])
                btn = BTN_TOAST_BACK
            "book":
                text = (LINE_BOOK_1 % nick) if n <= 1 else (LINE_BOOK_N % [nick, n])
                btn = BTN_BOOK
            "visit":
                text = LINE_VISIT % nick
            "more":
                text = LINE_MORE % n
            _:
                continue
        if who != "":
            people.append(who)
        _add_row(text, btn, kind, who, info)

## 昵称最长 12 个字，一行放不下：截到 6 个字加省略号；没有昵称写「有人」
static func short_nick(s: String) -> String:
    if s == "":
        return "有人"
    return s if s.length() <= NICK_MAX else s.substr(0, NICK_MAX) + "…"

func _add_row(text: String, btn_text: String, kind: String, who: String, info: Dictionary) -> void:
    var row := HBoxContainer.new()
    row.name = "row_" + kind
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_theme_constant_override("separation", 10)
    var l := Label.new()
    l.text = text
    l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", 24)
    l.add_theme_color_override("font_color", GOLD1 if kind != "more" else PAPER)
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    l.clip_text = true
    l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(l)
    if btn_text != "":
        var b := Button.new()
        b.name = "btn"
        b.text = btn_text
        b.add_theme_font_override("font", font)
        b.add_theme_font_size_override("font_size", 24)
        b.focus_mode = Control.FOCUS_NONE
        if kind == "toast":
            b.pressed.connect(func():
                b.disabled = true   # 点一次就收，不能连点（和原来的回敬按钮一样）
                toast_back.emit(who, info)
                close())
        else:
            b.pressed.connect(func():
                open_book.emit()
                close())
        row.add_child(b)
    rows_box.add_child(row)

func _process(dt: float) -> void:
    left -= dt
    if left <= 0.0:
        close()

## 点卡上没有按钮的地方：收起
func _gui_input(e: InputEvent) -> void:
    if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
        accept_event()
        close()

func close() -> void:
    if is_queued_for_deletion():
        return
    closed.emit()
    queue_free()
