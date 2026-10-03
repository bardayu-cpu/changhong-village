extends Control
## 开场（第 2 层，阿鱼 10/3 交的开屏页接进游戏）：原来是网页（苏七镇-开屏文件/index.html），小游戏里没有网页，照着在 Godot 里重做。
## 第 1 层是引擎起来之前的加载页（wxgame/splash.js），只有背景和进度条；引擎接手以后到这里：
##   预热（main.gd 的 hall.warm_up，手机上十几秒）→ 背景 + 第 1 层那条满了的进度条 + 一行轮换的字
##   → 「轻触屏幕，进入苏七镇」→ 点一下：音乐响、logo 落下、隔 5～9 秒扫一道金光、「进入游戏」「玩法说明」浮上来、新人和四只猫狗轮流说话
## 接得上（阿鱼 10/3：「位置、缩放完全一致，切换时不能跳」）：背景是同一张图（assets/splash/splash_bg.jpg，原样进包），
## 铺法跟第 1 层一样：等比铺满屏（cover）、居中。第 1 层分包下完就退回原大，到这里一直是原大，不再推近；
## 进度条照第 1 层的位置、大小、颜色画一条满的（BAR），接手那一下看不出换了一层。
## 角色点击区、气泡位置都按整张图的百分比（540×960 原图），手机上左右裁掉的部分跟着裁。
## 右上角是微信的胶囊按钮，左上角压着 logo（调试版还有帧率），音乐开关放左下角、跟署名一排（网页版在右上角）。

signal start_pressed

const BG_PATH := "res://assets/splash/splash_bg.jpg"   # .import 是 keep：包里是原 jpg，跟第 1 层读的是同一份字节
const LOGO := preload("res://assets/splash/title_ui_logo.png")
const BGM := preload("res://assets/splash/title_bgm.wav")
const IMG := Vector2(540, 960)

const NIGHT := Color("#110c22")
const LACQUER := Color("#a8241c")
const LACQUER_DEEP := Color("#6e140f")
const GOLD := Color("#f3c45a")
const GOLD_HI := Color("#ffe9a8")
const PAPER := Color("#fff7e4")
const INK := Color("#2a1608")

## 预热时轮换的字（网页版加载页那四句，说的是图上的东西）
const TIPS := ["正在点亮花灯……", "新人正在茹公桥上等你……", "喜多在桥头摇尾巴……", "铁花即将绽放……"]
const TAP_HINT := "轻触屏幕，进入苏七镇"
const CREDIT := "阿鱼 手作"
const HELP_TITLE := "玩法说明"
## 玩法说明正文：草稿给阿鱼看过、点头以后换进来（阿鱼 10/3）。点头之前先放一句现在游戏里就是这样的操作
const HELP_TEXT := "点地面走路，走近人和东西会出按钮。"

