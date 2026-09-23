extends "res://scripts/games/mini_game.gd"
## 接彩头（接物，T11/T12，蓝图 3.2；原来叫「接喜糖」，阿鱼起的新名）。
## 玩家抱着一个大红篮子在底下左右跑，天上撒下四种喜糖、小红包、大红包，接到的**直接就是金币**；
## 攒够这一关要的数马上过关，接到的全拿走。夹着鞭炮，接到鞭炮算一次失误，失误满了就输（糖掉地上不算）。
## 说明：`回执/接彩头和护菜-玩法改.md` 第一节（01 9/23 定，金币数是起步值，03 模拟以后调）
##
## 难度参数（minigames.json）：duration 时限（秒）、target 这关要接够多少金、speed 下落像素/秒、
## interval 隔多久掉一个、misses 接到第几个鞭炮就输（01 9/23 定 3）、bad 掉下来的是鞭炮的比例。
## 掉下来的六样有赏的东西各给几金、出现多少，写在同一个游戏的 drops 里；吉利话写在 sayings 里
##
## 图：assets/minigames/catch/ 下那 12 张（出图清单第 2 批，02 接图时去掉 prop_/chr_ 前缀和 _v1），
## 外加 catch.json 里 GPT 交接单给的篮口那条线。**一张不齐就整套用代码画的占位**（跟作物图一个规矩）
## 逻辑（下落、判定）和画面分开，都在 _game_tick 里：测试直接推时间、直接改 basket_x，不用真拖

const Cfg = preload("res://scripts/games/game_config.gd")
const ART_DIR := "res://assets/minigames/catch/"
const ART_FILES := ["player", "player_left", "player_right", "candy_a", "candy_b", "candy_c", "candy_d",
    "hongbao_s", "hongbao_l", "firecracker", "hit", "bg"]
const ART_CFG := ART_DIR + "catch.json"
const DROP_PX := 44.0          # 掉下来那一样在屏上多大（图是 128，缩着放）
const PLAYER_H := 128.0        # 抱篮子的人在屏上多高（图是 128×160）
const FACE_HOLD := 0.25        # 停下来多久转回正面
const GROUND_H := 22.0         # 地面（占位那条红毯）多高；没接住的东西落到它上沿就收掉（B14）
## 占位糖放大几倍（B12，体验第一轮：原来 1.35，四种糖看着只是颜色不一样的小圆点）
const DROP_SCALE := 1.6
## 占位的每一样从中心往下画到多深（44 见方里的像素，没乘 DROP_SCALE）：落地时按它的底边算，
## 不然小糖离地还有一截就没了、大红包沉进红毯一截（B14）
const DROP_BOTTOM := {"candy_a": 9.0, "candy_b": 10.0, "candy_c": 21.0, "candy_d": 17.0,
    "hongbao_s": 15.0, "hongbao_l": 20.0, "firecracker": 17.0}
## drops 没写时的兜底（和 minigames.json 里的一样）
const DEFAULT_DROPS := [
    {"id": "candy_a", "coins": 1, "weight": 40},
    {"id": "candy_b", "coins": 2, "weight": 25},
    {"id": "candy_c", "coins": 3, "weight": 15},
    {"id": "candy_d", "coins": 4, "weight": 10},
    {"id": "hongbao_s", "coins": 5, "weight": 7},
    {"id": "hongbao_l", "coins": 10, "weight": 3},
]
const INK := Color("#2c1f1c")

var duration := 30.0
var target := 10
var speed := 130.0
var interval := 2.3
var misses_max := 6
var bad_ratio := 0.0
var drop_table: Array = []    # [{id, coins, weight}]
var sayings: Array = []

var time_left := 0.0
var coins := 0                # 这一局接到的金（攒够 target 过关，全拿走）
var caught := 0               # 接到几样有赏的（模拟和测试用）
var misses := 0
var spawn_timer := 0.0
var drops: Array = []         # 每样 {x, y, bad, kind, coins, node}

