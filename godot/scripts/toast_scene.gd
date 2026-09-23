extends Control
## 敬酒插图（阿鱼 9/18 晚：「两人敬酒时使用一个画面插图表现在敬酒」）：
## 屏幕中间弹一张小画——左边敬酒的人、右边被敬的人，侧身面对面各举一杯，杯子碰一下、金光一闪，上面「干杯」，下面一行谁敬了谁。
## 敬的人（敬完）和被敬的人（在厅里当场、或下次进厅）看到的是同一张。
## 占位：人是代码画的那套像素人放大，底子是红底金边；正式插图等美术。点一下提前收，不点 LEN 秒后自己收。
## 卡多高跟着内容走（体验第二轮 新 5）：原来固定 300 高、底下留着放那行「谁敬了谁」，那行按 B22 拿掉以后下半截空着一块红。
## 现在从上往下排：「干杯」、两个人、那行字（有才排）、「点一下继续」，排到哪卡就到哪。
## 「点一下继续」（01 定，进厅先见人那一条）：点一下本来就能提前收，只是屏幕上没说，长辈只会干等；字小、颜色淡，不抢「干杯」
signal finished

const Spr = preload("res://scripts/sprites.gd")
const LEN := 2.8
const CUP := "res://assets/ambience/amb_cup.png"
const SPARK := "res://assets/ambience/amb_petal_2.png"
const PANEL_W := 420.0
const PEOPLE_H := 168.0   # 两个人画多高（屏幕像素）
const TITLE_Y := 14.0     # 「干杯」那行顶
const TITLE_H := 60.0
const PEOPLE_Y := 82.0    # 两个人的头顶（「干杯」底下留 8）
const CAP_H := 30.0       # 「谁敬了谁」那行（caption 空就不排）
const HINT_H := 28.0      # 「点一下继续」那行
const GAP := 6.0
const PAD_BOTTOM := 12.0
## 新写，等阿鱼定（01 定了要这一行，字是 02 写的）
const LINE_HINT := "点一下继续"

var t := 0.0
var closing := -1.0        # 开始收的时刻；-1 表示还没收
var shade: ColorRect
var panel: Panel
var left_p: TextureRect
var right_p: TextureRect
var left_cup: TextureRect
var right_cup: TextureRect
var title: Label
var cap: Label             # 「谁敬了谁」；caption 空就是 null
var hint: Label            # 「点一下继续」
var panel_size := Vector2(PANEL_W, 0.0)   # play 时按内容算
var sparks: Array = []
var clinked := false

## left_preset 敬酒的人，right_preset 被敬的人（都是形象编号 0～7）；title 大字，caption 下面一行
func play(font: Font, left_preset: int, right_preset: int, title_text: String, caption: String) -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP   # 插图开着时点屏幕不走路，点一下提前收
    shade = ColorRect.new()
    shade.color = Color(0, 0, 0, 0)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shade)
    panel = Panel.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color("#6e1e1e")
    sb.border_color = Color("#d4af37")
    sb.set_border_width_all(3)
    sb.set_corner_radius_all(10)
    panel.add_theme_stylebox_override("panel", sb)
    # 从上往下排：「干杯」、两个人、那行字（有才排）、「点一下继续」，卡的高度排到哪算到哪（新 5）
    var y := PEOPLE_Y + PEOPLE_H + GAP
    var cap_y := y
    if caption != "":
        y += CAP_H + GAP
    var hint_y := y
    panel_size = Vector2(PANEL_W, hint_y + HINT_H + PAD_BOTTOM)
    panel.size = panel_size
    panel.pivot_offset = panel_size * 0.5
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.clip_contents = true
    add_child(panel)
    # 两个人：侧身那一帧，左边朝右、右边翻过来朝左
    left_p = _person(left_preset, false)
    right_p = _person(right_preset, true)
    left_cup = _tex_rect(CUP, 3.0)
    right_cup = _tex_rect(CUP, 3.0)
    title = Label.new()
    title.text = title_text
    title.add_theme_font_override("font", font)
    title.add_theme_font_size_override("font_size", 48)
    title.add_theme_color_override("font_color", Color("#f4d97a"))
    title.add_theme_color_override("font_outline_color", Color("#2c1414"))
    title.add_theme_constant_override("outline_size", 6)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.size = Vector2(PANEL_W, TITLE_H)
    title.position = Vector2(0, TITLE_Y)
    title.pivot_offset = title.size * 0.5
    title.modulate.a = 0.0
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(title)
    if caption != "":
        cap = Label.new()
        cap.text = caption
        cap.add_theme_font_override("font", font)
        cap.add_theme_font_size_override("font_size", 24)
        cap.add_theme_color_override("font_color", Color("#efe6d8"))
        cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        cap.size = Vector2(PANEL_W, CAP_H)
        cap.position = Vector2(0, cap_y)
        cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(cap)
    # 「点一下继续」：像素字最小能看清的就是 24（字体只按 12 的整数倍放大，12 在手机上太小），靠颜色淡下去，
    # 半透明的米色压在红底上，比「干杯」的 48 号金字、那行 24 号亮米色都退一步
    hint = Label.new()
    hint.name = "hint"
    hint.text = LINE_HINT
    hint.add_theme_font_override("font", font)
    hint.add_theme_font_size_override("font_size", 24)
    hint.add_theme_color_override("font_color", Color(0.937, 0.902, 0.847, 0.5))
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.size = Vector2(PANEL_W, HINT_H)
    hint.position = Vector2(0, hint_y)
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(hint)
    for i in 10:
        var sp := _tex_rect(SPARK, 3.0)
        if sp != null:
            sp.visible = false
            sparks.append({"n": sp, "dir": Vector2.from_angle(TAU * i / 10.0 + 0.3), "v": 90.0 + 30.0 * (i % 3)})
    _layout()
    get_viewport().size_changed.connect(_layout)

