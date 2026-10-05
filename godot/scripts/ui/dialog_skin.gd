extends RefCounted
## 全游戏的对话框和头顶冒泡长什么样（05 10/4，01 H 派）。照阿鱼的定稿图一模一样（docs/参考图/对话框定稿-阿鱼10-04.png，main 48cfaa3；
## 阿鱼：「完全不对，我要的是这样」）。图是像素画但线不严格对格子（按钮亮边只有半格、边缘发虚），切出来会糊，所以照它用代码画，颜色从图里取：
##   - 框：深褐底，外一圈深色、里一圈金棕的双线，四个角金线往里收出台阶、空出来的角上一个金色小 L 角花
##   - 头像：后面不垫底块，人直接从框上沿顶出来，只到胸口（阿鱼：「到人物的胸部以上就好了」）：头大半在框外、肩膀和胸口上半截在框里，名字牌压在胸口下面，放大 3 倍
##   - 话那块一页最多 2 行（阿鱼 10/5）；超过 2 行右边出一对上、下翻页小三角，玩家点着翻，点框不翻页
##   - 名字牌：深底、金棕边、黄字，前面一个米白像素小身份证（阿鱼：图标是身份证的意思，不是对话泡）；压在头像下面、框左下角
##   - 话：米白字（带“”，07 在 map69 加），头像右边上半部分
##   - 按钮：红底，里一圈浅橘亮边、下面一截暗一点，深红描边，四个角各一颗金色小方钉，白字；一样宽、铺满右边那一行，中间留一道空
## 冒泡白底（阿鱼：「白底，注意像素风」）。全部像素硬边。先前的米白版、手画版都作废。
## 排法（阿鱼先前的话，照旧）：
##   「身份卡只用 icon 放到名字前就行了，点击头像就可以展开；NPC 的话放在对话框大部分，超长可以点翻页；最后一行放选择 btn，通用一行展示完成。
##    其他 npc 的小气泡也用同样的配色」
##   - 头像在框左边、往上顶出框的上沿；名字牌压在头像下边，名字前一个身份卡小图标；点头像（或名字牌）展开身份卡
##   - 说的话占框里大部分（头像右边）；一屏放不下点一下翻页，右下角小三角表示还有
##   - 最后一行放选项，所有选项排一行放完
##   - 没头像的（新娘、阿鱼）：名字牌照旧在左下，不放图
## 再加 04 的 12 条（godot/回执/体验-交互-第67版.md 第四节）：只有一个底部对话框；框高不超过屏幕 1/5（有选项时放得下为止）；
## 字一个一个出、点一下先出完、再点下一页 / 下一句；像素九宫格（台阶式小圆角、深色外边、一道稍亮的里线，没有平滑圆角、渐变、半透明）；
## 冒泡圆润（阿鱼：「你现在的太紧实了，太严肃」）、同屏最多两个；走到头的提示是人头顶的小气泡；「这里能点」小提示泡只出样子（交 07）。
## 只管长什么样，谁先说、什么时候冒、点人走过去照旧是 07 的 lounge_life.gd、lounge_ui.gd

## 颜色都是从定稿图里量的（框外 (22,12,5)、金棕 (191,128,68)、底 (49,30,21)；按钮描边 (62,3,3)、亮边 (248,168,112)、红 (203,28,28)、下截 (164,25,26)；
## 钉 (255,240,178)/(255,216,66)/(240,170,40)；话、按钮字、图标 (250,242,228)；名字 (242,194,62)）
## 色值都在 scripts/ui/ui_kit.gd（公共·界面组件，罗-1）；这里只按部位分好
const UI = preload("res://scripts/ui/ui_kit.gd")
const PAL := {
    "bubble": {"fill": UI.BUBBLE_BG, "edge": UI.BUBBLE_EDGE, "rim": null},
    "hint": {"fill": UI.BG, "edge": UI.LINE, "icon": UI.TEXT},
    "box": {"fill": UI.BG, "edge": UI.EDGE, "rim": UI.LINE},
    "plate": {"fill": UI.BG, "edge": UI.EDGE, "rim": UI.LINE},
    "name": UI.NAME, "arrow": UI.NAME, "icon": UI.TEXT, "text": UI.TEXT, "more": UI.TEXT, "bubble_text": UI.BUBBLE_TEXT,
    "choice": {"fill": UI.RED, "band": UI.RED_DARK, "edge": UI.RED_EDGE, "rim": UI.RED_RIM, "text": UI.TEXT, "down": UI.RED_DARK, "down_band": UI.RED_DOWN_BAND,
        "stud_l": UI.STUD_LIGHT, "stud": UI.STUD, "stud_d": UI.STUD_DARK},
}
const U := 2                 # 对话框里一个美术像素几个像素（界面层，540 宽算）
const BU := 2                # 冒泡里一个美术像素几个像素（冒泡在画布上，还要按镜头反着放大）
const BUBBLE_R := 9          # 冒泡圆角半径（格）：快到半个高，像胶囊那样圆
const BUBBLE_EW := 2         # 冒泡描边几格粗
const SMALL_R := 2           # 「这里能点」提示泡圆角半径（格）
const FU := 3                # 对话框、名字牌的线一格几个像素（定稿图一格约 10.5 像素，框 1702 宽折成 512：一格约 3.2）
const TYPE_CPS := 28.0       # 一秒打几个字
const BOTTOM := 40.0         # 框下沿离屏幕底多少
const SIDE := 14.0           # 框左右离屏幕边多少
const PAD := 16.0            # 框里四边留多少
const PAGE_LINES := 2        # 话那块一页几行（阿鱼 10/5：「右边展示 2 行文本的位置，超过 2 行长度出现上下翻页三角形手动翻页」）
const ARROW := 44.0          # 翻页三角能点的那块多大（≥ 44×44）；话那块右边让出这一列
const MIN_H := 124.0         # 框最矮多高：定稿图框高 409 / 1702 宽，折成 512 宽约 123（一行话 + 一行按钮）
const LINE_SIZE := 26        # 正文、按钮字号：定稿图字高 72 / 1702 宽，折成 512 宽约 22，正是像素字 24 那一档（像素字只能 12 的整倍清楚：26 出来是 24；上一档 36、下一档 12）
const LINE_GAP := 6.0
const NAME_SIZE := 24
const CHOICE_H := 48.0       # 选项多高（04：≥44，量出来按钮露在外面的约少 4）
const CHOICE_GAP := 23.0     # 按钮中间空多少：定稿图 75 / 1702，折成约 23
const CHOICE_IN := 19.0      # 按钮比话往右缩多少：定稿图话（带左引号）从 625 起、按钮从 690 起，折成约 19
const CHOICE_RIGHT := 26.0   # 按钮右边离框外沿多少：定稿图 85，折成约 26
const CHOICE_GAP_TIGHT := 6.0     # 照图的间距放不下（奶奶三个四字选项）时：间距收到 6、左边跟话对齐、右边收到 12
const CHOICE_RIGHT_TIGHT := 12.0
const CHOICE_PADX := 6.0     # 按钮字两边至少留多少（描边 3 + 亮边 2 + 1）
const CHOICE_MIN_W := 88.0    # 按钮最窄（01：能点的范围宽 ≥88、高 ≥44）
const PLATE_H := 40.0        # 名字牌多高
const FACE := Vector2(112, 129)   # 头像那块多大（不垫底、只用来裁）：只到胸口（阿鱼 10/5）——3 倍时人物图第 0～42 行（头顶到领口下第一颗扣子）= 129 高；
                                  # 下沿接名字牌上沿，往上顶出框约 51、下巴在框里约 48（定稿图也是约 48）；3 倍时人连肩宽 108，那块 112 不切左右