var basket: Control           # 抱篮子的那个人（名字沿用原来的篮子）
var basket_w := 100.0         # 篮口多宽（判定用）
var basket_h := 40.0
var basket_x := 0.0           # 篮口中心 x（逻辑位置，测试可以直接改）
var basket_y := 0.0           # 篮口那条线的 y
var dragging := false
var facing := 0               # -1 往左、0 正面、1 往右
var face_timer := 0.0
var last_x := 0.0
var mouth := Rect2()          # 篮口在人那张图里的位置（x、y、宽；高不用）
var player_scale := 1.0
var art := {}                 # 名字 -> Texture2D；空的就是用占位
var saying_l: Label
var hud: Label
var last_saying := -1

## 开始卡：外壳造的「探子」只 setup 没 _build，所以只读参数
func goal_text() -> String:
    # 卡片是按字硬折行的，自己断好行，别让逗号跑到行首（01 9/23）；一行不超过 16 个字
    # B12（体验第一轮）加过一行说四种糖、两种红包给的不一样多，整张卡涨到七行（04 复看第 43 版 新 6）：
    # 照 04 给的那句合并成两行，连 json 的 goal、「第 N 关」一共五行（新写，等阿鱼定）
    return "%d 秒内接够 %d 金\n喜糖、红包都是钱，给的金币不一样\n鞭炮别接，接到 %d 个就输" % [
        int(p_float("duration", 30.0)), p_int("target", 10), p_int("misses", 3)]

## 顶上那行：这关还差几金（B13，体验第一轮）。原来写「接了 N 金／这关要 M 金」，和右上角手上的「N 金」
## 一行里三个「金」，容易看串；改成只说还差多少。剩几秒、失误几次在游戏区左上角
func status_text() -> String:
    return "还差 %d 金" % maxi(p_int("target", 10) - coins, 0)

## 过关给多少：接到的全拿走（外壳读这个，不读奖励表）
func won_coins() -> int:
    return coins

## 过关结算卡上多说的一句
func win_lines() -> Array:
    var s := _pick_saying()
    return [s] if s != "" else []

func _build() -> void:
    duration = p_float("duration", 30.0)
    target = maxi(p_int("target", 10), 1)
    speed = maxf(p_float("speed", 130.0), 10.0)
    interval = maxf(p_float("interval", 2.3), 0.1)
    misses_max = maxi(p_int("misses", 3), 1)
    bad_ratio = clampf(p_float("bad", 0.0), 0.0, 1.0)
    _load_tables()
    time_left = duration
    coins = 0
    caught = 0
    misses = 0
    spawn_timer = interval * 0.6   # 开局别让人干等一整个间隔
    drops.clear()
    for c in get_children():
        c.queue_free()
    art = _load_art()

    if art.has("bg"):
        var bg := TextureRect.new()
        bg.texture = art["bg"]
        bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(bg)
    else:
        # 占位：底下一条红毯当地面
        var ground := ColorRect.new()
        ground.color = Color("#6e1f22")
        ground.position = Vector2(0, size.y - GROUND_H)
        ground.size = Vector2(size.x, GROUND_H)
        ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(ground)

    basket = _make_player()
    add_child(basket)
    basket_x = size.x * 0.5
    last_x = basket_x
    facing = 0
    _layout_basket()

    hud = Tiles.label("", font, 24, Color("#efe6d8"))
    hud.position = Vector2(8, 4)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(hud)
    _sync_hud()

    saying_l = Tiles.label("", font, 24, Color("#ffe08a"))
    saying_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    saying_l.size = Vector2(size.x, 30)
    saying_l.modulate.a = 0.0
    saying_l.z_index = 5
    saying_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(saying_l)

func _load_tables() -> void:
    var g := Cfg.game("catch")
    drop_table = []
    for d in g.get("drops", DEFAULT_DROPS):
        if d is Dictionary and float((d as Dictionary).get("weight", 0)) > 0.0:
            drop_table.append(d)
    if drop_table.is_empty():
        drop_table = DEFAULT_DROPS.duplicate(true)
    sayings = g.get("sayings", [])

