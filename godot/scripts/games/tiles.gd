extends RefCounted
## 席间小游戏共用的画法（占位）：菜牌 = 一种菜一个颜色的圆角方块 + 一个字（minigames.json 的 tiles），
## 正式美术到了换成图。几个游戏都从这拿，长得一样

const Cfg = preload("res://scripts/games/game_config.gd")
const INK := Color("#2c1f1c")

## 一张菜牌：kind 是 tiles 里的序号（超出就轮回去），size 边长（屏幕像素），font_size 字号（像素字体要 12 的倍数）
static func dish_tile(kind: int, size: float, font: Font, font_size := 24) -> Panel:
    var tl: Array = Cfg.tiles()
    var t: Dictionary = tl[kind % tl.size()] if not tl.is_empty() else {"ch": "?", "bg": "#cccccc"}
    var p := Panel.new()
    p.size = Vector2(size, size)
    p.add_theme_stylebox_override("panel", box(Color(str(t["bg"]))))
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var l := Label.new()
    l.text = str(t["ch"])
    l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", INK)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.size = p.size
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_child(l)
    return p

## 菜牌的底：圆角、深色描边、下沿一道暗边（有点厚度）
static func box(bg: Color, radius := 6) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = INK
    s.set_border_width_all(2)
    s.border_width_bottom = 4
    s.set_corner_radius_all(radius)
    return s

## 选中、高亮时换的底
static func highlight(p: Panel, on: bool) -> void:
    var s: StyleBoxFlat = (p.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
    s.border_color = Color("#f4d97a") if on else INK
    s.set_border_width_all(4 if on else 2)
    s.border_width_bottom = 4
    p.add_theme_stylebox_override("panel", s)

## 普通文字
static func label(text: String, font: Font, size := 24, color := Color("#efe6d8")) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l