const FACE_K := 3.0          # 头像放大几倍：阿鱼 10/5「头可以小到现在的 0.8x，不要放太大就有点糊」——4 × 0.8 = 3.2 不是整数倍反而更糊，用 3 倍（约 0.75，最接近、清楚）
const PLATE_W := 136.0       # 名字牌最窄：定稿图 450 宽，折成约 136
const COL_W := 132.0         # 左边一栏多宽（头像、名字牌）：话从 PAD + COL_W + 12 = 160 起（定稿图左引号从 162 起）

## 画好的像素图按参数存着，同样的框、小尖只画一次（冒泡一会儿冒一个，每次都现画，测试快进时整套慢了一半多）
static var _tex_cache := {}

static func _c(s) -> Color:
    return s if s is Color else Color(str(s))

static func _rim(s: Dictionary):
    return s["rim"] if s.get("rim") is Color else null

# ---------- 像素框（九宫格） ----------

## 一格一格的框：r 是圆角半径（格），角是台阶式的圆弧（像素风的圆角，不是 45° 斜切）；最外 ew 圈 edge，往里一圈 rim（没有就是 fill），
## 再往里 fill。描边按上下左右四个方向算，出来是台阶线。u 是一格几个像素。内容边距是 0（摆字由调用的人管）
static func pixel_box(fill: Color, edge: Color, rim, r: int, u: int, ew := 1) -> StyleBoxTexture:
    var m := r + 1          # 四角留位刚好包住圆弧：留多了，矮框（冒泡）的九宫格放不下，圆角就显得小
    var key := "box %s %s %s %d %d %d" % [fill.to_html(), edge.to_html(), rim.to_html() if rim != null else "-", r, u, ew]
    if _tex_cache.has(key):
        return _sb_of(_tex_cache[key], m * u)
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
    for k in layer.keys():
        for dv in near4:
            if not inside.call(k.x + dv.x, k.y + dv.y):
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
    _tex_cache[key] = ImageTexture.create_from_image(img)
    return _sb_of(_tex_cache[key], m * u)

## 每次给一个新的 StyleBoxTexture（调用的人会改内容边距），图共用
static func _sb_of(tex: Texture2D, margin: int) -> StyleBoxTexture:
    var sb := StyleBoxTexture.new()
    sb.texture = tex
    sb.set_texture_margin_all(margin)
    sb.set_content_margin_all(0)
    return sb

static func _box_of(s: Dictionary, r := SMALL_R) -> StyleBoxTexture:
    return pixel_box(_c(s["fill"]), _c(s["edge"]), _rim(s), r, U)

## 照左上角的字符图画九宫格（另外三个角照它翻过来）：. 透明、# 外边、G 金棕、f 底；最后一行、最后一列就是直边的样子，
## 中间一格往外拉。u 是一格几个像素
static func _map_box(key: String, corner: Array, cols: Dictionary, u: int) -> StyleBoxTexture:
    var m: int = corner.size()
    if not _tex_cache.has(key):
        var n := m * 2 + 1
        var img := Image.create(n * u, n * u, false, Image.FORMAT_RGBA8)
        for y in n:
            for x in n:
                var cx := mini(mini(x, n - 1 - x), m - 1)
                var cy := mini(mini(y, n - 1 - y), m - 1)
                var ch: String = (corner[cy] as String)[cx]
                if ch != ".":
                    img.fill_rect(Rect2i(x * u, y * u, u, u), cols[ch])
        _tex_cache[key] = ImageTexture.create_from_image(img)
    return _sb_of(_tex_cache[key], m * u)

## 对话框：外一圈深色、里一圈金棕；角上金线往里收出台阶，空出来的地方一个金色小 L 角花（定稿图四个角）
const BOX_CORNER := [
    ".######",
    "#GG#GGG",
    "#G##Gff",
    "####Gff",
    "#GGGGff",
    "#Gfffff",
    "#Gfffff",
]
static func box_frame() -> StyleBoxTexture:
    var s: Dictionary = PAL["box"]
    return _map_box("frame box", BOX_CORNER, {"#": _c(s["edge"]), "G": _c(s["rim"]), "f": _c(s["fill"])}, FU)

## 名字牌：同样的双线，角上缺一格（定稿图名字牌的角是一个小台阶）
const PLATE_CORNER := [
    ".###",
    "##GG",
    "#Gff",
    "#Gff",
]
static func plate_frame() -> StyleBoxTexture:
    var s: Dictionary = PAL["plate"]
    return _map_box("frame plate", PLATE_CORNER, {"#": _c(s["edge"]), "G": _c(s["rim"]), "f": _c(s["fill"])}, FU)

