extends RefCounted
## 席间小游戏共用的画法：菜牌 = 圆角方块的底 + GPT 交的那张菜图（`assets/minigames/tiles/dish_NN.png`，
## 交接单 handoff_minigames_shared_dish_tiles_v1，01 9/20 验收过，128×128 PNG）。
## **序号就是交接单的 index，绝对不能错位**（尤其 10 号是喜糖）：minigames.json 的 tiles 第 N 条配 dish_NN.png。
## 图缺了就退回原来的占位（一个颜色方块 + 一个字），不至于满屏空白。几个游戏都从这拿，长得一样

const Cfg = preload("res://scripts/games/game_config.gd")
const INK := Color("#2c1f1c")
## 两套图，别混（`回执/GPT出图清单-席间小游戏.md` 第一节 vs 第二节，本来就是分开列的）：
##   shared —— 五个游戏共用的 12 张菜牌（鱼、菜、豆、酒……），GPT 9/20 交了，已接进来
##   crop_01…crop_11 —— 小菜合大菜每一关那种作物的十级图（阿鱼 9/20：每关一种植物），**GPT 还没交**
##   pattern —— 翻牌配对的喜庆纹样（喜字、双喜、如意、同心结这类 12 张，阿鱼 9/20 定不再用菜），**GPT 还没交**
## 拿级数去共用那 12 张里取会错位（一级「花生」取到鱼的图，03 9/20 报的）。
## 阶梯图到了往 assets/minigames/ladder/ 一放就自动用上，代码一行都不用改
## 哪个游戏用哪一套，写在 minigames.json 每个游戏的 art_set 里（改配置不改代码）。
## **套名不在这张表里也认**：一律按 assets/minigames/<套名>/step_NN.png 找图（见 ART_ANY）。
## 所以小菜合大菜加第 N 种作物，只要把十张图放进 crop_NN/，代码和 json 都不用再动
const ART := {
    "shared": "res://assets/minigames/tiles/dish_%02d.png",
    "pattern": "res://assets/minigames/pattern/sign_%02d.png",
}
const ART_ANY := "res://assets/minigames/%s/step_%02d.png"
## 一张一个菜／一个纹样的那两套，少一张就退一张，不牵连整盘；
## 作物那种成阶梯的套不一样——**十级少一张就整盘退回色块**，不许半图半色块（01 9/20 定，03 9/21 测出来）
const ART_PER_TILE := ["shared", "pattern"]

static var _ready: Dictionary = {}   # 套名 -> 这套图齐不齐（查一次记着，别每画一格就问十次文件）
const ART_PAD := 0.08        # 图四周留一圈，别顶着描边

static var _art: Dictionary = {}   # "套名:序号" -> Texture2D（没有这张图就存 null，不用每次都去试）

## 这一套图齐不齐：`shared`／`pattern` 那种一张一个的永远算「齐」（少一张退一张就行）；
## 作物那种成阶梯的要 step_00 到 step_(n-1) **一张不缺**才算齐，缺一张就整套不用，那一关整盘退回色块 + 名字。
## 结果记在 _ready 里，一套只查一次
static func art_ready(art_set: String, n: int) -> bool:
    if art_set == "":
        return false
    if ART_PER_TILE.has(art_set):
        return true
    if not _ready.has(art_set):
        var all := true
        for i in n:
            if not ResourceLoader.exists(ART_ANY % [art_set, i]):
                all = false
                break
        _ready[art_set] = all
    return bool(_ready[art_set])

## 某一套图里的第 kind 张；没有返回 null（那就退回色块 + 字）
static func dish_art(kind: int, art_set := "shared") -> Texture2D:
    if art_set == "":
        return null
    var key := "%s:%d" % [art_set, kind]
    if not _art.has(key):
        var path := (str(ART[art_set]) % kind) if ART.has(art_set) else (ART_ANY % [art_set, kind])
        _art[key] = load(path) if ResourceLoader.exists(path) else null
    return _art[key]

## 一张菜牌：kind 是 tiles 里的序号（超出就轮回去），size 边长（屏幕像素），font_size 字号（像素字体要 12 的倍数）。
## caption 不是空串就写这几个字（小菜合大菜要的：那一级叫什么名字，光看图看不出先后）；
## 空串时有图就只放图，没图退回原来的「色块 + tiles 里那个字」。
## art_set 选哪一套图（见上面 ART）：五个游戏用 shared，小菜合大菜用 ladder。
## keep_bg：有图时还画不画底下那个色块。**默认不画**——阿鱼 9/20 真机原话「每个图都不是透明底，很奇怪」，
## 就是这个色块顶在透明图后面。**只有翻牌配对传 true**：那是一张「牌」，牌需要一个面。
## **别在外面去摸这个 Panel 的孩子**（有图没图孩子不一样，9/20 换图时 2048 就是这么崩的），要写字就用 caption
static func dish_tile(kind: int, size: float, font: Font, font_size := 24, caption := "", art_set := "shared", keep_bg := false) -> Panel:
    var tl: Array = Cfg.tiles()
    var n := kind % tl.size() if not tl.is_empty() else kind
    var t: Dictionary = tl[n] if not tl.is_empty() else {"ch": "?", "bg": "#cccccc"}
    var p := Panel.new()
    p.size = Vector2(size, size)
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # 阶梯、纹样那两套按级数/序号直取（不轮回，缺了就是缺了，退回色块），共用那套按 tiles 的序号取
    var tex := dish_art(kind if art_set != "shared" else n, art_set)
    # 有图又不用留底：底色和描边都透明，只剩那张透明图（描边宽度留着，选中时 highlight 把它染成金的）
    var show_bg: bool = tex == null or keep_bg
    var border0: Color = INK if show_bg else Color(0, 0, 0, 0)
    p.add_theme_stylebox_override("panel", box(Color(str(t["bg"])) if show_bg else Color(0, 0, 0, 0), 6, border0))
    # 选中了再取消时要恢复成这个样子，别一律写回 INK（03 9/20：有图的牌会多出一圈深色边）
    p.set_meta("border0", border0)
    p.set_meta("border_w0", 2)
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

## 菜牌的底：圆角、深色描边、下沿一道暗边（有点厚度）。border 传透明色就是「只占位不显形」，
## 留着宽度是为了选中时 highlight 能把它染成金的
static func box(bg: Color, radius := 6, border := INK) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(2)
    s.border_width_bottom = 4
    s.set_corner_radius_all(radius)
    return s

## 选中、高亮时换的底。**取消选中要恢复成这张牌原来的样子**：
## 有图的牌描边本来是透明的，一律写回 INK 就会多出一圈深色边（03 9/20 在三消和连连看都看到了）。
## 原来什么样记在 meta 里（dish_tile 建牌时存的），没存过的按老规矩当 INK
static func highlight(p: Panel, on: bool) -> void:
    var s: StyleBoxFlat = (p.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
    var base: Color = p.get_meta("border0", INK)
    var w: int = int(p.get_meta("border_w0", 2))
    s.border_color = Color("#f4d97a") if on else base
    s.set_border_width_all(4 if on else w)
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