## 角色：点击区 [左, 上, 宽, 高]、气泡尖指的点 [x, y]、气泡往哪边伸（c 居中，l 往右伸，r 往左伸），都是整张图的百分比。
## 照 GPT 原图量的（网页版是照视频画面定的，新娘新郎的框往下拉到脚）
const WHO := {
    "bride": {"name": "新娘", "hit": [28.0, 44.5, 20.0, 28.0], "at": [39.0, 43.5], "a": "c"},
    "groom": {"name": "新郎", "hit": [45.0, 41.0, 23.0, 31.5], "at": [54.0, 40.0], "a": "c"},
    "xiduo": {"name": "喜多", "hit": [8.0, 66.0, 16.0, 9.6], "at": [16.0, 65.8], "a": "l"},
    "tiantian": {"name": "天天", "hit": [24.5, 68.8, 12.7, 6.9], "at": [30.5, 68.6], "a": "l"},
    "luoluo": {"name": "落落", "hit": [61.0, 67.3, 8.6, 7.2], "at": [65.5, 67.3], "a": "r"},
    "qiuqiu": {"name": "求求", "hit": [69.6, 67.6, 9.0, 6.9], "at": [73.8, 67.6], "a": "r"},
}
## 台词（阿鱼 10/3：「茹公桥」留；「凑齐七个人」删；别的对照现在的剧情，对不上的换成喜宴、迎宾院的）
const LINES := {
    "bride": ["欢迎来到苏七镇！", "今晚的灯，都为你亮着～", "喜宴摆在罗曼山庄，快来吃席！"],
    "groom": ["先去迎宾院签个到，我们在厅里等你。", "准备好了吗？", "桥上人多，跟紧我们。"],
    "xiduo": ["汪！铁花好亮！", "汪汪！快来桥上玩！"],
    "tiantian": ["喵……河灯好暖和", "这条桥我走过一百遍啦"],
    "luoluo": ["喵……吃完席想睡一觉", "落落要坐船！"],
    "qiuqiu": ["求求在这里哦", "喵～今晚有好事发生"],
}
const ORDER := ["bride", "groom", "xiduo", "tiantian", "bride", "luoluo", "groom", "qiuqiu"]
const TALK_EVERY := 5.6      # 轮播隔几秒换一位
const TYPE_SECS := 0.055     # 一个字打多久
const LOGO_TOP := 0.155      # logo 上沿在整张图的几成（压在铁花上）
## 进度条，跟 wxgame/splash.js 的 SPLASH.bar、bar() 一样：中心在屏高 88.5%，宽占屏宽 72%，高 18 个 CSS 像素；
## 金边 1.5、填充往里缩 3（CSS 像素）；颜色平涂
const BAR := {"y": 0.885, "w": 0.72, "h": 18.0, "edge": 1.5, "pad": 3.0}
const BAR_SILK := Color("#7a1212")
const BAR_EDGE := Color("#e8c15a")
const BAR_GOLD := Color("#f2c94c")

var font: FontFile
var fast := false            # 截图：不放动画
var phase := "warm"          # warm 预热 → tap 等点 → menu 菜单
var music_on := true

var bg_tex: Texture2D
var stage := Rect2()         # 整张图现在铺在屏上哪儿
var css_w := 0.0             # 手机屏宽多少 CSS 像素（第 1 层报的）；读不到按 400
var css_k := 1.35            # 1 个 CSS 像素是几个视口像素
var handoff_text := ""       # 第 1 层最后那句：接手后先接着显示它，再轮换 TIPS
var bg_layer: Control
var motes_layer: Control
var motes: Array = []
var motes_in := 0.0          # 光点淡入（第 1 层没有光点，接手时别一下冒出来）
var hits: Dictionary = {}
var logo_box: Control
var logo_rect: TextureRect
var shine_rect: TextureRect
var shine_mat: ShaderMaterial
var bubble: PanelContainer
var bubble_name: Label
var bubble_text: Label
var bubble_tip_x := 0.0     # 小尖在气泡里的横坐标
var bubble_who := ""
var tip: Label
var tap_hint: Label
var tap_catch: Button
var menu: VBoxContainer
var start_btn: Button
var help_btn: Button
var credit: Label
var music_btn: Button
var sheet: Control
var sheet_card: PanelContainer
var bgm: AudioStreamPlayer
var vis_bridge = null

var _t := 0.0
var _tip_i := 0
var _tip_next := 1.5
var _talk_i := 0
var _talk_next := -1.0       # <0：还没开始轮播
var _counters := {}
var _shine_next := -1.0
var _hide_at := -1.0
var _bubble_tw: Tween
var _type_tw: Tween
var _glow_tw: Tween
var _blink_tw: Tween
var _enter_tws: Array = []  # 进来那一下的动画（logo 落下、按钮浮上来）：直接到菜单时先停掉
var _vis_next := 0.0