## 按钮（一像素一像素画）：深红描边 3、浅橘亮边 2、红底，下面一截暗一点；四个角各一颗金色小方钉（3×3 格、一格 2 像素，左上亮右下暗）；
## 最外角缺一像素。down 是按下去的样子（底子深一档）
static func choice_frame(down: bool) -> StyleBoxTexture:
    var key := "choice %s" % down
    var m := 13
    if not _tex_cache.has(key):
        var s: Dictionary = PAL["choice"]
        var fill := _c(s["down"] if down else s["fill"])
        var band := _c(s["down_band"] if down else s["band"])
        var stud := [[_c(s["stud_l"]), _c(s["stud"]), _c(s["stud"])], [_c(s["stud"]), _c(s["stud"]), _c(s["stud_d"])], [_c(s["stud"]), _c(s["stud_d"]), _c(s["stud_d"])]]
        var n := m * 2 + 1
        var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
        for y in n:
            for x in n:
                var dx := mini(x, n - 1 - x)
                var dy := mini(y, n - 1 - y)
                var c: Color
                if dx + dy < 1:
                    continue
                elif mini(dx, dy) < 3:
                    c = _c(s["edge"])
                elif mini(dx, dy) < 5:
                    c = _c(s["rim"])
                elif y > n - 1 - 10:
                    c = band          # 下面一截暗一点（定稿图约一格半）
                else:
                    c = fill
                if dx >= 3 and dx < 9 and dy >= 3 and dy < 9:   # 角上的钉：盖住亮边的拐角
                    var sx := (x - 3) / 2 if x < m else (x - (n - 9)) / 2
                    var sy := (y - 3) / 2 if y < m else (y - (n - 9)) / 2
                    c = stud[clampi(sy, 0, 2)][clampi(sx, 0, 2)]
                img.set_pixel(x, y, c)
        _tex_cache[key] = ImageTexture.create_from_image(img)
    return _sb_of(_tex_cache[key], m)

## 名字前的小图标：像素小身份证（阿鱼：「名字旁边的 icon 是身份证的意思」）：米白卡片，左边一个小人（头、肩膀），右边三条横线
static func _id_icon(c: Color, dot: Color) -> ImageTexture:
    var key := "idicon %s" % c.to_html()
    if _tex_cache.has(key):
        return _tex_cache[key]
    var rows := [
        "WWWWWWWWWWWWWW",
        "WWWWWWWWWWWWWW",
        "WWddWWddddddWW",
        "WWddWWWWWWWWWW",
        "WWWWWWddddWWWW",
        "WddddWWWWWWWWW",
        "WddddWddddddWW",
        "WWWWWWWWWWWWWW",
    ]
    var img := Image.create(14 * U, rows.size() * U, false, Image.FORMAT_RGBA8)
    for y in rows.size():
        for x in 14:
            var ch: String = rows[y][x]
            if ch != ".":
                img.fill_rect(Rect2i(x * U, y * U, U, U), c if ch == "W" else dot)
    _tex_cache[key] = ImageTexture.create_from_image(img)
    return _tex_cache[key]

# ---------- 冒泡 ----------

## 冒泡多大（不含小尾巴）：字宽 + 两边各 16，字高 + 上下各 11（留白多一点，不挤满；阿鱼：太紧实）
static func bubble_box_size(text: String, f: Font, size: int) -> Vector2:
    var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if f != null else float(text.length() * size)
    return Vector2(ceilf(tw) + 32.0, float(size) + 22.0)

## 小尾巴在框下沿下面多高
static func bubble_tail_h() -> float:
    return 3.0 * BU

## 冒泡的框（标题页、别处要单独用这个底子时拿）
static func bubble_box() -> StyleBoxTexture:
    var s: Dictionary = PAL["bubble"]
    return pixel_box(_c(s["fill"]), _c(s["edge"]), _rim(s), BUBBLE_R, BU, BUBBLE_EW)

## 冒一句：原点是小尾巴尖（对着说话的人头顶），框在原点正上方居中。回 {node, size（宽, 框高 + 尾巴）}
static func bubble(text: String, f: Font, size: int) -> Dictionary:
    var s: Dictionary = PAL["bubble"]
    var b := Node2D.new()
    var bs := bubble_box_size(text, f, size)
    var tail_h := bubble_tail_h()
    var box := Panel.new()
    box.add_theme_stylebox_override("panel", bubble_box())
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
    lb.add_theme_color_override("font_color", _c(PAL["bubble_text"]))
    lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lb.size = bs
    box.add_child(lb)
    var tail := Sprite2D.new()
    tail.texture = tail_tex(_c(s["fill"]), _c(s["edge"]))
    tail.centered = false
    tail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    tail.position = Vector2(-BU * 3.5, -tail_h - BU * BUBBLE_EW)   # 头两行压住框下沿（描边两格粗），尖正好落在原点
    b.add_child(tail)
    return {"node": b, "size": Vector2(bs.x, bs.y + tail_h)}

## 小尾巴的图（一格 BU）：. 透明、O 描边、F 填色；居中、往下收成一个尖。描边两格粗，头两行压住框下沿
static func tail_tex(fill: Color, edge: Color) -> ImageTexture:
    var key := "tail %s %s" % [fill.to_html(), edge.to_html()]
    if _tex_cache.has(key):
        return _tex_cache[key]
    var rows: Array = ["OOFFFOO", "OOFFFOO", ".OOFOO.", "..OOO..", "...O..."]
    var img := Image.create(rows[0].length() * BU, rows.size() * BU, false, Image.FORMAT_RGBA8)
    for y in rows.size():
        for x in (rows[y] as String).length():
            var ch: String = rows[y][x]
            if ch == ".":
                continue
            img.fill_rect(Rect2i(x * BU, y * BU, BU, BU), edge if ch == "O" else fill)
    _tex_cache[key] = ImageTexture.create_from_image(img)
    return _tex_cache[key]