## 12 张图 + 篮口那条线都在才用图；缺一样就整套占位（半图半占位比全占位更难看）
func _load_art() -> Dictionary:
    var out := {}
    for f in ART_FILES:
        var path: String = ART_DIR + f + ".png"
        if not ResourceLoader.exists(path):
            return {}
        out[f] = load(path)
    if not FileAccess.file_exists(ART_CFG):
        return {}
    var j = JSON.parse_string(FileAccess.get_file_as_string(ART_CFG))
    if not (j is Dictionary) or not (j as Dictionary).has("basket_line"):
        return {}
    var bl: Dictionary = j["basket_line"]
    var l: Array = bl.get("left", [])
    var r: Array = bl.get("right", [])
    if l.size() < 2 or r.size() < 2:
        return {}
    out["_mouth"] = Rect2(float(l[0]), float(l[1]), float(r[0]) - float(l[0]), 0.0)
    return out

## 抱篮子的人。图到了用图（正面、向左、向右三张），没到用代码画的占位
func _make_player() -> Control:
    var root := Control.new()
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.z_index = 2
    if art.has("player"):
        var tex: Texture2D = art["player"]
        player_scale = PLAYER_H / float(tex.get_height())
        root.size = Vector2(tex.get_width(), tex.get_height()) * player_scale
        var tr := TextureRect.new()
        tr.name = "pic"
        tr.texture = tex
        tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tr.stretch_mode = TextureRect.STRETCH_SCALE
        tr.size = root.size
        tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(tr)
        var m: Rect2 = art["_mouth"]
        mouth = Rect2(m.position * player_scale, m.size * player_scale)
    else:
        player_scale = 1.0
        root.size = Vector2(104, PLAYER_H)
        # 篮子是人胸前抱着的那只大红篮子，篮口在 y 70 那条线
        mouth = Rect2(8, 70, 88, 0)
        root.draw.connect(_draw_player.bind(root))
    basket_w = maxf(mouth.size.x, 40.0)
    basket_h = 40.0
    basket_y = size.y - root.size.y - 6.0 + mouth.position.y
    return root

## 占位的人：头、头发、身子、两条胳膊抱着一只大红篮子。朝向靠脸（眼睛）偏哪边、身子歪哪边
func _draw_player(n: Control) -> void:
    var cx := n.size.x * 0.5
    var lean := float(facing) * 6.0
    # 腿
    n.draw_rect(Rect2(cx - 16 + lean * 0.3, 104, 12, 22), Color("#3b2a2a"))
    n.draw_rect(Rect2(cx + 4 + lean * 0.3, 104, 12, 22), Color("#3b2a2a"))
    # 身子（喜庆的酒红衣服）
    n.draw_rect(Rect2(cx - 22 + lean * 0.5, 44, 44, 64), Color("#9c2a2e"))
    n.draw_rect(Rect2(cx - 22 + lean * 0.5, 44, 44, 64), INK, false, 2.0)
    # 两条胳膊（B16，体验第一轮）：原来只有两只手搭在篮沿上，和身子不连，像两块浮着的肉色方块。
    # 从肩膀斜着伸到篮沿上那两只手，袖子和衣服一个色、描深边；篮子后画，盖住胳膊下半截
    var top0 := mouth.position.y
    for side in [-1.0, 1.0]:
        var shoulder := Vector2(cx + side * 18.0 + lean * 0.5, 52)
        var hand := Vector2((mouth.position.x + 5.0) if side < 0.0 else (mouth.end.x - 5.0), top0)
        n.draw_line(shoulder, hand, INK, 11.0)
        n.draw_line(shoulder, hand, Color("#9c2a2e"), 8.0)
    # 头：先画一团头发（往后脑勺那边偏），再画脸（往跑的方向偏），朝向一眼看得出
    var hc := Vector2(cx + lean, 26)
    n.draw_circle(hc + Vector2(-float(facing) * 4.0, -4), 19, Color("#2a1d1a"))
    n.draw_circle(hc + Vector2(float(facing) * 3.0, 3), 15, Color("#f2c9a0"))
    n.draw_arc(hc + Vector2(float(facing) * 3.0, 3), 15, 0, TAU, 28, INK, 2.0)
    # 眼睛：往哪边跑就看哪边
    var ex := float(facing) * 6.0
    n.draw_circle(hc + Vector2(-5 + ex, 5), 2.2, INK)
    n.draw_circle(hc + Vector2(5 + ex, 5), 2.2, INK)
    # 大红篮子（梯形，篮口金边），抱在胸前
    var top := mouth.position.y
    var body := PackedVector2Array([Vector2(mouth.position.x, top), Vector2(mouth.end.x, top),
        Vector2(mouth.end.x - 12, top + 34), Vector2(mouth.position.x + 12, top + 34)])
    n.draw_colored_polygon(body, Color("#d62a2a"))
    n.draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]), INK, 2.0)
    for k in 3:
        var yy := top + 10.0 + k * 9.0
        n.draw_line(Vector2(mouth.position.x + 6 + k * 3, yy), Vector2(mouth.end.x - 6 - k * 3, yy), Color("#a61d1d"), 2.0)
    n.draw_rect(Rect2(mouth.position.x - 3, top - 4, mouth.size.x + 6, 7), Color("#f2c14e"))
    n.draw_rect(Rect2(mouth.position.x - 3, top - 4, mouth.size.x + 6, 7), INK, false, 1.5)
    # 两只手搭在篮沿上（胳膊的那一头，见上面）
    for hx in [mouth.position.x + 5.0, mouth.end.x - 5.0]:
        n.draw_circle(Vector2(hx, top), 6.5, INK)
        n.draw_circle(Vector2(hx, top), 5.0, Color("#f2c9a0"))

