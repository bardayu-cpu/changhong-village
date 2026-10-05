extends Control
## 席间小游戏的外壳（蓝图 3.2，阿鱼 9/19 定）：全屏盖在宴会厅上，六个游戏共用。
##   开始卡：游戏名、第几关、这一关目标、手上几金、「开始」「离开」（连连看多一个「菜单册」）
##   玩：顶栏写游戏名、第几关、状态（游戏自己给，比如「剩 45 秒」；有图的游戏可以给几张小图，见 status_parts）、手上几金、「离开」
##   结算卡：过了——「+N 金」、连连看写解锁了哪道菜，「下一关」「离开」；没过——为什么，「再来一次」「离开」
##   调试版底下多一行（阿鱼要「难度可调」）：难度倍数 −/+（参数怎么随倍数变见 minigames.json 的 hard）、上一关/下一关
## 游戏脚本在 SCRIPTS 里登记，缺哪个就在开始卡上写「这个还在做」
signal closed

const Cfg = preload("res://scripts/games/game_config.gd")
const Tiles = preload("res://scripts/games/tiles.gd")
const UISkin = preload("res://scripts/games/ui_skin.gd")
const SCRIPTS := {
    "lianliankan": "res://scripts/games/lianliankan.gd",
    "match3": "res://scripts/games/match3.gd",
    "g2048": "res://scripts/games/g2048.gd",
    "memory": "res://scripts/games/memory.gd",
    "whack": "res://scripts/games/whack.gd",
    "catch": "res://scripts/games/catch.gd",
}
const BAR_H := 64.0          # 顶栏两行本来多高（第二行被胶囊往下推时跟着加高，见 bar_h）
## 微信右上角的胶囊按钮（A1，体验第一轮）：屏幕坐标（540 宽）。下沿 iPhone 16 Pro 上约 124（main.gd 的 TOP_Y 150 就是为它让的），
## 左沿 402 宽的屏约 414、375 宽的约 405，取 400 留点余。原来面板顶在 70，右上角「N 金」和状态那行的右半截都压在胶囊底下
const CAPSULE_BOTTOM := 124.0
const CAPSULE_LEFT := 400.0
const DBG_H := 56.0
const BTN_ROW_H := 68.0      # 左下角「离开」「歇一下」占的那一条
## 顶栏状态那行的小图多大（B10：小菜合大菜的「目标」「现在最大」画成那一级的图）。
## 原来 32，比旁边 24 号的字还难认（04 复看第 43 版）；01 定 56 以上。这一行跟着变高，游戏区往下让，
## 只有带图的那一局这样（icon_row），别的游戏顶栏不变
const STATUS_ICON := 56.0
## 没过也给一点（体验评审第 12 条，阿鱼 9/20 定要给）。**新写，等阿鱼定**：
## 话要说清是安慰的，别让人以为过关了
const LINE_CONSOLE := "没过 也给你 %d 金 辛苦了"
const UI = preload("res://scripts/ui/ui_kit.gd")   # 界面颜色、字号都从这里取（公共·界面组件，罗-1）
const WINE := UI.OLD_WINE     # 旧主题，罗-2 换掉
const GOLD := UI.OLD_GOLD
const GOLD1 := UI.OLD_GOLD1
const PAPER := UI.OLD_PAPER
const MUTED := UI.OLD_MUTED

