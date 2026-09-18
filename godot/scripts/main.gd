extends Node
## 苏七镇奇缘 · 罗曼山庄吃席 demo
## 流程按《苏七镇 · 阶段 1 设计 v1.0》3.1：昵称 → 形象 → 两分钟剪辑 → 罗曼山庄吃席、给新人写悄悄话 → 出山庄
## 画面上的对白全部摘自设计文档；【待补】【待做】是占位，不是正式内容

const Hall = preload("res://scripts/hall.gd")
const LayeredHall = preload("res://scripts/layered_hall.gd")
## 宴会厅用分层场景（画面就是 GPT 的效果图，阿鱼 9/15 选定）；false 回到 3D 搭的 HD-2D 宴会厅
const USE_LAYERED := true
const Spr = preload("res://scripts/sprites.gd")

const LINE_ARRIVE := "到啦～ 罗曼山庄 席还没散"
const LINE_TABLE := "想跟我们说点什么 写这儿 只有我们看得到"
const LINE_LEAVE := "吃好了？走 带你回镇上"
const LINE_TOASTED_FMT := "敬了 %s 一杯"   # 新写，等阿鱼定
const GOLD := Color("#d4af37")
const GOLD1 := Color("#f4d97a")
const RED := Color("#c0392b")
const RED0 := Color("#8c2f27")
const PAPER := Color("#efe6d8")
const MUTED := Color("#b1a6ba")
const INK := Color("#15111b")
## 缝合像素字体 12px 简体版，SIL OFL 1.1，许可证在同目录。微信里没有系统字体，只能用打包进来的
const FONT_PATH := "res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"

var font: FontFile
var ui: Control
var view: SubViewportContainer
var hall
var fade: ColorRect
var screens := {}
var hud: Control
var dialog: PanelContainer
var dialog_text: Label
var hint: Label
var note: Label            # 顶部提示框里的字：进厅合并提示、坐好了、拒绝原因
var note_box: PanelContainer
var note_token := 0
## 屏幕上方的对白框、提示框从这一行往下排（阿鱼 9/17：提示放屏幕上方，要看得见）。
## 要让开右上角微信的胶囊按钮：iPhone 16 Pro 上它的下沿约在 124
const TOP_Y := 150.0
var sit_btn: Button        # 走到空椅子旁出现；第一次点变确认文案，再点执行
var sit_target := {"table_id": "", "chair_no": 0}
var sit_confirming := false
var person_btn: Button     # 走到坐着的人（不是自己）旁边出现，按钮上是对方昵称（蓝图 3.2，第 22 版）
var near_seat_info := {"table_id": "", "chair_no": 0}   # hall.chair_near 最新一次的内容
var near_person_id := ""   # hall.person_near 最新一次的内容
var card_open := false
var card_openid := ""      # 卡片开着时，正在看的那个人的 openid
var person_card: Control
var person_card_portrait: TextureRect
var person_card_name: Label
var person_card_inviter: Label
var person_card_toast_btn: Button
const CloudRpc = preload("res://scripts/cloud.gd")
var cloud: Node
# 拒绝原因对照（server-claude/README.md，文案阿鱼定稿）。
# 云函数的字段名和拒绝原因清单见 godot/回执/席位桥修复.md 第七节，发请求前对一遍
const REASONS := {
    "seat_taken": "这把有人坐了", "changed_today": "今天换过了 明天再换",
    "toast_limit": "今天敬够了", "toast_same_person": "这杯敬过了",
    "toast_self": "自己就不用敬了", "not_sat_here": "先坐下 慢慢写",
    "book_too_long": "太长啦 真实情感的话 短一点也没关系",
    "network": "没连上 再试一下", "no_resident": "没连上 再试一下",
    # 这两个是字段名对不上、或者服务端那边没有我的座位，玩家看不懂，统一说没连上；
    # 真实原因打进日志，不然又会像第 19 版那样被「没连上」盖住（bad_request 当时就是 changeSeat 字段名发错了）
    "bad_request": "没连上 再试一下", "no_seat": "没连上 再试一下",
}
var nick_edit: LineEdit
var nick_err: Label
var nick_count: Label
var nick_ok: Button
var whisper_box: PanelContainer
var whisper_edit: TextEdit
var whisper_count: Label
var whisper_ok: Button
var state := ""
var nickname := ""
var preset := 2
var fast := false
var say_token := 0
# 摇杆和转镜头
const STICK_R := 64.0
var stick_base: Panel
var stick_knob: Panel
var stick_touch := -1
var stick_origin := Vector2.ZERO
var touches := {}   # 手指编号 -> {start, t, drag}
# 调试版才有：左上角绿字是帧率，点开是日志面板
var dbg: Button
var dbg_panel: PanelContainer
var dbg_text: Label
var dbg_acc := 0.0
var dbg_log_acc := 0.0
var dbg_worst := 0.0