func _layout_basket() -> void:
    if basket == null or not is_instance_valid(basket):
        return
    if basket_x < last_x - 0.5:
        _face(-1)
    elif basket_x > last_x + 0.5:
        _face(1)
    last_x = basket_x
    var mc := mouth.position.x + mouth.size.x * 0.5
    basket.position = Vector2(basket_x - mc, basket_y - mouth.position.y)

func _face(dir: int) -> void:
    face_timer = FACE_HOLD if dir != 0 else 0.0
    if facing == dir:
        return
    facing = dir
    if basket == null or not is_instance_valid(basket):
        return
    var pic := basket.get_node_or_null("pic") as TextureRect
    if pic != null:
        var key := "player" if dir == 0 else ("player_left" if dir < 0 else "player_right")
        pic.texture = art[key]
    else:
        basket.queue_redraw()

func _game_tick(dt: float) -> void:
    time_left = maxf(time_left - dt, 0.0)
    if face_timer > 0.0:
        face_timer -= dt
        if face_timer <= 0.0:
            _face(0)
    spawn_timer += dt
    if spawn_timer >= interval:
        spawn_timer = 0.0
        _spawn_drop()

    var basket_left := basket_x - basket_w * 0.5
    var basket_right := basket_x + basket_w * 0.5
    var i := drops.size() - 1
    while i >= 0 and not over:
        var d: Dictionary = drops[i]
        d["y"] += speed * dt
        var node = d.get("node")
        if node != null and is_instance_valid(node):
            node.position = Vector2(d["x"] - node.size.x * 0.5, d["y"] - node.size.y * 0.5)
        if d["y"] >= basket_y and d["x"] >= basket_left and d["x"] <= basket_right:
            _collect(d, true)
            drops.remove_at(i)
        elif d["y"] + float(d.get("bottom", DROP_PX * 0.5)) >= ground_y():
            # 没接住：底边碰到地面（红毯上沿）就收掉（B14）。原来掉到游戏区下沿再多 30 才删，
            # 会穿过红毯往下沉、露半截再消失，像坏图。「接到」的判定在上面那个分支，没动
            _collect(d, false)
            drops.remove_at(i)
        i -= 1

    if saying_l != null and saying_l.modulate.a > 0.0:
        saying_l.modulate.a = maxf(saying_l.modulate.a - dt, 0.0)
    _sync_hud()
    if not over and time_left <= 0.0 and coins < target:
        lose("时间到了，接了 %d 金" % coins)

