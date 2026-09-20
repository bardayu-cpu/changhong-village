extends Control
## 席间小游戏的外壳（蓝图 3.2，阿鱼 9/19 定）：全屏盖在宴会厅上，六个游戏共用。
##   开始卡：游戏名、第几关、这一关目标、手上几金、「开始」「离开」（连连看多一个「菜单册」）
##   玩：顶栏写游戏名、第几关、状态（游戏自己给，比如「剩 45 秒」）、手上几金、「离开」
##   结算卡：过了——「+N 金」、连连看写解锁了哪道菜，「下一关」「离开」；没过——为什么，「再来一次」「离开」
##   调试版底下多一行（阿鱼要「难度可调」）：难度倍数 −/+（参数怎么随倍数变见 minigames.json 的 hard）、上一关/下一关
## 游戏脚本在 SCRIPTS 里登记，缺哪个就在开始卡上写「这个还在做」
signal closed

const Cfg = preload("res://scripts/games/game_config.gd")
const Tiles = preload("res://scripts/games/tiles.gd")
const SCRIPTS := {
    "lianliankan": "res://scripts/games/lianliankan.gd",
    "match3": "res://scripts/games/match3.gd",
    "g2048": "res://scripts/games/g2048.gd",
    "memory": "res://scripts/games/memory.gd",
    "whack": "res://scripts/games/whack.gd",
    "catch": "res://scripts/games/catch.gd",
}
const BAR_H := 64.0
const DBG_H := 56.0
const BTN_ROW_H := 68.0      # 左下角「离开」「歇一下」占的那一条
## 没过也给一点（体验评审第 12 条，阿鱼 9/20 定要给）。**新写，等阿鱼定**：
## 话要说清是安慰的，别让人以为过关了
const LINE_CONSOLE := "没过 也给你 %d 金 辛苦了"
const WINE := Color("#2a1418")
const GOLD := Color("#d4af37")
const GOLD1 := Color("#f4d97a")
const PAPER := Color("#efe6d8")
const MUTED := Color("#b1a6ba")

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
var coins_l: Label
var area: Control
var card: Panel
var dbg_l: Label
var book: Panel
var pause_b: Button
var played := false                  # 这一关真开过局没有（安慰奖只给真玩过的）
var consoled: Dictionary = {}        # 这次打开小游戏里，哪几关已经给过安慰奖了（同一关不重复给）

func open(p_game_id: String, p_table_id: String, p_save, p_font: Font, p_debug := false) -> void:
    game_id = p_game_id
    table_id = p_table_id
    save = p_save
    font = p_font
    debug = p_debug
    g = Cfg.game(game_id)
    level = save.next_level(game_id)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.55)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    panel = Panel.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = WINE
    sb.border_color = GOLD
    sb.set_border_width_all(3)
    sb.set_corner_radius_all(10)
    panel.add_theme_stylebox_override("panel", sb)
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 10
    panel.offset_right = -10
    panel.offset_top = 70
    panel.offset_bottom = -20
    add_child(panel)
    # 顶栏
    # 桌牌名和玩法名一样时只写一个（第 34 版顶栏是「连连看·连连看」，体验评审第 4 条）
    var t_name: String = Cfg.title(g)
    var t_kind: String = str(g.get("kind", ""))
    title_l = _label(t_name if t_kind == "" or t_kind == t_name else "%s·%s" % [t_name, t_kind], 24, GOLD1)
    title_l.position = Vector2(14, 8)
    panel.add_child(title_l)
    level_l = _label("", 24, PAPER)
    level_l.position = Vector2(14, 34)
    panel.add_child(level_l)
    status_l = _label("", 24, PAPER)
    status_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    panel.add_child(status_l)
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
    # 顶栏右边空出来了（原来被「离开」占着），金币和状态各往右挪回去
    coins_l.size = Vector2(160, 28)
    coins_l.position = Vector2(ps.x - 12 - 160, 8)
    status_l.size = Vector2(220, 28)
    status_l.position = Vector2(ps.x - 12 - 220, 34)
    area.position = Vector2(8, BAR_H + 8)
    # 底下给那两个按钮留一条（原来「离开」在顶栏，游戏区能铺到底）
    area.size = Vector2(ps.x - 16, ps.y - BAR_H - 16 - bottom - BTN_ROW_H)
    if game != null:
        game.size = area.size
    if dbg_l != null:
        (dbg_l.get_parent() as Control).position = Vector2(12, ps.y - DBG_H)
    if card != null:
        card.position = (area.size - card.size) * 0.5

