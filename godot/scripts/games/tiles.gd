extends RefCounted
## 席间小游戏共用的画法：菜牌 = 圆角方块的底 + GPT 交的那张菜图（`assets/minigames/tiles/dish_NN.png`，
## 交接单 handoff_minigames_shared_dish_tiles_v1，01 9/20 验收过，128×128 PNG）。
## **序号就是交接单的 index，绝对不能错位**（尤其 10 号是喜糖）：minigames.json 的 tiles 第 N 条配 dish_NN.png。
## 图缺了就退回原来的占位（一个颜色方块 + 一个字），不至于满屏空白。几个游戏都从这拿，长得一样

const Cfg = preload("res://scripts/games/game_config.gd")
const INK := Color("#2c1f1c")
const ART := "res://assets/minigames/tiles/dish_%02d.png"
const ART_PAD := 0.08        # 图四周留一圈，别顶着描边

static var _art: Dictionary = {}   # 序号 -> Texture2D（没有这张图就存 null，不用每次都去试）

## 交接单那 12 张图里的第 kind 张；没有返回 null
static func dish_art(kind: int) -> Texture2D:
    if not _art.has(kind):
        var path := ART % kind
        _art[kind] = load(path) if ResourceLoader.exists(path) else null
    return _art[kind]

## 一张菜牌：kind 是 tiles 里的序号（超出就轮回去），size 边长（屏幕像素），font_size 字号（像素字体要 12 的倍数）。
## caption 不是空串就写这几个字（小菜合大菜要的：那一级叫什么名字，光看图看不出先后）；
## 空串时有图就只放图，没图退回原来的「色块 + tiles 里那个字」。
## **别在外面去摸这个 Panel 的孩子**（有图没图孩子不一样，9/20 换图时 2048 就是这么崩的），要写字就用 caption
static func dish_tile(kind: int, size: float, font: Font, font_size := 24, caption := "") -> Panel:
    var tl: Array = Cfg.tiles()
    var n := kind % tl.size() if not tl.is_empty() else kind
    var t: Dictionary = tl[n] if not tl.is_empty() else {"ch": "?", "bg": "#cccccc"}
    var p := Panel.new()
    p.size = Vector2(size, size)
    p.add_theme_stylebox_override("panel", box(Color(str(t["bg"]))))
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var tex := dish_art(n)
    if tex != null:
        var r := TextureRect.new()
        r.texture = tex
        r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        var pad := size * ART_PAD
        r.position = Vector2(pad, pad)
        r.size = Vector2(size - pad * 2.0, size - pad * 2.0)
        r.mouse_filter = Control.MOUSE_FILTER_IGNORE
        p.add_child(r)
        if caption != "":
            # 名字压在图下沿，底下垫一条深色带子，压在花花绿绿的菜上也读得出来
            var strip := ColorRect.new()
            strip.color = Color(0.09, 0.06, 0.11, 0.72)
            strip.size = Vector2(size, float(font_size) + 6.0)
            strip.position = Vector2(0, size - strip.size.y - 3.0)
            strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
            p.add_child(strip)
            var cl := Label.new()
            cl.text = caption
            cl.add_theme_font_override("font", font)
            cl.add_theme_font_size_override("font_size", font_size)
            cl.add_theme_color_override("font_color", Color("#f4d97a"))
            cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            cl.clip_text = true
            cl.size = strip.size
            cl.position = strip.position
            cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
            p.add_child(cl)
        return p
    # 图还没到（或者缺了这一张）：还是原来那个色块加一个字
    var l := Label.new()
    l.text = caption if caption != "" else str(t["ch"])
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
