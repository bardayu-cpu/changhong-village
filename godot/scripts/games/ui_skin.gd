extends RefCounted
## 席间小游戏的外壳 UI（GPT 第 1 批 + 金币 v2，01 D 9/30 派；交接单 handoff_minigames_ui_v1 / v2，03 量过：回执/量尺-小游戏外壳和金币.md）。
## 图在 assets/minigames/ui/，这里只管「拿图、做成 StyleBox／NinePatch／小图」，外壳和三个游戏各自往上贴。
## **哪张图缺了就回 null**，调用的地方照旧用原来代码画的那套（StyleBoxFlat、色块），不至于一片空白。
## 只有 SKINNED 里这三个宴会厅游戏换外壳；翻牌、打地鼠、接彩头照旧（01 这次只派了三个）
## 格子底 base_ui_cell_v1、配对特效 decal_ui_matched_v1 是半透明的：01 D 定「界面底和特效允许半透明，0/255 那条只管场景零件」，照接

const DIR := "res://assets/minigames/ui/"
const SKINNED := ["lianliankan", "match3", "g2048"]
## 九宫格边（交接单 nine_slice）
const FRAME_M := 24
const CARD_M := 16
const BTN_M := 8
const BOARD_M := 16
const INK := Color("#2c1f1c")
const GOLD1 := Color("#f4d97a")

static var _tex: Dictionary = {}

static func tex(name: String) -> Texture2D:
    if not _tex.has(name):
        var p := DIR + name + ".png"
        _tex[name] = load(p) if ResourceLoader.exists(p) else null
    return _tex[name]

static func on(game_id: String) -> bool:
    return game_id in SKINNED and tex("base_ui_frame_v1") != null

## 九宫格的图做成 StyleBox（卡片、按钮、棋盘底）；图缺了回 null
static func box(name: String, m: int, content := -1) -> StyleBoxTexture:
    var t := tex(name)
    if t == null:
        return null
    var s := StyleBoxTexture.new()
    s.texture = t
    s.texture_margin_left = m
    s.texture_margin_top = m
    s.texture_margin_right = m
    s.texture_margin_bottom = m
    var c := float(m if content < 0 else content)
    s.content_margin_left = c
    s.content_margin_right = c
    s.content_margin_top = c
    s.content_margin_bottom = c
    return s

## 九宫格铺一块（外壳边框、顶栏、棋盘底）：图缺了回 null
static func patch(name: String, m: int) -> NinePatchRect:
    var t := tex(name)
    if t == null:
        return null
    var r := NinePatchRect.new()
    r.texture = t
    r.patch_margin_left = m
    r.patch_margin_top = m
    r.patch_margin_right = m
    r.patch_margin_bottom = m
    r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return r

## 一张小图原样摆（金币、钟）：size 边长；图缺了回 null
static func icon(name: String, size: float) -> TextureRect:
    var t := tex(name)
    if t == null:
        return null
    var r := TextureRect.new()
    r.texture = t
    r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    r.size = Vector2(size, size)
    r.custom_minimum_size = Vector2(size, size)
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return r

## 按钮换皮：main 主按钮（红底金边，字用金色）；否则次按钮（米色底金边，字用深色）。图缺了按钮照旧
static func skin_button(b: Button, main: bool) -> void:
    var n := "base_ui_btn_main_v1" if main else "base_ui_btn_sub_v1"
    var np := "base_ui_btn_main_pressed_v1" if main else "base_ui_btn_sub_pressed_v1"
    var s := _btn_box(n)
    if s == null:
        return
    var sp := _btn_box(np)
    if sp == null:
        sp = s
    b.add_theme_stylebox_override("normal", s)
    b.add_theme_stylebox_override("hover", s)
    b.add_theme_stylebox_override("focus", s)
    b.add_theme_stylebox_override("pressed", sp)
    b.add_theme_stylebox_override("disabled", s)
    var fc: Color = GOLD1 if main else INK
    for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
        b.add_theme_color_override(k, fc)

## 按钮底：九宫格 8；两头有菱形花，字左右各让 22，不压花
static func _btn_box(name: String) -> StyleBoxTexture:
    var s := box(name, BTN_M)
    if s != null:
        s.content_margin_left = 22
        s.content_margin_right = 22
        s.content_margin_top = 6
        s.content_margin_bottom = 6
    return s

## 卡片底（开始卡、结算卡、歇一下）：米色纸，里面一圈深红细框、四角红菱形、上下各一道金点花边。
## 九宫格照这些花留边（左右 48、上下 90），拉大缩小花不变形；字写在里面，用深色（纸是浅的）
const CARD_ML := 48
const CARD_MT := 90
const CARD_INK := Color("#2c1f1c")
const CARD_HEAD := Color("#6e1e1e")
static func card_box() -> StyleBoxTexture:
    var t := tex("base_ui_card_v1")
    if t == null:
        return null
    var s := StyleBoxTexture.new()
    s.texture = t
    s.texture_margin_left = CARD_ML
    s.texture_margin_right = CARD_ML
    s.texture_margin_top = CARD_MT
    s.texture_margin_bottom = CARD_MT
    return s

## 格子底（每一格空着时看得见）：一张 128 的图缩到格子大小
static func cell(size: float) -> TextureRect:
    var r := icon("base_ui_cell_v1", size)
    if r != null:
        r.stretch_mode = TextureRect.STRETCH_SCALE
    return r

## 选中框：比格子大一圈（144:128），盖在那张牌上面、居中
static func select_frame(cell_size: float) -> TextureRect:
    var s := cell_size * 144.0 / 128.0
    var r := icon("decal_ui_select_v1", s)
    if r != null:
        r.stretch_mode = TextureRect.STRETCH_SCALE
        r.position = Vector2(-(s - cell_size) * 0.5, -(s - cell_size) * 0.5)
        r.name = "select_frame"
    return r

## 配对成功／消掉／合成那一下：在 center（parent 里的坐标）冒一个星星，放大一点、0.35 秒淡掉
static func pop(parent: Node, center: Vector2, cell_size: float) -> void:
    var s := cell_size * 1.4
    var r := icon("decal_ui_matched_v1", s)
    if r == null:
        return
    r.stretch_mode = TextureRect.STRETCH_SCALE
    r.position = center - Vector2(s, s) * 0.5
    r.pivot_offset = Vector2(s, s) * 0.5
    r.scale = Vector2(0.6, 0.6)
    r.z_index = 5
    parent.add_child(r)
    var tw := r.create_tween()
    tw.set_parallel(true)
    tw.tween_property(r, "scale", Vector2(1.1, 1.1), 0.35)
    tw.tween_property(r, "modulate:a", 0.0, 0.35).set_delay(0.1)
    tw.chain().tween_callback(r.queue_free)

## 连连看的连线换成这张图一截截铺（32×32 的一小段金条）
static func skin_line(line: Line2D) -> void:
    var t := tex("tex_ui_link_v1")
    if t == null:
        return
    line.texture = t
    line.texture_mode = Line2D.LINE_TEXTURE_TILE
    line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    line.width = 24.0
    line.default_color = Color.WHITE
