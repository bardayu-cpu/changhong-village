extends RefCounted
## 罗曼山庄的冒泡和对话框换样子（05 10/4，01 H 派；阿鱼：「你要做的像正常的一个像素风的游戏的文本框一样的好看」）。
## 照 04 的 12 条（godot/回执/体验-交互-第67版.md 第四节）：只有一个底部对话框（NPC、新娘、阿鱼都走它）；框高随字数、不超过屏幕 1/5；
## 选项放在框里；字一个一个出、点一下先出完整句、再点下一句；右下角像素小三角表示还有；名字牌压在框左上沿；身份卡单独放右上角带图标；
## 框、按钮、名字牌、选项全是像素九宫格（像素切角、深色外边加亮边，没有圆角、渐变、半透明）；气泡白底黑字、同屏最多两个；
## 走到头的提示改成人头顶的小气泡。
## 阿鱼 10/4 又说：「对话气泡要这个像素风的感觉，你现在的太紧实了，太严肃」→ 冒泡、框都改圆润：台阶式圆弧角（不是 45° 斜切）、
## 描边粗一点、里面留白多；另出一个「这里能点」的小提示泡（深色底白边、里面白色小图标，tap_hint），什么时候出、出在谁头上以后交 07
## 只管长什么样，不管谁先说、什么时候冒、点人走过去这些（07 写的 lounge_life.gd、lounge_ui.gd 照旧）。
## 三种配色先出给阿鱼挑（启动参数 --ui_skin=A / B / C，默认 A）：
##   A 贴 DM2 底框：深褐底、深色外边加一道亮边，头像压出框上沿
##   B 贴 RPG 蓝框的排法、喜宴纸配色：米白底、深红边、一道金线，头像在框里左边
##   C 也是 RPG 排法，深红描金：深红底、金线、米白字，头像在框里左边

const STYLES := {
    "A": {
        "layout": "dm2",
        "bubble": {"fill": "#ffffff", "edge": "#2a1d17", "rim": ""},
        "hint": {"fill": "#7a4a30", "edge": "#ffffff", "icon": "#ffffff"},
        "box": {"fill": "#2a1d17", "edge": "#0e0806", "rim": "#5a4234"},
        "plate": {"fill": "#2a1d17", "edge": "#0e0806", "rim": "#5a4234"},
        "name": "#f3c45a", "text": "#fff7e4", "more": "#f3c45a",
        "choice": {"fill": "#3c2a20", "edge": "#0e0806", "rim": "#6e5444", "text": "#fff7e4", "down": "#5a4234"},
        "tab": {"fill": "#3c2a20", "edge": "#0e0806", "rim": "#6e5444", "text": "#ffe9a8", "icon": "#f3c45a"},
    },
    "B": {
        "layout": "rpg",
        "bubble": {"fill": "#ffffff", "edge": "#5a1a12", "rim": ""},
        "hint": {"fill": "#a8241c", "edge": "#ffffff", "icon": "#ffffff"},
        "box": {"fill": "#fff7e4", "edge": "#5a1a12", "rim": "#e8b84a"},
        "plate": {"fill": "#a8241c", "edge": "#5a1a12", "rim": "#f3c45a"},
        "name": "#fff7e4", "text": "#2a1608", "more": "#a8241c",
        "choice": {"fill": "#a8241c", "edge": "#5a1a12", "rim": "#f3c45a", "text": "#fff7e4", "down": "#6e140f"},
        "tab": {"fill": "#f3c45a", "edge": "#5a1a12", "rim": "#ffe9a8", "text": "#5a1a12", "icon": "#a8241c"},
    },
    "C": {
        "layout": "rpg",
        "bubble": {"fill": "#ffffff", "edge": "#6e140f", "rim": ""},
        "hint": {"fill": "#4a1410", "edge": "#f3c45a", "icon": "#f3c45a"},
        "box": {"fill": "#4a1410", "edge": "#1a0605", "rim": "#f3c45a"},
        "plate": {"fill": "#f3c45a", "edge": "#1a0605", "rim": "#ffe9a8"},
        "name": "#4a1410", "text": "#fff7e4", "more": "#f3c45a",
        "choice": {"fill": "#7a1a12", "edge": "#1a0605", "rim": "#f3c45a", "text": "#ffe9a8", "down": "#4a0d09"},
        "tab": {"fill": "#f3c45a", "edge": "#1a0605", "rim": "#ffe9a8", "text": "#4a1410", "icon": "#a8241c"},
    },
}
const INK_TEXT := "#141414"  # 气泡字：一律纯黑（04：气泡字改黑）
const U := 2                 # 对话框里一个美术像素几个像素（界面层，540 宽算）
const BU := 2                # 冒泡里一个美术像素几个像素（冒泡在画布上，还要按镜头反着放大）
const BUBBLE_R := 9          # 冒泡圆角半径（格）：快到半个高，像胶囊那样圆（阿鱼：太紧实、太严肃）
const BUBBLE_EW := 2         # 冒泡描边几格粗（粗一点的像素描边）
const BOX_R := 8             # 对话框圆角半径（格）
const SMALL_R := 5           # 名字牌、选项、身份卡圆角半径（格）
const TYPE_CPS := 28.0       # 一秒打几个字
const BOTTOM := 40.0         # 框下沿离屏幕底多少
const SIDE := 14.0           # 框左右离屏幕边多少
const PAD := 18.0            # 框里四边留多少
const MAX_H_FRAC := 0.2      # 框最高屏幕高的 1/5（04 第 1 条）
const LINE_SIZE := 26        # 正文字号（像素字 12 的整倍渲染，26 出来是 24）
const NAME_SIZE := 24
const CHOICE_H := 48.0       # 选项每个多高（04：≥44）
const PLATE_H := 44.0        # 名字牌多高，一半压在框上沿外面
const DM2_PORTRAIT := Vector2(150, 176)   # A：头像压出框上沿
const RPG_PORTRAIT_W := 132.0              # B、C：头像在框里左边，高跟着框