## 「这里能点」的小提示泡（阿鱼 10/4 参考：圆角底、描边、里面一个小图标、带小尾巴；配色跟冒泡一套）。
## kind：talk（能聊，三个点）、tap（能点的东西，小手）。原点是小尾巴尖，放在那个人或东西头顶；只出样子，什么时候出交 07
static func tap_hint(kind: String) -> Node2D:
    var s: Dictionary = PAL["hint"]
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
    tail.texture = tail_tex(_c(s["fill"]), _c(s["edge"]))
    tail.centered = false
    tail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    tail.position = Vector2(-BU * 3.5, -5.0 * BU)
    b.add_child(tail)
    return b

static func _hint_icon(kind: String, c: Color) -> ImageTexture:
    var key := "icon %s %s" % [kind, c.to_html()]
    if _tex_cache.has(key):
        return _tex_cache[key]
    var rows: Array = ["XX.XX.XX", "XX.XX.XX"] if kind == "talk" else ["..X..", "..X..", ".XXXX", "XXXXX", ".XXX."]
    var w: int = (rows[0] as String).length()
    var img := Image.create(w * BU, rows.size() * BU, false, Image.FORMAT_RGBA8)
    for y in rows.size():
        for x in w:
            if rows[y][x] == "X":
                img.fill_rect(Rect2i(x * BU, y * BU, BU, BU), c)
    _tex_cache[key] = ImageTexture.create_from_image(img)
    return _tex_cache[key]

## 人头顶冒一句、过 hold 秒收（走到头的提示，04 第 9 条；跟冒泡同一个样子）。zoom 是镜头缩放，气泡反着放大，屏幕上一样大
static func say_at(parent: Node2D, head: Vector2, text: String, f: Font, size: int, zoom: float, hold: float) -> Node2D:
    # 同一时间只留一个（03 测出：旧的 queue_free 了还没走，新的重名被改成 @Node2D@…，第三次按名字就删不到，连顶几次叠好几个）：
    # 先把组里的旧气泡马上摘下来再删，名字空出来，新的就叫 edge_bubble
    for old in parent.get_tree().get_nodes_in_group("edge_bubble"):
        if old.get_parent() != null:
            old.get_parent().remove_child(old)
        old.queue_free()
    var built: Dictionary = bubble(text, f, size)
    var b: Node2D = built["node"]
    b.name = "edge_bubble"
    b.add_to_group("edge_bubble")
    b.position = head
    b.scale = Vector2.ONE / maxf(zoom, 0.2)
    b.z_index = 4
    parent.add_child(b)
    b.get_tree().create_timer(hold).timeout.connect(b.queue_free)   # 接气泡自己：提前删掉时连接跟着断，不会到点再去碰已删的
    return b

# ---------- 对话框 ----------

## 搭 NPC 对话框：照旧把 ui（lounge_ui.gd）的 talk_box、name_plate、name_label、card_btn、portrait、line_label、hint_label、choices 填上，
## 名字、用途跟原来一样（07 的行为、03 的测试都认这几个）。line_label 照旧装着整句（行为、测试读它），屏上显示的是 Typer 里那一页。
## card_btn 留着（测试、行为都按它开身份卡）但不显示：身份卡改成点头像 / 名字牌展开（阿鱼）
static func build_talk(ui, font: Font) -> void:
    ui.talk_box = PanelContainer.new()
    ui.talk_box.name = "lounge_talk"
    _frame(ui.talk_box, MIN_H)
    ui.talk_box.mouse_filter = Control.MOUSE_FILTER_STOP
    ui.talk_box.visible = false
    var layer := Control.new()
    layer.name = "layer"
    layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.talk_box.add_child(layer)
    # 头像框：点了展开身份卡
    var face := Panel.new()
    face.name = "face"
    face.add_theme_stylebox_override("panel", StyleBoxEmpty.new())   # 头像后面不垫底块（定稿图）：人直接从框上沿顶出来
    face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    face.mouse_filter = Control.MOUSE_FILTER_STOP
    face.gui_input.connect(func(e):
        if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed and ui.talk_id != "":
            ui.open_card(ui.talk_id)
            face.accept_event())
    layer.add_child(face)
    ui.portrait = TextureRect.new()
    ui.portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ui.portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ui.portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    ui.portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    face.add_child(ui.portrait)
    ui.line_label = lbl("", font, LINE_SIZE, _c(PAL["text"]))
    ui.line_label.visible = false   # 装整句（行为、测试读）；屏上显示 Typer 的那一页
    layer.add_child(ui.line_label)
    ui.hint_label = lbl("", font, 18, _c(PAL["text"]))
    ui.hint_label.visible = false   # 「点一下继续」那行字换成右下小三角；字照旧写在这里，有字才出三角
    layer.add_child(ui.hint_label)
    # 选项：最后一行，所有选项排一行（阿鱼）
    ui.choices = HBoxContainer.new()
    ui.choices.name = "lounge_choices"
    ui.choices.add_theme_constant_override("separation", int(CHOICE_GAP))
    ui.choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.choices.visible = false
    layer.add_child(ui.choices)
    # 名字牌：压在头像下边，名字前一个身份卡小图标；点了也展开身份卡
    ui.name_plate = _plate(font, true)
    ui.name_label = ui.name_plate.get_meta("label")
    ui.name_plate.mouse_filter = Control.MOUSE_FILTER_STOP
    ui.name_plate.gui_input.connect(func(e):
        if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed and ui.talk_id != "":
            ui.open_card(ui.talk_id)
            ui.name_plate.accept_event())
    layer.add_child(ui.name_plate)
    ui.card_btn = Button.new()
    ui.card_btn.name = "lounge_card_btn"
    ui.card_btn.visible = false
    layer.add_child(ui.card_btn)
    var t := Typer.new()
    t.name = "typer"
    t.box = ui.talk_box
    t.src = ui.line_label
    t.hint = ui.hint_label
    t.face = face
    t.portrait = ui.portrait
    t.plate = ui.name_plate
    t.card = ui.card_btn
    t.choices = ui.choices
    t.font = font
    t.instant = ui.m != null and bool(ui.m.get("fast"))
    t.ui = ui
    t.setup(layer)
    ui.talk_box.add_child(t)
    ui.add_child(ui.talk_box)

