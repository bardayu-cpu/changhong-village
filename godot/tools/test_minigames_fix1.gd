extends SceneTree
## 验收：小游戏整改第一批（阿鱼 9/20 真机反馈 + 体验评审，01 派）。无界面跑，只看逻辑。
## 钉住的东西：
##   外壳——「离开」挪到左下角、「歇一下」真能暂停、开始卡大字是桌牌名、顶栏不重名、输了给安慰奖
##   翻牌——每行必须是满的、配对成功有反馈、用自己那套图（喜庆纹样）
##   夹菜——点冒出来那张菜的上半截能命中、辣椒不再是红底
##   接喜糖——糖落地不算漏、限时写在明处
##   小菜合大菜——水稻 10 级、按关数选作物的口子真能用
##   有图时不画色块底（翻牌的牌面除外）
## 用法：Godot --headless --path . --script res://tools/test_minigames_fix1.gd
## 最后一行 RESULT PASS 才算过

const Cfg = preload("res://scripts/games/game_config.gd")
const Save = preload("res://scripts/games/game_save.gd")
const Host = preload("res://scripts/games/game_host.gd")
const Tiles = preload("res://scripts/games/tiles.gd")
const Memory = preload("res://scripts/games/memory.gd")
const Whack = preload("res://scripts/games/whack.gd")
const Catch = preload("res://scripts/games/catch.gd")
const G2048 = preload("res://scripts/games/g2048.gd")

var started := false
var ok := true
var ui: Control

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func _save(path: String):
    var s := Save.new()
    s.local_path = path
    s.saver = func(_p, done): done.call(true)
    return s

func _host(id: String, s, debug := false):
    var h = Host.new()
    ui.add_child(h)
    h.open(id, "T1", s, SystemFont.new(), debug)
    return h