var save                      # game_save.gd
var font: Font
var debug := false
var g: Dictionary = {}        # 这个游戏的配置
var game_id := ""
var table_id := ""
var level := 1
var k := 1.0                  # 调试版难度倍数
var game: Control             # 正在玩的那一局（mini_game.gd 的子类）
var panel: Panel
var title_l: Label
var level_l: Label
var status_l: Label
var status_box: HBoxContainer        # 状态那行要放小图时用它（B10），不放图时藏着、照旧用 status_l
var status_sig := ""                 # status_box 现在摆的是什么，变了才重摆（每帧都读）
var bar_h := BAR_H                   # 顶栏实际多高（_layout 按胶囊算）
var icon_row := false                # 这一局顶栏第二行要放小图（B10），第二行按图高排
var coins_l: Label
var area: Control
var card: Panel
var dbg_l: Label
var book: Panel
var pause_b: Button
var played := false                  # 这一关真开过局没有（安慰奖只给真玩过的）
## 外壳换 GPT 第 1 批 UI（01 D 9/30，只换宴会厅那三个：连连看、川菜消消乐、小菜合大菜，见 ui_skin.gd）
var skin := false
var topbar: NinePatchRect            # 顶栏底图（换皮时有）
var coin_i: TextureRect              # 金币 v2（方孔铜钱），贴在「N 金」左边
var clock_i: TextureRect             # 倒计时钟，状态那行有「秒」时贴在它左边
const SKIN_ICON := 48.0

func open(p_game_id: String, p_table_id: String, p_save, p_font: Font, p_debug := false) -> void:
    game_id = p_game_id
    table_id = p_table_id
    save = p_save
    font = p_font
    debug = p_debug
    g = Cfg.game(game_id)
    level = save.next_level(game_id)
    skin = UISkin.on(game_id)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var shade := ColorRect.new()
    # 换皮时整屏垫深酒红（GPT 边框中间是空的，照预览图那样底子是深的）；不换皮照旧半透明黑，看得见后面的厅
    shade.color = WINE if skin else UI.DIM_GAME
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    panel = Panel.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = WINE
    sb.border_color = GOLD
    sb.set_border_width_all(0 if skin else 3)   # 换皮时金边由整屏那张边框出
    sb.set_corner_radius_all(10)
    panel.add_theme_stylebox_override("panel", sb)
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    # 换皮时整屏那张边框四边各 24：面板往里收到边框里面，字和按钮不压在金边底下
    var inset := 28.0 if skin else 10.0
    panel.offset_left = inset
    panel.offset_right = -inset
    panel.offset_top = 70
    panel.offset_bottom = -inset if skin else -20.0
    add_child(panel)
    if skin:
        # 整屏边框（540×960，九宫格 24，中间透明）盖在最上面，不挡点
        var frame := UISkin.patch("base_ui_frame_v1", UISkin.FRAME_M)
        frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        frame.name = "skin_frame"
        frame.z_index = 1
        add_child(frame)
        topbar = UISkin.patch("base_ui_topbar_v1", 8)
        topbar.name = "skin_topbar"
        panel.add_child(topbar)
        coin_i = UISkin.icon("prop_ui_coin_v2", SKIN_ICON)
        coin_i.name = "skin_coin"
        panel.add_child(coin_i)
        clock_i = UISkin.icon("prop_ui_clock_v1", SKIN_ICON)
        clock_i.name = "skin_clock"
        clock_i.visible = false
        panel.add_child(clock_i)
    # 顶栏：只写游戏名（B11，体验第一轮）。原来是「游戏名·玩法」，顶栏挂着「小菜合大菜·2048」「川菜消消乐·三消」这种行话；
    # kind 只留在 json 里给人看，玩家眼里不出现
    title_l = _label(Cfg.title(g), 24, GOLD1)
    title_l.position = Vector2(14, 8)
    panel.add_child(title_l)
    level_l = _label("", 24, PAPER)
    panel.add_child(level_l)
    status_l = _label("", 24, PAPER)
    status_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    panel.add_child(status_l)
    status_box = HBoxContainer.new()
    status_box.alignment = BoxContainer.ALIGNMENT_END
    status_box.add_theme_constant_override("separation", 6)
    status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    status_box.visible = false
    panel.add_child(status_box)
    coins_l = _label("", 24, GOLD1)
    coins_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    panel.add_child(coins_l)
    # 「离开」原来在右上角，紧挨着小程序自己的关闭按钮，阿鱼真机上容易误触退出整个游戏（A2）：挪到左下角
    var quit := _button("离开", _close)
    quit.name = "quit"
    panel.add_child(quit)
    # 「歇一下」（评论第 11 条）：喜宴上有人来敬酒、上菜、长辈说话是常态，不是意外。
    # paused 这个开关六个游戏一直在读，就是没人置过 true——位子留好了、开关没装
    pause_b = _button("歇一下", _pause)
    pause_b.name = "pause"
    pause_b.visible = false
    panel.add_child(pause_b)
    area = Control.new()
    area.clip_contents = true
    panel.add_child(area)
    if debug:
        _debug_row()
    _layout()
    get_viewport().size_changed.connect(_layout)
    _show_start()