func _ready() -> void:
    # [suqi] 开头的几行是启动进度，微信预览版的调试弹窗靠它们判断卡在哪
    print("[suqi] 脚本开始")
    font = _make_font()
    print("[suqi] 字体好了")
    ui = Control.new()
    ui.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.theme = _theme()
    add_child(ui)
    view = SubViewportContainer.new()
    view.stretch = true
    view.set_anchors_preset(Control.PRESET_FULL_RECT)
    view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # 移轴模糊、暗角是给 3D 宴会厅做 HD-2D 味道的；分层场景本身就是一张画，不加
    if not USE_LAYERED:
        var pm := ShaderMaterial.new()
        pm.shader = load("res://shaders/post.gdshader")
        view.material = pm
    ui.add_child(view)
    var sv := SubViewport.new()
    sv.msaa_3d = Viewport.MSAA_DISABLED
    view.add_child(sv)
    cloud = CloudRpc.new()
    add_child(cloud)
    hall = LayeredHall.new() if USE_LAYERED else Hall.new()
    sv.add_child(hall)
    hall.build(preset, "", font)
    print("[suqi] 宴会厅搭好了")
    hall.reached.connect(_on_reached)
    if USE_LAYERED:
        hall.chair_near.connect(_on_chair_near)
        hall.person_near.connect(_on_person_near)
    hall.walking_enabled = false
    _build_ui()
    print("[suqi] 界面搭好了")
    var cap := ""
    var shot := ""
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--capture="): cap = a.substr(10)
        elif a.begins_with("--shot="): shot = a.substr(7)
    if cap != "":
        fast = true
        if "--hud" in OS.get_cmdline_user_args():
            _build_debug()
        await _setup_shot(shot)
        for i in 50: await get_tree().process_frame
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png(cap.path_join(shot + ".png"))
        print("CAPTURED ", shot, " ", _render_stats())
        get_tree().quit()
    else:
        # 黑屏里先让每种材质都上一次画面，着色器编译完再亮出开场（见 hall.warm_up）
        fade.color.a = 1.0
        # 手机上这一步要十几二十秒，黑屏太久会以为卡死了，放一行字
        var wait := _label("加载中", 24, MUTED)
        wait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        wait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        ui.add_child(wait)
        await hall.warm_up()
        wait.queue_free()
        print("[suqi] 着色器预热完了")
        if OS.has_feature("suqi_debug") or "--hud" in OS.get_cmdline_user_args():
            _build_debug()
        _goto("title")
        _fade_to(0.0)
        # 保险：不管前面哪里没走完，2 秒后开场一定亮出来
        get_tree().create_timer(2.0).timeout.connect(func():
            if state == "title" and fade.color.a > 0.0:
                fade.color.a = 0.0
                print("[suqi] 开场黑幕是被保险掀开的"))
        await get_tree().process_frame
        print("[suqi] 开场出来了")

# ---------- 主题 ----------
func _sb(bg: Color, border: Color, bw := 2, rad := 6, pad := 14) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(bw)
    s.set_corner_radius_all(rad)
    s.content_margin_left = pad; s.content_margin_right = pad
    s.content_margin_top = pad * 0.7; s.content_margin_bottom = pad * 0.7
    return s

## 调试版：左上角显示帧率、最慢一帧、绘制次数；点一下打开日志面板，截图发出来就能看全部日志
func _build_debug() -> void:
    dbg = Button.new()
    dbg.add_theme_font_size_override("font_size", 24)
    dbg.add_theme_color_override("font_color", Color("#9CFF9C"))
    dbg.add_theme_color_override("font_hover_color", Color("#9CFF9C"))
    dbg.add_theme_color_override("font_pressed_color", Color("#9CFF9C"))
    for st in ["normal", "hover", "pressed", "focus"]:
        dbg.add_theme_stylebox_override(st, _sb(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0, 4, 8))
    dbg.position = Vector2(12, 100)
    dbg.text = "测帧率中"
    dbg.pressed.connect(_toggle_log)
    ui.add_child(dbg)
    # 走路速度两档，给阿鱼真机比一比（只有调试版有）：点一下在 3.2 和 2.4 米/秒之间切
    var spd := Button.new()
    spd.add_theme_font_size_override("font_size", 24)
    spd.add_theme_color_override("font_color", Color("#9CFF9C"))
    for st in ["normal", "hover", "pressed", "focus"]:
        spd.add_theme_stylebox_override(st, _sb(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0, 4, 8))
    spd.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    spd.offset_left = -170; spd.offset_right = -12
    spd.offset_top = -60; spd.offset_bottom = -16
    spd.text = "走路 %.1f" % hall.speed_m if USE_LAYERED else "走路"
    spd.pressed.connect(func():
        if not USE_LAYERED:
            return
        var i: int = hall.SPEED_CHOICES.find(hall.speed_m)
        hall.speed_m = hall.SPEED_CHOICES[(i + 1) % hall.SPEED_CHOICES.size()]
        spd.text = "走路 %.1f" % hall.speed_m
        print("[suqi] 走路速度切到 ", hall.speed_m, " 米/秒"))
    ui.add_child(spd)
    dbg_panel = PanelContainer.new()
    dbg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    dbg_panel.offset_left = 10; dbg_panel.offset_right = -10
    dbg_panel.offset_top = 150; dbg_panel.offset_bottom = -10
    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    dbg_text = _label("", 12, PAPER, HORIZONTAL_ALIGNMENT_LEFT)
    dbg_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.add_child(dbg_text)
    dbg_panel.add_child(sc)
    dbg_panel.visible = false
    ui.add_child(dbg_panel)

func _toggle_log() -> void:
    dbg_panel.visible = not dbg_panel.visible
    if dbg_panel.visible:
        dbg_text.text = _read_js_log()

## 日志在微信那一层（wxgame/debug-console.js 收集的），这里只是读出来显示。
## 打开面板时顺便让云桥自查一次，结果也会进日志，排查席位用
func _read_js_log() -> String:
    if not (OS.has_feature("web") or OS.has_feature("wechat")):
        return "电脑上没有这份日志，看 Godot 的输出窗口"
    var caps := ""
    if cloud != null:
        caps = cloud.diagnose() + "\n\n"
    var log_obj = JavaScriptBridge.get_interface("__suqiLog")
    if log_obj == null:
        return caps + "读不到日志：调试脚本没加载"
    return caps + str(log_obj.text())

func _process(dt: float) -> void:
    if dialog != null:
        _layout_top()
    if stick_base != null:
        # 写悄悄话、说话的时候不能走，摇杆也藏起来
        var show_stick: bool = state == "banquet" and hall.walking_enabled
        stick_base.visible = show_stick
        stick_knob.visible = show_stick
        if not show_stick and stick_touch != -1:
            stick_touch = -1
            hall.stick = Vector2.ZERO
            _stick_rest()
    if dbg == null:
        return
    dbg_worst = maxf(dbg_worst, dt)
    if dt > 0.15:
        print("[suqi] 卡了 %d 毫秒（%s）" % [int(dt * 1000.0), state])
    dbg_acc += dt
    if dbg_acc >= 0.5:
        dbg.text = "%d 帧/秒  最慢 %d 毫秒  绘制 %d" % [Engine.get_frames_per_second(), int(dbg_worst * 1000.0),
            RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]
        dbg_acc = 0.0
        dbg_worst = 0.0
    dbg_log_acc += dt
    if dbg_log_acc >= 5.0:
        dbg_log_acc = 0.0
        print("[suqi] " + dbg.text)