## 阿鱼说话那个框（main.gd 的 dialog，原来在屏幕上边一条）：挪到屏幕下边、换成同一个框和名字牌（没头像：不生成阿鱼的形象，HANDOFF §0.5）。
## 什么时候出、停多久照旧是 main._say
static func restyle_say(m) -> void:
    var d: PanelContainer = m.dialog
    _frame(d, MIN_H * 0.8)
    var old_v: Node = d.get_child(0)
    d.remove_child(old_v)
    var layer := Control.new()
    layer.name = "layer"
    layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    d.add_child(layer)
    var plate := _plate(m.font, false)
    var who: Label = m.dialog_who
    var tmp: Label = plate.get_meta("label")
    tmp.get_parent().remove_child(tmp)
    tmp.queue_free()
    who.get_parent().remove_child(who)
    who.add_theme_color_override("font_color", _c(PAL["name"]))
    who.add_theme_font_size_override("font_size", NAME_SIZE)
    who.autowrap_mode = TextServer.AUTOWRAP_OFF
    who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    (plate.get_child(0) as HBoxContainer).add_child(who)
    plate.set_meta("label", who)
    plate.visible = true
    layer.add_child(plate)
    var txt: Label = m.dialog_text
    txt.get_parent().remove_child(txt)
    txt.visible = false
    layer.add_child(txt)
    old_v.queue_free()
    var t := Typer.new()
    t.name = "typer"
    t.box = d
    t.src = txt
    t.plate = plate
    t.font = m.font
    t.instant = bool(m.get("fast"))
    t.m = m
    t.setup(layer)
    d.add_child(t)

static func _frame(p: PanelContainer, h: float) -> void:
    p.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    p.offset_left = SIDE
    p.offset_right = -SIDE
    p.offset_bottom = -BOTTOM
    p.offset_top = -BOTTOM - h
    p.grow_vertical = Control.GROW_DIRECTION_BEGIN
    p.add_theme_stylebox_override("panel", box_frame())
    p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## 名字牌：深底、金棕双线边、黄字，with_icon 时名字前一个米白像素小身份证
static func _plate(font: Font, with_icon: bool) -> PanelContainer:
    var p := PanelContainer.new()
    p.name = "lounge_name"
    var sb := plate_frame()
    sb.content_margin_left = 16
    sb.content_margin_right = 16
    sb.content_margin_top = 2
    sb.content_margin_bottom = 2
    p.add_theme_stylebox_override("panel", sb)
    p.custom_minimum_size = Vector2(PLATE_W, PLATE_H)
    p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.visible = false
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 18)   # 定稿图：图标和名字中间空约 20
    h.mouse_filter = Control.MOUSE_FILTER_IGNORE
    h.alignment = BoxContainer.ALIGNMENT_CENTER
    p.add_child(h)
    if with_icon:
        var ic := TextureRect.new()
        ic.name = "card_icon"   # 像素小身份证（阿鱼 10/4）；点它（或头像）开身份卡
        ic.texture = _id_icon(_c(PAL["icon"]), _c(PAL["plate"]["fill"]))
        ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
        ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
        h.add_child(ic)
    var l := lbl("", font, NAME_SIZE, _c(PAL["name"]))
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    h.add_child(l)
    p.set_meta("label", l)
    return p

static func lbl(t: String, font: Font, size: int, col: Color) -> Label:
    var l := Label.new()
    l.text = t
    if font != null:
        l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", col)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

## 翻页三角（阿鱼 10/5）：一个 44×44 能点的按钮，中间画一个金色像素三角（宽 7、5、3、1 格，一格 3 像素，跟名字一个金，外一圈深色）；up 尖朝上
static func page_arrow(up: bool) -> Button:
    var b := Button.new()
    b.name = "page_up" if up else "page_down"
    b.flat = true
    b.focus_mode = Control.FOCUS_NONE
    for k in ["normal", "hover", "pressed", "focus", "disabled"]:
        b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
    b.custom_minimum_size = Vector2(ARROW, ARROW)
    b.size = Vector2(ARROW, ARROW)
    b.mouse_filter = Control.MOUSE_FILTER_STOP
    b.visible = false
    var c := _c(PAL["arrow"])
    var edge := _c(PAL["box"]["edge"])
    b.draw.connect(func():
        # 一格 3 像素：深色一圈（每行宽 9、7、5、3、1）里面金色（宽 7、5、3、1），down 尖朝下、up 上下翻过来
        var u := 3.0
        var ox := (ARROW - 9.0 * u) * 0.5
        var oy := (ARROW - 5.0 * u) * 0.5
        for r in 5:
            var y := oy + float(r if not up else 4 - r) * u
            b.draw_rect(Rect2(ox + r * u, y, (9 - r * 2) * u, u), edge)
            if r < 4:
                b.draw_rect(Rect2(ox + (r + 1) * u, y, (7 - r * 2) * u, u), c))
    return b

## 「点一下继续」小三角：4 行台阶（宽 7、5、3、1 格），一格 U×2 宽、3 高
static func more_tri(c: Color) -> Control:
    var more := Control.new()
    more.name = "more"
    more.mouse_filter = Control.MOUSE_FILTER_IGNORE
    more.size = Vector2(28, 12)
    more.draw.connect(func():
        for r in 4:
            more.draw_rect(Rect2(r * U * 2, r * 3, (7 - r * 2) * U * 2, 3), c))
    return more