static var skin := ""

static func style_name() -> String:
    if skin == "":
        skin = "A"
        for a in OS.get_cmdline_user_args():
            if a.begins_with("--ui_skin="):
                skin = a.substr(10).to_upper()
        if not STYLES.has(skin):
            skin = "A"
    return skin

static func st() -> Dictionary:
    return STYLES[style_name()]

static func _c(s: String) -> Color:
    return Color(s)

static func _rim(s: Dictionary):
    return Color(str(s["rim"])) if str(s.get("rim", "")) != "" else null

# ---------- 像素框（九宫格） ----------

## 一格一格的框：r 是圆角半径（格），角是台阶式的圆弧（像素风的圆角，不是 45° 斜切）；最外一圈 edge，往里一圈 rim（没有就是 fill），
## 再往里 fill。描边只算上下左右四个方向贴着外面的格，出来是一格细的台阶线。u 是一格几个像素。内容边距是 0（摆字由调用的人管）
static func pixel_box(fill: Color, edge: Color, rim, r: int, u: int, ew := 1) -> StyleBoxTexture:
    var m := r + 1          # 四角留位刚好包住圆弧：留多了，矮框（冒泡）的九宫格放不下，圆角就显得小
    var n := m * 2 + 1
    var inside := func(x: int, y: int) -> bool:
        if x < 0 or y < 0 or x >= n or y >= n:
            return false
        var cx := mini(x, n - 1 - x)
        var cy := mini(y, n - 1 - y)
        if cx >= r or cy >= r:
            return true
        var dx := float(r - cx) - 0.5
        var dy := float(r - cy) - 0.5
        return dx * dx + dy * dy <= float(r * r) + 0.5
    var near4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    # 每格离外面几步（上下左右走）：0～ew-1 是描边，ew 是亮边，再往里是填色
    var layer := {}
    for y in n:
        for x in n:
            if inside.call(x, y):
                layer[Vector2i(x, y)] = 99
    for y in n:
        for x in n:
            var k := Vector2i(x, y)
            if layer.has(k):
                for dv in near4:
                    if not inside.call(x + dv.x, y + dv.y):
                        layer[k] = 0
    for step in range(1, ew + 1):
        for k in layer.keys():
            if layer[k] == 99:
                for dv in near4:
                    if int(layer.get(k + dv, 99)) == step - 1:
                        layer[k] = step
    var img := Image.create(n * u, n * u, false, Image.FORMAT_RGBA8)
    for k in layer:
        var c: Color = fill
        if layer[k] < ew:
            c = edge
        elif layer[k] == ew and rim != null:
            c = rim
        img.fill_rect(Rect2i(k.x * u, k.y * u, u, u), c)
    var sb := StyleBoxTexture.new()
    sb.texture = ImageTexture.create_from_image(img)
    sb.set_texture_margin_all(m * u)
    sb.set_content_margin_all(0)
    return sb