## 每帧的绘制次数和物体数。微信小游戏建议绘制次数不超过 200
func _render_stats() -> String:
    return "绘制 %d 次 物体 %d 个 三角形 %d" % [
        RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
        RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
        RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)]

## 按 12px 画一次，再整倍放大，像素才是方的。所以界面字号都用 12 的倍数
func _make_font() -> FontFile:
    var f := load(FONT_PATH) as FontFile
    f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
    f.hinting = TextServer.HINTING_NONE
    f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
    f.fixed_size = 12
    f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
    return f

func _theme() -> Theme:
    var t := Theme.new()
    t.default_font = font
    t.default_font_size = 24
    t.set_color("font_color", "Label", PAPER)
    t.set_stylebox("panel", "PanelContainer", _sb(Color(0.106, 0.078, 0.133, 0.94), GOLD))
    t.set_stylebox("normal", "Button", _sb(RED0, GOLD, 2, 6, 18))
    t.set_stylebox("hover", "Button", _sb(RED, GOLD1, 2, 6, 18))
    t.set_stylebox("pressed", "Button", _sb(Color("#6e211b"), GOLD1, 2, 6, 18))
    t.set_stylebox("disabled", "Button", _sb(Color("#3b3148"), Color("#5a4e68"), 2, 6, 18))
    t.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), GOLD1, 2, 6, 18))
    t.set_color("font_color", "Button", GOLD1)
    t.set_color("font_hover_color", "Button", GOLD1)
    t.set_color("font_pressed_color", "Button", GOLD1)
    t.set_color("font_disabled_color", "Button", MUTED)
    for cls in ["LineEdit", "TextEdit"]:
        t.set_stylebox("normal", cls, _sb(Color("#2a2235"), Color("#5a4e68"), 1, 6, 12))
        t.set_stylebox("focus", cls, _sb(Color("#2a2235"), GOLD, 2, 6, 12))
        t.set_color("font_color", cls, PAPER)
        t.set_color("font_placeholder_color", cls, MUTED)
        t.set_color("caret_color", cls, GOLD1)
    return t

## 压在场景图上的字：错开 2 个像素的深色硬投影，比描边清楚
func _hard_shadow(l: Label) -> void:
    l.add_theme_color_override("font_shadow_color", Color(0.08, 0.05, 0.1, 0.9))
    l.add_theme_constant_override("shadow_offset_x", 2)
    l.add_theme_constant_override("shadow_offset_y", 2)

func _label(text: String, size := 24, color := PAPER, align := HORIZONTAL_ALIGNMENT_CENTER, wrap := true) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.horizontal_alignment = align
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
    return l

func _center_panel(width := 440.0) -> Array:
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var dim := ColorRect.new()
    dim.color = Color(0.06, 0.03, 0.06, 0.55)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(dim)
    var cc := CenterContainer.new()
    cc.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(cc)
    var p := PanelContainer.new()
    p.custom_minimum_size = Vector2(width, 0)
    cc.add_child(p)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    p.add_child(box)
    ui.add_child(root)
    return [root, box]

# ---------- 界面 ----------
func _build_ui() -> void:
    # 开场
    var title := Control.new()
    title.set_anchors_preset(Control.PRESET_FULL_RECT)
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var dim := ColorRect.new()
    dim.color = Color(0.06, 0.02, 0.05, 0.62)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    title.add_child(dim)
    var tv := VBoxContainer.new()
    tv.set_anchors_preset(Control.PRESET_FULL_RECT)
    tv.alignment = BoxContainer.ALIGNMENT_CENTER
    tv.add_theme_constant_override("separation", 40)
    title.add_child(tv)
    var name_l := _label("苏七镇奇缘", 72, GOLD1)
    # 像素字的描边会糊，用错开一个字素的硬投影代替
    name_l.add_theme_color_override("font_shadow_color", RED0)
    name_l.add_theme_constant_override("shadow_offset_x", 6)
    name_l.add_theme_constant_override("shadow_offset_y", 6)
    tv.add_child(name_l)
    var open_b := Button.new()
    open_b.text = "打开看看"
    open_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    open_b.pressed.connect(func(): _goto("nick"))
    tv.add_child(open_b)
    ui.add_child(title)
    screens["title"] = title
    # 昵称：规则见《敏感词与昵称校验模块》第 2 节
    var np := _center_panel()
    screens["nick"] = np[0]
    var nb: VBoxContainer = np[1]
    nick_edit = LineEdit.new()
    nick_edit.placeholder_text = "填一个朋友们认得出的名字"
    nick_edit.max_length = 12
    nick_edit.text_changed.connect(func(_t): _check_nick_ui())
    nb.add_child(nick_edit)
    nb.add_child(_label("其他宾客会看到这个名字", 24, MUTED, HORIZONTAL_ALIGNMENT_LEFT))
    var row := HBoxContainer.new()
    nick_err = _label("", 24, Color("#E8746A"), HORIZONTAL_ALIGNMENT_LEFT)
    nick_err.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    nick_count = _label("0/12", 24, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false)
    row.add_child(nick_err)
    row.add_child(nick_count)
    nb.add_child(row)
    nick_ok = Button.new()
    nick_ok.text = "好"
    nick_ok.disabled = true
    nick_ok.pressed.connect(func():
        nickname = _normalize(nick_edit.text)
        _goto("avatar"))
    nb.add_child(nick_ok)
    # 形象：8 个预设
    var ap := _center_panel(470.0)
    screens["avatar"] = ap[0]
    var ab: VBoxContainer = ap[1]
    var grid := GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    var group := ButtonGroup.new()
    for i in 8:
        var b := Button.new()
        b.toggle_mode = true
        b.button_group = group
        var gl := Spr.gpt_look(i)
        if gl.is_empty():
            b.icon = Spr.portrait(i, 3)
        else:
            # GPT 画的形象：取朝前站着那一帧
            var at := AtlasTexture.new()
            at.atlas = gl["tex"]
            at.region = Rect2(int(gl["anim"]["down"]["idle"]) * int(gl["frame_w"]), 0, gl["frame_w"], gl["frame_h"])
            b.icon = at
            b.expand_icon = true
        b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
        b.custom_minimum_size = Vector2(96, 124)
        b.add_theme_stylebox_override("normal", _sb(Color("#2a2235"), Color("#5a4e68"), 1, 6, 6))
        b.add_theme_stylebox_override("hover", _sb(Color("#2a2235"), GOLD, 2, 6, 6))
        b.add_theme_stylebox_override("pressed", _sb(Color("#3b2230"), GOLD1, 3, 6, 6))
        b.button_pressed = (i == preset)
        b.pressed.connect(func(): preset = i)
        grid.add_child(b)
    ab.add_child(grid)
    var ok2 := Button.new()
    ok2.text = "好"
    ok2.pressed.connect(func(): _goto("clip"))
    ab.add_child(ok2)
    # 两分钟剪辑：六句还没定，只放占位
    var cp := _center_panel()
    screens["clip"] = cp[0]
    var cb: VBoxContainer = cp[1]
    cb.add_child(_label("【待补】两分钟剪辑", 36, GOLD1))
    cb.add_child(_label("六章各一张图一句话，等阿鱼提供。样机先跳过。", 24, MUTED))
    var go := Button.new()
    go.text = "继续"
    go.pressed.connect(_enter_banquet)
    cb.add_child(go)
    # 吃完出门：下一段还没做
    var ep := _center_panel(480.0)
    screens["end"] = ep[0]
    var eb: VBoxContainer = ep[1]
    eb.add_child(_label("【待做】出了罗曼山庄往南", 36, GOLD1))
    eb.add_child(_label("本地人集市、镇政府、小学门口的黄葛树、老街、石板桥", 24, MUTED))
    var again := Button.new()
    again.text = "再走一遍"
    again.pressed.connect(_enter_banquet)
    eb.add_child(again)
    _build_hud()
    _build_person_card()
    fade = ColorRect.new()
    fade.color = Color(0, 0, 0, 0)
    fade.set_anchors_preset(Control.PRESET_FULL_RECT)
    fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(fade)