## 选项按钮：定稿图的红按钮（深红描边、浅橘亮边、下截暗、四角金钉），按下换深一档；宽由对话框算（一样宽、铺满一行）
static func style_choice(b: Button, font: Font) -> void:
    var s: Dictionary = PAL["choice"]
    var n := choice_frame(false)
    var p := choice_frame(true)
    for sb in [n, p]:
        sb.content_margin_left = CHOICE_PADX
        sb.content_margin_right = CHOICE_PADX
    n.content_margin_top = 8
    n.content_margin_bottom = 10
    p.content_margin_top = 10       # 按下去字往下沉一点
    p.content_margin_bottom = 8
    for k in ["normal", "hover", "focus", "disabled"]:
        b.add_theme_stylebox_override(k, n)
    b.add_theme_stylebox_override("pressed", p)
    if font != null:
        b.add_theme_font_override("font", font)
    b.add_theme_font_size_override("font_size", LINE_SIZE)
    for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        b.add_theme_color_override(k, _c(s["text"]))
    b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    b.custom_minimum_size = Vector2(CHOICE_MIN_W, CHOICE_H)
    b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 宽由对话框按定稿图算好（一样宽、铺满右边那一行）

## 打字到一半吗、还有没有下一页（lounge_ui 点一下先出完、再翻页、再下一句）
static func typing(box: Control) -> bool:
    var t = box.get_node_or_null("typer")
    return t != null and t.typing()

static func finish(box: Control) -> void:
    var t = box.get_node_or_null("typer")
    if t != null:
        t.finish()

static func next_page(box: Control) -> bool:
    var t = box.get_node_or_null("typer")
    return t != null and t.next_page()

static func prev_page(box: Control) -> bool:
    var t = box.get_node_or_null("typer")
    return t != null and t.prev_page()

## 是不是在最后一页（没分页也算）：没到最后一页时点框既不翻页、也不往下一句走（翻页点右边的上下三角，阿鱼 10/5）
static func last_page(box: Control) -> bool:
    var t = box.get_node_or_null("typer")
    return t == null or t.last_page()

## 一行选项排不排得下（排不下回 ok=false、需要多宽、现在多宽；阿鱼说别换成两行，排不下报 01）
static func choices_fit(box: Control) -> Dictionary:
    var t = box.get_node_or_null("typer")
    return t.fit if t != null else {}