static func _box_of(s: Dictionary, r := SMALL_R) -> StyleBoxTexture:
    return pixel_box(_c(s["fill"]), _c(s["edge"]), _rim(s), r, U)

# ---------- 冒泡 ----------

## 冒泡多大（不含小尾巴）：字宽 + 两边各 16，字高 + 上下各 11（留白多一点，不挤满；阿鱼：太紧实）
static func bubble_box_size(text: String, f: Font, size: int) -> Vector2:
    var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if f != null else float(text.length() * size)
    return Vector2(ceilf(tw) + 32.0, float(size) + 22.0)

## 小尾巴在框下沿下面多高
static func bubble_tail_h() -> float:
    return 3.0 * BU

## 冒一句：原点是小尾巴尖（对着说话的人头顶），框在原点正上方居中。回 {node, size（宽, 框高 + 尾巴）}
static func bubble(text: String, f: Font, size: int) -> Dictionary:
    var s: Dictionary = st()["bubble"]
    var b := Node2D.new()
    var bs := bubble_box_size(text, f, size)
    var tail_h := bubble_tail_h()
    var box := Panel.new()
    box.add_theme_stylebox_override("panel", pixel_box(_c(s["fill"]), _c(s["edge"]), _rim(s), BUBBLE_R, BU, BUBBLE_EW))
    box.position = Vector2(-bs.x * 0.5, -tail_h - bs.y)
    box.size = bs
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    b.add_child(box)
    var lb := Label.new()
    lb.text = text
    if f != null:
        lb.add_theme_font_override("font", f)
    lb.add_theme_font_size_override("font_size", size)
    lb.add_theme_color_override("font_color", _c(INK_TEXT))
    lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lb.size = bs
    box.add_child(lb)
    # 小尾巴：小小一个台阶三角，尖在原点；头一行压住框下沿，把那一段边「打开」
    var tail := Sprite2D.new()
    tail.texture = _tail_tex(_c(s["fill"]), _c(s["edge"]), _rim(s))
    tail.centered = false
    tail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    tail.position = Vector2(-BU * 3.5, -tail_h - BU * BUBBLE_EW)   # 头两行压住框下沿（描边两格粗），尖正好落在原点
    b.add_child(tail)
    return {"node": b, "size": Vector2(bs.x, bs.y + tail_h)}

## 小尾巴的图（一格 BU）：. 透明、O 描边、F 填色；居中、往下收成一个尖。描边两格粗，头两行压住框下沿
static func _tail_tex(fill: Color, edge: Color, _rim_unused) -> ImageTexture:
    var rows: Array = ["OOFFFOO", "OOFFFOO", ".OOFOO.", "..OOO..", "...O..."]
    var img := Image.create(rows[0].length() * BU, rows.size() * BU, false, Image.FORMAT_RGBA8)
    for y in rows.size():
        for x in (rows[y] as String).length():
            var ch: String = rows[y][x]
            if ch == ".":
                continue
            img.fill_rect(Rect2i(x * BU, y * BU, BU, BU), edge if ch == "O" else fill)
    return ImageTexture.create_from_image(img)