func _build_hud() -> void:
    hud = Control.new()
    hud.set_anchors_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(hud)
    var chip := PanelContainer.new()
    chip.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.06, 0.1, 0.78), Color(GOLD, 0.5), 1, 14, 10))
    chip.position = Vector2(14, 14)
    chip.add_child(_label("● 罗曼山庄", 24, GOLD1, HORIZONTAL_ALIGNMENT_LEFT, false))
    hud.add_child(chip)
    stick_base = _ring(STICK_R * 2.0, Color(1, 1, 1, 0.08), Color(GOLD, 0.6))
    stick_knob = _ring(56.0, Color(GOLD1, 0.4), Color(GOLD1, 0.85))
    hud.add_child(stick_base)
    hud.add_child(stick_knob)
    _stick_rest.call_deferred()
    hint = _label("点地面走路", 24, Color(PAPER, 0.85))
    hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
    hint.offset_top = 66
    hint.offset_bottom = 96
    _hard_shadow(hint)
    hud.add_child(hint)
    # 提示框：第 21 版是一行没底色的字，压在场景图上，阿鱼真机上「什么都没看到」（9/17）。
    # 改成和对白框一样的深色底框，排在屏幕上方（位置每帧由 _layout_top 排）
    note_box = PanelContainer.new()
    note_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
    note_box.offset_left = 14; note_box.offset_right = -14
    note_box.add_theme_stylebox_override("panel", _sb(Color(0.106, 0.078, 0.133, 0.94), GOLD1, 2, 6, 14))
    note_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    note = _label("", 24, GOLD1)
    note_box.add_child(note)
    note_box.visible = false
    hud.add_child(note_box)
    sit_btn = Button.new()
    sit_btn.text = "坐这儿"
    sit_btn.visible = false
    sit_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    sit_btn.offset_top = -170
    sit_btn.offset_bottom = -120
    sit_btn.offset_left = -220
    sit_btn.offset_right = 220
    sit_btn.pressed.connect(_on_sit_pressed)
    hud.add_child(sit_btn)
    person_btn = Button.new()
    person_btn.text = ""
    person_btn.visible = false
    # 昵称最长 12 个字，并排时按钮只有 240 宽：放不下就截成省略号，不许把按钮撑到「坐这儿」上面
    person_btn.clip_text = true
    person_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    person_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    person_btn.offset_top = -170
    person_btn.offset_bottom = -120
    person_btn.offset_left = -220
    person_btn.offset_right = 220
    person_btn.pressed.connect(_on_person_pressed)
    hud.add_child(person_btn)
    # 阿鱼说话的对白框：原来在屏幕底下，阿鱼 9/17 要放到屏幕上方（底下留给按钮和操作盘）
    dialog = PanelContainer.new()
    dialog.set_anchors_preset(Control.PRESET_TOP_WIDE)
    dialog.offset_left = 14; dialog.offset_right = -14
    dialog.offset_top = TOP_Y; dialog.offset_bottom = TOP_Y
    dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var dv := VBoxContainer.new()
    dv.add_child(_label("阿鱼", 24, GOLD, HORIZONTAL_ALIGNMENT_LEFT))
    dialog_text = _label("", 24, PAPER, HORIZONTAL_ALIGNMENT_LEFT)
    dv.add_child(dialog_text)
    dialog.add_child(dv)
    dialog.visible = false
    hud.add_child(dialog)
    whisper_box = PanelContainer.new()
    whisper_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    whisper_box.offset_left = 14; whisper_box.offset_right = -14
    whisper_box.offset_top = -380; whisper_box.offset_bottom = -128
    var wv := VBoxContainer.new()
    wv.add_theme_constant_override("separation", 10)
    whisper_edit = TextEdit.new()
    whisper_edit.custom_minimum_size = Vector2(0, 140)
    whisper_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    whisper_edit.text_changed.connect(_check_whisper_ui)
    wv.add_child(whisper_edit)
    var wr := HBoxContainer.new()
    whisper_count = _label("0/200", 24, MUTED, HORIZONTAL_ALIGNMENT_LEFT, false)
    whisper_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    wr.add_child(whisper_count)
    whisper_ok = Button.new()
    whisper_ok.text = "好"
    whisper_ok.disabled = true
    whisper_ok.pressed.connect(_send_whisper)
    wr.add_child(whisper_ok)
    wv.add_child(wr)
    whisper_box.add_child(wv)
    whisper_box.visible = false
    hud.add_child(whisper_box)