func setup(f: FontFile) -> void:
    font = f
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    bg_tex = _load_bg()
    _log_handoff()

    bg_layer = Control.new()
    bg_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg_layer.mouse_filter = Control.MOUSE_FILTER_STOP   # 盖住下面预热的宴会厅，点不穿
    bg_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 跟第 1 层一样平滑缩放，接手那一下才看不出
    bg_layer.draw.connect(_draw_bg)
    add_child(bg_layer)

    motes_layer = Control.new()
    motes_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    motes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    motes_layer.draw.connect(_draw_motes)
    add_child(motes_layer)

    for who in WHO:
        var h := Button.new()
        h.flat = true
        h.focus_mode = Control.FOCUS_NONE
        h.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 菜单出来才能点
        h.tooltip_text = WHO[who]["name"]
        for st in ["normal", "hover", "pressed", "focus", "disabled"]:
            h.add_theme_stylebox_override(st, StyleBoxEmpty.new())
        h.pressed.connect(_on_hit.bind(who))
        add_child(h)
        hits[who] = h

    logo_box = Control.new()
    logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    logo_box.visible = false
    add_child(logo_box)
    logo_rect = TextureRect.new()
    logo_rect.texture = LOGO
    logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo_rect.stretch_mode = TextureRect.STRETCH_SCALE
    logo_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # logo 是手绘描金，不是像素画，按线性缩
    logo_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    logo_box.add_child(logo_rect)
    shine_mat = ShaderMaterial.new()
    shine_mat.shader = _shine_shader()
    shine_mat.set_shader_parameter("pos", -1.0)
    shine_rect = logo_rect.duplicate() as TextureRect
    shine_rect.material = shine_mat
    logo_box.add_child(shine_rect)

    _build_bubble()
    _build_hud()
    _build_sheet()

    bgm = AudioStreamPlayer.new()
    bgm.stream = BGM
    bgm.volume_db = linear_to_db(0.7)
    add_child(bgm)

    resized.connect(_layout)
    _layout()
    _set_phase("warm")
    if handoff_text != "":
        tip.text = handoff_text
        _tip_i = -1

## 预热完了（main.gd 调）：字换成「轻触屏幕」，点哪都行
func boot_done() -> void:
    if phase == "warm":
        _set_phase("tap")

## 截图预设：不等不放动画，直接到菜单；who 不空就让那位说第一句
func show_menu_now(who := "") -> void:
    fast = true
    for tw in _enter_tws:
        if tw != null and tw.is_valid():
            tw.kill()
    _enter_tws.clear()
    _set_phase("menu")
    logo_box.visible = true
    logo_box.modulate = Color.WHITE
    logo_box.scale = Vector2.ONE
    for b in [start_btn, help_btn]:
        b.modulate.a = 1.0
    credit.modulate.a = 1.0
    _layout()   # logo 落下那一半被停在半空的话放回原位
    music_btn.modulate.a = 1.0
    motes_in = 1.0
    _talk_next = -1.0
    if who in WHO:
        _say(who)

func show_help_now() -> void:
    show_menu_now()
    _open_help()

## 进游戏：淡出、音乐收掉；main.gd 等它完了再藏
func leave() -> void:
    _talk_next = -1.0
    var tw := create_tween().set_parallel()
    tw.tween_property(self, "modulate:a", 0.0, 0.0 if fast else 0.45)
    if bgm.playing:
        tw.tween_property(bgm, "volume_db", -40.0, 0.0 if fast else 0.6)
    await tw.finished
    bgm.stop()
    visible = false
    modulate.a = 1.0

# ---------- 搭 ----------

func _load_bg() -> Texture2D:
    var bytes := FileAccess.get_file_as_bytes(BG_PATH)
    var img := Image.new()
    if bytes.is_empty() or img.load_jpg_from_buffer(bytes) != OK:
        push_warning("[suqi] 开场背景读不出来：%s" % BG_PATH)
        return null
    return ImageTexture.create_from_image(img)

## 第 1 层留下的：接手那一刻推近到几倍（应该已经退回 1）、条子上写的什么。只打日志，真机上看接得齐不齐
func _log_handoff() -> void:
    if not (OS.has_feature("web") or OS.has_feature("wechat")):
        return
    var s = JavaScriptBridge.get_interface("__suqiSplash")
    if s == null:
        print("[suqi] 开场：读不到第 1 层（__suqiSplash）")
        return
    css_w = float(s.cssW())
    handoff_text = str(s.text())
    print("[suqi] 开场：第 1 层交过来时推近 %.3f 倍，屏宽 %d，字「%s」" % [float(s.zoom()), int(css_w), str(s.text())])

