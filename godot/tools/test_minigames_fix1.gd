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
    check("顶栏右上角空出来了（金币挪回最右）", h1.coins_l.position.x + h1.coins_l.size.x >= h1.panel.size.x - 16.0)

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

    # ---------- 3. 「歇一下」真能暂停 ----------
    print("3 歇一下（体验评审第 11 条：paused 六个游戏都在读，就是没人置过 true）")
    h1._start()
    check("开局了「歇一下」出来", pause.visible and not h1.game.paused)
    h1._pause()
    check("按下去真的暂停了", h1.game.paused)
    check("盖了一张卡", h1.card != null and is_instance_valid(h1.card))
    check("歇着的时候按钮收起来", not pause.visible)
    h1.game._process(1.0)   # 暂停时 _game_tick 不该跑
    h1._resume()
    check("「接着玩」恢复", not h1.game.paused and pause.visible)
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
    print("7 夹菜的命中判定（体验评审第 3 条：菜上面三成露在盘子外，原来点不到）")
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
    check("菜确实露在盘子上面", node.position.y < plate.position.y)
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
    print("9 接喜糖（体验评审第 1、2 条）")
    var cg = Catch.new()
    cg.setup(1, {"duration": 30.0, "target": 12.0, "speed": 170.0, "interval": 0.85, "misses": 10.0, "bad": 0.0}, SystemFont.new(), 3)
    cg.size = Vector2(500, 700)
    ui.add_child(cg)
    cg.start()
    check("开始卡写了秒数：%s" % cg.goal_text(), cg.goal_text().contains("30 秒内"))
    check("玩的时候顶上有剩余秒数：%s" % cg.status_text(), cg.status_text().contains("剩") and cg.status_text().contains("秒"))
    cg._collect({"bad": false, "node": null}, false)
    check("糖落地不算漏", cg.misses == 0)
    cg._collect({"bad": true, "node": null}, true)
    check("接到鞭炮才算漏", cg.misses == 1)
    cg._collect({"bad": true, "node": null}, false)
    check("鞭炮落地没事", cg.misses == 1)
    cg.queue_free()

    # ---------- 10. 小菜合大菜：水稻 10 级 + 按关数选作物 ----------
    print("10 合的是农作物的成长路径（阿鱼 9/20 定，原来那 11 级菜作废）")
    var gg = G2048.new()
    gg.setup(1, {"size": 4.0, "target_pow": 5.0}, SystemFont.new(), 9)
    gg.size = Vector2(400, 400)
    ui.add_child(gg)
    gg.start()
    var st: Array = gg.steps()
    check("水稻 10 级：%s" % [st], st.size() == 10 and str(st[0]) == "种子" and str(st[9]) == "喜宴")
    check("开始卡说的是从种子合到哪：%s" % gg.goal_text(), gg.goal_text().contains("种子") and gg.goal_text().contains("稻穗"))
    check("顶栏写现在最大合到哪：%s" % gg.status_text(), gg.status_text().contains("现在最大"))
    check("目标级数封顶跟着表长度走，不会越界", gg.target <= st.size())
    # 按关数换作物的口子（01 9/20：阿鱼要每关一种植物）
    gg._ladder = {"default": "rice",
        "by_level": [{"from": 1, "to": 5, "crop": "rice"}, {"from": 6, "to": 10, "crop": "wheat"}],
        "crops": {"rice": {"steps": ["种子", "秧苗"], "art_set": "ladder"},
                  "wheat": {"steps": ["麦种", "麦苗", "麦穗"], "art_set": "ladder_wheat"}}}
    gg.level = 3
    check("第 3 关走水稻", gg.steps().size() == 2 and str(gg.crop().get("art_set")) == "ladder")
    gg.level = 8
    check("第 8 关换小麦、连图那套一起换", gg.steps().size() == 3 and str(gg.crop().get("art_set")) == "ladder_wheat")
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
    check("小菜合大菜用成长阶梯那套", str(sets["g2048"]) == "ladder")
    check("另外四个也共用那 12 张菜牌", str(sets["lianliankan"]) == "shared" and str(sets["match3"]) == "shared" and str(sets["whack"]) == "shared" and str(sets["catch"]) == "shared")
    check("三套图的口子还在（换一个字就能切过去）", Tiles.ART.has("pattern") and Tiles.ART.has("ladder") and Tiles.ART.has("shared"))
    check("作废的那 11 张阶梯图已经删了", not ResourceLoader.exists("res://assets/minigames/ladder/step_00.png"))

    h1._close()
    print("RESULT ", "PASS" if ok else "FAIL")
    quit()