## 看人卡片（蓝图 3.2）：形象、昵称、「XX 带进来的」（没有邀请人或查不到邀请人昵称，整行不显示）、敬一杯。
## 点卡片外面暗下去的地方关掉；字体里有「×」再加一个右上角关闭按钮（第 22 版）
func _build_person_card() -> void:
    person_card = Control.new()
    person_card.set_anchors_preset(Control.PRESET_FULL_RECT)
    person_card.visible = false
    var dim := Button.new()
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    for st in ["normal", "hover", "pressed", "focus"]:
        dim.add_theme_stylebox_override(st, _sb(Color(0.06, 0.03, 0.06, 0.6), Color(0, 0, 0, 0), 0, 0, 0))
    dim.pressed.connect(_close_person_card)
    person_card.add_child(dim)
    var cc := CenterContainer.new()
    cc.set_anchors_preset(Control.PRESET_FULL_RECT)
    cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    person_card.add_child(cc)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(400.0, 0)
    cc.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    panel.add_child(box)
    if font.has_char(0xD7):
        var head := HBoxContainer.new()
        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        head.add_child(spacer)
        var close_b := Button.new()
        close_b.text = "×"
        close_b.custom_minimum_size = Vector2(40, 40)
        close_b.pressed.connect(_close_person_card)
        head.add_child(close_b)
        box.add_child(head)
    var pc := CenterContainer.new()
    person_card_portrait = TextureRect.new()
    person_card_portrait.custom_minimum_size = Vector2(140, 220)
    person_card_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    person_card_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    pc.add_child(person_card_portrait)
    box.add_child(pc)
    person_card_name = _label("", 36, GOLD1)
    box.add_child(person_card_name)
    person_card_inviter = _label("", 24, MUTED)
    box.add_child(person_card_inviter)
    person_card_toast_btn = Button.new()
    person_card_toast_btn.text = "敬一杯"
    person_card_toast_btn.pressed.connect(_on_toast_pressed)
    box.add_child(person_card_toast_btn)
    ui.add_child(person_card)

## 形象取法照选形象界面：GPT 画的图集有就取正面 idle 帧做 AtlasTexture，没有就代码画的占位；
## 编号不在 0～7 按 0（和 layered_hall._seated 一样）
func _set_person_portrait(preset_in: int) -> void:
    var p := preset_in
    if p < 0 or p > 7:
        p = 0
    var gl := Spr.gpt_look(p)
    if gl.is_empty():
        person_card_portrait.texture = Spr.portrait(p, 3)
    else:
        var at := AtlasTexture.new()
        at.atlas = gl["tex"]
        at.region = Rect2(int(gl["anim"]["down"]["idle"]) * int(gl["frame_w"]), 0, gl["frame_w"], gl["frame_h"])
        person_card_portrait.texture = at

func _open_person_card(openid: String) -> void:
    if openid == "" or whisper_box.visible:
        return   # 写悄悄话的框开着时不弹卡片
    card_open = true
    card_openid = openid
    var info: Dictionary = hall.resident_names.get(openid, {})
    var nick := str(info.get("nick", ""))
    person_card_name.text = nick if nick != "" else "有人"
    # inviter 没有邀请人时是 null（不是空字符串，见 enterHall/index.js）；查不到邀请人昵称也整行不显示
    var inviter_raw = info.get("inviter", "")
    var inviter := "" if inviter_raw == null else str(inviter_raw)
    var inviter_nick := ""
    if inviter != "":
        inviter_nick = str((hall.resident_names.get(inviter, {}) as Dictionary).get("nick", ""))
    if inviter != "" and inviter_nick != "":
        person_card_inviter.text = inviter_nick + " 带进来的"
        person_card_inviter.visible = true
    else:
        person_card_inviter.text = ""
        person_card_inviter.visible = false
    _set_person_portrait(int(info.get("avatar", -1)))
    person_card_toast_btn.disabled = false
    person_card_toast_btn.text = "敬一杯"
    person_card.visible = true
    hall.walking_enabled = false
    _refresh_seat_buttons()

func _close_person_card() -> void:
    if not card_open:
        return
    card_open = false
    card_openid = ""
    person_card.visible = false
    if state == "banquet" and not whisper_box.visible:
        hall.walking_enabled = true
    _refresh_seat_buttons()

# ---------- 流程 ----------
func _goto(s: String) -> void:
    state = s
    hall.stick = Vector2.ZERO
    stick_touch = -1
    touches.clear()
    for k in screens:
        screens[k].visible = (k == s)
    hud.visible = (s == "banquet")
    if sit_btn != null and s != "banquet":
        sit_btn.visible = false
    if person_btn != null and s != "banquet":
        person_btn.visible = false
    if person_card != null and s != "banquet" and card_open:
        card_open = false
        card_openid = ""
        person_card.visible = false
    hall.walking_enabled = (s == "banquet") and not whisper_box.visible
    if s == "nick":
        nick_edit.grab_focus()
        _check_nick_ui()

func _fade_to(a: float) -> void:
    if fast:
        fade.color.a = a
        return
    var tw := create_tween()
    tw.tween_property(fade, "color:a", a, 0.35)
    await tw.finished

func _enter_banquet() -> void:
    await _fade_to(1.0)
    hall.set_look(preset, nickname)
    hall.couple_armed = true
    hall.exit_armed = false
    hall.exit_mark.visible = false
    whisper_box.visible = false
    hall.reset_to(hall.SPAWN)
    _goto("banquet")
    hint.visible = true
    await _fade_to(0.0)
    _say(LINE_ARRIVE)
    # 存资料、进厅拿席位（蓝图 3.2）。失败不拦流程，只顶部提示
    cloud.call_fn("saveProfile", {"nick": nickname, "avatar": preset}, _after_profile)

func _say(text: String, hold := -1.0) -> void:
    say_token += 1
    var my := say_token
    dialog_text.text = text
    dialog.visible = true
    if hold == 0.0:
        return
    var d := hold if hold > 0.0 else 2.4 + text.length() * 0.09
    await get_tree().create_timer(d).timeout
    if my == say_token:
        dialog.visible = false