## 「这里能点」的小提示泡（阿鱼 10/4 第二张参考：圆角深色底、白描边、里面一个白色小图标、带小尾巴）。
## kind：talk（能聊，三个点）、tap（能点的东西，小手）。原点是小尾巴尖，放在那个人或东西头顶；只出样子，什么时候出交 07
static func tap_hint(kind: String) -> Node2D:
    var s: Dictionary = st()["hint"]
    var b := Node2D.new()
    b.name = "tap_hint"
    var sz := Vector2(19, 16) * BU
    var box := Panel.new()
    box.add_theme_stylebox_override("panel", pixel_box(_c(s["fill"]), _c(s["edge"]), null, 5, BU, 2))
    box.position = Vector2(-sz.x * 0.5, -sz.y - 3.0 * BU)
    box.size = sz
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    b.add_child(box)
    var icon := Sprite2D.new()
    icon.texture = _hint_icon(kind, _c(s["icon"]))
    icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    icon.position = box.position + sz * 0.5
    b.add_child(icon)
    var tail := Sprite2D.new()
    tail.texture = _tail_tex(_c(s["fill"]), _c(s["edge"]), null)
    tail.centered = false
    tail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    tail.position = Vector2(-BU * 3.5, -5.0 * BU)
    b.add_child(tail)
    return b

static func _hint_icon(kind: String, c: Color) -> ImageTexture:
    var rows: Array = ["XX.XX.XX", "XX.XX.XX"] if kind == "talk" else [
        "..X..",
        "..X..",
        ".XXXX",
        "XXXXX",
        ".XXX.",
    ]
    var w: int = (rows[0] as String).length()
    var img := Image.create(w * BU, rows.size() * BU, false, Image.FORMAT_RGBA8)
    for y in rows.size():
        for x in w:
            if rows[y][x] == "X":
                img.fill_rect(Rect2i(x * BU, y * BU, BU, BU), c)
    return ImageTexture.create_from_image(img)

## 人头顶冒一句、过 hold 秒收（走到头的提示用，04 第 9 条；跟冒泡同一个样子）。zoom 是镜头缩放，气泡反着放大，屏幕上一样大
static func say_at(parent: Node2D, head: Vector2, text: String, f: Font, size: int, zoom: float, hold: float) -> Node2D:
    var built: Dictionary = bubble(text, f, size)
    var b: Node2D = built["node"]
    b.name = "edge_bubble"
    b.position = head
    b.scale = Vector2.ONE / maxf(zoom, 0.2)
    b.z_index = 4
    parent.add_child(b)
    b.get_tree().create_timer(hold).timeout.connect(func():
        if is_instance_valid(b):
            b.queue_free())
    return b

# ---------- 对话框 ----------