func _process(_dt: float) -> void:
    if game != null and is_instance_valid(game):
        status_l.text = game.status_text()
    level_l.text = "第 %d 关" % level
    coins_l.text = "%d 金" % save.coins

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
    game.size = area.size
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

func _on_finished(won: bool, why: String) -> void:
    _sync_buttons()
    print("[suqi] 小游戏 %s 第 %d 关 %s %s" % [game_id, level, "过了" if won else "没过", why])
    if won:
        var reward: int = Cfg.reward(g, level)
        var dish := -1
        var lines: Array = ["+%d 金（手上 %d 金）" % [reward, save.coins + reward]]
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
## ③ 同一关这次打开只给一次，不许反复送死刷金币
func _after_lose(why: String) -> void:
    var lines: Array = [why] if why != "" else []
    var prize := 0
    if played and not consoled.has(level):
        prize = int(floor(float(Cfg.reward(g, level)) / 4.0))
        if prize > 0:
            consoled[level] = true
            save.earn(prize)
            lines.append(LINE_CONSOLE % prize)
    _card("差一点", lines, [["再来一次", _show_start], ["离开", _close]])

## 卡片：大字标题、几行字、一排按钮；盖在游戏区中间
func _card(head: String, lines: Array, btns: Array, foot := "") -> void:
    _clear_card()
    card = Panel.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color("#6e1e1e")
    sb.border_color = GOLD
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(8)
    card.add_theme_stylebox_override("panel", sb)
    var w := minf(area.size.x - 24.0, 460.0)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    box.position = Vector2(16, 16)
    box.size = Vector2(w - 32, 0)
    card.add_child(box)
    var h := _label(head, 36, GOLD1)
    h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(h)
    for ln in lines:
        var l := _label(str(ln), 24, PAPER)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
        l.custom_minimum_size = Vector2(w - 32, 0)
        box.add_child(l)
    if foot != "":
        var f := _label(foot, 24, MUTED)
        f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        f.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
        f.custom_minimum_size = Vector2(w - 32, 0)
        box.add_child(f)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 12)
    for b in btns:
        var bt := _button(str(b[0]), b[1])
        bt.custom_minimum_size = Vector2(120, 52)
        row.add_child(bt)
    box.add_child(row)
    area.add_child(card)
    # 等一帧量出内容高度再定卡片大小、居中
    await get_tree().process_frame
    if not is_instance_valid(card):
        return
    card.size = Vector2(w, box.get_combined_minimum_size().y + 32)
    card.position = (area.size - card.size) * 0.5

func _clear_card() -> void:
    if card != null and is_instance_valid(card):
        card.queue_free()
    card = null

func _clear_game() -> void:
    _clear_card()
    if pause_b != null:
        pause_b.visible = false
    if game != null and is_instance_valid(game):
        game.queue_free()
    game = null

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
    sb.bg_color = Color("#efe6d8")
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
    var head := _label("菜单册", 36, Color("#6e1e1e"))
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
            24, Color("#2c1f1c") if open_d else Color("#8a7a66"))
        l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
        l.custom_minimum_size = Vector2(list.custom_minimum_size.x, 0)
        list.add_child(l)
        if open_d:
            var n := _label("　" + str(d.get("note", "")), 24, Color("#5a4a3a"))
            n.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
            n.custom_minimum_size = Vector2(list.custom_minimum_size.x, 0)
            list.add_child(n)
    area.add_child(book)

# ---------- 调试：难度倍数、跳关 ----------
func _debug_row() -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    dbg_l = _label("", 24, Color("#7ee08a"))
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
    return b