## 地面那条线的 y（红毯上沿；正式背景图到了也按这条线，人就站在这上面）
func ground_y() -> float:
    return size.y - GROUND_H

func _sync_hud() -> void:
    if hud != null:
        hud.text = "剩 %d 秒  鞭炮 %d/%d" % [int(ceil(maxf(time_left, 0.0))), misses, misses_max]

## 按 drops 的 weight 抽一样
func _pick_kind() -> Dictionary:
    var total := 0.0
    for d in drop_table:
        total += float(d.get("weight", 0))
    var r := rng.randf() * total
    for d in drop_table:
        r -= float(d.get("weight", 0))
        if r <= 0.0:
            return d
    return drop_table[drop_table.size() - 1]

func _spawn_drop() -> void:
    var bad := rng.randf() < bad_ratio
    var kind := "firecracker"
    var worth := 0
    if not bad:
        var d := _pick_kind()
        kind = str(d.get("id", "candy_a"))
        worth = int(d.get("coins", 1))
    var node := _drop_node(kind)
    var x := rng.randf_range(DROP_PX * 0.5, maxf(size.x - DROP_PX * 0.5, DROP_PX * 0.5))
    node.position = Vector2(x - DROP_PX * 0.5, -DROP_PX)
    add_child(node)
    var bottom: float = DROP_PX * 0.5 if art.has(kind) else float(DROP_BOTTOM.get(kind, 11.0)) * DROP_SCALE
    drops.append({"x": x, "y": -DROP_PX * 0.5, "bad": bad, "kind": kind, "coins": worth, "node": node, "bottom": bottom})

func _drop_node(kind: String) -> Control:
    if art.has(kind):
        var tr := TextureRect.new()
        tr.texture = art[kind]
        tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        tr.size = Vector2(DROP_PX, DROP_PX)
        tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return tr
    var c := Control.new()
    c.size = Vector2(DROP_PX, DROP_PX)
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    c.draw.connect(_draw_drop.bind(c, kind))
    # 占位的形状画在 44 见方里偏小，放大 DROP_SCALE 倍，深色底上看得清（判定只看中心 x，不受影响）
    c.pivot_offset = c.size * 0.5
    c.scale = Vector2(DROP_SCALE, DROP_SCALE)
    return c

