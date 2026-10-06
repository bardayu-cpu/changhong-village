extends RefCounted
## 麻将牌面（娱乐室「摸两把」，庄Z2 10/6；阿鱼：牌面「没事就用 A」= 真麻将牌）：代码画，不用图。
## 34 种：0～8 一～九万、9～17 一～九条、18～26 一～九筒、27～33 东南西北中发白。
## 牌：米白牌面、深色描边、下边一截绿色牌背（看得出是一张立着的牌）；跟连连看的牌一样是 Panel，选中高亮照旧走 Tiles.highlight
## 提审被当成牌类卡住时，换「喜牌」只改这一份（玩家说明第「风险」节）

const Tiles = preload("res://scripts/games/tiles.gd")
const IVORY := Color("#f4ecd6")
const EDGE := Color("#5a4632")
const BACK := Color("#2f7a4f")
const RED := Color("#c0281e")
const GREEN := Color("#2f7a4f")
const BLUE := Color("#24407a")
const INK := Color("#1d1a24")
const NUM := ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
const WORDS := ["东", "南", "西", "北", "中", "发", "白"]
const COUNT := 34

## 一张牌（size 见方）
static func tile(face: int, size: float, font: Font) -> Panel:
    var p := Panel.new()
    p.size = Vector2(size, size)
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var sb := Tiles.box(IVORY, 4, EDGE)
    sb.border_width_bottom = maxi(4, int(size * 0.09))   # 下边粗一截：牌背的厚度
    sb.border_color = EDGE
    p.add_theme_stylebox_override("panel", sb)
    p.set_meta("border0", EDGE)
    p.set_meta("border_w0", 2)
    p.set_meta("face", face)
    var back := ColorRect.new()   # 牌背那条绿边
    back.color = BACK
    back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    back.position = Vector2(3, size - maxf(4.0, size * 0.09) - 1.0)
    back.size = Vector2(size - 6, maxf(3.0, size * 0.05))
    p.add_child(back)
    var d := Face.new()
    d.face = face
    d.font = font
    d.position = Vector2(4, 3)
    d.size = Vector2(size - 8, size - maxf(4.0, size * 0.09) - 6.0)
    d.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_child(d)
    return p

## 这一把用哪几种牌（kinds 种，不重样，打乱）
static func pick(kinds: int, rng: RandomNumberGenerator) -> Array:
    var all: Array = []
    for i in COUNT:
        all.append(i)
    for i in range(all.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var t = all[i]
        all[i] = all[j]
        all[j] = t
    return all.slice(0, kinds)

## 牌名（测试、日志用）
static func name_of(face: int) -> String:
    if face < 9:
        return NUM[face] + "万"
    if face < 18:
        return NUM[face - 9] + "条"
    if face < 27:
        return NUM[face - 18] + "筒"
    return WORDS[face - 27]

class Face extends Control:
    var face := 0
    var font: Font

    func _draw() -> void:
        var w := size.x
        var h := size.y
        if face < 9:          # 万：上面数字，下面红「万」
            _text(NUM[face], Vector2(w * 0.5, h * 0.3), h * 0.38, BLUE)
            _text("万", Vector2(w * 0.5, h * 0.76), h * 0.4, RED)
        elif face < 18:       # 条：一根根竹签
            _sticks(face - 9 + 1, w, h)
        elif face < 27:       # 筒：圆饼
            _dots(face - 18 + 1, w, h)
        else:
            var wd: String = WORDS[face - 27]
            if wd == "白":    # 白板：一个蓝框
                var r := Rect2(w * 0.22, h * 0.18, w * 0.56, h * 0.64)
                draw_rect(r, BLUE, false, maxf(2.0, w * 0.06))
            else:
                _text(wd, Vector2(w * 0.5, h * 0.52), h * 0.62, RED if wd == "中" else (GREEN if wd == "发" else INK))

    func _text(s: String, at: Vector2, px: float, c: Color) -> void:
        if font == null:
            return
        var fs := maxi(8, int(px))
        var sz := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
        draw_string(font, Vector2(at.x - sz.x * 0.5, at.y + fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)

    ## 排法：n 个格点（列、行）都按 0～1 算
    static func _layout(n: int) -> Array:
        match n:
            1: return [Vector2(0.5, 0.5)]
            2: return [Vector2(0.5, 0.25), Vector2(0.5, 0.75)]
            3: return [Vector2(0.25, 0.2), Vector2(0.5, 0.5), Vector2(0.75, 0.8)]
            4: return [Vector2(0.28, 0.25), Vector2(0.72, 0.25), Vector2(0.28, 0.75), Vector2(0.72, 0.75)]
            5: return [Vector2(0.25, 0.2), Vector2(0.75, 0.2), Vector2(0.5, 0.5), Vector2(0.25, 0.8), Vector2(0.75, 0.8)]
            6: return [Vector2(0.3, 0.18), Vector2(0.7, 0.18), Vector2(0.3, 0.5), Vector2(0.7, 0.5), Vector2(0.3, 0.82), Vector2(0.7, 0.82)]
            7: return [Vector2(0.2, 0.14), Vector2(0.5, 0.26), Vector2(0.8, 0.38), Vector2(0.3, 0.62), Vector2(0.7, 0.62), Vector2(0.3, 0.86), Vector2(0.7, 0.86)]
            8: return [Vector2(0.3, 0.13), Vector2(0.7, 0.13), Vector2(0.3, 0.38), Vector2(0.7, 0.38), Vector2(0.3, 0.62), Vector2(0.7, 0.62), Vector2(0.3, 0.87), Vector2(0.7, 0.87)]
            _: return [Vector2(0.2, 0.18), Vector2(0.5, 0.18), Vector2(0.8, 0.18), Vector2(0.2, 0.5), Vector2(0.5, 0.5), Vector2(0.8, 0.5), Vector2(0.2, 0.82), Vector2(0.5, 0.82), Vector2(0.8, 0.82)]

    func _dots(n: int, w: float, h: float) -> void:
        var pts := _layout(n)
        var r := minf(w, h) * (0.3 if n == 1 else (0.16 if n <= 4 else 0.12))
        var cols := [BLUE, GREEN, RED]
        for i in pts.size():
            var c: Vector2 = Vector2(pts[i].x * w, pts[i].y * h)
            draw_circle(c, r, cols[i % 3] if n != 1 else RED)
            draw_circle(c, r * 0.5, IVORY)
            draw_circle(c, r * 0.22, cols[i % 3] if n != 1 else GREEN)

    func _sticks(n: int, w: float, h: float) -> void:
        if n == 1:   # 一条：一根粗竹加红顶（真牌是只鸟，像素小牌上画一根大竹子代替）
            var r := Rect2(w * 0.4, h * 0.12, w * 0.2, h * 0.76)
            draw_rect(r, GREEN)
            draw_rect(Rect2(r.position.x, h * 0.45, r.size.x, h * 0.06), IVORY)
            draw_circle(Vector2(w * 0.5, h * 0.12), w * 0.12, RED)
            return
        var pts := _layout(n)
        var sw := maxf(2.0, w * 0.1)
        var sh := h * (0.34 if n <= 6 else 0.22)
        for i in pts.size():
            var c: Vector2 = Vector2(pts[i].x * w, pts[i].y * h)
            var col: Color = RED if (n == 5 or n == 7 or n == 9) and i == pts.size() / 2 else GREEN
            draw_rect(Rect2(c.x - sw * 0.5, c.y - sh * 0.5, sw, sh), col)
            draw_rect(Rect2(c.x - sw * 0.5, c.y - 1.0, sw, 2.0), IVORY)