func _person(preset: int, flip: bool) -> TextureRect:
    var tr := TextureRect.new()
    var at := AtlasTexture.new()
    var gl := Spr.gpt_look(preset)
    var w := 16.0
    var h := 32.0
    if gl.is_empty():
        at.atlas = ImageTexture.create_from_image(Spr.sheet(preset))
        at.region = Rect2(6 * 16.0, 0.0, 16.0, 32.0)   # 侧面那一帧（朝右）
    else:
        w = float(gl["frame_w"])
        h = float(gl["frame_h"])
        var idx: int = int(gl["anim"]["right"]["idle"])
        var hf: int = int(gl["hframes"])
        at.atlas = gl["tex"]
        at.region = Rect2(float(idx % hf) * w, float(idx / hf) * h, w, h)
    tr.texture = at
    tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
    tr.size = Vector2(PEOPLE_H * w / h, PEOPLE_H)
    tr.flip_h = flip
    tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(tr)
    return tr

func _tex_rect(path: String, scale_k: float) -> TextureRect:
    if not ResourceLoader.exists(path):
        return null
    var tr := TextureRect.new()
    tr.texture = load(path)
    tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tr.size = tr.texture.get_size() * scale_k
    tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(tr)
    return tr

func _layout() -> void:
    var vp := get_viewport_rect().size
    panel.position = (vp - panel_size) * 0.5

func _gui_input(e: InputEvent) -> void:
    if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed and closing < 0.0:
        closing = t
        accept_event()

## 时间线：0～0.3 暗下来、小画弹出；0.2～0.6 两个人从两边进来；0.6～0.95 举杯往中间凑；0.95 碰杯金光；之后停住；最后 0.35 秒淡出
func _process(dt: float) -> void:
    t += dt
    if closing < 0.0 and t >= LEN - 0.35:
        closing = t
    var k_in := clampf(t / 0.3, 0.0, 1.0)
    var k_out := 1.0 - clampf((t - closing) / 0.35, 0.0, 1.0) if closing >= 0.0 else 1.0
    shade.color.a = 0.45 * k_in * k_out
    panel.modulate.a = k_in * k_out
    panel.scale = Vector2.ONE * lerpf(0.85, 1.0, _ease(k_in))
    var mid := PANEL_W * 0.5
    var base_y := PEOPLE_Y
    var slide := _ease(clampf((t - 0.2) / 0.4, 0.0, 1.0))
    left_p.position = Vector2(lerpf(-left_p.size.x, mid - left_p.size.x - 6.0, slide), base_y)
    right_p.position = Vector2(lerpf(PANEL_W, mid + 6.0, slide), base_y)
    # 杯子：在两人身前胸口高，举起来往中间碰
    var lift := _ease(clampf((t - 0.6) / 0.35, 0.0, 1.0))
    var chest := base_y + PEOPLE_H * 0.42
    if left_cup != null:
        var cw := left_cup.size.x
        left_cup.position = Vector2(lerpf(left_p.position.x + left_p.size.x - cw * 0.6, mid - cw - 1.0, lift), chest - 40.0 * lift)
        right_cup.position = Vector2(lerpf(right_p.position.x - cw * 0.4, mid + 1.0, lift), chest - 40.0 * lift)
    if not clinked and t >= 0.95:
        clinked = true
        for s in sparks:
            s["n"].visible = true
    var ks := clampf((t - 0.95) / 0.6, 0.0, 1.0)
    for s in sparks:
        if s["n"].visible:
            var n: TextureRect = s["n"]
            n.position = Vector2(mid, chest - 46.0) + s["dir"] * s["v"] * _ease(ks) - n.size * 0.5
            n.modulate.a = 1.0 - ks
    # 「干杯」碰杯那一下弹出来：先大后正常
    var kt := clampf((t - 0.95) / 0.25, 0.0, 1.0)
    title.modulate.a = kt
    title.scale = Vector2.ONE * lerpf(1.4, 1.0, _ease(kt))
    if closing >= 0.0 and t - closing >= 0.35:
        finished.emit()
        queue_free()

static func _ease(k: float) -> float:
    return 1.0 - (1.0 - k) * (1.0 - k)