func _label(text: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

## 压在图上的字：深色硬投影（像素字描边会糊）
func _shadow(l: Label, c := INK, d := 3) -> void:
    l.add_theme_color_override("font_shadow_color", c)
    l.add_theme_constant_override("shadow_offset_x", 0)
    l.add_theme_constant_override("shadow_offset_y", d)

func _box(bg: Color, border: Color, bw: int, mx: int, my: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(bw)
    s.set_corner_radius_all(0)   # 像素风：直角
    s.content_margin_left = mx
    s.content_margin_right = mx
    s.content_margin_top = my
    s.content_margin_bottom = my
    return s

func _pbtn(text: String, main: bool) -> Button:
    var b := Button.new()
    b.text = text
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_override("font", font)
    b.add_theme_font_size_override("font_size", 36 if main else 24)
    var fg := GOLD_HI if main else GOLD
    for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        b.add_theme_color_override(st, fg)
    b.add_theme_color_override("font_shadow_color", LACQUER_DEEP)
    b.add_theme_constant_override("shadow_offset_x", 0)
    b.add_theme_constant_override("shadow_offset_y", 3)
    var n := _box(LACQUER if main else Color(LACQUER_DEEP, 0.92), GOLD, 3, 12, 10 if main else 7)
    n.shadow_color = Color(0, 0, 0, 0.6)
    n.shadow_size = 1
    n.shadow_offset = Vector2(0, 8)
    var p := n.duplicate() as StyleBoxFlat
    p.bg_color = LACQUER_DEEP
    p.shadow_offset = Vector2(0, 3)
    b.add_theme_stylebox_override("normal", n)
    b.add_theme_stylebox_override("hover", n)
    b.add_theme_stylebox_override("focus", n)
    b.add_theme_stylebox_override("pressed", p)
    return b

func _build_bubble() -> void:
    bubble = PanelContainer.new()
    var sb := _box(PAPER, INK, 3, 12, 7)
    sb.shadow_color = Color(0, 0, 0, 0.35)
    sb.shadow_size = 1
    sb.shadow_offset = Vector2(0, 5)
    bubble.add_theme_stylebox_override("panel", sb)
    bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bubble.modulate.a = 0.0
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bubble.add_child(row)
    bubble_name = _label("", 24, LACQUER)
    bubble_text = _label("", 24, INK)
    row.add_child(bubble_name)
    row.add_child(bubble_text)
    bubble.draw.connect(_draw_tail)   # 气泡自己画完底再画小尖，压住下边框
    add_child(bubble)

func _build_hud() -> void:
    tip = _label(TIPS[0], 24, GOLD_HI)
    _shadow(tip)
    add_child(tip)
    tap_hint = _label(TAP_HINT, 24, PAPER)
    _shadow(tap_hint)
    add_child(tap_hint)

    menu = VBoxContainer.new()
    menu.alignment = BoxContainer.ALIGNMENT_CENTER
    menu.add_theme_constant_override("separation", 14)
    menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(menu)
    start_btn = _pbtn("进入游戏", true)
    start_btn.custom_minimum_size = Vector2(390, 0)
    start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    start_btn.pressed.connect(func(): start_pressed.emit())
    menu.add_child(start_btn)
    help_btn = _pbtn("玩法说明", false)
    help_btn.custom_minimum_size = Vector2(270, 0)
    help_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    help_btn.pressed.connect(_open_help)
    menu.add_child(help_btn)

    credit = _label(CREDIT, 24, Color(GOLD_HI, 0.55))
    _shadow(credit, Color(INK, 0.8), 2)
    add_child(credit)

    music_btn = Button.new()
    music_btn.focus_mode = Control.FOCUS_NONE
    music_btn.custom_minimum_size = Vector2(64, 64)
    music_btn.tooltip_text = "关闭音乐"
    var ms := _box(Color(NIGHT, 0.72), GOLD, 3, 0, 0)
    for st in ["normal", "hover", "pressed", "focus"]:
        music_btn.add_theme_stylebox_override(st, ms)
    music_btn.draw.connect(_draw_note)
    music_btn.pressed.connect(_toggle_music)
    add_child(music_btn)

    tap_catch = Button.new()
    tap_catch.flat = true
    tap_catch.focus_mode = Control.FOCUS_NONE
    for st in ["normal", "hover", "pressed", "focus"]:
        tap_catch.add_theme_stylebox_override(st, StyleBoxEmpty.new())
    tap_catch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tap_catch.pressed.connect(_enter)
    add_child(tap_catch)

func _build_sheet() -> void:
    sheet = Control.new()
    sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    sheet.visible = false
    add_child(sheet)
    var dim := ColorRect.new()
    dim.color = Color(0.04, 0.02, 0.08, 0.62)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.gui_input.connect(func(e):
        if e is InputEventMouseButton and e.pressed:
            _close_help())
    sheet.add_child(dim)
    sheet_card = PanelContainer.new()
    var cs := _box(PAPER, LACQUER, 5, 28, 26)
    cs.shadow_color = Color(0, 0, 0, 0.5)
    cs.shadow_size = 1
    cs.shadow_offset = Vector2(0, 12)
    sheet_card.add_theme_stylebox_override("panel", cs)
    sheet.add_child(sheet_card)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 16)
    sheet_card.add_child(col)
    var h := _label(HELP_TITLE, 36, LACQUER)
    h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    col.add_child(h)
    var sc := ScrollContainer.new()
    sc.name = "scroll"
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(sc)
    var body := _label(HELP_TEXT, 24, INK)
    body.name = "body"
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY   # 中文没有空格，按字折
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("line_spacing", 10)
    sc.add_child(body)
    var close := Button.new()
    close.text = "知道了"
    close.focus_mode = Control.FOCUS_NONE
    close.custom_minimum_size = Vector2(0, 68)
    close.add_theme_font_override("font", font)
    close.add_theme_font_size_override("font_size", 24)
    for st in ["font_color", "font_hover_color", "font_pressed_color"]:
        close.add_theme_color_override(st, GOLD_HI)
    var cb := _box(LACQUER, LACQUER, 0, 0, 0)
    var cp := _box(LACQUER_DEEP, LACQUER_DEEP, 0, 0, 0)
    for st in ["normal", "hover", "focus"]:
        close.add_theme_stylebox_override(st, cb)
    close.add_theme_stylebox_override("pressed", cp)
    close.pressed.connect(_close_help)
    col.add_child(close)

func _shine_shader() -> Shader:
    var s := Shader.new()
    # logo 上一道斜的亮光从左扫到右（网页版的 mask + 渐变）：只亮在 logo 不透明的地方，叠加
    s.code = """
shader_type canvas_item;
render_mode blend_add;
uniform float pos = -1.0;
void fragment() {
    vec4 t = texture(TEXTURE, UV);
    float x = UV.x + (UV.y - 0.5) * 0.12;
    float band = 1.0 - smoothstep(0.0, 0.07, abs(x - pos));
    COLOR = vec4(vec3(1.0, 0.95, 0.78), band * t.a * 0.85);
}
"""
    return s

# ---------- 摆 ----------

## 整张图等比铺满（cover）、居中：跟第 1 层（splash.js 的 draw，推近退回 1 以后）、Godot 启动画面（boot_splash stretch_mode 4）一样
func _layout() -> void:
    var vs := size
    if vs.x <= 0.0 or vs.y <= 0.0:
        return
    css_k = vs.x / (css_w if css_w > 0.0 else 400.0)
    var k := maxf(vs.x / IMG.x, vs.y / IMG.y)
    var sz := IMG * k
    stage = Rect2((vs - sz) / 2.0, sz)
    if motes.is_empty():
        for i in 36:
            motes.append(_mote(true))
    bg_layer.queue_redraw()
    for who in WHO:
        var r: Array = WHO[who]["hit"]
        hits[who].position = _at(r[0], r[1])
        hits[who].size = Vector2(r[2], r[3]) / 100.0 * stage.size
    # logo：宽 = 图宽 84%，但不超过屏宽 92%（长屏手机左右裁得多）；上沿在图高 15.5%
    var lw := minf(stage.size.x * 0.84, vs.x * 0.92)
    var lh := lw * float(LOGO.get_height()) / float(LOGO.get_width())
    logo_box.size = Vector2(lw, lh)
    logo_box.position = Vector2((vs.x - lw) / 2.0, stage.position.y + stage.size.y * LOGO_TOP)
    logo_box.pivot_offset = logo_box.size / 2.0
    # 底下一摞：署名贴底（让开 iPhone 底部横条），按钮紧挨在上面，让开桥上猫狗的脚（图高 75% 往上）
    var bottom := vs.y - 40.0
    credit.size = Vector2(vs.x, 30)
    credit.position = Vector2(0, bottom - 30)
    menu.size = Vector2(vs.x, 0)
    menu.reset_size()
    menu.size.x = vs.x
    menu.position = Vector2(0, bottom - 30 - 12 - menu.get_combined_minimum_size().y)
    # 字底边在条子上面 8 个 CSS 像素（跟第 1 层一样）
    for l in [tip, tap_hint]:
        l.size = Vector2(vs.x, 36)
        l.position = Vector2(0, vs.y * BAR["y"] - BAR["h"] * css_k / 2.0 - 8.0 * css_k - 34.0)
    # 音乐开关：左下角，跟署名一排
    music_btn.position = Vector2(16, bottom - 15 - music_btn.custom_minimum_size.y / 2.0)
    if sheet_card != null:
        var cw := minf(vs.x - 48.0, 470.0)
        var ch := minf(vs.y * 0.72, 780.0)
        sheet_card.size = Vector2(cw, ch)
        sheet_card.position = (vs - sheet_card.size) / 2.0
    if bubble_who != "":
        _place_bubble()

func _at(px: float, py: float) -> Vector2:
    return stage.position + Vector2(px, py) / 100.0 * stage.size

func _place_bubble() -> void:
    var w: Dictionary = WHO[bubble_who]
    var p := _at(w["at"][0], w["at"][1])
    bubble.reset_size()
    var bs := bubble.get_combined_minimum_size()
    bubble.size = bs
    var fx := 0.5
    match str(w["a"]):
        "l": fx = 0.12
        "r": fx = 0.88
    var x := p.x - bs.x * fx
    x = clampf(x, 8.0, size.x - bs.x - 8.0)   # 长屏左右裁掉的地方别伸出去
    bubble.position = Vector2(x, p.y - bs.y - 12.0)
    bubble_tip_x = clampf(p.x - x, 14.0, bs.x - 14.0)
    bubble.queue_redraw()

# ---------- 画 ----------

func _draw_bg() -> void:
    bg_layer.draw_rect(Rect2(Vector2.ZERO, size), NIGHT)
    if bg_tex != null:
        bg_layer.draw_texture_rect(bg_tex, stage, false)
    if phase == "warm":
        _draw_bar()

func _draw_bar() -> void:
    var bw: float = size.x * BAR["w"]
    var bh: float = BAR["h"] * css_k
    var r := Rect2((size.x - bw) / 2.0, size.y * BAR["y"] - bh / 2.0, bw, bh)
    var silk := StyleBoxFlat.new()
    silk.bg_color = BAR_SILK
    silk.border_color = BAR_EDGE
    silk.set_border_width_all(maxi(1, roundi(BAR["edge"] * css_k / 2.0)))   # 第 1 层描边是压在边线正中，一半在外
    silk.set_corner_radius_all(int(bh / 2.0))
    silk.anti_aliasing = true
    bg_layer.draw_style_box(silk, r)
    var pad: float = BAR["pad"] * css_k
    var gold := StyleBoxFlat.new()
    gold.bg_color = BAR_GOLD
    gold.set_corner_radius_all(int((bh - 2.0 * pad) / 2.0))
    gold.anti_aliasing = true
    bg_layer.draw_style_box(gold, r.grow(-pad))

## 气泡下面的小尖：三格像素，跟气泡一个色、墨色边
func _draw_tail() -> void:
    var tx := bubble_tip_x
    var y0 := bubble.size.y - 3.0
    var u := 3.0
    bubble.draw_rect(Rect2(tx - 2.5 * u, y0, 5 * u, 3 * u + 3.0), INK)
    bubble.draw_rect(Rect2(tx - 1.5 * u, y0, 3 * u, 3 * u), PAPER)
    bubble.draw_rect(Rect2(tx - 1.5 * u, y0 + 3 * u, 3 * u, u), INK)

## 音乐开关的小音符（网页版 11×11 像素图），关了加一道红斜线
func _draw_note() -> void:
    var u := 4.0
    var o := (music_btn.size - Vector2(11, 11) * u) / 2.0
    var c := GOLD_HI
    for r in [[4, 1, 1, 7], [5, 1, 4, 1], [8, 1, 1, 6], [2, 7, 3, 2], [6, 6, 3, 2]]:
        music_btn.draw_rect(Rect2(o + Vector2(r[0], r[1]) * u, Vector2(r[2], r[3]) * u), c)
    if not music_on:
        for i in range(1, 10):
            music_btn.draw_rect(Rect2(o + Vector2(i, i) * u, Vector2(u, u)), Color("#e2483b"))

## 金色小方块往上飘（网页版的 motes）：贴着格子画，近顶上淡掉
func _mote(anywhere: bool) -> Dictionary:
    var big := randf() < 0.3
    return {
        "x": randf() * maxf(size.x, 1.0),
        "y": randf() * maxf(size.y, 1.0) if anywhere else size.y + 10.0,
        "s": 6.0 if big else 3.0,
        "v": (0.15 + randf() * 0.45) * 81.0,
        "w": randf() * TAU,
        "a": 0.35 + randf() * 0.5,
    }

func _draw_motes() -> void:
    if motes_in <= 0.0:
        return
    for m in motes:
        var fade := clampf(m["y"] / (size.y * 0.25), 0.0, 1.0)
        var a: float = m["a"] * fade * (0.6 + 0.4 * sin(_t / 0.3 + m["w"])) * motes_in
        if a <= 0.0:
            continue
        var s: float = m["s"]
        var c := GOLD_HI if s > 4.0 else GOLD
        motes_layer.draw_rect(Rect2(Vector2(roundf(m["x"] / s) * s, roundf(m["y"] / s) * s), Vector2(s, s)), Color(c, a))

# ---------- 动 ----------

func _process(dt: float) -> void:
    if not visible:
        return
    _t += dt
    if not fast:
        motes_in = minf(1.0, motes_in + dt / 1.5)
        for m in motes:
            m["y"] -= m["v"] * dt
            m["x"] += sin(_t / 1.4 + m["w"]) * 15.0 * dt
            if m["y"] < -10.0:
                m.merge(_mote(false), true)
        motes_layer.queue_redraw()
    if phase == "warm" and _t >= _tip_next:
        _tip_i = (_tip_i + 1) % TIPS.size()
        tip.text = TIPS[_tip_i]
        _tip_next = _t + 1.5
    if _talk_next >= 0.0 and _t >= _talk_next:
        _say(ORDER[_talk_i % ORDER.size()])
        _talk_i += 1
        _talk_next = _t + TALK_EVERY
    if _hide_at >= 0.0 and _t >= _hide_at:
        _hide_at = -1.0
        _bubble_fade(false)
    if _shine_next >= 0.0 and _t >= _shine_next:
        _shine()
        _shine_next = _t + 5.2 + randf() * 4.2
    if bgm.playing or (phase == "menu" and music_on):
        _poll_visibility()

func _set_phase(p: String) -> void:
    phase = p
    bg_layer.queue_redraw()   # 进度条只在预热时画
    tip.visible = p == "warm"
    tap_hint.visible = p == "tap"
    tap_catch.visible = p == "tap"
    menu.visible = p == "menu"
    credit.visible = p == "menu"
    music_btn.visible = p == "menu"
    for who in hits:
        hits[who].mouse_filter = Control.MOUSE_FILTER_STOP if p == "menu" else Control.MOUSE_FILTER_IGNORE
    if _blink_tw != null:
        _blink_tw.kill()
        _blink_tw = null
    if p == "tap" and not fast:
        # 一明一暗地闪（网页版 steps(2)）
        _blink_tw = create_tween().set_loops()
        _blink_tw.tween_property(tap_hint, "modulate:a", 0.25, 0.0).set_delay(0.7)
        _blink_tw.tween_property(tap_hint, "modulate:a", 1.0, 0.0).set_delay(0.7)

## 点一下进来：音乐（微信要点过才出声）、logo 落下、按钮浮上来、开始说话
func _enter() -> void:
    if phase != "tap":
        return
    _set_phase("menu")
    _play_music()
    logo_box.visible = true
    logo_box.position.y -= logo_box.size.y * 0.38
    logo_box.scale = Vector2(1.06, 1.06)
    logo_box.modulate = Color(2.2, 2.2, 2.2, 0.0)
    var to_y := logo_box.position.y + logo_box.size.y * 0.38
    var tw := create_tween().set_parallel()
    tw.tween_property(logo_box, "position:y", to_y, 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(logo_box, "scale", Vector2.ONE, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    var lm := create_tween()
    lm.tween_property(logo_box, "modulate", Color(1.4, 1.4, 1.4, 1.0), 0.77)
    lm.tween_property(logo_box, "modulate", Color.WHITE, 0.63)
    for b in [start_btn, help_btn, credit, music_btn]:
        b.modulate.a = 0.0
    var mt := create_tween()
    mt.tween_interval(0.9)
    mt.tween_property(start_btn, "modulate:a", 1.0, 0.5)
    mt.parallel().tween_property(music_btn, "modulate:a", 1.0, 0.4)
    mt.parallel().tween_property(help_btn, "modulate:a", 1.0, 0.5).set_delay(0.18)
    mt.parallel().tween_property(credit, "modulate:a", 1.0, 1.0).set_delay(0.6)
    mt.tween_callback(_glow)
    _enter_tws = [tw, lm, mt]
    _shine_next = _t + 1.1
    _talk_next = _t + 2.6

## 「进入游戏」一明一暗地呼吸
func _glow() -> void:
    if _glow_tw != null:
        _glow_tw.kill()
    _glow_tw = create_tween().set_loops()
    _glow_tw.tween_property(start_btn, "modulate", Color(1.18, 1.18, 1.18, 1.0), 1.3).set_trans(Tween.TRANS_SINE)
    _glow_tw.tween_property(start_btn, "modulate", Color.WHITE, 1.3).set_trans(Tween.TRANS_SINE)

func _shine() -> void:
    var tw := create_tween()
    shine_mat.set_shader_parameter("pos", -0.2)
    tw.tween_method(func(v): shine_mat.set_shader_parameter("pos", v), -0.2, 1.2, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_hit(who: String) -> void:
    if phase != "menu" or sheet.visible:
        return
    _say(who)
    _talk_next = _t + 6.0

## 说一句：气泡换位置、一个字一个字打出来，停一会儿收掉；同一位每次说下一句
func _say(who: String) -> void:
    var list: Array = LINES[who]
    _counters[who] = (int(_counters.get(who, -1)) + 1) % list.size()
    var text: String = list[_counters[who]]
    bubble_who = who
    bubble_name.text = WHO[who]["name"]
    bubble_text.text = text
    _place_bubble()
    if _type_tw != null:
        _type_tw.kill()
    if fast:
        bubble_text.visible_characters = -1
        bubble.modulate.a = 1.0
        return
    bubble_text.visible_characters = 0
    _type_tw = create_tween()
    _type_tw.tween_property(bubble_text, "visible_characters", text.length(), TYPE_SECS * text.length())
    _bubble_fade(true)
    _hide_at = _t + 3.0 + text.length() * TYPE_SECS

func _bubble_fade(show: bool) -> void:
    if _bubble_tw != null:
        _bubble_tw.kill()
    _bubble_tw = create_tween()
    if show:
        bubble.modulate.a = 0.0
        _bubble_tw.tween_property(bubble, "modulate:a", 1.0, 0.25)
    else:
        _bubble_tw.tween_property(bubble, "modulate:a", 0.0, 0.25)

func _open_help() -> void:
    sheet.visible = true
    var sc := sheet_card.find_child("scroll", true, false) as ScrollContainer
    if sc != null:
        sc.scroll_vertical = 0

func _close_help() -> void:
    sheet.visible = false

# ---------- 音乐 ----------

func _play_music() -> void:
    if music_on and not bgm.playing:
        bgm.volume_db = linear_to_db(0.7)
        bgm.play()

func _toggle_music() -> void:
    music_on = not music_on
    music_btn.tooltip_text = "关闭音乐" if music_on else "打开音乐"
    music_btn.queue_redraw()
    if music_on:
        _play_music()
    else:
        bgm.stop()

## 切到后台停音乐、回来接着放。微信里收不到 Godot 的前后台通知，读 kitchen-visibility.js 记的（厨房也是这么判的）
func _notification(what: int) -> void:
    if bgm == null:
        return
    if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
        bgm.stream_paused = true
    elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
        bgm.stream_paused = false

func _poll_visibility() -> void:
    if _t < _vis_next or not (OS.has_feature("web") or OS.has_feature("wechat")):
        return
    _vis_next = _t + 0.5
    if vis_bridge == null:
        vis_bridge = JavaScriptBridge.get_interface("__suqiKitchenVisibility")
    if vis_bridge == null:
        return
    bgm.stream_paused = str(vis_bridge.hidden()) == "1"