## 每帧：摆头像、名字牌、话、选项，算框多高，字一个个出、分页、小三角一闪一闪
class Typer extends Node:
    const LMPeople = preload("res://scripts/lm_people.gd")
    var box: Control
    var src: Label           # 行为写进来的整句
    var hint: Label
    var face: Control
    var portrait: TextureRect
    var plate: Control
    var card: Control
    var choices: Control
    var font: Font
    var instant := false     # 截图、测试（main.fast）：不打字，整页直接出
    var shown: Label         # 屏上这一页
    var more: Control
    var up_btn: Button       # 翻页三角（阿鱼 10/5）
    var down_btn: Button
    var text_w := 0.0
    var _shown_before := false   # 上一帧框开着没有：关了再开就从第 1 页来
    var pages: Array = []    # 每页的字
    var page := 0
    var fit := {}
    var _last := ""
    var _last_w := -1.0
    var _t := 0.0
    var _blink := 0.0
    var ui                   # NPC 对话框：lounge_ui（找正在说话的人、在哪块画布）
    var m                    # 阿鱼那个框：main（找现在的画布、玩家）
    var _lift := 0.0         # 镜头现在往下让了多少（画布像素）：框盖住人就让，让人和说话的人都露在框上面（04 第 1 条）
    var _lift_cam: Camera2D
    var _lift_limit := 0

    ## 现在在哪块画布上、要露出来的几个点（说话的人头顶、脚下，玩家头顶、脚下）
    func _lift_targets() -> Array:
        var cv = null
        var pts: Array = []
        if ui != null and str(ui.talk_id) != "" and ui.talk_cv != null:
            cv = ui.talk_cv
            var lf = ui.life_of(str(ui.talk_id))
            if lf != null:
                var p: Dictionary = lf.people.get(str(ui.talk_id), {})
                if p.has("foot"):
                    pts.append(p["foot"])
                if p.has("head"):
                    pts.append(p["head"])
        elif m != null and m.has_method("_in_scene") and m._in_scene():
            cv = m.cv
        if cv == null or cv.get("cam") == null:
            return []
        pts.append(cv.pos)
        if cv.has_method("px_per_m"):
            pts.append(cv.pos - Vector2(0, cv.px_per_m(cv.pos.y) * 1.8))
        return [cv, pts]

    ## 框开着：说话的人、玩家被框盖住了，镜头往下让（画面里的东西往上走），让到都露在框上沿上面；框收了慢慢放回去。
    ## 镜头底边原来卡在画布下沿，让的时候下沿临时放宽这么多（多出来那块在框后面，看不见）
    func _lift_tick(dt: float, open: bool) -> void:
        var want := 0.0
        var cv = null
        if open:
            var tg := _lift_targets()
            if not tg.is_empty():
                cv = tg[0]
                var cam: Camera2D = cv.cam
                if _lift_cam != cam:
                    _lift_reset()
                    _lift_cam = cam
                    _lift_limit = cam.limit_bottom
                var xf: Transform2D = cv.get_global_transform_with_canvas()
                var lowest := -INF
                for p in tg[1]:
                    lowest = maxf(lowest, (xf * (p as Vector2)).y)
                var top: float = box.get_global_rect().position.y
                var z: float = maxf(cam.zoom.y, 0.2)
                want = maxf(0.0, _lift + (lowest + 24.0 - top) / z)
        if _lift_cam == null:
            return
        _lift = lerpf(_lift, want, minf(1.0, dt * 8.0))
        if want == 0.0 and _lift < 0.5:
            _lift_reset()
            return
        _lift_cam.limit_bottom = _lift_limit + int(ceil(_lift)) + 2
        _lift_cam.offset.y = _lift

    ## 头像（定稿图：头在框外、身子在框里，后面不垫底）：人物实际占的那块（帧左右有透明边）照 lm_index.json 里离线量好的 front
    ## （tools/bake_used.py；不在游戏里读图——微信上从显存读回很慢，test_no_readback 管着）左右居中，放大 FACE_K 倍（整数倍不糊），
    ## 头顶贴着那块的上沿，下面到名字牌上沿裁掉
    var _fit_key := ""
    func _fit_portrait() -> void:
        var tex: Texture2D = portrait.texture
        var code := str(ui.talk_info.get("code", "")) if ui != null and ui.get("talk_info") is Dictionary else ""
        var l: Dictionary = LMPeople.look(code) if code != "" else {}
        var at := tex as AtlasTexture
        # lounge_ui.pose_tex 只给帧的上面 PORTRAIT_KEEP（56%），3 倍放大到名字牌上沿还差一截：对话框这里把截的那块往下放长到
        # 头像那块要的行数（不超过这一帧），露出胸口。只换对话框里这张，pose_tex、身份卡不动。lounge_ui 每句都会换回短的，所以每帧都看
        if at != null and not l.is_empty():
            var want := minf(ceilf(FACE.y / FACE_K), float(int(l.get("fh", 0)) - int(l.get("top", 0))))
            if at.region.size.y < want:
                var at2 := AtlasTexture.new()
                at2.atlas = at.atlas
                at2.region = Rect2(at.region.position, Vector2(at.region.size.x, want))
                portrait.texture = at2
                tex = at2
                at = at2
        var key := "%s %s %s" % [code, at.atlas.get_rid() if at != null and at.atlas != null else tex.get_rid(), at.region if at != null else Rect2(Vector2.ZERO, tex.get_size())]
        if key == _fit_key:
            return
        _fit_key = key
        face.clip_contents = true
        var full := tex.get_size()
        var used := Rect2(Vector2.ZERO, full)
        if code != "":
            var fr = l.get("front")
            if fr is Rect2i and int(l.get("fw", 0)) == int(full.x) and (fr as Rect2i).size.x > 0:
                used = Rect2(float(fr.position.x), float(fr.position.y - int(l.get("top", 0))), float(fr.size.x), full.y)
        var k := FACE_K
        portrait.stretch_mode = TextureRect.STRETCH_SCALE
        portrait.size = full * k
        portrait.position = Vector2(roundf((FACE.x - used.size.x * k) * 0.5 - used.position.x * k), -maxf(used.position.y, 0.0) * k)

    func _lift_reset() -> void:
        if _lift_cam != null and is_instance_valid(_lift_cam):
            _lift_cam.offset.y = 0.0
            _lift_cam.limit_bottom = _lift_limit
        _lift_cam = null
        _lift = 0.0

    func setup(layer: Control) -> void:
        var Skin = load("res://scripts/ui/dialog_skin.gd")
        shown = Skin.lbl("", font, LINE_SIZE, Color(PAL["text"]))
        shown.name = "page"
        shown.add_theme_constant_override("line_spacing", int(LINE_GAP))
        shown.autowrap_mode = TextServer.AUTOWRAP_OFF   # 自己折好行（中文按字折），翻页才数得准
        layer.add_child(shown)
        more = Skin.more_tri(Color(PAL["more"]))
        layer.add_child(more)
        up_btn = Skin.page_arrow(true)
        down_btn = Skin.page_arrow(false)
        up_btn.pressed.connect(prev_page)
        down_btn.pressed.connect(next_page)
        layer.add_child(up_btn)
        layer.add_child(down_btn)

    func typing() -> bool:
        return shown != null and shown.visible_characters >= 0 and shown.visible_characters < shown.text.length()

    func finish() -> void:
        shown.visible_characters = -1

    ## 翻页（点上下三角）：翻到的那页字照样一个个出；翻回去看过的那页直接整页出
    func next_page() -> bool:
        if page + 1 < pages.size():
            page += 1
            shown.text = pages[page]
            _t = 0.0
            shown.visible_characters = -1 if instant else 0
            return true
        return false

    func prev_page() -> bool:
        if page > 0:
            page -= 1
            shown.text = pages[page]
            shown.visible_characters = -1
            return true
        return false

    func last_page() -> bool:
        return page >= pages.size() - 1

    ## 照宽度一个字一个字折行（标点不放行首：跟着上一行，宁可多出半个字；左引号、左括号不留在行尾：带到下一行），再按一页几行分页
    ## 说话的那句带“”（阿鱼 10/4 定的规矩，07 在 lounge_ui、main._say 里加）：右引号不放行首、左引号不落单
    func _paginate(text: String, w: float, lines_per_page: int) -> Array:
        const NO_HEAD := "，。、！？；：）」』”’…—,.!?;:)"
        const NO_TAIL := "“‘「『（("
        var lines: Array = []
        for para in text.split("\n"):
            var cur := ""
            for ch in para:
                if cur != "" and not NO_HEAD.contains(ch) and font != null and font.get_string_size(cur + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_SIZE).x > w:
                    var carry := ""
                    while cur.length() > 1 and NO_TAIL.contains(cur[-1]):
                        carry = cur[-1] + carry
                        cur = cur.left(-1)
                    lines.append(cur)
                    cur = carry
                cur += ch
            lines.append(cur)
        var out: Array = []
        var n := maxi(lines_per_page, 1)
        for i in range(0, lines.size(), n):
            out.append("\n".join(lines.slice(i, i + n)))
        return out

    func _process(dt: float) -> void:
        if card != null:
            card.visible = false
        _lift_tick(get_process_delta_time(), box.visible)
        if not box.visible:
            _shown_before = false
            return
        if not _shown_before:
            # 框刚打开：同一句也从第 1 页重新来（03 测出：翻到后面关掉再开同一人同一句，会落在上回那页、选项也露着）
            _shown_before = true
            _last = ""
        var vs: Vector2 = box.get_viewport_rect().size
        var w: float = vs.x - SIDE * 2.0
        var has_face: bool = portrait != null and portrait.texture != null and portrait.visible
        var col := COL_W if (has_face or plate.visible) else 0.0
        var x0 := PAD + col + (12.0 if col > 0.0 else 0.0)
        var full_w := w - x0 - PAD
        var lh := (font.get_height(LINE_SIZE) if font != null else float(LINE_SIZE)) + LINE_GAP   # 一行多高：照字体实际行高
        var ch_on: bool = choices != null and choices.visible
        var row_h := (CHOICE_H + 10.0) if ch_on else 0.0
        # 话一页最多 PAGE_LINES 行（阿鱼 10/5）：先按满宽折；超过一页，右边让出一列放上下翻页三角，再折一遍
        var txt: String = src.text
        if txt != _last or not is_equal_approx(full_w, _last_w):
            _last = txt
            _last_w = full_w
            text_w = full_w
            pages = _paginate(txt, text_w, PAGE_LINES)
            if pages.size() > 1:
                text_w = full_w - ARROW
                pages = _paginate(txt, text_w, PAGE_LINES)
            page = 0
            shown.text = pages[0] if not pages.is_empty() else ""
            _t = 0.0
            shown.visible_characters = -1 if instant else 0
        var paged := pages.size() > 1
        var lines_max := 1
        for pg in pages:
            lines_max = maxi(lines_max, (pg as String).count("\n") + 1)
        var text_h := lines_max * lh - LINE_GAP        # 翻页时每页一样高（按最多那页、最多 2 行），框不跳
        var one_row: bool = not has_face and not ch_on and not paged   # 没头像、没选项、一页（阿鱼说话）：一行两行都收矮居中
        var h := maxf(PAD * 2.0 + text_h + row_h, MIN_H if has_face else 96.0)
        if paged and not ch_on:
            h = maxf(h, PAD + ARROW * 2.0)             # 上下两个三角（各 44）摆得下
        if one_row:
            h = PAD * 2.0 + maxf(PLATE_H, text_h) + 12.0   # 没头像、没选项（阿鱼）：名字牌和话上下居中，不空一大块（04）；加了“”以后常常两行
        box.offset_bottom = -BOTTOM   # 阿鱼的框：main._layout_top 还按原来顶上那条每帧设下沿（= TOP_Y），这里钉回屏幕底；main.gd 不动
        box.offset_top = -BOTTOM - h
        shown.position = Vector2(x0, (h - text_h) * 0.5 if one_row else PAD + 2.0)
        shown.size = Vector2(text_w, text_h)
        # 翻页三角：话那块右边一列，上一个贴顶、下一个接在下面；第一页不出上、最后一页不出下（阿鱼 10/5）
        var ax := w - PAD - ARROW + 6.0
        up_btn.position = Vector2(ax, PAD - 8.0)
        down_btn.position = Vector2(ax, PAD - 8.0 + ARROW)
        up_btn.visible = paged and page > 0
        down_btn.visible = paged and page < pages.size() - 1
        # 名字牌：框左下角，贴着里面那圈金线（定稿图）；头像：名字牌上面，下沿接名字牌上沿，往上顶出框（不垫底）
        plate.reset_size()
        var pw: float = plate.get_combined_minimum_size().x
        plate.size = Vector2(pw, PLATE_H)
        plate.position = Vector2(PAD, (h - PLATE_H) * 0.5 if one_row else h - FU * 2.0 - 2.0 - PLATE_H)
        if face != null:
            face.visible = has_face
            if has_face:
                face.size = FACE
                face.position = Vector2(PAD + (col - FACE.x) * 0.5, plate.position.y + 2.0 - FACE.y)
                _fit_portrait()
        # 选项：最后一行，照定稿图一样宽、铺满右边那一行：从话往右缩 CHOICE_IN 起，到离框右沿 CHOICE_RIGHT，中间空 CHOICE_GAP。
        # 最长那个字放不下（奶奶三个四字选项）：间距收到 CHOICE_GAP_TIGHT、左边跟话对齐、右边收到 CHOICE_RIGHT_TIGHT；还放不下 fit.ok = false（报 01）
        if ch_on:
            var btns: Array = []
            for c in choices.get_children():
                if c is Button and not c.is_queued_for_deletion():
                    btns.append(c)
            var cnt := maxi(btns.size(), 1)
            var need_w := CHOICE_MIN_W
            for bt in btns:
                var tw: float = font.get_string_size((bt as Button).text, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_SIZE).x if font != null else 0.0
                need_w = maxf(need_w, ceilf(tw) + CHOICE_PADX * 2.0)
            var left := x0 + CHOICE_IN
            var right := CHOICE_RIGHT
            var gap := CHOICE_GAP
            var bw := (w - right - left - gap * (cnt - 1)) / cnt
            var tight := bw < need_w
            if tight:
                left = x0
                right = CHOICE_RIGHT_TIGHT
                gap = CHOICE_GAP_TIGHT
                bw = (w - right - left - gap * (cnt - 1)) / cnt
            bw = floorf(bw)
            for bt in btns:
                if (bt as Button).custom_minimum_size.x != bw:
                    (bt as Button).custom_minimum_size = Vector2(bw, CHOICE_H)
            if choices.get_theme_constant("separation") != int(gap):
                choices.add_theme_constant_override("separation", int(gap))
            choices.position = Vector2(left, h - PAD - CHOICE_H)
            choices.size = Vector2(w - right - left, CHOICE_H)
            fit = {"need": need_w * cnt + gap * (cnt - 1), "have": w - right - left, "ok": bw >= need_w, "count": btns.size(), "tight": tight, "w": bw}
            # 最后一页才出选项
            var last := page >= pages.size() - 1
            choices.modulate.a = 1.0 if last else 0.0
            for c in choices.get_children():
                if c is Control:
                    (c as Control).mouse_filter = Control.MOUSE_FILTER_STOP if last else Control.MOUSE_FILTER_IGNORE
        # 字一个个出
        if typing():
            _t += dt
            shown.visible_characters = mini(shown.text.length(), int(_t * TYPE_CPS) + 1)
            if shown.visible_characters >= shown.text.length():
                shown.visible_characters = -1
        # 小三角：这一页出完了，后面还有页、或者有「点一下继续」（没选项），一闪一闪
        _blink += dt
        more.position = Vector2(w - PAD - 28.0, h - PAD - 12.0)
        var cont := hint != null and hint.text != "" and not ch_on   # 右下小三角只剩「点一下继续」（下一句）；翻页改成上下三角
        more.visible = cont and page >= pages.size() - 1 and not typing() and fmod(_blink, 1.0) < 0.6
