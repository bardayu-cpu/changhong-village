extends Control
## 宴会厅的席面菜单和「添一道菜」（阿鱼 9/20 定的两样）：
##   左上角地名底下一块牌子「席面菜单」（体验 A1 前在右上角，被微信胶囊挡住），点开就是今天席上的菜——中午正席、晚上晚宴，按手机的真实时间切；
##   点一道菜，简介就在这张面板里展开，不切场景（阿鱼 9/20 原话）；简介底下「学做这道」跳后厅厨房（厨房还没做，先顶一句话）；
##   坐在自己桌上时底下多一个「添一道菜」：40 金一道，服务员真端过来放你桌上，摆到你离开宴会厅为止。
## 菜名、简介、几点切、多少钱全在 assets/banquet/menu.json，改字改数不改代码（菜名是阿鱼认过的定稿，别动）。
## main.gd 管走路、提示框、金币；这张面板自己的事在这里

signal panel_changed(open: bool)   # 面板开、关：main 据此让人停下、能走

const Menu = preload("res://scripts/banquet_menu.gd")
const GameCfg = preload("res://scripts/games/game_config.gd")
const GOLD := Color("#d4af37")
const GOLD1 := Color("#f4d97a")
const PAPER := Color("#efe6d8")
const MUTED := Color("#b1a6ba")

var m                        # main.gd
var font: Font
var menu                     # banquet_menu.gd
var chip: Button             # 左上角那块「席面菜单」
var root: Control            # 面板
var head: Label
var sub: Label
var list_box: VBoxContainer
var swap_btn: Button         # 「添一道菜」↔「看席面菜单」
var page := "menu"           # menu 席面菜单 / add 添菜
var open_dish := ""          # 现在展开着简介的那道菜（再点一下收起来）

func setup(main_ref, f: Font) -> void:
    m = main_ref
    font = f
    menu = Menu.new()
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _build_chip()
    _build_panel()

# ---------- 左上角那块牌子 ----------
func _build_chip() -> void:
    chip = Button.new()
    chip.text = menu.line("btn_menu")
    chip.add_theme_font_override("font", font)
    chip.add_theme_font_size_override("font_size", 24)
    chip.add_theme_color_override("font_color", GOLD1)
    for st in ["normal", "hover", "pressed", "focus", "disabled"]:
        chip.add_theme_stylebox_override(st, _sb())
    # 原来在右上角 y 66～110，落在微信胶囊按钮底下（胶囊下沿约 y 124），按不到（体验 A1）：挪到左边，地名那排下面
    chip.set_anchors_preset(Control.PRESET_TOP_LEFT)
    chip.offset_left = 14
    chip.offset_right = 164
    chip.offset_top = 66
    chip.offset_bottom = 110
    chip.visible = false
    chip.pressed.connect(open_menu)
    add_child(chip)

func _sb() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.08, 0.06, 0.1, 0.78)
    s.border_color = Color(GOLD, 0.5)
    s.set_border_width_all(1)
    s.set_corner_radius_all(10)
    s.content_margin_left = 14
    s.content_margin_right = 14
    s.content_margin_top = 8
    s.content_margin_bottom = 8
    return s

# ---------- 面板 ----------
func _build_panel() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.visible = false
    var dim := Button.new()
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for st in ["normal", "hover", "pressed", "focus"]:
        var d := StyleBoxFlat.new()
        d.bg_color = Color(0.06, 0.03, 0.06, 0.55)
        dim.add_theme_stylebox_override(st, d)
    dim.pressed.connect(close)
    root.add_child(dim)
    var cc := CenterContainer.new()
    cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(cc)
    var p := PanelContainer.new()
    p.custom_minimum_size = Vector2(470.0, 0)
    cc.add_child(p)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    p.add_child(box)
    head = _lbl("", 32, GOLD1)
    box.add_child(head)
    sub = _lbl("", 24, MUTED)
    box.add_child(sub)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0, 420)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    list_box = VBoxContainer.new()
    list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list_box.add_theme_constant_override("separation", 4)
    scroll.add_child(list_box)
    box.add_child(scroll)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    swap_btn = _btn("", _swap)
    swap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(swap_btn)
    var close_b := _btn("合上", close)
    close_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(close_b)
    box.add_child(row)
    add_child(root)

# ---------- 开、关 ----------
func open_menu() -> void:
    page = "menu"
    open_dish = ""
    _fill()
    _show(true)

func open_add() -> void:
    page = "add"
    _fill()
    _show(true)

func close() -> void:
    _show(false)

func panel_open() -> bool:
    return root != null and root.visible

