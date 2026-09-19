extends Node
## 苏七镇奇缘 · 罗曼山庄吃席 demo
## 流程按《苏七镇 · 阶段 1 设计 v1.0》3.1：昵称 → 形象 → 两分钟剪辑 → 罗曼山庄吃席、给新人写悄悄话 → 出山庄
## 画面上的对白全部摘自设计文档；【待补】【待做】是占位，不是正式内容

const Hall = preload("res://scripts/hall.gd")
const LayeredHall = preload("res://scripts/layered_hall.gd")
## 罗曼山庄迎宾院（蓝图 3.1，灰盒，01 9/19 派）：进山庄先到这里，走到楼门进宴会厅，宴会厅的门出来回到这里
const Entrance = preload("res://scripts/entrance.gd")
const CourtCopy = preload("res://scripts/court_copy.gd")
## 切画布：0.35 秒暖色淡出淡入（蓝图 1），人保持朝向，出现在对面的「到了站在」点
const SWITCH_TINT := Color("#3a1d12")
const COURT_FROM_HALL := Vector2(768, 260)   # 蓝图 1 出入口表：宴会厅的门 → 迎宾院 (768, 260)
## 后厅（蓝图 3.3，灰盒，01 9/19 派任务 7）：宴会厅东侧门进去，西口出来回宴会厅
const Backhall = preload("res://scripts/backhall.gd")
const BackhallUI = preload("res://scripts/backhall_ui.gd")
## 蓝图 1 出入口表写宴会厅 → 后厅站 (50, 780)，离后厅西口 (40, 780, 50) 只有 10 像素、站在出口圈里；
## 01 9/19 定：到了站的点离出口至少 1 米，沿出口方向往里挪，所以是 (100, 780)
const BACKHALL_FROM_HALL := Vector2(100, 780)
const HALL_FROM_BACKHALL := Vector2(1440, 600)   # 蓝图 1：后厅西口 → 宴会厅 (1440, 600)，离东侧门 60 像素
## 草坪（蓝图 3.4，灰盒，01 9/19 派任务 8）：迎宾院东小径、后厅厨房后门都通这里；北口去果园还没修好
const Lawn = preload("res://scripts/lawn.gd")
const LawnUI = preload("res://scripts/lawn_ui.gd")
## 蓝图 1 写迎宾院 → 草坪站 (50, 780)、后厅 → 草坪站 (50, 300)，离草坪西南口 (40, 780, 50)、西北口 (40, 300, 50) 都只有 10 像素；
## 照 01 9/19 的规矩（到了站的点离出口至少 1 米，沿出口方向往里挪）改成下面两个，离出口 60 像素
const LAWN_FROM_COURT := Vector2(100, 780)
const LAWN_FROM_BACKHALL := Vector2(100, 300)
const COURT_FROM_LAWN := Vector2(1440, 780)      # 蓝图 1：草坪西南口 → 迎宾院 (1440, 780)，离东小径 60 像素
const BACKHALL_FROM_LAWN := Vector2(1440, 780)   # 蓝图 1：草坪西北口 → 后厅 (1440, 780)，离厨房后门 60 像素
var court
var backhall
var backhall_ui: Control        # 后厅四个房间的按钮（backhall_ui.gd）
var lawn
var lawn_ui: Control            # 草坪的「踢一脚」（lawn_ui.gd）
var kids_heard := false         # 这次在草坪小孩说过了（每回到草坪说一次）
var cv                          # 现在人在哪块画布（court、hall 或 backhall）：走路、摇杆、镜头都交给它
var switching := false
var hall_door_latched := true   # 刚进宴会厅时人就站在门口：先走出门的范围，门才算数（不会来回弹）
var hall_side_latched := true   # 东侧门也一样：从后厅回来站在门边，先走出去一次才算
var profile_saved := false      # 这次打开游戏 saveProfile 成功过没有（进厅前要有住民记录）
const CourtSave = preload("res://scripts/court_save.gd")
const CourtUI = preload("res://scripts/court_ui.gd")
var court_save                  # 迎宾院存在本机的：迎过了、签过到、喜糖……（蓝图 2.4）
var court_ui: Control           # 迎宾院的按钮和面板：签到、回忆册、合影……
var photo_greeted := false      # 这次在迎宾院摄影师招呼过了（每回到迎宾院招呼一次，不走一步说一句）
var rest_heard := false         # 这次在迎宾院休息区的老人说过了（同上）
var debug_override := false     # 测试里当成调试版（回忆册的占位屏只有调试版能打开）
## 宴会厅用分层场景（画面就是 GPT 的效果图，阿鱼 9/15 选定）；false 回到 3D 搭的 HD-2D 宴会厅
const USE_LAYERED := true
const Spr = preload("res://scripts/sprites.gd")