func _after_profile(_r: Dictionary) -> void:
    cloud.call_fn("enterHall", {}, _on_enter_hall)

## 拒绝原因转成给玩家看的一句话。没见过的原因一律说「没连上」，但日志里要打出真实原因，
## 不然像第 19 版那样：服务端回 bad_request，玩家只看到「没连上」，查了半天才发现是字段名发错了
func _reason_text(r: Dictionary, where: String) -> String:
    var reason := str(r.get("reason", "network"))
    if not REASONS.has(reason):
        print("[suqi] ", where, " 被拒，原因没见过：", reason, " 整条返回 ", JSON.stringify(r).substr(0, 160))
        return "没连上 再试一下"
    print("[suqi] ", where, " 被拒，原因 ", reason)
    return str(REASONS[reason])

func _on_enter_hall(r: Dictionary) -> void:
    if not bool(r.get("ok", false)):
        _note(_reason_text(r, "进厅"))
        return
    var d: Dictionary = r["data"]
    hall.set_seats(d, cloud.openid())
    # 真机排查用：这厅有多少人、带邀请人的有几个（看人卡片「XX 带进来的」靠这个字段）
    var with_inviter := 0
    for k in hall.resident_names:
        var inv = (hall.resident_names[k] as Dictionary).get("inviter", null)
        if inv != null and str(inv) != "":
            with_inviter += 1
    print("[suqi] 进厅 名字 ", hall.resident_names.size(), " 个 带邀请人的 ", with_inviter, " 个")
    # 服务端可能把人分在试点还没摆出来的桌（T3 以后），金标画不了：提示先找把椅子坐
    if hall._my_chair_pos() == Vector2.ZERO:
        _note("先找把空椅子坐下", 4.0)
    var dg: Dictionary = d.get("digest", {})
    if bool(dg.get("hasNews", false)):
        var names: Dictionary = d.get("names", {})
        var parts: Array[String] = []
        var tc := int(dg.get("toastCount", 0))
        if tc > 0:
            var first: Dictionary = dg["toasts"][0]
            var who := str(names.get(str(first.get("from", "")), {}).get("nick", "有人"))
            parts.append(who + ("等 %d 人敬了你" % tc if tc > 1 else " 敬了你一杯"))
        var bc := int(dg.get("bookLineCount", 0))
        if bc > 0:
            parts.append("簿子上多了 %d 句" % bc)
        _note("，".join(parts), 5.0)

func _on_chair_near(table_id: String, chair_no: int) -> void:
    sit_confirming = false
    near_seat_info = {"table_id": table_id, "chair_no": chair_no}
    _refresh_seat_buttons()

func _on_person_near(openid: String) -> void:
    near_person_id = openid
    _refresh_seat_buttons()

## 「坐这儿」「昵称」两个按钮的显示状态统一在这里算（第 22 版规则 7）：
## 卡片开着、或不在宴会厅里，两个都收起；「坐这儿」进了确认文案时昵称按钮先让开，免得并排挤在一起
func _refresh_seat_buttons() -> void:
    var blocked: bool = card_open or state != "banquet"
    if blocked or int(near_seat_info.get("chair_no", 0)) == 0:
        sit_btn.visible = false
    else:
        sit_target = near_seat_info
        if not sit_confirming:
            sit_btn.text = "坐这儿"
        sit_btn.visible = true
    if blocked or whisper_box.visible or near_person_id == "" or sit_confirming:
        person_btn.visible = false
    else:
        var info: Dictionary = hall.resident_names.get(near_person_id, {})
        var nick := str(info.get("nick", ""))
        person_btn.text = nick if nick != "" else "有人"
        person_btn.visible = true
    _layout_seat_buttons()

## 两个都出现时并排；只有一个时居中（440 宽，和原来一样）。竖屏 540 宽下并排每个 240 宽，够点
func _layout_seat_buttons() -> void:
    if sit_btn.visible and person_btn.visible:
        person_btn.offset_left = -250; person_btn.offset_right = -10
        sit_btn.offset_left = 10; sit_btn.offset_right = 250
    else:
        sit_btn.offset_left = -220; sit_btn.offset_right = 220
        person_btn.offset_left = -220; person_btn.offset_right = 220

func _on_person_pressed() -> void:
    if near_person_id != "":
        _open_person_card(near_person_id)

func _on_toast_pressed() -> void:
    if card_openid == "" or person_card_toast_btn.disabled:
        return
    person_card_toast_btn.disabled = true   # 先置灰防连点
    var target := card_openid
    cloud.call_fn("toast", {"to": target}, func(r): _on_toast_result(r, target))

func _on_toast_result(r: Dictionary, target: String) -> void:
    _close_person_card()
    if bool(r.get("ok", false)):
        var nick := str(hall.resident_names.get(target, {}).get("nick", ""))
        _note(LINE_TOASTED_FMT % (nick if nick != "" else "有人"))
    else:
        _note(_reason_text(r, "敬酒"))

func _on_sit_pressed() -> void:
    if not sit_confirming:
        sit_confirming = true
        var tn: String = hall.table_names.get(sit_target["table_id"], "")
        # 问句放上方提示框，按钮只留「再点一下确认」。蓝图 3.2 9/18 改：换桌不限次数，去掉「今天只能换一次」
        sit_btn.text = "再点一下确认"
        _note("换到" + tn + "那桌？" if tn != "" else "坐这桌？", 4.0)
        _refresh_seat_buttons()   # 昵称按钮先让开
        return
    sit_btn.disabled = true
    # 字段名以服务端为准：changeSeat 收的是驼峰 tableId、chairNo。
    # 本地 sit_target 还是下划线（和 layered_hall 的席位数据一套），发出去的时候转
    cloud.call_fn("changeSeat", {
        "tableId": str(sit_target["table_id"]),
        "chairNo": int(sit_target["chair_no"]),
    }, _on_seat_changed)

func _on_seat_changed(r: Dictionary) -> void:
    sit_btn.disabled = false
    sit_confirming = false
    if bool(r.get("ok", false)):
        hall.apply_change(sit_target["table_id"], int(sit_target["chair_no"]), cloud.openid())
        _note("坐好了")
    else:
        _note(_reason_text(r, "换桌"))
    _refresh_seat_buttons()