func _layout() -> void:
    var ps := panel.size
    var bottom := DBG_H if debug else 0.0
    # 「离开」「歇一下」都在左下角（A2：右上角紧挨小程序的关闭按钮，会误触退出整个游戏）
    var quit: Button = panel.get_node("quit")
    quit.size = Vector2(96, 44)
    quit.position = Vector2(12, ps.y - bottom - quit.size.y - 12)
    pause_b.size = Vector2(112, 44)
    pause_b.position = Vector2(12 + quit.size.x + 12, quit.position.y)
    # 让开微信的胶囊（A1，体验第一轮）：面板顶不动（整块往下挪要少 60 像素游戏区），顶栏自己躲——
    #   第一行（游戏名、手上几金）在胶囊左边：金币右边收到胶囊左沿再往左 6 像素；
    #   第二行（第 N 关、状态）挪到胶囊下沿以下，这一行要占满右边，躲不开就往下挪。游戏区只少 26 像素
    var p0: Vector2 = panel.global_position     # 胶囊是按屏幕算的
    coins_l.size = Vector2(160, 28)
    var coins_r := minf(ps.x - 12.0, CAPSULE_LEFT - p0.x - 6.0)
    coins_l.position = Vector2(coins_r - 160.0, 8)
    var row2 := maxf(34.0, CAPSULE_BOTTOM - p0.y + 6.0)
    bar_h = BAR_H + (row2 - 34.0)
    # 带小图那一局（B10）：第二行按图高 STATUS_ICON 排，「第 N 关」跟图上下居中，顶栏跟着加高，游戏区整块往下让
    var row2_h := STATUS_ICON if icon_row else 28.0
    if icon_row:
        bar_h = maxf(bar_h, row2 + STATUS_ICON)
    elif skin:
        # 换皮：第二行要放 48 的钟，按钟高排（游戏区往下让一点）
        row2_h = SKIN_ICON
        bar_h = maxf(bar_h, row2 + SKIN_ICON)
    level_l.position = Vector2(14, row2 + (row2_h - 28.0) * 0.5)
    if skin:
        status_l.position.y = row2 + (row2_h - 28.0) * 0.5
    # 状态那行原来只给 220 宽，小菜合大菜「目标 抽杆 现在最大 芽谷」有 276 宽，右边被面板截掉一截（第 38 版）。
    # 改成占满「第 N 关」右边整条（540 宽的屏上约 380，最长那句 324）；万一还放不下，尾巴收成省略号，不出面板
    var st_x := 14.0 + 96.0 + 16.0      # 「第 10 关」96 宽
    status_l.size = Vector2(maxf(ps.x - 12.0 - st_x, 60.0), 28)
    status_l.position = Vector2(st_x, row2 + ((row2_h - 28.0) * 0.5 if skin and not icon_row else 0.0))
    status_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    # 带小图的那行：和 status_l 占同一条，右对齐；图是 STATUS_ICON 见方，顶在胶囊下沿以下（row2），底下就是游戏区
    status_box.position = Vector2(st_x, row2)
    status_box.size = Vector2(status_l.size.x, STATUS_ICON)
    if topbar != null:
        title_l.position.x = 36.0   # 顶栏两头有小括号花，游戏名往里让开
        # 顶栏底图只垫第一行（游戏名、手上几金），高到第二行上面；不往下拉长，不然两头的小箭头跑到中间
        topbar.position = Vector2(0, 0)
        topbar.size = Vector2(ps.x, minf(64.0, row2 - 2.0))
    area.position = Vector2(8, bar_h + 8)
    # 底下给那两个按钮留一条（原来「离开」在顶栏，游戏区能铺到底）
    area.size = Vector2(ps.x - 16, ps.y - bar_h - 16 - bottom - BTN_ROW_H)
    if game != null:
        game.size = area.size
    if dbg_l != null:
        (dbg_l.get_parent() as Control).position = Vector2(12, ps.y - DBG_H)
    if card != null:
        card.position = (area.size - card.size) * 0.5