## 搭 NPC 对话框：照旧把 ui（lounge_ui.gd）的 talk_box、name_plate、name_label、card_btn、portrait、line_label、hint_label、choices 填上，
## 名字、用途跟原来一样（07 的行为、03 的测试都认这几个）；摆法换成新的（框里摆什么、多高由 Typer 每帧算）
static func build_talk(ui, font: Font) -> void:
    var s: Dictionary = st()
    ui.talk_box = PanelContainer.new()
    ui.talk_box.name = "lounge_talk"
    ui.talk_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    ui.talk_box.offset_left = SIDE
    ui.talk_box.offset_right = -SIDE
    ui.talk_box.offset_bottom = -BOTTOM
    ui.talk_box.offset_top = -BOTTOM - 150
    ui.talk_box.add_theme_stylebox_override("panel", _box_of(s["box"], BOX_R))
    ui.talk_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    ui.talk_box.mouse_filter = Control.MOUSE_FILTER_STOP
    ui.talk_box.visible = false
    var layer := Control.new()
    layer.name = "layer"
    layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.talk_box.add_child(layer)
    ui.portrait = TextureRect.new()
    ui.portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ui.portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ui.portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    ui.portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui.portrait)
    ui.line_label = _lbl("", font, LINE_SIZE, _c(s["text"]))
    ui.line_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY   # 中文按字折
    ui.line_label.add_theme_constant_override("line_spacing", 6)
    layer.add_child(ui.line_label)
    ui.hint_label = _lbl("", font, 18, _c(s["text"]))
    ui.hint_label.visible = false   # 「点一下继续」那行字换成右下小三角；字照旧写在 hint_label 里，有字才出三角
    layer.add_child(ui.hint_label)
    # 选项：放在框里、字下面，每个整行宽（04 第 3 条）
    ui.choices = VBoxContainer.new()
    ui.choices.name = "lounge_choices"
    ui.choices.add_theme_constant_override("separation", 8)
    ui.choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.choices.visible = false
    layer.add_child(ui.choices)
    var more := _more(_c(s["more"]))
    layer.add_child(more)
    # 名字牌：压在框左上沿（04 第 5 条）；身份卡：框右上沿单独一个带图标的牌子
    ui.name_plate = _plate(s, font)
    ui.name_label = ui.name_plate.get_child(0)
    layer.add_child(ui.name_plate)
    ui.card_btn = Button.new()
    ui.card_btn.name = "lounge_card_tab"
    style_button(ui.card_btn, s["tab"], font, 24, 8)
    ui.card_btn.icon = _card_icon(_c(s["tab"]["icon"]), _c(s["tab"]["edge"]))
    ui.card_btn.add_theme_constant_override("h_separation", 8)
    ui.card_btn.visible = false
    layer.add_child(ui.card_btn)
    var typer := Typer.new()
    typer.name = "typer"
    typer.box = ui.talk_box
    typer.label = ui.line_label
    typer.hint = ui.hint_label
    typer.portrait = ui.portrait
    typer.plate = ui.name_plate
    typer.card = ui.card_btn
    typer.choices = ui.choices
    typer.more = more
    typer.rpg = str(s["layout"]) == "rpg"
    typer.instant = ui.m != null and bool(ui.m.get("fast"))
    ui.talk_box.add_child(typer)
    ui.add_child(ui.talk_box)

## 阿鱼说话那个框（main.gd 的 dialog，原来在屏幕上边一条）：挪到屏幕下边、换成跟 NPC 对话框一样的框和名字牌（04 第 2、6 条）。
## 什么时候出、停多久照旧是 main._say
static func restyle_say(m) -> void:
    var s: Dictionary = st()
    var d: PanelContainer = m.dialog
    d.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    d.offset_left = SIDE
    d.offset_right = -SIDE
    d.offset_bottom = -BOTTOM
    d.offset_top = -BOTTOM - 110
    d.add_theme_stylebox_override("panel", _box_of(s["box"], BOX_R))
    d.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var old_v: Node = d.get_child(0)
    var layer := Control.new()
    layer.name = "layer"
    layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    d.remove_child(old_v)
    d.add_child(layer)
    # 名字：原来那个 dialog_who 挪进名字牌
    var plate := _plate(s, m.font)
    var tmp: Label = plate.get_child(0)
    plate.remove_child(tmp)
    tmp.queue_free()
    var who: Label = m.dialog_who
    who.get_parent().remove_child(who)
    who.add_theme_color_override("font_color", _c(s["name"]))
    who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    who.autowrap_mode = TextServer.AUTOWRAP_OFF   # 原来是会折行的，挪进牌子里会被挤成一个字宽
    who.add_theme_font_size_override("font_size", NAME_SIZE)
    plate.add_child(who)
    plate.visible = true
    layer.add_child(plate)
    var txt: Label = m.dialog_text
    txt.get_parent().remove_child(txt)
    txt.add_theme_color_override("font_color", _c(s["text"]))
    txt.add_theme_font_size_override("font_size", LINE_SIZE)
    txt.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
    txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    txt.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    layer.add_child(txt)
    old_v.queue_free()
    var typer := Typer.new()
    typer.name = "typer"
    typer.box = d
    typer.label = txt
    typer.plate = plate
    typer.rpg = true
    typer.instant = bool(m.get("fast"))
    d.add_child(typer)