## 占位的七样：**靠形状和颜色分，不写字**（01 定）。四种糖四个形状四个颜色，红包是红底金圆，
## 鞭炮是一捆细长的红炮仗、顶上冒火星——和红包一样红，但一个是扁方块、一个是细棍子
func _draw_drop(n: Control, kind: String) -> void:
    var c := n.size * 0.5
    match kind:
        # B12（体验第一轮）：四种糖原来都缩在半径 11～15 里，屏上看是四个颜色不同的小圆点。
        # 改成**轮廓一眼不同**、个头随金数变大：小圆球 → 横着的包装糖 → 竖着的棒棒糖 → 大星星
        "candy_a":   # 1 金：粉色小圆球糖（最小）
            n.draw_circle(c, 9, Color("#f48fb1"))
            n.draw_arc(c, 9, 0, TAU, 24, INK, 2.0)
            n.draw_circle(c + Vector2(-3, -3), 2.5, Color("#fff4f8"))
        "candy_b":   # 2 金：黄色包装糖，横着宽（中间椭圆、两头拧成蝴蝶结）
            var col := Color("#ffc107")
            var left := PackedVector2Array([c + Vector2(-9, 0), c + Vector2(-21, -10), c + Vector2(-21, 10)])
            var right := PackedVector2Array([c + Vector2(9, 0), c + Vector2(21, -10), c + Vector2(21, 10)])
            n.draw_colored_polygon(left, col)
            n.draw_colored_polygon(right, col)
            n.draw_polyline(PackedVector2Array([left[0], left[1], left[2], left[0]]), INK, 1.5)
            n.draw_polyline(PackedVector2Array([right[0], right[1], right[2], right[0]]), INK, 1.5)
            var ell := PackedVector2Array()
            for i in 20:
                var a := TAU * float(i) / 20.0
                ell.append(c + Vector2(cos(a) * 11, sin(a) * 8))
            n.draw_colored_polygon(ell, col)
            ell.append(ell[0])
            n.draw_polyline(ell, INK, 2.0)
        "candy_c":   # 3 金：绿色棒棒糖，竖着高（上面一个带旋纹的圆、下面一根白棍）
            var head := c + Vector2(0, -7)
            n.draw_rect(Rect2(c.x - 2, c.y + 1, 4, 20), Color("#f5efe6"))
            n.draw_rect(Rect2(c.x - 2, c.y + 1, 4, 20), INK, false, 1.5)
            n.draw_circle(head, 13, Color("#43a047"))
            n.draw_arc(head, 13, 0, TAU, 28, INK, 2.0)
            n.draw_arc(head, 8, 0, PI * 1.5, 16, Color("#c8f5c0"), 2.0)
            n.draw_arc(head, 3.5, PI, PI * 2.5, 10, Color("#c8f5c0"), 2.0)
        "candy_d":   # 4 金：紫色大五角星糖（最大）
            var star := PackedVector2Array()
            for i in 10:
                var a := -PI * 0.5 + PI * float(i) / 5.0
                var rr := 20.0 if i % 2 == 0 else 8.5
                star.append(c + Vector2(cos(a) * rr, sin(a) * rr))
            n.draw_colored_polygon(star, Color("#b56cf0"))
            star.append(star[0])
            n.draw_polyline(star, INK, 2.0)
            n.draw_circle(c + Vector2(-3, -4), 2.5, Color("#ecd6ff"))
        "hongbao_s":  # 5 金：小红包
            var r := Rect2(c - Vector2(11, 15), Vector2(22, 30))
            n.draw_rect(r, Color("#d81b1b"))
            n.draw_rect(r, INK, false, 2.0)
            n.draw_line(r.position + Vector2(0, 9), r.position + Vector2(22, 9), Color("#8e1010"), 2.0)
            n.draw_circle(c + Vector2(0, -3), 4.5, Color("#f2c14e"))
        "hongbao_l":  # 10 金：大红包，金边
            var r := Rect2(c - Vector2(16, 20), Vector2(32, 40))
            n.draw_rect(r, Color("#d81b1b"))
            n.draw_rect(r.grow(-3), Color("#f2c14e"), false, 2.0)
            n.draw_rect(r, INK, false, 2.0)
            n.draw_line(r.position + Vector2(0, 12), r.position + Vector2(32, 12), Color("#8e1010"), 2.0)
            n.draw_circle(c + Vector2(0, -4), 7, Color("#f2c14e"))
            n.draw_arc(c + Vector2(0, -4), 7, 0, TAU, 20, INK, 1.5)
        "firecracker":  # 失误：一捆三根细炮仗，顶上引信冒火星
            for k in 3:
                var bx := c.x - 11 + k * 8
                var rr := Rect2(bx, c.y - 8 + absf(k - 1) * 3.0, 7, 22)
                n.draw_rect(rr, Color("#c62828"))
                n.draw_rect(Rect2(rr.position.x, rr.position.y + 4, 7, 2), Color("#f2c14e"))
                n.draw_rect(rr, INK, false, 1.5)
            n.draw_line(c + Vector2(0, -8), c + Vector2(4, -15), Color("#3a3a3a"), 2.0)
            var sp := c + Vector2(5, -17)
            for k in 6:
                var a := TAU * float(k) / 6.0
                n.draw_line(sp, sp + Vector2(cos(a), sin(a)) * 6.0, Color("#ffeb3b") if k % 2 == 0 else Color("#ff9800"), 2.0)
        _:
            n.draw_circle(c, 10, Color("#cccccc"))