func _process(_dt: float) -> void:
    if game != null and is_instance_valid(game):
        _sync_status()
    level_l.text = "第 %d 关" % level
    coins_l.text = "%d 金" % save.coins
    if skin:
        _place_icons()

## 换皮：金币贴在「N 金」左边、钟贴在「剩 N 秒」左边（字是右对齐的，按字宽算）
func _place_icons() -> void:
    if coin_i != null:
        var w := font.get_string_size(coins_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
        coin_i.position = Vector2(coins_l.position.x + coins_l.size.x - w - SKIN_ICON - 4.0, coins_l.position.y + 14.0 - SKIN_ICON * 0.5)
    if clock_i != null:
        var timed: bool = status_l.visible and status_l.text.contains("秒")
        clock_i.visible = timed
        if timed:
            var w2 := font.get_string_size(status_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
            w2 = minf(w2, status_l.size.x)
            clock_i.position = Vector2(status_l.position.x + status_l.size.x - w2 - SKIN_ICON - 4.0, status_l.position.y + 14.0 - SKIN_ICON * 0.5)

## 顶栏状态那行（B10，阿鱼 9/23「有图就别叠字」）：游戏给了 status_parts（字和小图混排）就摆那个，
## 没给（空数组）就照旧写 status_text 那一句。现在只有小菜合大菜给图：「目标 [图] 现在最大 [图]」；
## 那一关图没交齐（色块兜底）它也不给图，还是写名字
func _sync_status() -> void:
    var parts: Array = game.status_parts()
    if parts.is_empty():
        status_box.visible = false
        status_l.visible = true
        status_l.text = game.status_text()
        return
    status_l.visible = false
    status_box.visible = true
    var sig := ""
    for p in parts:
        sig += ("[%s]" % (p as Texture2D).resource_path) if p is Texture2D else ("|" + str(p))
    if sig == status_sig:
        return
    status_sig = sig
    for c in status_box.get_children():
        c.queue_free()
    for p in parts:
        if p is Texture2D:
            status_box.add_child(_status_icon(p))
        else:
            var l := _label(str(p), 24, PAPER)
            l.custom_minimum_size = Vector2(0, STATUS_ICON)
            l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            status_box.add_child(l)

## 状态行里的一张小图：垫一层和 2048 牌面一样的浅米色牌底（最低几级只有一小粒，没底看不出是个东西）
func _status_icon(tex: Texture2D) -> Panel:
    var p := Panel.new()
    p.custom_minimum_size = Vector2(STATUS_ICON, STATUS_ICON)
    p.add_theme_stylebox_override("panel", Tiles.box(Tiles.CARD_BG, 4, Tiles.CARD_EDGE))
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var r := TextureRect.new()
    r.texture = tex
    r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    r.position = Vector2(2, 2)
    r.size = Vector2(STATUS_ICON - 4, STATUS_ICON - 4)
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_child(r)
    return p

# ---------- 开始卡、结算卡 ----------
func _show_start() -> void:
    _clear_game()
    played = false
    _sync_buttons()
    # 最大那行字原来是「2048」「三消」这种行话，说人话的那句排在最底下、颜色最淡（评审第 4 条）：
    # 大字换成桌牌名，json 里那句 goal 提到「第 N 关」上面
    var lines: Array = []
    var human: String = str(g.get("goal", ""))
    if human != "":
        lines.append(human)
    lines.append("第 %d 关" % level)
    var probe := _make_game()
    var ready_to_play := probe != null
    if not ready_to_play:
        lines.append("这个游戏还在做")
    else:
        var goal: String = probe.goal_text()
        if goal != "":
            lines.append(goal)
        probe.free()
    var btns: Array = []
    if ready_to_play:
        btns.append(["开始", _start])
    if game_id == "lianliankan":
        btns.append(["菜单册", _open_book])
    btns.append(["离开", _close])
    _card(Cfg.title(g), lines, btns)

func _make_game() -> Control:
    var path: String = SCRIPTS.get(game_id, "")
    if path == "" or not ResourceLoader.exists(path):
        return null
    var gm: Control = load(path).new()
    gm.setup(level, Cfg.params(g, level, k), font, int(Time.get_ticks_usec()) ^ (level * 7919))
    gm.art_set = str(g.get("art_set", "shared"))
    return gm

func _start() -> void:
    _clear_card()
    game = _make_game()
    if game == null:
        _show_start()
        return
    # 这一局顶栏要不要放小图，开局前问好、排好，游戏区定了大小再搭盘（开局后再改大小，盘就不居中了）
    icon_row = game.status_has_icons()
    _layout()
    game.size = area.size
    status_sig = ""
    area.add_child(game)
    game.finished.connect(_on_finished)
    game.start()
    played = true
    _sync_buttons()
    print("[suqi] 小游戏 %s 第 %d 关 开始 难度×%.1f 参数 %s" % [game_id, level, k, JSON.stringify(game.params)])

## 歇一下（评审第 11 条）：把 paused 置上，盖一张卡。这一关不作废、不扣金币，接着玩就从刚才那下继续
func _pause() -> void:
    if game == null or not is_instance_valid(game) or game.over or game.paused:
        return
    game.paused = true
    _sync_buttons()
    _card("歇一下", ["这一关停在这儿 等你回来", "不算输 也不扣金币"], [["接着玩", _resume], ["离开", _close]])

func _resume() -> void:
    _clear_card()
    if game != null and is_instance_valid(game) and not game.over:
        game.paused = false
    _sync_buttons()

## 「歇一下」只在真在玩的时候出：开始卡、结算卡、歇着的时候都收起来
func _sync_buttons() -> void:
    if pause_b == null:
        return
    pause_b.visible = game != null and is_instance_valid(game) and not game.over and not game.paused
    _sync_quit()

## 左下角「离开」：卡片开着的时候收起来（B15，体验第一轮）——卡片上自己有一个「离开」，
## 原来屏幕上同时两个一模一样的「离开」。卡片一收，它就回来
func _sync_quit() -> void:
    if panel == null:
        return
    var quit := panel.get_node_or_null("quit") as Button
    if quit != null:
        quit.visible = card == null

func _on_finished(won: bool, why: String) -> void:
    _sync_buttons()
    print("[suqi] 小游戏 %s 第 %d 关 %s %s" % [game_id, level, "过了" if won else "没过", why])
    if won:
        var reward: int = Cfg.reward(g, level)
        var extra: Array = []
        if game != null and is_instance_valid(game):
            # 接彩头：接到的全拿走，不照奖励表（01 9/23）
            if game.won_coins() >= 0:
                reward = game.won_coins()
            extra = game.win_lines()
        var dish := -1
        var lines: Array = ["+%d 金（手上 %d 金）" % [reward, save.coins + reward]]
        lines.append_array(extra)
        if game_id == "lianliankan" and not Cfg.dishes().is_empty():
            dish = (level - 1) % Cfg.dishes().size()
            var d: Dictionary = Cfg.dishes()[dish]
            lines.append("菜单册多了一道：%s" % str(d.get("name", "")))
        save.clear_level(game_id, level, reward, dish)
        # 停半秒让玩家看清最后一下，再出结算卡（外壳关掉了，定时器连的方法跟着断开，不会再调）
        get_tree().create_timer(0.5).timeout.connect(_after_win.bind(level, lines))
    else:
        get_tree().create_timer(0.5).timeout.connect(_after_lose.bind(why))

func _after_win(cleared: int, lines: Array) -> void:
    level = save.next_level(game_id)
    _card("第 %d 关 过了" % cleared, lines, [["下一关", _show_start], ["离开", _close]])

## 没过（体验评审第 12 条，阿鱼 9/20 定「要给」）：给该关奖励的四分之一、向下取整（第 1 关 10 金 → 2 金）。
## 三条守住：① 只有真开过局才给（点开就点「离开」那种走的是 _close，根本到不了这儿，另外再拿 played 兜一层）；
## ② 走现成的钱包出口 save.earn，不新开路径，也不动关卡进度（输了就是没过）；
## ③ **每次输都给**（01 9/20 算过：输一局 30 秒拿 2 金 = 4 金/分钟，
##    果园一趟 40 金、5 分钟一轮 = 8 金/分钟，刷安慰奖比走果园还慢，没人会刷；
##    真限成「一关只给一次」，挡住的正好是连输好几次的长辈——安慰奖本来就是给他的）
func _after_lose(why: String) -> void:
    var lines: Array = [why] if why != "" else []
    var prize := 0
    if played:
        prize = int(floor(float(Cfg.reward(g, level)) / 4.0))
        if prize > 0:
            save.earn(prize)
            lines.append(LINE_CONSOLE % prize)
    _card("差一点", lines, [["再来一次", _show_start], ["离开", _close]])

## 卡片：大字标题、几行字、一排按钮；盖在游戏区中间
func _card(head: String, lines: Array, btns: Array, foot := "") -> void:
    _clear_card()
    card = Panel.new()
    _sync_quit()
    var sb := StyleBoxFlat.new()
    sb.bg_color = UI.OLD_GAME_CARD
    sb.border_color = GOLD
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(8)
    var skin_sb: StyleBox = UISkin.card_box() if skin else null
    card.add_theme_stylebox_override("panel", skin_sb if skin_sb != null else sb)
    var paper: bool = skin_sb != null   # 米色纸卡：字用深色，四周按卡上的花留边
    var w := minf(area.size.x - 24.0, 460.0)
    # 纸卡上下各有一道金点花边（离边 77），字从花边里面写起，不压花边
    var pad := Vector2(52, float(UISkin.CARD_MT)) if paper else Vector2(16, 16)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    box.position = pad
    box.size = Vector2(w - pad.x * 2.0, 0)
    card.add_child(box)
    var h := _label(head, 36, UISkin.CARD_HEAD if paper else GOLD1)
    h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(h)
    for ln in lines:
        var l := _label(str(ln), 24, UISkin.CARD_INK if paper else PAPER)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
        l.custom_minimum_size = Vector2(w - pad.x * 2.0, 0)
        box.add_child(l)
    if foot != "":
        var f := _label(foot, 24, UI.OLD_MENU_FOOT if paper else MUTED)
        f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        f.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
        f.custom_minimum_size = Vector2(w - pad.x * 2.0, 0)
        box.add_child(f)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 12)
    for i in btns.size():
        var b: Array = btns[i]
        var bt := _button(str(b[0]), b[1])
        bt.custom_minimum_size = Vector2(120, 52)
        if skin:
            UISkin.skin_button(bt, i == 0)   # 第一个（开始、下一关、再来一次、接着玩）是主按钮，其余次按钮
        row.add_child(bt)
    box.add_child(row)
    area.add_child(card)
    # 等一帧量出内容高度再定卡片大小、居中
    await get_tree().process_frame
    if not is_instance_valid(card):
        return
    card.size = Vector2(w, box.get_combined_minimum_size().y + pad.y * 2.0)
    card.position = (area.size - card.size) * 0.5

func _clear_card() -> void:
    if card != null and is_instance_valid(card):
        card.queue_free()
    card = null
    _sync_quit()

func _clear_game() -> void:
    _clear_card()
    if pause_b != null:
        pause_b.visible = false
    if game != null and is_instance_valid(game):
        game.queue_free()
    game = null
    # 上一局的状态别留到下一张开始卡上（带小图那行尤其显眼）
    if status_l != null:
        status_l.text = ""
        status_l.visible = true
        status_box.visible = false
        status_sig = ""
    if icon_row:
        icon_row = false
        _layout()

func _close() -> void:
    _clear_game()
    closed.emit()
    queue_free()

# ---------- 连连看的菜单册 ----------
func _open_book() -> void:
    if book != null and is_instance_valid(book):
        book.queue_free()
    book = Panel.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = UI.OLD_MENU_PAPER
    sb.border_color = GOLD
    sb.set_border_width_all(3)
    sb.set_corner_radius_all(8)
    book.add_theme_stylebox_override("panel", sb)
    book.position = Vector2(8, 8)
    book.size = area.size - Vector2(16, 16)
    var scroll := ScrollContainer.new()
    scroll.position = Vector2(12, 56)
    scroll.size = book.size - Vector2(24, 68)
    book.add_child(scroll)
    var list := VBoxContainer.new()
    list.custom_minimum_size = Vector2(scroll.size.x - 12, 0)
    list.add_theme_constant_override("separation", 10)
    scroll.add_child(list)
    var head := _label("菜单册", 36, UI.OLD_GAME_CARD)
    head.position = Vector2(16, 8)
    book.add_child(head)
    var close_b := _button("合上", func(): book.queue_free())
    close_b.size = Vector2(96, 44)
    close_b.position = Vector2(book.size.x - 108, 8)
    book.add_child(close_b)
    var ds: Array = Cfg.dishes()
    for i in ds.size():
        var open_d: bool = save.dishes.has(i)
        var d: Dictionary = ds[i]
        var l := _label(("%d. %s" % [i + 1, str(d.get("name", ""))]) if open_d else ("%d. ？？？（连连看第 %d 关解锁）" % [i + 1, i + 1]),
            24, UI.OLD_MENU_INK if open_d else UI.OLD_MENU_DIM)
        l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
        l.custom_minimum_size = Vector2(list.custom_minimum_size.x, 0)
        list.add_child(l)
        if open_d:
            var n := _label("　" + str(d.get("note", "")), 24, UI.OLD_MENU_NOTE)
            n.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
            n.custom_minimum_size = Vector2(list.custom_minimum_size.x, 0)
            list.add_child(n)
    area.add_child(book)

# ---------- 调试：难度倍数、跳关 ----------
func _debug_row() -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    dbg_l = _label("", 24, UI.DEBUG_GAME)
    dbg_l.custom_minimum_size = Vector2(150, 0)
    row.add_child(dbg_l)
    for spec in [["难−", func(): _set_k(k - 0.1)], ["难+", func(): _set_k(k + 0.1)],
            ["上关", func(): _jump(-1)], ["下关", func(): _jump(1)]]:
        var b := _button(spec[0], spec[1])
        b.custom_minimum_size = Vector2(76, 44)
        row.add_child(b)
    panel.add_child(row)
    _set_k(k)

func _set_k(v: float) -> void:
    k = clampf(snappedf(v, 0.1), 0.5, 2.0)
    dbg_l.text = "调试 难度×%.1f" % k
    if game != null and not game.over:
        _show_start()   # 正在玩的这一局按新倍数重开

func _jump(d: int) -> void:
    level = maxi(level + d, 1)
    save.debug_set_cleared(game_id, level - 1)
    _show_start()

# ---------- 小工具 ----------
func _label(text: String, size_px := 24, color := PAPER) -> Label:
    return Tiles.label(text, font, size_px, color)

func _button(text: String, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_override("font", font)
    b.add_theme_font_size_override("font_size", 24)
    b.pressed.connect(cb)
    if skin:
        UISkin.skin_button(b, false)   # 默认次按钮（离开、歇一下、菜单册、合上、调试那排）；卡片上第一个再换成主按钮
    return b