func _note(text: String, hold := 3.0) -> void:
    note_token += 1
    var my := note_token
    note.text = text
    note_box.visible = true
    await get_tree().create_timer(hold).timeout
    if my == note_token:
        note_box.visible = false

## 屏幕上方从 TOP_Y 往下排：对白框在上，提示框紧跟在下面；对白框收起时提示框顶上去
func _layout_top() -> void:
    var y := TOP_Y
    if dialog.visible:
        dialog.offset_top = y
        dialog.offset_bottom = y
        y += dialog.size.y + 10.0
    note_box.offset_top = y
    note_box.offset_bottom = y


func _on_reached(what: String) -> void:
    if what == "couple":
        hint.visible = false
        hall.walking_enabled = false
        _say(LINE_TABLE, 0.0)
        whisper_box.visible = true
        whisper_edit.grab_focus()
        _check_whisper_ui()
        _refresh_seat_buttons()   # 写悄悄话的框开着时昵称按钮也收起，别叠在一起
    elif what == "exit":
        await _fade_to(1.0)
        _goto("end")
        await _fade_to(0.0)

func _send_whisper() -> void:
    var text := whisper_edit.text.strip_edges()
    if text == "":
        return
    # 样机只存在本机；正式版存云数据库，只有阿鱼能看
    var path := "user://whispers.json"
    var arr: Array = []
    if FileAccess.file_exists(path):
        var old = JSON.parse_string(FileAccess.get_file_as_string(path))
        if old is Array: arr = old
    arr.append({"nickname": nickname, "text": text, "at": Time.get_datetime_string_from_system()})
    var f := FileAccess.open(path, FileAccess.WRITE)
    f.store_string(JSON.stringify(arr, "  "))
    f.close()
    cloud.call_fn("saveProfile", {"whisper": text}, func(_r): pass)
    whisper_edit.text = ""
    whisper_box.visible = false
    hall.walking_enabled = true
    hall.arm_exit()
    _say(LINE_LEAVE)
    _refresh_seat_buttons()

# ---------- 校验 ----------
func _graphemes(s: String) -> int:
    var ts := TextServerManager.get_primary_interface()
    if ts != null and ts.has_method("string_get_character_breaks"):
        return ts.string_get_character_breaks(s).size()
    return s.length()

func _normalize(s: String) -> String:
    var re := RegEx.new()
    re.compile("[\\x{200B}-\\x{200F}\\x{2060}\\x{FEFF}\\x{0000}-\\x{001F}]")
    s = re.sub(s, "", true)
    var ws := RegEx.new()
    ws.compile("\\s+")
    return ws.sub(s.strip_edges(), " ", true)

## 返回提示文案；空字符串是可以提交，"empty" 是还没填
func _check_nick(raw: String) -> String:
    var s := _normalize(raw)
    if s == "":
        return "empty"
    var g := _graphemes(s)
    if g < 2: return "再长一点"
    if g > 12: return "最多 12 个字"
    var digits := RegEx.new()
    digits.compile("^[0-9 ]+$")
    var letters := RegEx.new()
    letters.compile("[\\p{L}\\p{N}]")
    if digits.search(s) != null or letters.search(s) == null:
        return "用中文、英文或数字"
    # 字体里没有的字（生僻字、表情），别的宾客那里会显示成空白
    for i in s.length():
        if not font.has_char(s.unicode_at(i)):
            return "有个字显示不出来 换一个"
    return ""

func _check_nick_ui() -> void:
    var r := _check_nick(nick_edit.text)
    nick_count.text = "%d/12" % _graphemes(_normalize(nick_edit.text))
    nick_err.text = "" if r == "empty" else r
    nick_ok.disabled = r != ""

func _check_whisper_ui() -> void:
    var n := _graphemes(whisper_edit.text.strip_edges())
    whisper_count.text = "%d/200" % n
    whisper_count.add_theme_color_override("font_color", Color("#E8746A") if n > 200 else MUTED)
    whisper_ok.disabled = n == 0 or n > 200

# ---------- 输入 ----------
## 触屏操作（只认触摸事件；电脑上鼠标会被当成触摸，见 project.godot）：
## 屏幕左下方按住拖 = 摇杆；别处左右拖 = 转镜头；轻点一下 = 走过去
func _unhandled_input(e: InputEvent) -> void:
    if e is InputEventScreenTouch and not e.pressed:
        var tc = touches.get(e.index)
        touches.erase(e.index)
        if e.index == stick_touch:
            stick_touch = -1
            hall.stick = Vector2.ZERO
            _stick_rest()
        var quick: bool = tc != null and not tc["drag"] and Time.get_ticks_msec() - int(tc["t"]) < 350
        if quick and state == "banquet" and hall.walking_enabled:
            hint.visible = false
            hall.tap(e.position)
        return
    if state != "banquet" or not hall.walking_enabled:
        return
    var vp := get_viewport().get_visible_rect().size
    if e is InputEventScreenTouch and e.pressed:
        touches[e.index] = {"start": e.position, "t": Time.get_ticks_msec(), "drag": false}
        if stick_touch == -1 and e.position.x < vp.x * 0.5 and e.position.y > vp.y * 0.5:
            stick_touch = e.index
            stick_origin = e.position
            _stick_show(stick_origin, Vector2.ZERO)
    elif e is InputEventScreenDrag:
        var tc = touches.get(e.index)
        if tc == null:
            return
        if not tc["drag"] and (tc["start"] as Vector2).distance_to(e.position) > 12.0:
            tc["drag"] = true
            hint.visible = false
        if not tc["drag"]:
            return
        if e.index == stick_touch:
            var v: Vector2 = (e.position - stick_origin) / STICK_R
            if v.length() > 1.0:
                v = v.normalized()
            hall.stick = v
            _stick_show(stick_origin, v)
        else:
            hall.rotate_cam(e.relative.x)

## 摇杆：平时淡淡地停在左下角提示有它；按下时跟到手指位置
func _ring(d: float, bg: Color, border: Color) -> Panel:
    var p := Panel.new()
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(2)
    s.set_corner_radius_all(int(d / 2.0))
    p.add_theme_stylebox_override("panel", s)
    p.size = Vector2(d, d)
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return p