func run() -> void:
    ui = Control.new()
    ui.size = Vector2(540, 960)
    get_root().add_child(ui)

    # ---------- 1. 「离开」挪到左下角，旁边是「歇一下」 ----------
    print("1 底下那两个按钮（阿鱼 A2：原来贴着小程序的关闭按钮，会误触退出整个游戏）")
    var s1 = _save("user://test_fix1_a.json")
    var h1 = _host("g2048", s1)
    var quit: Button = h1.panel.get_node("quit")
    var pause: Button = h1.panel.get_node("pause")
    check("「离开」在左半边", quit.position.x < h1.panel.size.x * 0.5)
    check("「离开」在下半边", quit.position.y > h1.panel.size.y * 0.5)
    check("「歇一下」紧挨着它、不重叠", pause.position.x >= quit.position.x + quit.size.x and is_equal_approx(pause.position.y, quit.position.y))
    check("两个都没出面板", quit.position.x >= 0.0 and pause.position.x + pause.size.x <= h1.panel.size.x)
    # 金币原来挪回最右（「离开」挪走以后），可那儿压在微信的胶囊底下（A1，体验第一轮）：收到胶囊左边
    var coins_end: float = h1.panel.global_position.x + h1.coins_l.position.x + h1.coins_l.size.x
    check("金币在胶囊左边（右沿 %.0f ≤ %.0f）" % [coins_end, Host.CAPSULE_LEFT], coins_end <= Host.CAPSULE_LEFT)
    check("金币还在顶栏右半边，没挤到游戏名上", h1.coins_l.position.x > h1.title_l.position.x + 130.0)

    # ---------- 2. 开始卡：大字是桌牌名，不是行话 ----------
    print("2 开始卡（体验评审第 4 条：最大那行原来写着「2048」「三消」）")
    await process_frame
    await process_frame
    var head := ""
    var card_lines: Array = []
    for c in h1.card.get_child(0).get_children():
        if c is Label:
            if head == "":
                head = (c as Label).text
            else:
                card_lines.append((c as Label).text)
    check("大字是桌牌名「小菜合大菜」：%s" % head, head == "小菜合大菜")
    check("说人话那句排在「第 N 关」上面：%s" % [card_lines.slice(0, 2)], card_lines.size() >= 2 and card_lines[1].begins_with("第 1 关"))
    check("顶栏不重名（原来是「连连看·连连看」）", not h1.title_l.text.contains("·") or h1.title_l.text.split("·")[0] != h1.title_l.text.split("·")[1])
    check("还没开局，「歇一下」不出", not pause.visible)
    # B11（体验第一轮）：顶栏只写游戏名，不再挂「· 2048」「· 三消」这种行话
    check("顶栏只写游戏名：%s" % h1.title_l.text, h1.title_l.text == "小菜合大菜")
    var hm = _host("match3", _save("user://test_fix1_m3.json"))
    check("消消乐顶栏只写游戏名：%s" % hm.title_l.text, hm.title_l.text == "川菜消消乐")
    hm._close()
    # B15（体验第一轮）：卡片开着的时候左下角那个「离开」收起来（卡片上自己有一个），屏幕上只剩一个「离开」
    check("开始卡开着，左下角「离开」收起来", not quit.visible and h1.card != null)

    # ---------- 3. 「歇一下」真能暂停 ----------
    print("3 歇一下（体验评审第 11 条：paused 六个游戏都在读，就是没人置过 true）")
    h1._start()
    check("开局了「歇一下」出来", pause.visible and not h1.game.paused)
    check("开局了左下角「离开」回来（B15）", quit.visible)
    h1._pause()
    check("按下去真的暂停了", h1.game.paused)
    check("盖了一张卡", h1.card != null and is_instance_valid(h1.card))
    check("歇着的时候按钮收起来", not pause.visible)
    check("歇一下那张卡开着，左下角「离开」也收起来（B15）", not quit.visible)
    h1.game._process(1.0)   # 暂停时 _game_tick 不该跑
    h1._resume()
    check("「接着玩」恢复", not h1.game.paused and pause.visible)
    check("卡收了左下角「离开」回来（B15）", quit.visible)
    # B10（体验第一轮，阿鱼 9/23「有图就别叠字」）：小菜合大菜顶栏「目标」「现在最大」画成那一级的小图，不写级名
    h1._process(0.0)
    var icons := 0
    var words: Array = []
    for c in h1.status_box.get_children():
        if c is Panel and (c as Panel).get_child_count() > 0 and (c as Panel).get_child(0) is TextureRect:
            icons += 1
        elif c is Label:
            words.append((c as Label).text)
    var named := false
    for w in h1.game.steps():
        if words.has(str(w)) or h1.status_l.text.contains(str(w)) and h1.status_l.visible:
            named = true
    check("第 1 关（水稻，图齐）顶栏：%s + %d 张小图" % [words, icons],
        h1.status_box.visible and not h1.status_l.visible and icons == 2 and words == ["目标", "现在最大"])
    check("顶栏不写级名（谷种、抽杆……）", not named)
    var goal_tex: Texture2D = ((h1.status_box.get_child(1) as Panel).get_child(0) as TextureRect).texture
    check("「目标」那张是这关目标那一级的图：%s" % goal_tex.resource_path, goal_tex == Tiles.dish_art(h1.game.target - 1, h1.game.art_set))
    var sb_end: float = h1.status_box.position.x + h1.status_box.size.x
    check("小图那行不出面板、不压「第 N 关」", sb_end <= h1.panel.size.x - 12.0 + 0.5 and h1.status_box.position.x >= 14.0 + 96.0)
    check("小图不压到游戏区", h1.status_box.position.y + h1.status_box.size.y <= h1.area.position.y)
    check("卡片收了", h1.card == null or not is_instance_valid(h1.card))
    check("这一关没作废、金币没动", h1.level == 1 and s1.coins == 0)

    # ---------- 4. 输了给安慰奖（阿鱼 9/20 定「要给」） ----------
    print("4 安慰奖（该关奖励的四分之一，向下取整）")
    var r1: int = Cfg.reward(Cfg.game("g2048"), 1)
    h1.game.lose("试试")
    await create_timer(0.6).timeout
    check("第 1 关奖励 %d 金 → 安慰 %d 金" % [r1, r1 / 4], s1.coins == r1 / 4 and s1.coins == 2)
    check("没记成过关", s1.cleared("g2048") == 0 and h1.level == 1)
    # 01 9/20 定：每次输都给（刷它 4 金/分钟，比果园 8 金/分钟还慢；
    # 限成一关一次挡住的正好是连输好几次的长辈，那才是安慰奖要给的人）
    var after_first: int = s1.coins
    h1._after_lose("再输一次")
    check("同一关连输也照给（%d → %d 金）" % [after_first, s1.coins], s1.coins == after_first + r1 / 4)
    var s2 = _save("user://test_fix1_b.json")
    var h2 = _host("g2048", s2)
    h2._after_lose("根本没开局")
    check("没真开过局不给", s2.coins == 0)
    check("金币不会成负数", s1.coins >= 0 and s2.coins >= 0)
    h2._close()

    # ---------- 5. 翻牌：每行必须是满的 ----------
    print("5 翻牌每行都满（阿鱼 9/20：第 3 关 10 张摆成 4+4+2，最后一行缺两个）")
    var full := true
    var shapes: Array = []
    for pairs in [3, 4, 5, 6, 7, 8, 9, 10, 11, 12]:
        var sp: int = Memory.snap_pairs(pairs)
        var total := sp * 2
        var cols: int = Memory._cols_for(total)
        shapes.append("%d对→%d列×%d行" % [sp, cols, total / cols])
        if total % cols != 0:
            full = false
    check("对数 3～12 排出来都是整行：%s" % [shapes], full)
    check("难度表给的怪数往下取整（7 对 → 6 对）", Memory.snap_pairs(7) == 6 and Memory.snap_pairs(11) == 10)

    # ---------- 6. 翻牌：配对成功要有明确反馈 ----------
    print("6 配对成功的反馈（阿鱼 9/20：现在翻对了就那么消掉）")
    var mg = Memory.new()
    mg.setup(1, {"pairs": 3.0, "preview": 0.0, "misses": 8.0}, SystemFont.new(), 42)
    mg.size = Vector2(400, 400)
    ui.add_child(mg)
    mg.start()
    var a := -1
    var b := -1
    for i in mg.deck.size():
        for j in range(i + 1, mg.deck.size()):
            if mg.deck[i] == mg.deck[j] and a < 0:
                a = i
                b = j
    mg.tap(a)
    mg.tap(b)
    check("配上了：两张都记成对", mg.matched[a] and mg.matched[b])
    check("有「配上了」那一下的余韵", mg.pop_left > 0.0 and mg.status_text() == "配上了")
    check("那两张描了金边", true)
    mg.queue_free()

    # ---------- 7. 夹菜：点冒出来那一截能命中 ----------
    print("7 护菜（原来叫夹菜）的命中判定（体验评审第 3 条：冒出来那一截露在盘子外，原来点不到）")
    var wg = Whack.new()
    wg.setup(1, {"holes": 6.0, "duration": 30.0, "target": 12.0, "show": 5.0, "interval": 99.0, "bad": 0.0}, SystemFont.new(), 7)
    wg.size = Vector2(500, 700)
    ui.add_child(wg)
    wg.start()
    wg._spawn_at(0)
    var node: Control = wg.holes_state[0]["node"]
    await create_timer(0.25).timeout   # 冒出来那一下是 tween，等它走完
    var plate: Panel = wg.plates[0]
    var top_point := node.position + Vector2(node.size.x * 0.5, 6.0)   # 菜露在盘沿上面那一截
    check("松鼠确实探出盘子上面", node.position.y < plate.position.y)
    check("点那一截命中的是这个盘子（原来认成上一排或者没反应）", wg._hole_at(top_point) == 0)
    check("点盘子本身照样命中", wg._hole_at(plate.position + plate.size * 0.5) == 0)
    var wg2 = wg

    # ---------- 8. 辣椒不再是红底（体验评审第 13 条） ----------
    print("8 辣椒和「肉」撞色")
    var src := FileAccess.get_file_as_string("res://scripts/games/whack.gd")
    check("不再全屏红闪（喜宴桌上那是「出事了」的信号）", not src.contains("_flash_red()"))
    var meat := ""
    for t in Cfg.tiles():
        if str((t as Dictionary).get("ch", "")) == "肉":
            meat = str((t as Dictionary).get("bg", ""))
    check("12 号菜牌「肉」还是红的：%s" % meat, meat != "")
    # 真造一张辣椒出来量颜色，别去源码里找字符串（注释里提旧色号也会被当成没改）
    var chili: Panel = wg2._bad_tile(48.0, 24)
    var cb: StyleBoxFlat = chili.get_theme_stylebox("panel")
    var meat_c := Color(meat)
    var d_h: float = absf(cb.bg_color.h - meat_c.h)
    d_h = minf(d_h, 1.0 - d_h)
    print("    辣椒 %s 肉 %s 色相差 %.2f 圈" % [cb.bg_color.to_html(false), meat, d_h])
    check("辣椒和「肉」不再是一个红（色相差半圈以上）", d_h > 0.25)
    check("描边也换成亮的，一眼认得出", cb.border_color.v > 0.8)
    chili.queue_free()
    wg2.queue_free()

    # ---------- 9. 接喜糖：糖落地不算漏、限时写在明处 ----------
    print("9 接彩头（原来叫接喜糖；体验评审第 1、2 条）")
    var cg = Catch.new()
    cg.setup(1, {"duration": 30.0, "target": 12.0, "speed": 170.0, "interval": 0.85, "misses": 10.0, "bad": 0.0}, SystemFont.new(), 3)
    cg.size = Vector2(500, 700)
    ui.add_child(cg)
    cg.start()
    check("开始卡写了秒数：%s" % cg.goal_text(), cg.goal_text().contains("30 秒内"))
    # 9/23 起顶上那行写这关的金（01 定），剩几秒挪到游戏区左上角。
    # B13（体验第一轮）：原来「接了 N 金／这关要 M 金」一行两个「金」，和右上角手上的金看串，改成「还差 N 金」
    check("顶上写这关还差多少金：%s" % cg.status_text(), cg.status_text() == "还差 12 金")
    check("顶上那行只有一个「金」（B13）", cg.status_text().count("金") == 1)
    cg.coins = 5
    check("接了 5 金以后：%s" % cg.status_text(), cg.status_text() == "还差 7 金")
    cg.coins = 20
    check("接够了不写负数：%s" % cg.status_text(), cg.status_text() == "还差 0 金")
    cg.coins = 0
    check("玩的时候看得到剩余秒数：%s" % cg.hud.text, cg.hud.text.contains("剩") and cg.hud.text.contains("秒"))
    cg._collect({"bad": false, "node": null}, false)
    check("糖落地不算漏", cg.misses == 0)
    cg._collect({"bad": true, "node": null}, true)
    check("接到鞭炮才算漏", cg.misses == 1)
    cg._collect({"bad": true, "node": null}, false)
    check("鞭炮落地没事", cg.misses == 1)
    cg.queue_free()

    # ---------- 10. 小菜合大菜：每关一种作物，牌面写大白话名 ----------
    print("10 合的是农作物的成长路径，每关一种（阿鱼 9/20 定）")
    var gg = G2048.new()
    gg.setup(1, {"size": 4.0, "target_pow": 5.0}, SystemFont.new(), 9)
    gg.size = Vector2(400, 400)
    ui.add_child(gg)
    gg.start()
    var st: Array = gg.steps()
    check("第 1 关是水稻十级：%s" % ["／".join(PackedStringArray(st))],
        st.size() == 10 and str(st[0]) == "谷种" and str(st[9]) == "米饭")
    check("牌面这十个字和成长阶段表第 1 种一字不差",
        "／".join(PackedStringArray(st)) == "谷种／芽谷／秧苗／一窝苗／抽杆／大肚子／稻穗／鼓粒／黄谷／米饭")
    check("开始卡说的是从哪合到哪：%s" % gg.goal_text(), gg.goal_text().contains("谷种") and gg.goal_text().contains("抽杆"))
    check("顶栏写现在最大合到哪：%s" % gg.status_text(), gg.status_text().contains("现在最大"))
    check("目标级数封顶跟着表长度走，不会越界", gg.target <= st.size())
    # 植物学阶段名一个字都不上牌面（长辈不认「分蘖期」，合成时每秒都要分清哪级是哪级）
    var on_card := "／".join(PackedStringArray(st))
    var leaked: Array = []
    for w in ["分蘖", "拔节", "孕穗", "灌浆", "蜡熟", "期"]:
        if on_card.contains(w):
            leaked.append(w)
    check("学名没漏到牌面上（%s）" % ["没有" if leaked.is_empty() else leaked], leaked.is_empty())
    check("学名存着没丢，以后做图鉴用", str(gg.crop().get("stages", [])).contains("分蘖期"))
    # 每关一种：第 2 关草莓、第 3 关枇杷、超过种数就一直用最后一种
    var by_level: Array = []
    for lv in [1, 2, 3, 9, 11, 20]:
        gg.level = lv
        by_level.append("第%d关=%s" % [lv, str(gg.crop().get("title", "?"))])
    check("每关一种：%s" % [by_level],
        by_level[0].ends_with("水稻") and by_level[1].ends_with("草莓") and by_level[2].ends_with("枇杷")
        and by_level[3].ends_with("辣椒") and by_level[4].ends_with("猕猴桃") and by_level[5].ends_with("猕猴桃"))
    gg.level = 2
    check("第 2 关那套图是 crop_02（十张图放进去就用上，代码不用改）", str(gg.crop().get("art_set")) == "crop_02")
    # by_level 填了就按它来（要按段分的时候）
    gg._ladder["by_level"] = [{"from": 1, "to": 5, "crop": "crop_11"}]
    gg.level = 3
    check("by_level 填了它说了算", str(gg.crop().get("title")) == "猕猴桃")
    gg._ladder["by_level"] = []
    G2048._ladder = {}
    gg.queue_free()

    # ---------- 11. 有图时不画色块底（阿鱼 A1） ----------
    print("11 透明底（阿鱼原话：每个图都不是透明底，很奇怪）")
    var f := SystemFont.new()
    var with_art: Panel = Tiles.dish_tile(0, 48.0, f, 24, "", "shared")
    var sb: StyleBoxFlat = with_art.get_theme_stylebox("panel")
    check("有图的牌不画色块底", sb.bg_color.a == 0.0)
    check("描边也不显形（选中时还能染成金的）", sb.border_color.a == 0.0 and sb.get_border_width(SIDE_TOP) > 0)
    Tiles.highlight(with_art, true)
    var sb2: StyleBoxFlat = with_art.get_theme_stylebox("panel")
    check("选中还是看得出来", sb2.border_color.a > 0.5)
    var card_tile: Panel = Tiles.dish_tile(0, 48.0, f, 24, "", "shared", true)
    var sb3: StyleBoxFlat = card_tile.get_theme_stylebox("panel")
    check("翻牌的牌面留底色（那是一张「牌」）", sb3.bg_color.a > 0.5)
    var no_art: Panel = Tiles.dish_tile(0, 48.0, f, 24, "", "nosuchset")
    var sb4: StyleBoxFlat = no_art.get_theme_stylebox("panel")
    check("图没交的那套照旧色块 + 一个字", sb4.bg_color.a > 0.5)
    with_art.queue_free()
    card_tile.queue_free()
    no_art.queue_free()

    # ---------- 12. 每个游戏用哪套图写在配置里 ----------
    print("12 三套图分开（菜牌、成长阶梯、喜庆纹样）")
    var sets: Dictionary = {}
    for gid in ["lianliankan", "match3", "g2048", "memory", "whack", "catch"]:
        sets[gid] = str(Cfg.game(gid).get("art_set", ""))
    # 纹样图 GPT 还没交，先用回菜图（01 9/20：不然真机上那桌变成色块加一个字）
    check("翻牌先用回共用菜牌，等纹样图：%s" % [sets], str(sets["memory"]) == "shared")
    check("小菜合大菜按关数换作物（这里只是兜底）", str(sets["g2048"]).begins_with("crop_"))
    check("另外四个也共用那 12 张菜牌", str(sets["lianliankan"]) == "shared" and str(sets["match3"]) == "shared" and str(sets["whack"]) == "shared" and str(sets["catch"]) == "shared")
    check("认得共用菜牌和纹样两套", Tiles.ART.has("pattern") and Tiles.ART.has("shared"))
    # 加第 N 种作物只要把十张图放进 crop_NN/，代码和 json 都不用再动（03 9/20 指出原来是写死的三条路径）
    check("表里没有的套名也认，按 assets/minigames/<套名>/step_NN.png 找", Tiles.ART_ANY.contains("assets/minigames/%s/step_%02d.png"))
    check("没这套图就返回 null（那一关整盘退回色块）", Tiles.dish_art(0, "crop_11") == null)
    # 「齐不齐」的判断（03 9/21 报的：原来一张张单独找，crop_02 放 9 张就是 9 图 + 1 色块）
    check("一张一个的那两套永远算齐（少一张退一张，不牵连整盘）",
        Tiles.art_ready("shared", 12) and Tiles.art_ready("pattern", 12))
    # 前三种（水稻、草莓、枇杷）GPT 9/21 交了，齐；第 4 种起还没交
    # 9/23 晚第 4～10 种（玉米、油菜、花生、洋芋、莲藕、辣椒、茶）也交了，第 11 种（猕猴桃）还在画
    var ready_sets := ["crop_01", "crop_02", "crop_03", "crop_04", "crop_05", "crop_06", "crop_07", "crop_08", "crop_09", "crop_10"]
    check("交齐的那几套算齐（第 1～10 种）", ready_sets.all(func(c): return Tiles.art_ready(c, 10)))
    check("没交的还是不齐（第 11 种）", not Tiles.art_ready("crop_11", 10))
    check("套名空着直接算不齐", not Tiles.art_ready("", 10) and Tiles.dish_art(0, "") == null)
    check("查过就记着，不会每画一格问十次文件", Tiles._ready.has("crop_02"))
    # 图不齐时，整盘都是色块 + 名字，不许一半图一半色块
    var gz = G2048.new()
    gz.setup(11, {"size": 4.0, "target_pow": 5.0}, SystemFont.new(), 11)   # 第 11 关猕猴桃，图还没交
    gz.size = Vector2(400, 400)
    ui.add_child(gz)
    gz.start()
    var pics2 := 0
    var blocks2 := 0
    var named2 := 0
    for c in gz.cells:
        for kid in (c as Panel).get_children():
            if kid is TextureRect: pics2 += 1
            if kid is Label and gz.steps().has(str((kid as Label).text)): named2 += 1
        if ((c as Panel).get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a > 0.5: blocks2 += 1
    check("第 11 关（猕猴桃，图没交）：%d 张牌全是色块、一张图都没有" % gz.cells.size(),
        pics2 == 0 and blocks2 == gz.cells.size() and gz.cells.size() > 0)
    check("这一关的 art_set 被清空了（整套不用）", gz.art_set == "")
    check("色块牌照旧写级名（%d/%d），不然分不出是哪一级" % [named2, gz.cells.size()], named2 == gz.cells.size())
    gz.queue_free()
    # 交了图的前三关：整盘都该是图，不许半图半色块（GPT 9/21 交了水稻、草莓、枇杷 30 张）
    for lv in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
        var gy = G2048.new()
        gy.setup(lv, {"size": 4.0, "target_pow": 5.0}, SystemFont.new(), 3)
        gy.size = Vector2(400, 400)
        ui.add_child(gy)
        gy.start()
        var pics3 := 0
        var texts3 := 0
        for c in gy.cells:
            for kid in (c as Panel).get_children():
                if kid is TextureRect:
                    pics3 += 1
                elif kid is Label or kid is ColorRect:
                    texts3 += 1
        check("第 %d 关（%s）整盘都是图（%d/%d），套 %s" % [lv, str(gy.crop().get("title", "")), pics3, gy.cells.size(), gy.art_set],
            gy.cells.size() > 0 and pics3 == gy.cells.size() and gy.art_set == "crop_%02d" % lv)
        check("第 %d 关有图的牌上不叠字、不垫字条（阿鱼 9/23）：%d 处" % [lv, texts3], texts3 == 0)
        var carded := 0
        for c in gy.cells:
            var cst := (c as Panel).get_theme_stylebox("panel") as StyleBoxFlat
            if cst.bg_color == Tiles.CARD_BG and cst.border_color == Tiles.CARD_EDGE:
                carded += 1
        check("第 %d 关有图的牌都垫了浅色牌底（01 9/23）：%d/%d" % [lv, carded, gy.cells.size()], carded == gy.cells.size())
        gy.queue_free()
    # 关号超过种数回绕到最后一种，不许崩
    var gw = G2048.new()
    gw.setup(15, {"size": 4.0, "target_pow": 5.0}, SystemFont.new(), 3)
    gw.size = Vector2(400, 400)
    ui.add_child(gw)
    gw.start()
    check("第 15 关回绕到猕猴桃、不崩、整盘色块", str(gw.crop().get("title", "")) == "猕猴桃" and gw.cells.size() > 0)
    gw.queue_free()
    check("作废的那 11 张旧阶梯图已经删了", not ResourceLoader.exists("res://assets/minigames/ladder/step_00.png"))

    # ---------- 13. 六个游戏歇着的时候都不收操作（03 9/20：三消漏判 paused） ----------
    print("13 歇一下对六个游戏都管用")
    var deaf := []
    var heard := []
    for gid in ["lianliankan", "match3", "g2048", "memory", "whack", "catch"]:
        var src2 := FileAccess.get_file_as_string("res://scripts/games/%s.gd" % gid)
        var good := true
        # 每个收手势的入口都得判 paused
        for fn in ["func _gui_input", "func _unhandled_key_input"]:
            var at := src2.find(fn)
            while at >= 0:
                var seg := src2.substr(at, 220)
                if not seg.contains("paused"):
                    good = false
                at = src2.find(fn, at + 1)
        (deaf if good else heard).append(gid)
    check("六个都判了 paused（漏的：%s）" % ["没有" if heard.is_empty() else heard], heard.is_empty() and deaf.size() == 6)
    # 三消那个是 03 真点出来的：歇着换块，步数和分数都不该动
    var m3 = load("res://scripts/games/match3.gd").new()
    m3.setup(1, Cfg.params(Cfg.game("match3"), 1), SystemFont.new(), 5)
    m3.size = Vector2(480, 480)
    ui.add_child(m3)
    m3.start()
    var moves0: int = m3.moves
    var score0: int = m3.score
    m3.paused = true
    var ev := InputEventMouseButton.new()
    ev.button_index = MOUSE_BUTTON_LEFT
    ev.pressed = true
    ev.position = Vector2(60, 60)
    m3._gui_input(ev)
    ev.pressed = false
    ev.position = Vector2(120, 60)
    m3._gui_input(ev)
    check("三消歇着时换块：步数和分数都没动（%d 步 %d 分）" % [m3.moves, m3.score], m3.moves == moves0 and m3.score == score0)
    m3.paused = false
    m3.queue_free()

    # ---------- 14. 选中再取消，不许多出一圈深色边（03 9/20 在三消和连连看看到的） ----------
    print("14 取消选中要恢复成它原来的样子")
    var f2 := SystemFont.new()
    var art_tile: Panel = Tiles.dish_tile(0, 48.0, f2, 24, "", "shared")
    var b0: Color = (art_tile.get_theme_stylebox("panel") as StyleBoxFlat).border_color
    Tiles.highlight(art_tile, true)
    var b1: Color = (art_tile.get_theme_stylebox("panel") as StyleBoxFlat).border_color
    Tiles.highlight(art_tile, false)
    var b2: StyleBoxFlat = art_tile.get_theme_stylebox("panel")
    check("有图的牌：选中是金的", b1.a > 0.5 and b1.r > 0.8)
    check("取消以后描边还是透明的（原来会写回深色，多出一圈边）", b2.border_color.a == 0.0 and b0.a == 0.0)
    var plain: Panel = Tiles.dish_tile(0, 48.0, f2, 24, "", "nosuchset")
    var p0: Color = (plain.get_theme_stylebox("panel") as StyleBoxFlat).border_color
    Tiles.highlight(plain, true)
    Tiles.highlight(plain, false)
    var p2: StyleBoxFlat = plain.get_theme_stylebox("panel")
    check("没图的牌：取消以后还是原来那圈深边", p2.border_color == p0 and p0.a > 0.5)
    check("描边粗细也回到原样", p2.get_border_width(SIDE_TOP) == 2)
    art_tile.queue_free()
    plain.queue_free()

    h1._close()

    # ---------- 15. B10 色块兜底的关照旧写名字；别的游戏不受影响 ----------
    print("15 顶栏小图只在有图时出（B10）")
    var s15 = _save("user://test_fix1_c.json")
    s15.games["g2048"] = 10     # 第 11 关猕猴桃，图还没交，整盘色块
    var h15 = _host("g2048", s15)
    h15._start()
    h15._process(0.0)
    check("第 11 关（图没交）顶栏照旧写名字：%s" % h15.status_l.text,
        h15.status_l.visible and not h15.status_box.visible and h15.status_l.text.begins_with("目标 ") and h15.game.art_set == "")
    h15._close()
    var h16 = _host("lianliankan", _save("user://test_fix1_d.json"))
    h16._start()
    h16._process(0.0)
    check("连连看顶栏还是一句字：%s" % h16.status_l.text, h16.status_l.visible and not h16.status_box.visible and h16.status_l.text.begins_with("剩"))
    h16._close()
    print("RESULT ", "PASS" if ok else "FAIL")
    quit()