static func _plate(s: Dictionary, font: Font) -> PanelContainer:
    var p := PanelContainer.new()
    p.name = "lounge_name"
    var sb := _box_of(s["plate"])
    sb.content_margin_left = 20
    sb.content_margin_right = 20
    sb.content_margin_top = 4
    sb.content_margin_bottom = 4
    p.add_theme_stylebox_override("panel", sb)
    p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.visible = false
    var l := _lbl("", font, NAME_SIZE, _c(s["name"]))
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    p.add_child(l)
    return p

static func _lbl(t: String, font: Font, size: int, col: Color) -> Label:
    var l := Label.new()
    l.text = t
    if font != null:
        l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", col)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

## 「还有」小三角：4 行台阶（宽 7、5、3、1 格），一格 U×2 宽、3 高
static func _more(c: Color) -> Control:
    var more := Control.new()
    more.name = "more"
    more.mouse_filter = Control.MOUSE_FILTER_IGNORE
    more.size = Vector2(28, 12)
    more.draw.connect(func():
        for r in 4:
            more.draw_rect(Rect2(r * U * 2, r * 3, (7 - r * 2) * U * 2, 3), c))
    return more

## 身份卡的小图标：一张小卡片（像素画，一格 U）：左上一个小人头，右边两道横线
static func _card_icon(c: Color, edge: Color) -> ImageTexture:
    var rows := [
        "OOOOOOOOOOO",
        "OCCCCCCCCCO",
        "OCEECCCCCCO",
        "OCEECEEEECO",
        "OCCCCCCCCCO",
        "OCEEECEEECO",
        "OCCCCCCCCCO",
        "OOOOOOOOOOO",
    ]
    var img := Image.create(11 * U, 8 * U, false, Image.FORMAT_RGBA8)
    for y in rows.size():
        for x in (rows[y] as String).length():
            var ch: String = rows[y][x]
            var col: Color = edge if ch == "O" else (Color("#fff7e4") if ch == "C" else c)
            img.fill_rect(Rect2i(x * U, y * U, U, U), col)
    return ImageTexture.create_from_image(img)

## 选项按钮、身份卡牌子：像素框底子、按下换深一档
static func style_button(b: Button, s: Dictionary, font: Font, size := 26, pad := 12) -> void:
    var n := _box_of(s)
    n.content_margin_left = pad + 8
    n.content_margin_right = pad + 8
    n.content_margin_top = pad
    n.content_margin_bottom = pad
    var p := pixel_box(_c(str(s.get("down", s["fill"]))), _c(s["edge"]), _rim(s), SMALL_R, U)
    p.content_margin_left = pad + 8
    p.content_margin_right = pad + 8
    p.content_margin_top = pad + 2
    p.content_margin_bottom = pad - 2
    for k in ["normal", "hover", "focus", "disabled"]:
        b.add_theme_stylebox_override(k, n)
    b.add_theme_stylebox_override("pressed", p)
    if font != null:
        b.add_theme_font_override("font", font)
    b.add_theme_font_size_override("font_size", size)
    for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        b.add_theme_color_override(k, _c(s["text"]))
    b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

static func style_choice(b: Button, font: Font) -> void:
    style_button(b, st()["choice"], font, LINE_SIZE, 8)
    b.custom_minimum_size = Vector2(0, CHOICE_H)
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT

## 打字到一半吗（lounge_ui 点一下先出完整句用）
static func typing(box: Control) -> bool:
    var t = box.get_node_or_null("typer")
    return t != null and t.typing()

static func finish(box: Control) -> void:
    var t = box.get_node_or_null("typer")
    if t != null:
        t.finish()