func _stick_show(center: Vector2, v: Vector2) -> void:
    stick_base.position = center - stick_base.size / 2.0
    stick_knob.position = center + v * STICK_R - stick_knob.size / 2.0
    stick_base.modulate.a = 1.0
    stick_knob.modulate.a = 1.0

func _stick_rest() -> void:
    var vp := get_viewport().get_visible_rect().size
    _stick_show(Vector2(STICK_R + 36.0, vp.y - 220.0), Vector2.ZERO)
    stick_base.modulate.a = 0.45
    stick_knob.modulate.a = 0.45

# ---------- 自动截图（开发用） ----------
func _setup_shot(shot: String) -> void:
    match shot:
        "title":
            _goto("title")
        "nick":
            _goto("nick")
            nick_edit.text = "小李"
            _check_nick_ui()
        "avatar":
            nickname = "小李"
            _goto("avatar")
        "clip":
            _goto("clip")
        "arrive":
            nickname = "小李"
            await _enter_banquet()
        "walk":
            nickname = "小李"
            await _enter_banquet()
            hall.reset_to(Vector2(760, 640) if USE_LAYERED else Vector2(1.4, -7.2))
            hall.face = "up"
        "sit":
            # 换桌成功以后的样子：人坐在椅子上、面朝桌心，顶部一句「坐好了」
            nickname = "小李"
            await _enter_banquet()
            if USE_LAYERED:
                sit_target = {"table_id": "T1", "chair_no": 4}
                hall.apply_change("T1", 4, cloud.openid())
                _note("坐好了")
                await get_tree().process_frame
        "sit_front", "sit_back":
            # 坐下的样子（占位）两个方向：桌子前面那把（背对镜头）、桌子后面那把（面朝镜头）
            nickname = "小李"
            await _enter_banquet()
            if USE_LAYERED:
                if shot == "sit_front":
                    hall.reset_to(hall.near(hall.chair_world(hall._table_cfg("T1"), 6), Vector2(0.0, 0.8)))
                    hall.apply_change("T1", 6, cloud.openid())
                else:
                    hall.reset_to(hall.near(hall.chair_world(hall._table_cfg("T2"), 1), Vector2(0.0, -0.8)))
                    hall.apply_change("T2", 1, cloud.openid())
                _note("坐好了")
                await get_tree().process_frame
        "person":
            # 站在一个坐着的人（老王）旁边，底部昵称按钮出来了（第 22 版）
            nickname = "小李"
            await _enter_banquet()
            if USE_LAYERED:
                hall.reset_to(hall.chair_world(hall._table_cfg("T1"), 1))
                await get_tree().process_frame
        "card":
            # 卡片打开：形象、昵称、「老王 带进来的」、敬一杯（第 22 版）
            nickname = "小李"
            await _enter_banquet()
            if USE_LAYERED:
                hall.reset_to(hall.chair_world(hall._table_cfg("T2"), 4))
                _open_person_card("fake_li")
                await get_tree().process_frame
        "toasted":
            # 敬完，顶部「敬了 XX 一杯」（第 22 版，文案新写，等阿鱼定）
            nickname = "小李"
            await _enter_banquet()
            _note(LINE_TOASTED_FMT % "老王")
            await get_tree().process_frame
        "couple":
            nickname = "小李"
            preset = 5
            await _enter_banquet()
            hall.reset_to(hall.near(hall.COUPLE_SPOT, Vector2(0.2, 0.6)))
            await get_tree().process_frame
            await get_tree().process_frame
            whisper_edit.text = "新婚快乐"
            _check_whisper_ui()
        "leave":
            nickname = "小李"
            preset = 7
            await _enter_banquet()
            hall.couple_armed = false
            hall.reset_to(Vector2(860, 780) if USE_LAYERED else Vector2(0.4, -1.0))
            whisper_edit.text = "测试"
            _send_whisper()
        "behind":
            # 站在桌子后面：看椅背有没有挡住腿、人有没有被地面切掉
            nickname = "小李"
            await _enter_banquet()
            hall.couple_armed = false
            hall.reset_to(Vector2(478, 690) if USE_LAYERED else Vector2(-4.8, -3.6))
            dialog.visible = false
        "end":
            _goto("end")
        "stick":
            # 摇杆往左上推、镜头转到左边 40 度：看转镜头和摇杆有没有画对
            nickname = "小李"
            await _enter_banquet()
            hall.reset_to(Vector2(1000, 700) if USE_LAYERED else Vector2(0.0, -4.0))
            if not USE_LAYERED:
                hall.cam_yaw = deg_to_rad(40.0)
            hall.snap_cam()
            hall.stick = Vector2(-0.5, -0.8)
            _stick_show(Vector2(STICK_R + 36.0, get_viewport().get_visible_rect().size.y - 220.0), Vector2(-0.5, -0.8))
        "overview":
            # 和 GPT 的拼装预览图对照用：高处俯视整个厅，没有界面
            nickname = ""
            await _enter_banquet()
            hall.couple_armed = false
            hall.reset_to(Vector2(836, 700) if USE_LAYERED else Vector2(0.0, -3.0))
            hud.visible = false
            hall.walking_enabled = false
            hall.set_process(false)
            if USE_LAYERED:
                # 整张场景图缩进画面，和效果图对照
                var vs := get_viewport().get_visible_rect().size
                var z := minf(vs.x / 1672.0, vs.y / 941.0)
                hall.cam.zoom = Vector2(z, z)
                hall.cam.position = Vector2(836, 470)
                hall.cam.reset_smoothing()
            else:
                hall.cam.fov = 50.0
                hall.cam.position = Vector3(0, 19.0, 10.5)
                hall.cam.look_at(Vector3(0, 0, -8.0), Vector3.UP)
        "share":
            # 分享卡片用的干净画面：没有界面，站在新人桌前
            nickname = ""
            preset = 2
            await _enter_banquet()
            hall.couple_armed = false
            hall.reset_to(hall.near(hall.COUPLE_SPOT, Vector2(0.0, 2.2)))
            hud.visible = false