## 离开宴会厅：牌子、面板都收起来（添的菜由 main 叫 hall.life.clear_orders 清）
func hide_all() -> void:
    if chip != null:
        chip.visible = false
    if root != null and root.visible:
        _show(false)

## 每帧（main._process 在宴会厅时调）：牌子什么时候露出来
func sync() -> void:
    if chip == null:
        return
    chip.visible = m.state == "banquet" and not panel_open() and not m._hall_busy()

func _show(v: bool) -> void:
    root.visible = v
    panel_changed.emit(v)

func _swap() -> void:
    if page == "menu":
        open_add()
    else:
        open_menu()

# ---------- 填内容 ----------
func _fill() -> void:
    # 先摘下来再 queue_free：queue_free 要等到这一帧末才真删，光排队的话旧行和新行会叠在一起
    for c in list_box.get_children():
        list_box.remove_child(c)
        c.queue_free()
    if page == "menu":
        _fill_menu()
    else:
        _fill_add()

func _fill_menu() -> void:
    var key: String = menu.menu_key()
    head.text = menu.line("head_midday" if key == "midday" else "head_evening")
    var ds: Array = menu.dishes(key)
    sub.text = menu.line("sub_fmt").format({"n": ds.size()})
    swap_btn.text = menu.line("btn_add")
    for i in ds.size():
        var name := str(ds[i])
        var b := _btn("%d. %s" % [i + 1, name], _tap_dish.bind(name))
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        list_box.add_child(b)
        if name != open_dish:
            continue
        # 点开的那道：简介就在这儿展开，不切场景（阿鱼 9/20）
        var txt: String = menu.intro(name)
        var intro := _lbl("　" + (txt if txt != "" else menu.line("intro_todo")), 24, PAPER if txt != "" else MUTED)
        list_box.add_child(intro)
        var learn := _btn(_learn_cfg("btn", "学做这道"), _learn.bind(name))
        learn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        list_box.add_child(learn)

func _fill_add() -> void:
    var price: int = menu.add_price()
    head.text = menu.line("add_head_fmt").format({"price": price})
    sub.text = "手上 %d 金" % _coins()
    swap_btn.text = menu.line("btn_menu")
    var can: Array = menu.addable(GameCfg.dishes(), m.games_save.dishes)
    for n in can:
        var name := str(n)
        var b := _btn("%s　%d 金" % [name, price], _tap_add.bind(name))
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.disabled = _coins() < price
        list_box.add_child(b)
    var locked: Array = menu.locked_dishes(GameCfg.dishes(), m.games_save.dishes)
    if not locked.is_empty():
        list_box.add_child(_lbl(menu.line("add_locked"), 24, MUTED))

func _tap_dish(name: String) -> void:
    open_dish = "" if open_dish == name else name
    _fill()

func _learn_cfg(key: String, fallback: String) -> String:
    return str((menu.d.get("learn", {}) as Dictionary).get(key, fallback))

func _learn(name: String) -> void:
    # 厨房那套还没做（排在菜单层后面）。做好了这里改成切后厅厨房、带上这道菜
    close()
    m._note(_learn_cfg("not_ready", "厨房还没开火 等等再来").format({"dish": name}), 3.0)

func _tap_add(name: String) -> void:
    var tid: String = m._my_table()
    if tid == "":
        close()
        m._note(menu.line("add_sit_first"), 3.0)
        return
    var life = m._hall_life()
    if life == null:
        return
    # 摆上桌的 + 还在路上的一起数：服务员端过去要几秒，只数桌上的话连点就绕过上限了（03 9/20 测出来）
    var on_table: int = life.ordered_total(tid)
    if on_table >= menu.add_max():
        close()
        m._note(menu.line("add_full"), 3.0)
        return
    var price: int = menu.add_price()
    if _coins() < price:
        close()
        m._note(menu.line("add_no_coins_fmt").format({"n": price - _coins()}), 3.0)
        return
    var paid: bool = m.games_save.spend(price)
    if not paid:
        return
    var sent: bool = life.order_dish(tid, name)
    if not sent:
        # 端不过去就把钱退回来，不能收了钱不上菜
        m.games_save.earn(price)
        return
    close()
    m._note(menu.line("add_done_fmt").format({"dish": name}), 3.0)

func _coins() -> int:
    return int(m.games_save.coins)

# ---------- 小工具 ----------
func _lbl(text: String, size := 24, color := PAPER) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(430, 0)
    return l

func _btn(text: String, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_override("font", font)
    b.add_theme_font_size_override("font_size", 24)
    b.clip_text = true
    b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    b.pressed.connect(cb)
    return b