## 一样东西落地或落进篮子：有赏的进篮加金，**掉地上不算失误**；鞭炮进篮算一次失误（人抖一下），鞭炮落地没事。
## 失误只数接到鞭炮那一种（第 37 版起的规矩，体验评审第 1 条）
func _collect(d: Dictionary, in_basket: bool) -> void:
    var node = d.get("node")
    if node != null and is_instance_valid(node):
        node.queue_free()
    if in_basket:
        if d["bad"]:
            misses += 1
            _shake_basket()
        else:
            coins += int(d.get("coins", 1))
            caught += 1
            _hit_flash()
            if str(d.get("kind", "")).begins_with("hongbao"):
                _say(_pick_saying())
    if coins >= target:
        win()
    elif misses >= misses_max:
        lose("接到的鞭炮太多了")

## 接到红包冒一句吉利话：同一时间只有一句（新的顶掉旧的），1 秒左右淡掉。**接到糖不冒字**（阿鱼 9/23：字多了乱）
func _say(s: String) -> void:
    if saying_l == null or s == "":
        return
    saying_l.text = s
    saying_l.position = Vector2(0, basket_y - basket.size.y * 0.55 - 34.0) if basket != null else Vector2.ZERO
    saying_l.modulate.a = 1.2   # 前 0.2 秒不淡，再 1 秒淡完

## 不连着两次说同一句
func _pick_saying() -> String:
    if sayings.is_empty():
        return ""
    var i := rng.randi() % sayings.size()
    if sayings.size() > 1 and i == last_saying:
        i = (i + 1) % sayings.size()
    last_saying = i
    return str(sayings[i])

## 接到东西篮口闪一下：有图用「接住的光」，没图画一圈金光
func _hit_flash() -> void:
    var fx: Control
    if art.has("hit"):
        var tr := TextureRect.new()
        tr.texture = art["hit"]
        tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        fx = tr
    else:
        fx = Control.new()
        fx.draw.connect(func(): fx.draw_arc(fx.size * 0.5, fx.size.x * 0.35, 0, TAU, 28, Color("#ffe08a"), 4.0))
    fx.size = Vector2(basket_w, basket_w) * 0.9
    fx.position = Vector2(basket_x - fx.size.x * 0.5, basket_y - fx.size.y * 0.5)
    fx.pivot_offset = fx.size * 0.5
    fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fx.z_index = 3
    add_child(fx)
    var tw := create_tween()
    tw.set_parallel(true)
    tw.tween_property(fx, "scale", Vector2(1.3, 1.3), 0.25)
    tw.tween_property(fx, "modulate:a", 0.0, 0.25)
    tw.chain().tween_callback(fx.queue_free)

func _shake_basket() -> void:
    if basket == null or not is_instance_valid(basket):
        return
    var bx := basket.position.x
    var tw := create_tween()
    tw.tween_property(basket, "position:x", bx - 8.0, 0.05)
    tw.tween_property(basket, "position:x", bx + 8.0, 0.05)
    tw.tween_property(basket, "position:x", bx, 0.05)

# ---------- 手势 ----------
func _gui_input(e: InputEvent) -> void:
    if over or paused:
        return
    if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
        dragging = e.pressed
        if e.pressed:
            _set_basket_x(e.position.x)
        accept_event()
    elif e is InputEventMouseMotion and dragging:
        _set_basket_x(e.position.x)
        accept_event()

func _unhandled_key_input(e: InputEvent) -> void:
    # 电脑上调试：方向键
    if over or paused or not (e is InputEventKey) or not e.pressed:
        return
    match e.keycode:
        KEY_LEFT: _set_basket_x(basket_x - 40.0)
        KEY_RIGHT: _set_basket_x(basket_x + 40.0)

func _set_basket_x(x: float) -> void:
    basket_x = clampf(x, basket_w * 0.5, size.x - basket_w * 0.5)
    _layout_basket()