## 每帧：框里摆东西、框多高（随字数和选项，不超过屏幕 1/5，有选项时可以高到放得下）、字一个个出、小三角一闪一闪
class Typer extends Node:
    var box: Control
    var label: Label
    var hint: Label
    var portrait: TextureRect
    var plate: Control
    var card: Control
    var choices: Control
    var more: Control
    var rpg := false
    var instant := false     # 截图、测试（main.fast）：不打字，整句直接出
    var _last := ""
    var _t := 0.0
    var _blink := 0.0

    func typing() -> bool:
        return label.visible_characters >= 0 and label.visible_characters < label.text.length()

    func finish() -> void:
        label.visible_characters = -1

    func _process(dt: float) -> void:
        if not box.visible:
            if card != null:
                card.visible = false
            return
        var vw: float = box.get_viewport_rect().size.x
        var vh: float = box.get_viewport_rect().size.y
        var w: float = vw - SIDE * 2.0
        var has_face: bool = portrait != null and portrait.visible and portrait.texture != null
        var x0 := PAD
        if has_face:
            x0 = (DM2_PORTRAIT.x + 10.0) if not rpg else (PAD + RPG_PORTRAIT_W + 12.0)
        var tw := w - x0 - PAD - 30.0   # 右边留给小三角
        var top := PAD + 10.0           # 名字牌压在上沿，字从牌子下面一点起
        label.position = Vector2(x0, top)
        label.size = Vector2(tw, 0)
        label.reset_size()
        label.size.x = tw
        var text_h := maxf(label.get_combined_minimum_size().y, float(LINE_SIZE))
        var h := top + text_h + PAD
        var ch_on: bool = choices != null and choices.visible
        if ch_on:
            var n := 0
            for c in choices.get_children():
                if not c.is_queued_for_deletion():
                    n += 1
            choices.position = Vector2(x0, top + text_h + 10.0)
            choices.size = Vector2(w - x0 - PAD, n * CHOICE_H + maxi(n - 1, 0) * 8.0)
            h = choices.position.y + choices.size.y + PAD
        var hmin := 112.0
        if has_face and rpg:
            hmin = 150.0
        h = clampf(h, hmin, maxf(vh * MAX_H_FRAC, hmin) if not ch_on else 400.0)
        box.offset_top = -BOTTOM - h
        if has_face:
            if rpg:
                portrait.size = Vector2(RPG_PORTRAIT_W, h - PAD * 1.4)
                portrait.position = Vector2(PAD, PAD * 0.7)
            else:
                portrait.size = DM2_PORTRAIT
                portrait.position = Vector2(4, h - DM2_PORTRAIT.y - 6.0)
        # 名字牌压在框左上沿，一半在外面；A 有头像时牌子挪到头像右边
        plate.reset_size()
        var px := 12.0 if (rpg or not has_face) else x0 - 8.0
        plate.position = Vector2(px, -PLATE_H * 0.5)
        plate.size = Vector2(plate.get_combined_minimum_size().x, PLATE_H)
        if card != null:
            card.visible = plate.visible
            card.reset_size()
            card.size = Vector2(card.get_combined_minimum_size().x, PLATE_H)
            card.position = Vector2(w - card.size.x - 12.0, -PLATE_H * 0.5)
        if more != null:
            more.position = Vector2(w - PAD - 28.0, h - PAD - 10.0)
        # 字一个个出
        var txt: String = label.text
        if txt != _last:
            _last = txt
            _t = 0.0
            label.visible_characters = -1 if instant else 0
        if typing():
            _t += dt
            label.visible_characters = mini(txt.length(), int(_t * TYPE_CPS) + 1)
            if label.visible_characters >= txt.length():
                label.visible_characters = -1
        # 小三角：有「点一下继续」那句（没选项）、字出完了才出，一闪一闪
        _blink += dt
        if more != null:
            more.visible = hint != null and hint.text != "" and not ch_on and not typing() and fmod(_blink, 1.0) < 0.6