const LINE_ARRIVE := "到啦～ 罗曼山庄 席还没散"
const LINE_TABLE := "想跟我们说点什么 写这儿 只有我们看得到"
const LINE_LEAVE := "吃好了？走 带你回镇上"
const LINE_TOASTED_FMT := "敬了 %s 一杯"   # 新写，等阿鱼定
const LINE_CHEERS := "干杯"   # 敬酒插图上的大字，新写，等阿鱼定
## 想认识你（蓝图 3.2 加好友，01 9/19 派）：看人卡片「敬一杯」旁边。现在同一桌、或者敬过酒（谁敬谁都算）才能发，服务端判；
## 阶段 1 只记请求（云函数 wantToMeet 写 friend_request），对方看不到，好友关系在阶段 2
const LINE_MEET := "想认识你"   # 按钮上的字，蓝图 3.2、阶段 1 设计 v1.1 §4 文案「加好友请求」
const LINE_MEET_SENT_FMT := "想认识 %s 记下了"   # 发成功后顶部那句，新写，等阿鱼定
## 长凳（蓝图 3.2「满了新来的人坐在墙边的长凳上」，01 9/19 派任务 5）：服务端把我分到长凳时进厅说一句，金标在凳子上我那个位置
const LINE_BENCH := "桌子都坐满了 先坐墙边的长凳"   # 新写，等阿鱼定
const ToastScene = preload("res://scripts/toast_scene.gd")
## 席间小游戏（蓝图 3.2，阿鱼 9/19 定）：两桌一个，坐下后点桌心的菜或底下「玩·XX」开；金币只能玩出来，唯一去处是主桌添礼金
const GameCfg = preload("res://scripts/games/game_config.gd")
const GameSave = preload("res://scripts/games/game_save.gd")
const GameHost = preload("res://scripts/games/game_host.gd")
const LINE_SIT_FIRST_GAME := "先坐下 再玩"   # 在自己没坐着的桌点桌心的菜（蓝图 3.2 异常表：文案待阿鱼定），新写
const LINE_GIFT_DONE_FMT := "添了 %d 金 礼金簿记上了"   # 主桌添礼金以后，新写，等阿鱼定
const GIFT_CHOICES := [8, 88, 188, 888]
var games_save
var game_host: Control
var play_btn: Button            # 坐在有小游戏的桌上时出现：「玩·吃席」
var coins_chip: Label           # 右上角：手上几金
var gift_row: HBoxContainer     # 写悄悄话的框里：「手上 N 金 添礼金」，有金币才出
var gift_pick: HBoxContainer    # 点「添礼金」以后换成几个数目
## 在厅里时每隔几秒问一次服务端「有没有人刚敬我」（云函数 hallPulse，阿鱼 9/18 晚：被敬的人在线要当场知道）
const PULSE_EVERY := 8.0
var pulse_t := 0.0
var pulse_since := 0            # hallPulse 上一次回的服务端时间（毫秒）；0 表示这次进厅还没对过表
var pulse_busy := false
var hall_ready := false         # 这次进厅拿到席位了没（拿到才开始问 hallPulse）
var pulse_seen: Dictionary = {} # 这次进厅报过的敬酒「from:created_at」：hallPulse 往回多看 3 秒，靠它去重
var toast_scene: Control
var toast_queue: Array = []     # 排队等着放的干杯插图 [left, right, caption]
## 回敬（蓝图 3.2「可回敬一次」，01 9/19 派）：被敬以后顶部那句提示右边出一个按钮，点了直接敬回去，不用再去找对方的座位
const LINE_TOAST_BACK := "回敬一杯"   # 按钮上的字，新写，等阿鱼定
const TOAST_BACK_SECS := 6.0    # 被敬的那句提示连同按钮留多久，秒
var toast_back_btn: Button
var toast_back_to := ""         # 回敬给谁（openid）；"" 表示现在没有可回敬的
var toast_back_info: Dictionary = {}   # 对方的昵称、形象（hallPulse、enterHall 带回的 names；对方不一定坐在我这边的厅里）
var toast_back_note := -1       # 按钮跟的是哪一句提示（note_token）：提示换了一句、或者收了，按钮一起收
const LINE_BOOK_EMPTY := "还没人写 你来第一句"   # 新写，等阿鱼定
const BOOK_PLACEHOLDER := "接一句"   # 新写，等阿鱼定
const LINE_BOOK_READONLY := "先坐下 慢慢写"   # 蓝图 3.2 9/18 定稿：不是自己现在坐的那桌，只能看
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
var dialog_who: Label      # 说话框左上角：谁在说（默认阿鱼；迎宾院有新娘妈妈、新娘爸爸、摄影师、老人）
var dialog_gloss := ""     # 这句里方言词的普通话（《乐山话 v0.2》：点一下出普通话）；空的时候说话框点不了
var say_log: Array = []    # 最近说过的 20 句 [谁, 话]：一串话接着说时前一句会被盖掉，测试、排查靠它看说过什么
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
var person_card_meet_btn: Button     # 想认识你，挨着敬一杯
var book_btn: Button      # 走到桌边、或坐在自己桌上时出现，「翻簿子」（第 24 版，蓝图 3.2）
var near_table_id := ""   # hall.table_near 最新一次的内容
var book_open := false
var book_table := ""      # 正在翻的是哪一桌
var book_empty_shown := false   # 列表当前显示的是不是「还没人写 你来第一句」占位
var book_panel: Control
var book_list_box: VBoxContainer
var book_scroll: ScrollContainer
var book_loading: Label
var book_input_row: VBoxContainer   # 输入框 + 好，写得了的时候显示
var book_readonly_label: Label      # 「先坐下 慢慢写」，写不了的时候显示
var book_edit: TextEdit
var book_count: Label
var book_err: Label
var book_ok: Button
const CloudRpc = preload("res://scripts/cloud.gd")
var cloud: Node
# 拒绝原因对照（server-claude/README.md，文案阿鱼定稿）。
# 云函数的字段名和拒绝原因清单见 godot/回执/席位桥修复.md 第七节，发请求前对一遍
const REASONS := {
    "seat_taken": "这把有人坐了",   # changed_today（今天换过了）9/18 蓝图改为换桌不限次数，服务端不再回
    "toast_limit": "今天敬够了", "toast_same_person": "这杯敬过了",
    "toast_self": "自己就不用敬了", "not_sat_here": "先坐下 慢慢写",
    "book_too_long": "太长啦 真实情感的话 短一点也没关系",
    "network": "没连上 再试一下", "no_resident": "没连上 再试一下",
    # 这两个是字段名对不上、或者服务端那边没有我的座位，玩家看不懂，统一说没连上；
    # 真实原因打进日志，不然又会像第 19 版那样被「没连上」盖住（bad_request 当时就是 changeSeat 字段名发错了）
    "bad_request": "没连上 再试一下", "no_seat": "没连上 再试一下",
    # 敏感词模块（docs/敏感词模块-需求.md 第 2 节定稿文案，回执 05）：起昵称、写簿子命中都用这两句
    "sensitive": "换一个吧", "reserved": "这个名字留给主角了，换一个吧",
    # 想认识你（01 9/19 派）：三句都是新写，等阿鱼定，照异常表的口吻（「自己就不用敬了」「这杯敬过了」「先坐下 慢慢写」）
    "meet_self": "自己就不用认识了", "meet_already": "这句说过了", "meet_not_met": "先坐到一桌 或者敬一杯",
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
# 远程加载的最小验证（HANDOFF §0.9，01 9/19 派）：只有调试版日志面板里有入口，见 scripts/remote_probe.gd
const RemoteProbe = preload("res://scripts/remote_probe.gd")
var remote_probe: RefCounted     # 正在跑的那一次（跑完清掉）；跑的时候再点不重复开
var remote_status: Label
var remote_img: TextureRect

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
    games_save = GameSave.new()
    games_save.load_local()
    games_save.saver = _save_games
    hall = LayeredHall.new() if USE_LAYERED else Hall.new()
    sv.add_child(hall)
    hall.build(preset, "", font)
    print("[suqi] 宴会厅搭好了")
    hall.reached.connect(_on_reached)
    if USE_LAYERED:
        hall.chair_near.connect(_on_chair_near)
        hall.person_near.connect(_on_person_near)
        hall.table_near.connect(_on_table_near)
        hall.game_tap.connect(_on_game_tap)
    hall.walking_enabled = false
    court = Entrance.new()
    sv.add_child(court)
    court.build(preset, "", font)
    court.spot.connect(_on_court_spot)
    court.walking_enabled = false
    print("[suqi] 迎宾院搭好了")
    backhall = Backhall.new()
    sv.add_child(backhall)
    backhall.build(preset, "", font)
    backhall.spot.connect(_on_backhall_spot)
    backhall.walking_enabled = false
    print("[suqi] 后厅搭好了")
    lawn = Lawn.new()
    sv.add_child(lawn)
    lawn.build(preset, "", font)
    lawn.spot.connect(_on_lawn_spot)
    lawn.walking_enabled = false
    print("[suqi] 草坪搭好了")
    _show_canvas("banquet")   # 开场、起名、选形象时背后是宴会厅（和原来一样）
    _build_ui()
    court_save = CourtSave.new()
    court_save.load_local()
    court_ui = CourtUI.new()
    ui.add_child(court_ui)
    court_ui.setup(self, font, court_save)
    court_ui.panel_changed.connect(func(open): court.walking_enabled = state == "court" and not open)
    backhall_ui = BackhallUI.new()
    ui.add_child(backhall_ui)
    backhall_ui.setup(self)
    lawn_ui = LawnUI.new()
    ui.add_child(lawn_ui)
    lawn_ui.setup(self)
    ui.move_child(fade, -1)   # 黑幕盖在迎宾院的面板上面
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
    var dv := VBoxContainer.new()
    dv.add_theme_constant_override("separation", 8)
    dbg_panel.add_child(dv)
    # 远程加载的最小验证（§0.9）：先点「远程加载」（下载、存本地、显示），关掉小游戏再打开、再点一次，
    # 应该写「读的本地，没下载」。「删掉本地副本」用来重验下载那一路。回执 godot/回执/远程加载-最小验证.md
    var rrow := HBoxContainer.new()
    rrow.add_theme_constant_override("separation", 8)
    var rb := Button.new()
    rb.text = "远程加载"
    rb.pressed.connect(_run_remote_probe)
    rrow.add_child(rb)
    var rc := Button.new()
    rc.text = "删掉本地副本"
    rc.pressed.connect(_clear_remote_probe)
    rrow.add_child(rc)
    dv.add_child(rrow)
    remote_status = _label("", 24, GOLD1, HORIZONTAL_ALIGNMENT_LEFT)
    dv.add_child(remote_status)
    remote_img = TextureRect.new()
    remote_img.custom_minimum_size = Vector2(0, 240)
    remote_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    remote_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    remote_img.visible = false
    dv.add_child(remote_img)
    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    dbg_text = _label("", 12, PAPER, HORIZONTAL_ALIGNMENT_LEFT)
    dbg_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.add_child(dbg_text)
    dv.add_child(sc)
    dbg_panel.visible = false
    ui.add_child(dbg_panel)

func _toggle_log() -> void:
    dbg_panel.visible = not dbg_panel.visible
    if dbg_panel.visible:
        dbg_text.text = _read_js_log()

## 远程加载的最小验证（HANDOFF §0.9）：本地有就读本地，没有就从云存储下载；结果一行字加那张图，日志跟着刷新。
## p：截图时传一个填好假 File ID 的进来（电脑上走 cloud.gd 的假下载）；按钮点的时候是空的，照 assets/remote_probe.json
func _run_remote_probe(p: RefCounted = null) -> void:
    if remote_probe != null:
        return
    remote_status.text = "远程加载中"
    remote_probe = p if p != null else RemoteProbe.new()
    remote_probe.run(cloud, func(r: Dictionary):
        remote_probe = null
        remote_status.text = str(r.get("text", ""))
        var tex = r.get("texture", null)
        remote_img.texture = tex
        remote_img.visible = tex != null
        dbg_text.text = _read_js_log())

func _clear_remote_probe() -> void:
    if remote_probe != null:
        return
    var had: bool = RemoteProbe.new().clear_local()
    remote_status.text = "本地副本删了，再点「远程加载」会重新下载" if had else "本地没有副本"
    remote_img.texture = null
    remote_img.visible = false

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
    if coins_chip != null and _in_scene():
        coins_chip.text = "%d 金" % games_save.coins
    # 宴会厅的门出去回迎宾院（蓝图 1 出入口表）。刚进厅时人就站在门口：先走出门的范围，门才算数
    if state == "banquet" and not switching and hall.door_r > 0.0:
        var dd: float = hall.pos.distance_to(hall.door)
        if hall_door_latched:
            if dd > hall.door_r:
                hall_door_latched = false
        elif dd < hall.door_r and hall.walking_enabled:
            _switch_canvas("court")
    # 东侧门进后厅（蓝图 1、3.2），一样先走出去一次才算
    if state == "banquet" and not switching and USE_LAYERED and hall.side_door_r > 0.0:
        var sd: float = hall.pos.distance_to(hall.side_door)
        if hall_side_latched:
            if sd > hall.side_door_r:
                hall_side_latched = false
        elif sd < hall.side_door_r and hall.walking_enabled:
            _switch_canvas("backhall")
    if state == "banquet" and hall_ready and not pulse_busy:
        pulse_t += dt
        # 进厅后先对一次表（1 秒后），之后每 PULSE_EVERY 秒问一次
        if pulse_t >= (1.0 if pulse_since == 0 else PULSE_EVERY):
            pulse_t = 0.0
            pulse_busy = true
            cloud.call_fn("hallPulse", {"since": pulse_since}, _on_pulse)
    if stick_base != null:
        # 写悄悄话、说话的时候不能走，摇杆也藏起来
        var show_stick: bool = _in_scene() and cv.walking_enabled
        stick_base.visible = show_stick
        stick_knob.visible = show_stick
        if not show_stick and stick_touch != -1:
            stick_touch = -1
            cv.stick = Vector2.ZERO
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
    ok2.pressed.connect(_enter_court)   # 选完形象从迎宾院大门进来（蓝图 2.1）；两分钟剪辑挪进回忆册
    ab.add_child(ok2)
    # 两分钟剪辑：六句还没定，只放占位
    var cp := _center_panel()
    screens["clip"] = cp[0]
    var cb: VBoxContainer = cp[1]
    cb.add_child(_label("【待补】两分钟剪辑", 36, GOLD1))
    cb.add_child(_label("六章各一张图一句话，等阿鱼提供。样机先跳过。", 24, MUTED))
    var go := Button.new()
    go.text = "继续"
    go.pressed.connect(_close_clip)   # 回忆册的剪辑看完（或点「继续」）回到迎宾院，人站在原地（世界观 1.1）
    cb.add_child(go)
    # 吃完出门：下一段还没做
    var ep := _center_panel(480.0)
    screens["end"] = ep[0]
    var eb: VBoxContainer = ep[1]
    eb.add_child(_label("【待做】出了罗曼山庄往南", 36, GOLD1))
    eb.add_child(_label("本地人集市、镇政府、小学门口的黄葛树、老街、石板桥", 24, MUTED))
    var again := Button.new()
    again.text = "再走一遍"
    again.pressed.connect(_enter_court)
    eb.add_child(again)
    _build_hud()
    _build_person_card()
    _build_book_panel()
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
    var cchip := PanelContainer.new()
    cchip.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.06, 0.1, 0.78), Color(GOLD, 0.5), 1, 14, 10))
    cchip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    cchip.offset_left = -150
    cchip.offset_right = -14
    cchip.offset_top = 14
    coins_chip = _label("0 金", 24, GOLD1, HORIZONTAL_ALIGNMENT_RIGHT, false)
    cchip.add_child(coins_chip)
    hud.add_child(cchip)
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
    book_btn = Button.new()
    book_btn.text = "翻簿子"
    book_btn.visible = false
    book_btn.clip_text = true
    book_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    book_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    book_btn.offset_top = -170
    book_btn.offset_bottom = -120
    book_btn.pressed.connect(_on_book_btn_pressed)
    hud.add_child(book_btn)
    play_btn = Button.new()
    play_btn.visible = false
    play_btn.clip_text = true
    play_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    play_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    play_btn.offset_top = -170
    play_btn.offset_bottom = -120
    play_btn.pressed.connect(func(): _open_game(str(hall.my_seat.get("table_id", ""))))
    hud.add_child(play_btn)
    # 阿鱼说话的对白框：原来在屏幕底下，阿鱼 9/17 要放到屏幕上方（底下留给按钮和操作盘）
    dialog = PanelContainer.new()
    dialog.set_anchors_preset(Control.PRESET_TOP_WIDE)
    dialog.offset_left = 14; dialog.offset_right = -14
    dialog.offset_top = TOP_Y; dialog.offset_bottom = TOP_Y
    dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var dv := VBoxContainer.new()
    dialog_who = _label("阿鱼", 24, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
    dv.add_child(dialog_who)
    dialog_text = _label("", 24, PAPER, HORIZONTAL_ALIGNMENT_LEFT)
    dv.add_child(dialog_text)
    dialog.add_child(dv)
    dialog.visible = false
    # 带方言词的话（休息区老人）：说话框能点，点一下出普通话（《乐山话 v0.2》§2）
    dialog.gui_input.connect(func(e):
        if dialog_gloss != "" and ((e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed):
            _note(dialog_gloss, 2.5)
            dialog.accept_event())
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
    # 主桌添礼金（蓝图 3.2 9/19）：小游戏玩出来的金币添给新人，服务端礼金簿记一笔。没金币这一行不出
    gift_row = HBoxContainer.new()
    var gl := _label("", 24, GOLD1, HORIZONTAL_ALIGNMENT_LEFT, false)
    gl.name = "coins"
    gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    gift_row.add_child(gl)
    var gb := Button.new()
    gb.text = "添礼金"
    gb.pressed.connect(_open_gift_pick)
    gift_row.add_child(gb)
    wv.add_child(gift_row)
    gift_pick = HBoxContainer.new()
    gift_pick.add_theme_constant_override("separation", 8)
    gift_pick.visible = false
    wv.add_child(gift_pick)
    whisper_box.add_child(wv)
    whisper_box.visible = false
    hud.add_child(whisper_box)
    # 回敬一杯：挂在 ui 上、不在 hud 里，这样能挪到干杯插图上面，插图开着也点得到（见 _restack_top）。位置每帧由 _layout_top 排
    toast_back_btn = Button.new()
    toast_back_btn.text = LINE_TOAST_BACK
    toast_back_btn.visible = false
    toast_back_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    toast_back_btn.pressed.connect(_on_toast_back_pressed)
    ui.add_child(toast_back_btn)

## 看人卡片（蓝图 3.2）：形象、昵称、「XX 带进来的」（没有邀请人或查不到邀请人昵称，整行不显示），
## 底下一排两个按钮「敬一杯」「想认识你」（阶段 1 只显示这三样，9/19 总策划定）。
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
    var btns := HBoxContainer.new()
    btns.add_theme_constant_override("separation", 12)
    person_card_toast_btn = Button.new()
    person_card_toast_btn.text = "敬一杯"
    person_card_toast_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    person_card_toast_btn.pressed.connect(_on_toast_pressed)
    btns.add_child(person_card_toast_btn)
    person_card_meet_btn = Button.new()
    person_card_meet_btn.text = LINE_MEET
    person_card_meet_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    person_card_meet_btn.pressed.connect(_on_meet_pressed)
    btns.add_child(person_card_meet_btn)
    box.add_child(btns)
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

## 翻簿子面板（第 24 版，蓝图 3.2）：样式照看人卡片——暗底、点外面或右上角「×」关。
## 先「加载中」，读到接龙列表；列表下面输入框 + 好；不是自己现在坐的那桌时输入换成一行「先坐下 慢慢写」
func _build_book_panel() -> void:
    book_panel = Control.new()
    book_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    book_panel.visible = false
    var dim := Button.new()
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    for st in ["normal", "hover", "pressed", "focus"]:
        dim.add_theme_stylebox_override(st, _sb(Color(0.06, 0.03, 0.06, 0.6), Color(0, 0, 0, 0), 0, 0, 0))
    dim.pressed.connect(_close_book_panel)
    book_panel.add_child(dim)
    var cc := CenterContainer.new()
    cc.set_anchors_preset(Control.PRESET_FULL_RECT)
    cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    book_panel.add_child(cc)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(460.0, 0)
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
        close_b.pressed.connect(_close_book_panel)
        head.add_child(close_b)
        box.add_child(head)
    book_scroll = ScrollContainer.new()
    book_scroll.custom_minimum_size = Vector2(0, 220)
    book_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    book_list_box = VBoxContainer.new()
    book_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    book_list_box.add_theme_constant_override("separation", 6)
    book_scroll.add_child(book_list_box)
    box.add_child(book_scroll)
    book_loading = _label("加载中", 24, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
    box.add_child(book_loading)
    book_readonly_label = _label(LINE_BOOK_READONLY, 24, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
    book_readonly_label.visible = false
    box.add_child(book_readonly_label)
    book_input_row = VBoxContainer.new()
    book_input_row.add_theme_constant_override("separation", 10)
    book_edit = TextEdit.new()
    book_edit.custom_minimum_size = Vector2(0, 80)
    book_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    book_edit.placeholder_text = BOOK_PLACEHOLDER
    book_edit.text_changed.connect(_check_book_ui)
    book_input_row.add_child(book_edit)
    var br := HBoxContainer.new()
    book_err = _label("", 24, Color("#E8746A"), HORIZONTAL_ALIGNMENT_LEFT)
    book_err.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    book_count = _label("0/100", 24, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false)
    br.add_child(book_err)
    br.add_child(book_count)
    book_input_row.add_child(br)
    book_ok = Button.new()
    book_ok.text = "好"
    book_ok.disabled = true
    book_ok.pressed.connect(_on_book_ok_pressed)
    book_input_row.add_child(book_ok)
    box.add_child(book_input_row)
    ui.add_child(book_panel)

func _open_person_card(openid: String) -> void:
    if openid == "" or whisper_box.visible or book_open:
        return   # 写悄悄话的框、翻簿子面板开着时不弹卡片
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
    person_card_meet_btn.disabled = false
    person_card_meet_btn.text = LINE_MEET
    person_card.visible = true
    hall.walking_enabled = false
    _refresh_seat_buttons()

func _close_person_card() -> void:
    if not card_open:
        return
    card_open = false
    card_openid = ""
    person_card.visible = false
    if state == "banquet" and not whisper_box.visible and not book_open:
        hall.walking_enabled = true
    _refresh_seat_buttons()

# ---------- 流程 ----------
## 人在能走路的场景里（迎宾院、宴会厅、后厅、草坪），不是开场、起名这些界面
func _in_scene() -> bool:
    return state == "court" or state == "banquet" or state == "backhall" or state == "lawn"

## 换到哪块画布：别的都藏起来、停下（宴会厅的服务员、NPC 也跟着停），镜头换过去。几块一直都在，
## 所以座位、NPC、敬酒这些宴会厅的状态切来切去都还在
func _show_canvas(which: String) -> void:
    var canvases := {"court": court, "banquet": hall, "backhall": backhall, "lawn": lawn}
    for k in canvases:
        var c = canvases[k]
        if c == null:
            continue
        var on: bool = k == which
        c.visible = on
        c.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
    cv = canvases[which] if canvases.get(which) != null else hall
    if cv.cam != null:
        cv.cam.make_current()

func _goto(s: String) -> void:
    state = s
    hall.stick = Vector2.ZERO
    court.stick = Vector2.ZERO
    if backhall != null:
        backhall.stick = Vector2.ZERO
    if lawn != null:
        lawn.stick = Vector2.ZERO
    stick_touch = -1
    touches.clear()
    for k in screens:
        screens[k].visible = (k == s)
    hud.visible = (s == "banquet" or s == "court" or s == "backhall" or s == "lawn")
    if sit_btn != null and s != "banquet":
        sit_btn.visible = false
    if person_btn != null and s != "banquet":
        person_btn.visible = false
    if book_btn != null and s != "banquet":
        book_btn.visible = false
    if play_btn != null and s != "banquet":
        play_btn.visible = false
    if is_instance_valid(game_host) and s != "banquet":
        game_host.queue_free()
        game_host = null
    if person_card != null and s != "banquet" and card_open:
        card_open = false
        card_openid = ""
        person_card.visible = false
    if book_panel != null and s != "banquet" and book_open:
        book_open = false
        book_table = ""
        book_panel.visible = false
    hall.walking_enabled = (s == "banquet") and not whisper_box.visible
    court.walking_enabled = (s == "court") and not court_ui.panel_open()
    if s != "court":
        court_ui.hide_all()
    if backhall != null:
        backhall.walking_enabled = (s == "backhall")
    if backhall_ui != null and s != "backhall":
        backhall_ui.hide_all()
    if lawn != null:
        lawn.walking_enabled = (s == "lawn")
    if lawn_ui != null and s != "lawn":
        lawn_ui.hide_all()
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

## 进山庄（01 9/19 起的正式流程：选完形象从迎宾院大门走进来，蓝图 2.1）。「到啦～ 罗曼山庄 席还没散」挪到大门口说（01 定）。
## 这时先存资料（签到、进厅都要有住民记录）；进厅拿席位等走进宴会厅再说
func _enter_court() -> void:
    await _fade_to(1.0)
    hall.set_look(preset, nickname)
    court.set_look(preset, nickname)
    backhall.set_look(preset, nickname)
    lawn.set_look(preset, nickname)
    hall.couple_armed = true
    hall.exit_armed = false
    hall.exit_mark.visible = false
    whisper_box.visible = false
    hall.reset_to(hall.SPAWN)
    hall_side_latched = true
    court.reset_to(court.SPAWN)
    _show_canvas("court")
    _goto("court")
    photo_greeted = false
    rest_heard = false
    _update_gate()
    hall_ready = false
    hint.visible = true
    await _fade_to(0.0)
    _say(LINE_ARRIVE)
    _save_profile()

func _save_profile() -> void:
    var inv: String = cloud.inviter()
    var payload := profile_payload(nickname, preset, inv, cloud.openid())
    print("[suqi] 存资料 带邀请人 ", payload.has("inviter"), " ", inv.substr(0, 6))
    cloud.call_fn("saveProfile", payload, _after_profile)

## 在画布之间走（蓝图 1：0.35 秒暖色淡出淡入，人保持朝向，出现在对面的「到了站在」点）。
## 进宴会厅：从迎宾院来站到厅门口 (768,840)、从后厅来站到东侧门边 (1440,600)，都重新拿一次席位（进厅提示、别人敬的酒照旧报）；
## 回迎宾院：从宴会厅来站到 (768,260)、从草坪来站到东小径边 (1440,780)；进后厅：从宴会厅来站到西口边 (100,780)、从草坪来站到厨房后门边 (1440,780)；
## 进草坪：从迎宾院来站到西南口边 (100,780)、从后厅来站到西北口边 (100,300)。离开草坪时球回起始点（蓝图 3.4）
func _switch_canvas(to: String) -> void:
    if switching or not _in_scene():
        return
    switching = true
    var from := state
    var keep_face: String = cv.face
    cv.walking_enabled = false
    cv.stick = Vector2.ZERO
    cv.path.clear()
    fade.color = Color(SWITCH_TINT, fade.color.a)
    await _fade_to(1.0)
    if from == "lawn":
        lawn.reset_ball()
    if to == "banquet":
        _show_canvas("banquet")
        hall.reset_to(HALL_FROM_BACKHALL if from == "backhall" else hall.SPAWN)
        hall_door_latched = true
        hall_side_latched = true
        _goto("banquet")
        _enter_hall_net()
    elif to == "backhall":
        _show_canvas("backhall")
        backhall.reset_to(BACKHALL_FROM_LAWN if from == "lawn" else BACKHALL_FROM_HALL)
        _goto("backhall")
    elif to == "lawn":
        _show_canvas("lawn")
        lawn.reset_ball()
        lawn.reset_to(LAWN_FROM_BACKHALL if from == "backhall" else LAWN_FROM_COURT)
        kids_heard = false
        _goto("lawn")
    else:
        _show_canvas("court")
        court.reset_to(COURT_FROM_LAWN if from == "lawn" else COURT_FROM_HALL)
        _goto("court")
        photo_greeted = false
        rest_heard = false
        _update_gate()
    cv.face = keep_face
    print("[suqi] 换画布 到 ", to)
    await _fade_to(0.0)
    fade.color = Color(0, 0, 0, 0)
    switching = false

## 进宴会厅要做的网上的事：心跳重新对表；资料存过了就直接进厅拿席位，没存上（刚才断网）先补存一次
func _enter_hall_net() -> void:
    hall_ready = false
    pulse_since = 0
    pulse_t = 0.0
    pulse_seen.clear()
    if profile_saved:
        cloud.call_fn("enterHall", {}, _on_enter_hall)
    else:
        _save_profile()

## 走到迎宾院的交互点（进、出半径各一次，见 entrance.gd）：门口迎宾、签到（按钮和面板在 court_ui.gd）、楼门进宴会厅、东西小径还没修好
func _on_court_spot(id: String, inside: bool) -> void:
    if state != "court" or switching:
        return
    court_ui.spot(id, inside)
    match id:
        "welcome":
            # 第一次走到这，新娘妈妈迎一句（蓝图 3.1）；迎过就不再说。签过到的（重进山庄）也不用再招呼去签到
            if inside and not court_save.welcomed:
                court_save.welcomed = true
                court_save.save()
                if not court_save.signed_in:
                    _say(CourtCopy.text("welcome"), -1.0, CourtCopy.who("welcome"))
        "photo_wait":
            # 摄影师招呼（蓝图 3.1）：每回到迎宾院招呼一次
            if inside and not photo_greeted:
                photo_greeted = true
                _say(CourtCopy.text("photo_greet"), -1.0, CourtCopy.who("photo_greet"))
        "rest":
            # 休息区的老人一句乐山话（蓝图 3.1）；方言词第一次自动弹普通话，之后点说话框再看
            if inside and not rest_heard:
                rest_heard = true
                _say(CourtCopy.text("elder"), -1.0, CourtCopy.who("elder"), CourtCopy.text("elder_gloss"))
                if not court_save.gloss_seen:
                    court_save.gloss_seen = true
                    court_save.save()
                    _note(CourtCopy.text("elder_gloss"), 3.0)
        "gate":
            if inside:
                _at_gate()
        "to_hall":
            if inside:
                _switch_canvas("banquet")
        "to_lawn":
            if inside:
                _switch_canvas("lawn")
        "to_lake":
            if inside:
                _note(CourtCopy.text(id), 3.0)

## 走到后厅的交互点（蓝图 3.3，进、出半径各一次，见 entrance.gd）：四个房间的按钮在 backhall_ui.gd；
## 西口回宴会厅；东口是厨房后门去草坪
func _on_backhall_spot(id: String, inside: bool) -> void:
    if state != "backhall" or switching:
        return
    backhall_ui.spot(id, inside)
    match id:
        "to_hall":
            if inside:
                _switch_canvas("banquet")
        "to_lawn":
            if inside:
                _switch_canvas("lawn")

## 走到草坪的交互点（蓝图 3.4）：球旁的「踢一脚」在 lawn_ui.gd（lawn.gd 按球现在的位置发 ball）；孩童区小孩说一句（每回到草坪一次）；
## 西南口回迎宾院、西北口去后厅；北口去果园，果园还没做，出「还没修好」
func _on_lawn_spot(id: String, inside: bool) -> void:
    if state != "lawn" or switching:
        return
    lawn_ui.spot(id, inside)
    match id:
        "kids":
            if inside and not kids_heard:
                kids_heard = true
                _say(CourtCopy.text("kids", CourtCopy.LAWN), -1.0, CourtCopy.who("kids", CourtCopy.LAWN))
        "to_entrance":
            if inside:
                _switch_canvas("court")
        "to_backhall":
            if inside:
                _switch_canvas("backhall")
        "to_orchard":
            if inside:
                _note(CourtCopy.text("to_orchard", CourtCopy.LAWN), 3.0)

## 调试版（导出预设「小游戏调试」，或者电脑上带 --hud）；测试里用 debug_override 当成调试版
func is_debug() -> bool:
    return debug_override or OS.has_feature("suqi_debug") or "--hud" in OS.get_cmdline_user_args()

## 回忆册：打开两分钟剪辑（世界观 1.1）。现在六张图六句话还没到，是占位屏，只有调试版进得来（court_ui.can_open_album）
func open_clip() -> void:
    _goto("clip")

func _close_clip() -> void:
    _goto("court")
    court_ui.refresh_spots()

## 大门（蓝图 3.1、2.3）：悄悄话写完、也签过到才开，门口一圈金光。开了走到门口：「镇上的路还没修好 下次带你去」，
## 人停在门口，存档（阶段 1 到这里结束，阶段 2 接进镇）。写了悄悄话没签到：大门不开，新娘妈妈提醒先签到。还没写悄悄话：大门不理人
func _at_gate() -> void:
    if court_save.gate_open():
        court.path.clear()
        court.stick = Vector2.ZERO
        court_save.save()
        _note(CourtCopy.text("gate_road"), 3.0)
        print("[suqi] 走到大门口 大门开着")
    elif court_save.whisper_done:
        _say(CourtCopy.text("gate_not_signed"), -1.0, CourtCopy.who("gate_not_signed"))

## 大门那圈金光跟着开没开（签完到、写完悄悄话、回到迎宾院时都对一次）
func _update_gate() -> void:
    court.exit_mark.visible = court_save.gate_open()

## 截图、测试用：不走迎宾院，直接进宴会厅（原来的进场流程）
func _enter_banquet() -> void:
    await _fade_to(1.0)
    hall.set_look(preset, nickname)
    court.set_look(preset, nickname)
    backhall.set_look(preset, nickname)
    lawn.set_look(preset, nickname)
    hall.couple_armed = true
    hall.exit_armed = false
    hall.exit_mark.visible = false
    whisper_box.visible = false
    hall.reset_to(hall.SPAWN)
    hall_door_latched = true
    hall_side_latched = true
    _show_canvas("banquet")
    _goto("banquet")
    hall_ready = false
    pulse_since = 0
    pulse_t = 0.0
    pulse_seen.clear()
    hint.visible = true
    await _fade_to(0.0)
    _say(LINE_ARRIVE)
    # 存资料、进厅拿席位（蓝图 3.2）。失败不拦流程，只顶部提示
    _save_profile()

## 存资料要发的字段（字段名以服务端 saveProfile 为准）。邀请链：点谁的卡片进来就带上 inviter，
## 不带自己；服务端还会再判「只认第一次、查无此人不认」（回执 03）
static func profile_payload(nick: String, avatar: int, inviter: String, me: String) -> Dictionary:
    var d := {"nick": nick, "avatar": avatar}
    if inviter != "" and inviter != me:
        d["inviter"] = inviter
    return d

func _say(text: String, hold := -1.0, who := "阿鱼", gloss := "") -> void:
    say_token += 1
    var my := say_token
    dialog_who.text = who
    dialog_text.text = text
    say_log.append([who, text])
    if say_log.size() > 20:
        say_log.pop_front()
    dialog_gloss = gloss
    dialog.mouse_filter = Control.MOUSE_FILTER_STOP if gloss != "" else Control.MOUSE_FILTER_IGNORE
    dialog.visible = true
    if hold == 0.0:
        return
    var d := hold if hold > 0.0 else 2.4 + text.length() * 0.09
    await get_tree().create_timer(d).timeout
    if my == say_token:
        dialog.visible = false

## 起昵称被服务端拒（敏感词模块，docs/敏感词模块-需求.md 第 2 节：服务端拒绝 → 回到输入、
## 显示服务端的提示）：只拦 sensitive/reserved 这两种——回到起昵称那一屏，nick_err 显示对应
## 那句，不进厅。别的原因（网络问题等）不拦流程，照旧直接进厅，跟改动前一样
func _after_profile(r: Dictionary) -> void:
    var reason := str(r.get("reason", ""))
    if not bool(r.get("ok", false)) and (reason == "sensitive" or reason == "reserved"):
        print("[suqi] 起昵称 被拒，原因 ", reason)
        _goto("nick")
        nick_err.text = str(REASONS[reason])
        nick_ok.disabled = true
        return
    profile_saved = bool(r.get("ok", false))
    # 服务端说签过到了（换了手机、清过本机存档）：签到桌也只显示「已签到」，喜糖当收过了（第五段，saveProfile 回 checked_in）
    if bool(r.get("checked_in", false)) and not court_save.signed_in:
        court_save.signed_in = true
        court_save.candy = true
        court_save.save()
        _update_gate()
        court_ui.refresh_spots()
    # 在迎宾院存的资料：进厅拿席位等走进宴会厅再说（_switch_canvas → _enter_hall_net）
    if state == "banquet":
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
    hall_ready = true   # 席位拿到了，开始每隔几秒问 hallPulse
    # 小游戏的金币、进度：服务端有就以服务端为准（换手机还在）；还没部署新版 enterHall 时没有 mine，用本机的
    if d.has("mine"):
        games_save.apply_cloud(d["mine"])
    print("[suqi] 小游戏存档 金 ", games_save.coins, " 进度 ", games_save.games)
    # 真机排查用：这厅有多少人、带邀请人的有几个（看人卡片「XX 带进来的」靠这个字段）
    var with_inviter := 0
    for k in hall.resident_names:
        var inv = (hall.resident_names[k] as Dictionary).get("inviter", null)
        if inv != null and str(inv) != "":
            with_inviter += 1
    print("[suqi] 进厅 名字 ", hall.resident_names.size(), " 个 带邀请人的 ", with_inviter, " 个")
    # 120 个座坐满了，服务端把我分到长凳（seat 的 table_id 是 bench）：说一句，金标在凳子上；
    # 分到了画面上没摆出来的桌、金标画不了：提示先找把椅子坐
    if USE_LAYERED and str(hall.my_seat.get("table_id", "")) == LayeredHall.BENCH_ID:
        _note(LINE_BENCH, 4.0)
    elif hall._my_chair_pos() == Vector2.ZERO:
        _note("先找把空椅子坐下", 4.0)
    var dg: Dictionary = d.get("digest", {})
    if bool(dg.get("hasNews", false)):
        var names: Dictionary = d.get("names", {})
        var parts: Array[String] = []
        var tc := int(dg.get("toastCount", 0))
        for dt_ in dg.get("toasts", []):
            pulse_seen["%s:%d" % [str(dt_.get("from", "")), int(dt_.get("at", 0))]] = true   # 进厅报过的，心跳别再报
        # 几个人敬的，名字、插图、回敬都按最新的那位（进厅提示的敬酒是按文档 id 排的，不按时间，不能拿第一条）
        var latest := latest_toast(dg.get("toasts", []), "at")
        var from := str(latest.get("from", ""))
        var finfo: Dictionary = names.get(from, {})
        if tc > 0:
            var who := str(finfo.get("nick", "有人"))
            parts.append(who + ("等 %d 人敬了你" % tc if tc > 1 else " 敬了你一杯"))
            # 不在线时被敬的：进厅也看一次干杯插图（阿鱼 9/18 晚）
            var cap: String = parts[parts.size() - 1]
            get_tree().create_timer(1.5).timeout.connect(func():
                if state == "banquet":
                    _play_toast(_avatar_of(finfo), preset, cap))
        var bc := int(dg.get("bookLineCount", 0))
        if bc > 0:
            parts.append("簿子上多了 %d 句" % bc)
        _note("，".join(parts), TOAST_BACK_SECS if tc > 0 else 5.0)
        if tc > 0:
            _offer_toast_back(from, finfo)

func _on_chair_near(table_id: String, chair_no: int) -> void:
    sit_confirming = false
    near_seat_info = {"table_id": table_id, "chair_no": chair_no}
    _refresh_seat_buttons()

func _on_person_near(openid: String) -> void:
    near_person_id = openid
    _refresh_seat_buttons()

func _on_table_near(table_id: String) -> void:
    near_table_id = table_id
    _refresh_seat_buttons()

## 「坐这儿」「昵称」「翻簿子」三个按钮的显示状态统一在这里算（第 22 版规则 7，第 24 版加翻簿子）：
## 卡片或翻簿子面板开着、或不在宴会厅里，全部收起；「坐这儿」进了确认文案时另外两个先让开，免得并排挤在一起
func _refresh_seat_buttons() -> void:
    var blocked: bool = card_open or book_open or state != "banquet" or is_instance_valid(game_host)
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
    if blocked or whisper_box.visible or near_table_id == "" or sit_confirming:
        book_btn.visible = false
    else:
        book_btn.visible = true
    # 玩·XX：坐在自己的椅子上、这桌有小游戏才出（蓝图 3.2：坐在这桌才能开这桌的游戏）
    var my_game: Dictionary = GameCfg.game_for_table(str(hall.my_seat.get("table_id", ""))) if USE_LAYERED else {}
    if blocked or whisper_box.visible or sit_confirming or not (USE_LAYERED and hall.seated) or my_game.is_empty():
        play_btn.visible = false
    else:
        play_btn.text = "玩·" + GameCfg.title(my_game)
        play_btn.visible = true
    _layout_seat_buttons()

## 1～3 个都要能排（第 24 版起加了翻簿子）。这一路 UI 都按 540 宽竖屏设计，用固定像素挪位置，
## 不查实际屏宽：1 个时居中 440 宽（原来的样子）；2 个时各 240 宽、中间留 20（原来的样子）；
## 3 个时各 164 宽、间隔 8，总宽 508，比 2 个时的 500 宽不了多少，两侧到 540 屏幕边还各留 16 像素。
## 固定顺序昵称、翻簿子、坐这儿从左到右排，缺哪个就少一个槽位，不会跳位置
func _layout_seat_buttons() -> void:
    var slots: Array[Button] = []
    if person_btn.visible: slots.append(person_btn)
    if book_btn.visible: slots.append(book_btn)
    if play_btn.visible: slots.append(play_btn)
    if sit_btn.visible: slots.append(sit_btn)
    match slots.size():
        1:
            slots[0].offset_left = -220; slots[0].offset_right = 220
        2:
            slots[0].offset_left = -250; slots[0].offset_right = -10
            slots[1].offset_left = 10; slots[1].offset_right = 250
        3:
            slots[0].offset_left = -254; slots[0].offset_right = -90
            slots[1].offset_left = -82; slots[1].offset_right = 82
            slots[2].offset_left = 90; slots[2].offset_right = 254
        _:
            pass

func _on_person_pressed() -> void:
    if near_person_id != "":
        _open_person_card(near_person_id)

func _on_toast_pressed() -> void:
    if card_openid == "" or person_card_toast_btn.disabled:
        return
    person_card_toast_btn.disabled = true   # 先置灰防连点；想认识你也一起置灰，结果回来卡片就关了
    person_card_meet_btn.disabled = true
    var target := card_openid
    cloud.call_fn("toast", {"to": target}, func(r): _on_toast_result(r, target))

## 想认识你：发给服务端判（现在同一桌、或者敬过酒；同一对只记一次），客户端不先拦
func _on_meet_pressed() -> void:
    if card_openid == "" or person_card_meet_btn.disabled:
        return
    person_card_meet_btn.disabled = true    # 先置灰防连点，敬一杯也一起
    person_card_toast_btn.disabled = true
    var target := card_openid
    cloud.call_fn("wantToMeet", {"to": target}, func(r): _on_meet_result(r, target))

## 成了顶部说一句「想认识 XX 记下了」，没成说原因；两样都先关卡片（和敬酒一样，提示在卡片底下会被暗底盖住）
func _on_meet_result(r: Dictionary, target: String) -> void:
    _close_person_card()
    if bool(r.get("ok", false)):
        var nick := str((hall.resident_names.get(target, {}) as Dictionary).get("nick", ""))
        _note(LINE_MEET_SENT_FMT % (nick if nick != "" else "有人"))
        print("[suqi] 想认识你 记下了 ", nick)
    else:
        _note(_reason_text(r, "想认识你"))

## known：回敬时带过来的对方昵称、形象（对方可能是我进厅以后才进来的，hall.resident_names 里没有他）
func _on_toast_result(r: Dictionary, target: String, known := {}) -> void:
    _close_person_card()
    if bool(r.get("ok", false)):
        var info: Dictionary = known if not known.is_empty() else hall.resident_names.get(target, {})
        var nick := str(info.get("nick", ""))
        var line := LINE_TOASTED_FMT % (nick if nick != "" else "有人")
        _note(line)
        # 阿鱼 9/18 晚：敬了要有反应——对方站起来碰杯、弹一张干杯的插图（对方不用点同意）
        if USE_LAYERED:
            hall.resident_toast(target)
            hall.raise_cup()
        _play_toast(preset, _avatar_of(info), line)
    else:
        _note(_reason_text(r, "敬酒"))

## 干杯插图：left 敬酒的人、right 被敬的人（形象编号）。同一时间只放一张，正在放就排队，放完接着放下一张
func _play_toast(left_preset: int, right_preset: int, caption: String) -> void:
    if is_instance_valid(toast_scene):
        toast_queue.append([left_preset, right_preset, caption])
        return
    toast_scene = ToastScene.new()
    ui.add_child(toast_scene)
    _restack_top()
    toast_scene.finished.connect(_on_toast_scene_done)
    toast_scene.play(font, left_preset, right_preset, LINE_CHEERS, caption)
    print("[suqi] 干杯插图 ", caption)

## 叠放顺序：……干杯插图、回敬按钮、调试版的绿字和日志面板、黑幕。插图整屏接点击（点一下提前收），按钮要在它上面才点得到；
## 调试面板打开时要盖住回敬按钮；黑幕永远在最上面，切场景时把这些都盖住（原来插图加在黑幕上面，出门淡出时插图还亮着）
func _restack_top() -> void:
    if toast_back_btn.visible:
        ui.move_child(toast_back_btn, -1)
    for n in [dbg, dbg_panel]:
        if n != null:
            ui.move_child(n, -1)
    ui.move_child(fade, -1)

## 被敬以后在顶部那句提示右边出「回敬一杯」。先 _note 出那句提示再调：按钮认的是那一句（note_token），
## 提示换了一句或者收了（TOAST_BACK_SECS 秒），按钮一起收，见 _layout_top。开着小游戏时不出（提示也被小游戏盖着）；
## 看人卡片、簿子开着时也不出：提示被它们的暗底盖着，按钮却浮在最上面，压在卡片上（9/19 做想认识你时截图看到的）
func _offer_toast_back(from: String, info: Dictionary) -> void:
    if from == "" or from == cloud.openid() or is_instance_valid(game_host) or card_open or book_open:
        return
    toast_back_to = from
    toast_back_info = info
    toast_back_note = note_token
    toast_back_btn.disabled = false
    toast_back_btn.visible = true
    _restack_top()
    print("[suqi] 可以回敬 ", str(info.get("nick", "")))

func _clear_toast_back() -> void:
    toast_back_to = ""
    toast_back_info = {}
    toast_back_btn.visible = false

## 点「回敬一杯」：直接敬回去，和看人卡片的「敬一杯」走同一条路（对方站起来、我举杯、插图、顶部一句）；
## 每天几杯、敬过没有，都由服务端定，被拒就显示原因。按钮点一次就收，不能连点
func _on_toast_back_pressed() -> void:
    var target := toast_back_to
    var info := toast_back_info
    _clear_toast_back()
    if target == "":
        return
    # 眼前那张「XX 敬了你一杯」的插图先收起来（跟点一下插图一样），接着放我敬回去的那张
    if is_instance_valid(toast_scene) and toast_scene.closing < 0.0:
        toast_scene.closing = toast_scene.t
    print("[suqi] 回敬 ", str(info.get("nick", "")))
    cloud.call_fn("toast", {"to": target}, func(r): _on_toast_result(r, target, info))

## 几个人一起敬我时回敬最新的那位：取时间最大的一条，一样大取后面那条。key：hallPulse 回的是 created_at（升序），
## enterHall 进厅提示回的是 at（按文档 id 排，不按时间），所以不能拿第一条、最后一条凑合。没有就回空的
static func latest_toast(toasts: Array, key: String) -> Dictionary:
    var best: Dictionary = {}
    var best_t := -1
    for t in toasts:
        if typeof(t) != TYPE_DICTIONARY:
            continue
        var at := int((t as Dictionary).get(key, 0))
        if at >= best_t:
            best_t = at
            best = t
    return best

func _on_toast_scene_done() -> void:
    toast_scene = null
    if not toast_queue.is_empty() and state == "banquet":
        var n: Array = toast_queue.pop_front()
        _play_toast(int(n[0]), int(n[1]), str(n[2]))

static func _avatar_of(info: Dictionary) -> int:
    var a := int(info.get("avatar", -1))
    return a if a >= 0 and a <= 7 else 0

## hallPulse 回来：有人刚敬了我——顶部一句、自己站起来举杯、弹同一张插图。没连上就等下一轮，不打扰
func _on_pulse(r: Dictionary) -> void:
    pulse_busy = false
    if not bool(r.get("ok", false)):
        return
    pulse_since = int(r.get("now", pulse_since))
    var toasts: Array = []
    for tt in r.get("toasts", []):
        var key := "%s:%d" % [str(tt.get("from", "")), int(tt.get("created_at", 0))]
        if not pulse_seen.has(key):
            pulse_seen[key] = true
            toasts.append(tt)
    if toasts.is_empty() or state != "banquet":
        return
    var names: Dictionary = r.get("names", {})
    # 几个人一起敬的，名字、插图、回敬都按最新的那位
    var from := str(latest_toast(toasts, "created_at").get("from", ""))
    var info: Dictionary = names.get(from, {})
    var who := str(info.get("nick", ""))
    if who == "":
        who = "有人"
    var line := who + (" 等 %d 人敬了你" % toasts.size() if toasts.size() > 1 else " 敬了你一杯")
    print("[suqi] 当场收到敬酒 ", toasts.size(), " 杯")
    _note(line, TOAST_BACK_SECS)
    _offer_toast_back(from, info)
    if USE_LAYERED:
        hall.toasted_me()
    _play_toast(_avatar_of(info), preset, line)

# ---------- 席间小游戏（蓝图 3.2，阿鱼 9/19） ----------
## 点了某张桌桌心的菜：坐在这桌就开这桌的游戏；没坐在这桌就提示先坐下（人照样往那边走）
func _on_game_tap(table_id: String) -> void:
    if hall.seated and str(hall.my_seat.get("table_id", "")) == table_id:
        _open_game(table_id)
    else:
        _note(LINE_SIT_FIRST_GAME, 2.5)

func _open_game(table_id: String) -> void:
    var g := GameCfg.game_for_table(table_id)
    if g.is_empty() or is_instance_valid(game_host) or card_open or book_open or whisper_box.visible:
        return
    hall.walking_enabled = false
    hall.stick = Vector2.ZERO
    game_host = GameHost.new()
    ui.add_child(game_host)
    game_host.closed.connect(_on_game_closed)
    game_host.open(str(g["id"]), table_id, games_save, font, OS.has_feature("suqi_debug") or "--hud" in OS.get_cmdline_user_args())
    print("[suqi] 开小游戏 ", g["id"], " 在 ", table_id)
    _refresh_seat_buttons()

func _on_game_closed() -> void:
    game_host = null
    hall.walking_enabled = state == "banquet" and not whisper_box.visible
    _refresh_seat_buttons()

## 存档：GameSave 每次有变化调这里，存进住民资料（saveProfile 的新字段，待部署）；done(成功没有)
func _save_games(payload: Dictionary, done: Callable) -> void:
    cloud.call_fn("saveProfile", payload, func(r):
        var ok := bool(r.get("ok", false))
        if not ok:
            print("[suqi] 小游戏存档没存上 ", str(r.get("reason", "")))
        done.call(ok))

## 写悄悄话的框里「手上 N 金 添礼金」：有金币才出
func _refresh_gift_row() -> void:
    gift_pick.visible = false
    gift_row.visible = games_save.coins > 0
    (gift_row.get_node("coins") as Label).text = "手上 %d 金" % games_save.coins

func _open_gift_pick() -> void:
    for c in gift_pick.get_children():
        c.queue_free()
    var amounts: Array = GIFT_CHOICES.filter(func(n): return n < games_save.coins)
    amounts.append(games_save.coins)   # 最后一个是「全部」
    for n in amounts:
        var b := Button.new()
        b.text = ("全部 %d" % n) if n == games_save.coins else str(n)
        b.pressed.connect(_give_gift.bind(int(n)))
        gift_pick.add_child(b)
    var back := Button.new()
    back.text = "算了"
    back.pressed.connect(_refresh_gift_row)
    gift_pick.add_child(back)
    gift_row.visible = false
    gift_pick.visible = true

func _give_gift(n: int) -> void:
    if games_save.give_gift(n):
        print("[suqi] 添礼金 ", n, " 金，累计 ", games_save.gift_coins)
        _note(LINE_GIFT_DONE_FMT % n, 3.0)
    _refresh_gift_row()

func _on_book_btn_pressed() -> void:
    if near_table_id != "":
        _open_book_panel(near_table_id)

## 打开翻簿子面板：先「加载中」，调 readBook 拿接龙列表。写悄悄话的框、看人卡片开着时不弹（同person卡片的规矩）
func _open_book_panel(table_id: String) -> void:
    if table_id == "" or whisper_box.visible or card_open:
        return
    book_open = true
    book_table = table_id
    hall.walking_enabled = false
    _refresh_seat_buttons()
    for c in book_list_box.get_children():
        c.queue_free()
    book_empty_shown = false
    book_err.text = ""
    book_edit.text = ""
    book_loading.visible = true
    book_scroll.visible = false
    book_input_row.visible = false
    book_readonly_label.visible = false
    book_panel.visible = true
    cloud.call_fn("readBook", {"table": table_id}, func(r): _on_book_loaded(r, table_id))

## readBook 回来晚了、面板已经关掉或者又翻了别的桌：这条结果就不管了
func _on_book_loaded(r: Dictionary, table_id: String) -> void:
    if not book_open or book_table != table_id:
        return
    book_loading.visible = false
    book_scroll.visible = true
    var lines: Array = []
    var names: Dictionary = {}
    if bool(r.get("ok", false)):
        var d: Dictionary = r.get("data", {})
        lines = d.get("lines", [])
        names = d.get("names", {})
    else:
        _note(_reason_text(r, "翻簿子"))
    await _render_book_lines(lines, names)
    _update_book_write_state()

## 每条一行「昵称：内容」，最新的在最下面；空的写占位「还没人写 你来第一句」。画完滚到最下面
func _render_book_lines(lines: Array, names: Dictionary) -> void:
    for c in book_list_box.get_children():
        c.queue_free()
    if lines.is_empty():
        book_list_box.add_child(_label(LINE_BOOK_EMPTY, 24, MUTED, HORIZONTAL_ALIGNMENT_LEFT))
        book_empty_shown = true
    else:
        book_empty_shown = false
        for line in lines:
            var nick := _book_nick(str((line as Dictionary).get("openid", "")), names)
            book_list_box.add_child(_label(nick + "：" + str((line as Dictionary).get("text", "")), 24, PAPER, HORIZONTAL_ALIGNMENT_LEFT))
    await get_tree().process_frame
    _scroll_book_to_bottom()

func _scroll_book_to_bottom() -> void:
    var bar := book_scroll.get_v_scroll_bar()
    if bar != null:
        book_scroll.scroll_vertical = int(bar.max_value)

## 昵称先用 readBook 带回的 names，没有再用进厅拿到的 hall.resident_names，都没有写「有人」（已有兜底词）
func _book_nick(openid: String, names: Dictionary) -> String:
    if names.has(openid):
        var n := str((names[openid] as Dictionary).get("nick", ""))
        if n != "": return n
    if hall.resident_names.has(openid):
        var n2 := str((hall.resident_names[openid] as Dictionary).get("nick", ""))
        if n2 != "": return n2
    return "有人"

## 只能写自己现在坐着的那桌（蓝图 3.2 9/18 定稿）：不是这桌时输入框、「好」换成一行「先坐下 慢慢写」
func _update_book_write_state() -> void:
    var can_write: bool = book_table != "" and str(hall.my_seat.get("table_id", "")) == book_table
    book_input_row.visible = can_write
    book_readonly_label.visible = not can_write
    if can_write:
        _check_book_ui()

func _close_book_panel() -> void:
    if not book_open:
        return
    book_open = false
    book_table = ""
    book_panel.visible = false
    book_edit.text = ""
    if state == "banquet" and not whisper_box.visible and not card_open:
        hall.walking_enabled = true
    _refresh_seat_buttons()

## 翻簿子输入校验：空、超100字、字体里没有的字（照昵称校验），"empty" 是还没填，其余是要显示的提示
func _check_book(text: String) -> String:
    var s := text.strip_edges()
    var g := _graphemes(s)
    if g == 0:
        return "empty"
    if g > 100:
        return str(REASONS["book_too_long"])
    for i in s.length():
        if not font.has_char(s.unicode_at(i)):
            return "有个字显示不出来 换一个"
    return ""

func _check_book_ui() -> void:
    var r := _check_book(book_edit.text)
    var n := _graphemes(book_edit.text.strip_edges())
    book_count.text = "%d/100" % n
    book_count.add_theme_color_override("font_color", Color("#E8746A") if n > 100 else MUTED)
    book_err.text = "" if r == "empty" else r
    book_ok.disabled = r != ""

func _on_book_ok_pressed() -> void:
    if book_ok.disabled or book_table == "":
        return
    var text := book_edit.text.strip_edges()
    if text == "":
        return
    book_ok.disabled = true   # 先置灰防连点
    var t := book_table
    cloud.call_fn("writeBook", {"table": t, "text": text}, func(r): _on_book_written(r, t, text))

func _on_book_written(r: Dictionary, table_id: String, text: String) -> void:
    var still_here: bool = book_open and book_table == table_id
    if still_here:
        book_ok.disabled = false
    if bool(r.get("ok", false)):
        if still_here:
            _append_book_line({"openid": cloud.openid(), "text": text}, nickname)
            book_edit.text = ""
            _check_book_ui()
    else:
        _note(_reason_text(r, "写簿子"))

## 成功写完，在列表最下面加自己这一条：自己的昵称本地就知道（main.gd 的 nickname），不用等服务器的
## names 回来；nick_override 传空字符串时退回 _book_nick 的兜底顺序（备用，目前调用方都会传昵称）
func _append_book_line(line: Dictionary, nick_override := "") -> void:
    if book_empty_shown:
        for c in book_list_box.get_children():
            c.queue_free()
        book_empty_shown = false
    var nick := nick_override
    if nick == "":
        nick = _book_nick(str(line.get("openid", "")), {})
    book_list_box.add_child(_label(nick + "：" + str(line.get("text", "")), 24, PAPER, HORIZONTAL_ALIGNMENT_LEFT))
    await get_tree().process_frame
    _scroll_book_to_bottom()

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
    # 回敬按钮跟着它那一句提示走：提示换了、收了，离开宴会厅、开了小游戏、开了看人卡片或簿子，按钮一起收
    # （卡片上本来就有「敬一杯」，簿子关了回头再点那人也一样）
    if toast_back_btn.visible and (note_token != toast_back_note or not note_box.visible
            or state != "banquet" or is_instance_valid(game_host) or card_open or book_open):
        _clear_toast_back()
    var right := 14.0
    if toast_back_btn.visible:
        # 按钮在提示框右边，竖着和提示框对中；提示框让出这一块
        var bs := toast_back_btn.get_combined_minimum_size()
        var by := y + maxf(0.0, (note_box.size.y - bs.y) * 0.5)
        toast_back_btn.offset_left = -14.0 - bs.x
        toast_back_btn.offset_right = -14.0
        toast_back_btn.offset_top = by
        toast_back_btn.offset_bottom = by + bs.y
        right += bs.x + 8.0
    note_box.offset_right = -right
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
        _refresh_gift_row()
        _refresh_seat_buttons()   # 写悄悄话的框开着时昵称按钮也收起，别叠在一起

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
    # 写完悄悄话大门才开（蓝图 2.3、3.1），记在本机（蓝图 2.4「大门开了」存本机）
    court_save.whisper_done = true
    court_save.save()
    _update_gate()
    whisper_edit.text = ""
    whisper_box.visible = false
    hall.walking_enabled = true
    # 厅门亮一圈金光，提示往外走（门一直通迎宾院；大门开不开在迎宾院那边管）
    hall.exit_mark.visible = true
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
## 屏幕左下方按住拖 = 摇杆；别处左右拖 = 转镜头（宴会厅是左右挪着看全厅，9/18 晚）；轻点一下 = 走过去
func _unhandled_input(e: InputEvent) -> void:
    if e is InputEventScreenTouch and not e.pressed:
        var tc = touches.get(e.index)
        touches.erase(e.index)
        if e.index == stick_touch:
            stick_touch = -1
            cv.stick = Vector2.ZERO
            _stick_rest()
        var quick: bool = tc != null and not tc["drag"] and Time.get_ticks_msec() - int(tc["t"]) < 350
        if quick and _in_scene() and cv.walking_enabled:
            hint.visible = false
            cv.tap(e.position)
        return
    if not _in_scene() or not cv.walking_enabled:
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
            cv.stick = v
            _stick_show(stick_origin, v)
        else:
            cv.rotate_cam(e.relative.x)

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
## 小游戏截图：game_<id> 坐到这个游戏的第一张桌、打开开始卡；game_<id>_play 再点开始、玩一会儿；
## 名字里带 lvN（比如 game_memory_lv10_play）就从第 N 关开：只改内存里的进度，不存档，不影响本机存档
func _shot_game(shot: String) -> void:
    var parts := shot.split("_")
    var id := parts[1]
    nickname = "小李"
    await _enter_banquet()
    hall.couple_armed = false
    dialog.visible = false
    var g := GameCfg.game(id)
    if g.is_empty():
        return
    for part in parts:
        if part.begins_with("lv") and int(part.substr(2)) > 1:
            games_save.games[id] = int(part.substr(2)) - 1
    var tid := str(g["tables"][0])
    hall.apply_change(tid, 5, cloud.openid())
    for i in 30: await get_tree().process_frame
    _open_game(tid)
    await get_tree().process_frame
    await get_tree().process_frame
    if (shot.ends_with("_play") or shot.ends_with("_ring")) and is_instance_valid(game_host):
        game_host._start()
        for i in 30: await get_tree().process_frame
        if shot.ends_with("_ring") and id == "lianliankan":
            _shot_llk_ring(game_host.game)

## 截图用（game_lianliankan_lv9_ring）：最左一列最上、最下两张换成同一种菜（跟别处同种的对换，数量不变），再点这两张：
## 只能从棋盘左边外面那一圈绕过去。连线停住不淡，看它画没画进游戏区（01 9/19：原来左右会被裁掉一截）
func _shot_llk_ring(gm) -> void:
    var b: Array = gm.board
    var k := int(b[0][0])
    var bot := Vector2i(0, b.size() - 1)
    if int(b[bot.y][bot.x]) != k:
        var swapped := false
        for y in b.size():
            for x in range(1, (b[y] as Array).size()):
                if not swapped and int(b[y][x]) == k:
                    b[y][x] = b[bot.y][bot.x]
                    b[bot.y][bot.x] = k
                    swapped = true
        gm._redraw_all()
    gm.line_fade = 60.0
    gm.tap(Vector2i(0, 0))
    gm.tap(bot)

## 截图用：迎宾院从头来（没迎过、没签到），存档写到临时文件，不动这台电脑上的真存档
func _shot_court_fresh() -> void:
    court_save.local_path = "user://shot_court.json"
    court_save.welcomed = false
    court_save.signed_in = false
    court_save.candy = false
    court_save.draft = {}

## 截图用：进厅提示那张干杯插图 1.5 秒后才放，先等它出来、收掉，免得和要截的那张抢
func _shot_skip_entry_toast() -> void:
    for i in 600:
        if is_instance_valid(toast_scene):
            break
        await get_tree().process_frame
    if is_instance_valid(toast_scene):
        toast_scene.closing = toast_scene.t
        while is_instance_valid(toast_scene):
            await get_tree().process_frame

func _setup_shot(shot: String) -> void:
    if shot.begins_with("game_"):
        await _shot_game(shot)
        return
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
            # 卡片打开：形象、昵称、「老王 带进来的」、底下「敬一杯」「想认识你」（第 22 版；想认识你 01 9/19 派）
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
        "bench", "bench_crowd", "bench_me", "bench_card", "bench_toast":
            # 长凳（01 9/19 派任务 5）：北墙根、舞台西边，8 个人正好一排；bench_crowd 30 个挤着叠；
            # bench_me 是我被分到长凳：金标在凳子上我那个位置（进厅那句提示测试里查）；card、toast 是对凳子上的人看人、敬酒（他站到凳子跟前）
            var n := 30 if shot == "bench_crowd" else 8
            var nicks := ["阿强", "小周", "大刘", "阿梅", "小陈", "老孙", "阿兰", "小吴"]
            cloud.fake_bench = []
            for i in n:
                var oid := "fake_b%d" % i
                cloud.fake_bench.append(oid)
                cloud.fake_names[oid] = {"nick": nicks[i] if i < nicks.size() else "客%d" % (i + 1), "avatar": i % 8, "inviter": null}
            if shot == "bench_me":
                cloud.fake_me = {"table_id": "bench", "chair_no": null}
                cloud.fake_bench.insert(3, "fake_me")
            nickname = "阿花"
            await _enter_banquet()
            hall.couple_armed = false
            dialog.visible = false
            await _shot_skip_entry_toast()
            var spot: Vector2 = hall.bench_pos(4, cloud.fake_bench.size())
            # 敬酒那张站开半个身位，不然被敬的人站起来正好和我叠在一起
            hall.reset_to(Vector2(spot.x + (15.0 if shot == "bench_toast" else 0.0), 282.0 if shot == "bench_toast" else 268.0))
            for i in 12: await get_tree().process_frame
            # 凳子在画布最上面，顶部提示框正好压在它上面（提示几秒就收）；截图把提示收了，看得见凳子和金标
            note_box.visible = false
            _clear_toast_back()
            if shot == "bench_card" or shot == "bench_toast":
                _open_person_card(hall.person_near_key)
                if shot == "bench_toast":
                    _on_toast_pressed()
                    await _shot_skip_entry_toast()
                    note_box.visible = false
            await get_tree().process_frame
        "meet_sent", "meet_not_met":
            # 想认识你（01 9/19 派，文案新写，等阿鱼定）：我坐 T1，老王也在 T1，发得出去，顶部「想认识 老王 记下了」；
            # 小李在 T2、没敬过酒，顶部「先坐到一桌 或者敬一杯」
            nickname = "阿花"
            await _enter_banquet()
            hall.couple_armed = false
            dialog.visible = false
            await _shot_skip_entry_toast()
            var who := "fake_wang" if shot == "meet_sent" else "fake_li"
            if USE_LAYERED:
                hall.reset_to(hall.chair_world(hall._table_cfg("T1" if shot == "meet_sent" else "T2"), 1 if shot == "meet_sent" else 4))
            _open_person_card(who)
            _on_meet_pressed()
            await get_tree().process_frame
        "book":
            # 翻簿子：坐在 T1，面板打开，有几条句子，能写（第 24 版）
            nickname = "小李"
            await _enter_banquet()
            if USE_LAYERED:
                hall.apply_change("T1", 4, cloud.openid())
                _open_book_panel("T1")
                await get_tree().process_frame
        "book_empty":
            # T2 的空簿子：「还没人写 你来第一句」（第 24 版，新写文案）
            nickname = "小李"
            await _enter_banquet()
            if USE_LAYERED:
                hall.apply_change("T2", 4, cloud.openid())
                _open_book_panel("T2")
                await get_tree().process_frame
        "book_readonly":
            # 坐在 T1、翻 T2 的簿子：只能看，「先坐下 慢慢写」（蓝图 3.2 9/18 定稿，第 24 版）
            nickname = "小李"
            await _enter_banquet()
            if USE_LAYERED:
                hall.apply_change("T1", 4, cloud.openid())
                _open_book_panel("T2")
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
        "behind_rail":
            # 站到左下角栏杆后面（9/18 第三排桌子在栏杆后面）：看栏杆有没有把人的下半身挡住
            nickname = "小李"
            await _enter_banquet()
            hall.couple_armed = false
            hall.reset_to(Vector2(330, 845) if USE_LAYERED else Vector2(-4.8, -3.6))
            dialog.visible = false
        "gift":
            # 主桌添礼金（蓝图 3.2 9/19）：手上 120 金，走到主桌前，点了「添礼金」出几个数目
            cloud.fake_mine["coins"] = 120
            nickname = "小李"
            await _enter_banquet()
            for i in 20: await get_tree().process_frame
            hall.reset_to(hall.near(hall.COUPLE_SPOT, Vector2(0.2, 0.6)))
            for i in 5: await get_tree().process_frame
            _open_gift_pick()
        "toast_send", "toast_recv":
            # 敬酒的样子（阿鱼 9/18 晚）：send 我敬坐着的小李——小李站起来、我举杯、干杯插图；
            # recv 我坐在 T1，hallPulse 带回「老王刚敬了我」——我站起来举杯、同一张插图
            nickname = "小李" if shot == "toast_recv" else "阿鱼"
            await _enter_banquet()
            hall.couple_armed = false
            dialog.visible = false
            for i in 10: await get_tree().process_frame
            if shot == "toast_send":
                var li: Dictionary = hall.resident_nodes.get("fake_li", {})
                if not li.is_empty():
                    hall.reset_to(hall._stand_spot(li["at"], li["center"]) + Vector2(-30, 20))
                card_openid = "fake_li"
                person_card_toast_btn.disabled = false
                _on_toast_pressed()
            else:
                hall.apply_change("T1", 5, cloud.openid())
                for i in 30: await get_tree().process_frame
                cloud.fake_pulse_toasts = [{"from": "fake_wang"}]
                cloud.call_fn("hallPulse", {"since": 1}, _on_pulse)
            # 等到碰杯之后再截（插图 0.95 秒碰杯、「干杯」弹出来）；截图模式下一帧不一定是 1/60 秒，按插图自己的钟等
            while is_instance_valid(toast_scene) and toast_scene.t < 1.3:
                await get_tree().process_frame
        "remote_probe", "remote_probe_local", "remote_probe_fail":
            # 远程加载的最小验证（§0.9）：调试版日志面板里点「远程加载」以后的样子。要加 --hud 才有调试面板。
            # 电脑上走假下载；remote_probe 是第一次（下载了），remote_probe_local 是第二次（读的本地，没下载）；
            # remote_probe_fail 是第 30 版真机那样下载失败，带上问临时链接的回话（这里假装回的是没权限）
            if dbg == null:
                _build_debug()
            nickname = "小李"
            await _enter_banquet()
            dialog.visible = false
            _toggle_log()
            var pr = RemoteProbe.new()
            pr.file_id = "cloud://fake-env.fake-bucket/canvas/scene_roman_banquet/base.png"
            if shot == "remote_probe_fail":
                pr.clear_local()
                cloud.fake_fetch_fail = "download_failed"
                cloud.fake_fetch_diag = {"env_in_id": "cloud1-d9ggg36tj34742bef", "env_init": "cloud1-d9ggg36tj34742bef",
                    "status": -1, "errMsg": "STORAGE_EXCEED_AUTHORITY", "url_host": ""}
            if shot == "remote_probe" or shot == "remote_probe_fail":
                pr.clear_local()
            else:
                _run_remote_probe(pr)
                pr = RemoteProbe.new()
                pr.file_id = "cloud://fake-env.fake-bucket/canvas/scene_roman_banquet/base.png"
            _run_remote_probe(pr)
        "toast_back", "toast_back_sent":
            # 回敬（蓝图 3.2「可回敬一次」，01 9/19）：我坐在 T1，老王当场敬了我——顶部提示右边出「回敬一杯」，
            # 浮在插图上面；sent 是点了以后：顶部「敬了 老王 一杯」、老王站起来、我举杯、放我敬他的那张插图
            nickname = "小李"
            await _enter_banquet()
            hall.couple_armed = false
            dialog.visible = false
            hall.apply_change("T1", 5, cloud.openid())
            await _shot_skip_entry_toast()
            cloud.fake_pulse_toasts = [{"from": "fake_wang"}]
            cloud.call_fn("hallPulse", {"since": 1}, _on_pulse)
            var first_scene := toast_scene
            if shot == "toast_back_sent":
                _on_toast_back_pressed()
            for i in 900:
                var s := toast_scene
                if is_instance_valid(s) and s.t >= 1.3 and (shot == "toast_back" or s != first_scene):
                    break
                await get_tree().process_frame
        "life_band", "life_gifts", "life_guests", "life_waiter":
            # 厅里的热闹（阿鱼 9/18）：乐队、贺礼、别桌的 NPC 宾客、服务员，各拍一张看摆得对不对
            nickname = "小李"
            await _enter_banquet()
            hall.couple_armed = false
            dialog.visible = false
            var spot := {"life_band": Vector2(1150, 360), "life_gifts": Vector2(420, 360),
                "life_guests": Vector2(640, 690), "life_waiter": Vector2(1300, 520)}
            hall.reset_to(spot[shot])
            if shot == "life_waiter" and hall.life != null and not hall.life.waiters.is_empty():
                # 服务员在 8 号桌边放菜：托盘放低、菜已经上桌冒着热气（9/19：原来只端着走不放下）
                var w = hall.life.waiters[0]
                var sp: Array = hall.life.spots.get("T8", [])
                if not sp.is_empty():
                    w.pos = sp[0]
                    w.table = "T8"
                    w.state = "serve"
                    w.serve_t = hall.life.SERVE_LEN * 0.5
                    w.placed = false
            # 多跑一会儿，让举杯、音符、弓都动起来
            for i in 90: await get_tree().process_frame
            if shot == "life_waiter" and hall.life != null:
                # 定格在菜刚放上桌、托盘还低着的那一下
                var w = hall.life.waiters[0]
                w.state = "serve"
                w.serve_t = hall.life.SERVE_LEN * 0.55
                hall.life._pose_waiter(w, false)
                hall.life.set_process(false)
            if shot == "life_guests" and hall.life != null:
                # 截图那一刻正好 9 号桌整桌举杯（再过 50 帧截，杯子正举在最高）
                hall.life.toast_left["T9"] = hall.life.TOAST_LEN
                hall.life.toast_next["T9"] = 99.0
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
        "court", "court_sign", "court_photo", "court_rest", "court_hall_door":
            # 迎宾院灰盒（蓝图 3.1）：court 刚从大门进来；另外几张站到签到桌前、花墙前、休息区、楼门口
            nickname = "小李"
            await _enter_court()
            var at := {"court_sign": Vector2(1100, 690), "court_photo": Vector2(1150, 440),
                "court_rest": Vector2(330, 520), "court_hall_door": Vector2(768, 270)}
            if at.has(shot):
                dialog.visible = false
                court.reset_to(at[shot])
                court.face = "up"
        "court_welcome", "court_sign_name", "court_sign_gift", "court_sign_confirm", "court_candy", "court_signed":
            # 迎宾院签到（蓝图 3.1）：门口新娘妈妈迎一句；签到面板三页；签完喜糖弹窗和新娘妈妈指路；再来只显示「已签到」
            _shot_court_fresh()
            nickname = "小李"
            await _enter_court()
            dialog.visible = false
            if shot == "court_welcome":
                court.reset_to(Vector2(768, 700))
                court.face = "up"
                _on_court_spot("welcome", true)
            else:
                court.reset_to(court.spot_pos("sign_in"))
                court.face = "up"
                court_ui.spot("sign_in", true)
                if shot == "court_signed":
                    court_save.signed_in = true
                    court_ui.spot("sign_in", true)
                else:
                    court_ui.open_sign()
                    if shot != "court_sign_name":
                        court_ui._name_next()
                    if shot == "court_sign_confirm" or shot == "court_candy":
                        court_ui._pick_gift(88)
                    if shot == "court_candy":
                        court_ui._submit()
        "court_album", "court_clip", "court_pose", "court_focus", "court_paper_wave", "court_paper_heart":
            # 回忆册（正式版置灰「还没印好」；court_clip 是调试版打开的占位屏）、花墙合影三步（蓝图 3.1、世界观 1.1）
            _shot_court_fresh()
            nickname = "小李"
            await _enter_court()
            dialog.visible = false
            if shot == "court_album" or shot == "court_clip":
                debug_override = shot == "court_clip"
                court.reset_to(court.spot_pos("album") + Vector2(0, 100))
                court.face = "up"
                court.go_to(court.spot_pos("album"))
                for i in 90: await get_tree().process_frame
                if shot == "court_clip":
                    court_ui._on_act()
            else:
                court.reset_to(court.spot_pos("photo_mark") + Vector2(0, 60))
                court.go_to(court.spot_pos("photo_mark"))
                for i in 60: await get_tree().process_frame
                court_ui._on_act()
                if shot != "court_pose":
                    court_ui._pick_pose("heart" if shot == "court_paper_heart" else "wave")
                    for i in 20: await get_tree().process_frame
                if shot.begins_with("court_paper"):
                    court_ui._shutter()
        "court_elder", "court_gate_open", "court_gate_not_signed", "court_to_hall":
            # 休息区老人一句（第一次自动弹普通话）；大门开了走到门口、写了悄悄话没签到；从迎宾院走进楼门到宴会厅（03 9/19 建议加）
            _shot_court_fresh()
            nickname = "小李"
            await _enter_court()
            dialog.visible = false
            match shot:
                "court_elder":
                    court.reset_to(court.spot_pos("rest") + Vector2(0, 30))
                    court.face = "up"
                    _on_court_spot("rest", true)
                "court_gate_open", "court_gate_not_signed":
                    court_save.whisper_done = true
                    court_save.signed_in = shot == "court_gate_open"
                    _update_gate()
                    court.reset_to(court.spot_pos("gate") + Vector2(0, -20))
                    court.face = "down"
                    _at_gate()
                "court_to_hall":
                    court.reset_to(court.spot_pos("to_hall") + Vector2(0, 120))
                    court.go_to(court.spot_pos("to_hall"))
                    for i in 240:
                        await get_tree().process_frame
                        if state == "banquet" and not switching:
                            break
                    dialog.visible = false
        "backhall", "backhall_overview", "backhall_dress", "backhall_lounge", "backhall_mahjong", "backhall_pot", "backhall_lawn", "hall_side_door":
            # 后厅灰盒（蓝图 3.3，01 9/19 派任务 7）：backhall 是从宴会厅东侧门刚进来；dress、lounge、mahjong、pot 是走进各房间的点、
            # 点了按钮出那句（话没定之前是【待补】）；lawn 是走到厨房后门；overview 整张（横屏 RES=1536x1024）；
            # hall_side_door 是宴会厅里走到东侧门跟前（再走一步就进后厅）
            nickname = "阿花"
            await _enter_banquet()
            hall.couple_armed = false
            dialog.visible = false
            await _shot_skip_entry_toast()
            note_box.visible = false
            _clear_toast_back()
            if shot == "hall_side_door":
                hall.reset_to(HALL_FROM_BACKHALL + Vector2(-60, 20))
                hall.face = "right"
                for i in 6: await get_tree().process_frame
            else:
                hall_side_latched = false
                hall.reset_to(hall.side_door + Vector2(-20, 0))
                for i in 90:
                    await get_tree().process_frame
                    if state == "backhall" and not switching:
                        break
                var at := {"backhall_dress": Vector2(168, 420), "backhall_lounge": Vector2(504, 440),
                    "backhall_mahjong": Vector2(840, 510), "backhall_pot": Vector2(1272, 400), "backhall_lawn": Vector2(1490, 780)}
                if at.has(shot):
                    backhall.reset_to(at[shot] + Vector2(0, 60))
                    backhall.face = "up"
                    backhall.go_to(at[shot])
                    for i in 90:
                        await get_tree().process_frame
                        if backhall.path.is_empty():
                            break
                    if shot != "backhall_lawn":
                        backhall_ui._on_act()
                if shot == "backhall_overview":
                    hud.visible = false
                    dialog.visible = false
                    backhall.walking_enabled = false
                    backhall.set_process(false)
                    var vb := get_viewport().get_visible_rect().size
                    var zb := minf(vb.x / 1536.0, vb.y / 1024.0)
                    backhall.cam.zoom = Vector2(zb, zb)
                    backhall.cam.limit_right = 100000
                    backhall.cam.position = Vector2(768, 512)
                    backhall.cam.reset_smoothing()
            await get_tree().process_frame
        "lawn", "lawn_overview", "lawn_greet", "lawn_kick", "lawn_fetch", "lawn_kids", "lawn_orchard":
            # 草坪灰盒（蓝图 3.4，01 9/19 派任务 8）：lawn 是从迎宾院东小径刚过来；greet 是走近球、喜多叼着球跑过来；
            # kick 是往右踢一脚、球在滚；fetch 是喜多叼着球往回跑；kids 是走到孩童区小孩说一句；orchard 是走到北口；
            # overview 整张（横屏 RES=1536x1024）
            nickname = "阿花"
            await _enter_court()
            dialog.visible = false
            _switch_canvas("lawn")
            for i in 30:
                await get_tree().process_frame
                if state == "lawn" and not switching:
                    break
            if shot == "lawn_overview":
                lawn.reset_to(Vector2(620, 600))
                lawn.face = "right"
                for i in 90:
                    await get_tree().process_frame
                    if lawn.dog_state == "idle" and lawn.greeted:
                        break
                hud.visible = false
                dialog.visible = false
                lawn_ui.hide_all()
                lawn.walking_enabled = false
                lawn.set_process(false)
                var vl := get_viewport().get_visible_rect().size
                var zl := minf(vl.x / 1536.0, vl.y / 1024.0)
                lawn.cam.zoom = Vector2(zl, zl)
                lawn.cam.limit_right = 100000
                lawn.cam.position = Vector2(768, 512)
                lawn.cam.reset_smoothing()
            elif shot in ["lawn_greet", "lawn_kick", "lawn_fetch"]:
                lawn.reset_to(Vector2(560, 600))
                lawn.face = "right"
                for i in 300:
                    await get_tree().process_frame
                    if shot == "lawn_greet" and lawn.ball_state == "held" and lawn.dog_pos.distance_to(lawn.pos) < 120.0:
                        lawn.set_process(false)   # 定在叼着球跑过来那一下
                        break
                    if shot != "lawn_greet" and lawn.greeted and lawn.dog_state == "idle":
                        break
                if shot != "lawn_greet":
                    lawn.face = "right"
                    lawn.kick()
                    for i in 300:
                        await get_tree().process_frame
                        if shot == "lawn_kick" and lawn.roll_t > 0.35:
                            break
                        if shot == "lawn_fetch" and lawn.ball_state == "held" and lawn.dog_pos.distance_to(lawn.pos) < 150.0:
                            lawn.set_process(false)
                            break
                    if shot == "lawn_kick":
                        lawn.set_process(false)
            elif shot == "lawn_kids":
                lawn.reset_to(Vector2(1180, 560))
                lawn.go_to(lawn.spot_pos("kids"))
                for i in 200:
                    await get_tree().process_frame
                    if dialog.visible:
                        break
            elif shot == "lawn_orchard":
                lawn.reset_to(Vector2(768, 300))
                lawn.go_to(lawn.spot_pos("to_orchard"))
                for i in 200:
                    await get_tree().process_frame
                    if note_box.visible:
                        break
            await get_tree().process_frame
        "court_overview":
            # 迎宾院整张（灰盒）：镜头拉远看全图，没有界面。横屏截：RES=1536x1024 ./capture.sh 目录 court_overview
            nickname = ""
            await _enter_court()
            hud.visible = false
            court.walking_enabled = false
            court.set_process(false)
            var vsz := get_viewport().get_visible_rect().size
            var zz := minf(vsz.x / 1536.0, vsz.y / 1024.0)
            court.cam.zoom = Vector2(zz, zz)
            court.cam.limit_right = 100000
            court.cam.position = Vector2(768, 512)
            court.cam.reset_smoothing()
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
        "nick_rejected":
            # 起昵称被服务端拒（敏感词模块，回执 05）：cloud.gd 的假数据遇到"测试敏感"回 sensitive，
            # _after_profile 应该带回起昵称那一屏、nick_err 显示「换一个吧」，不进厅
            nick_edit.text = "测试敏感"
            nickname = "测试敏感"
            await _enter_banquet()
            await get_tree().process_frame
