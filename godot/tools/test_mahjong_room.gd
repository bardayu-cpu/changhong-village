extends SceneTree
## 验收：娱乐室（原麻将室）单独成一间屋、坐下摸两把（庄Z2 10/6；回执 godot/回执/娱乐室-接入.md）。无界面跑整个 main.gd，手机屏 540×960。
##   1 进屋：后厅走廊走进娱乐室门口（to_mahjong）→ 整屏换成娱乐室；画面上方出「娱乐室」
##   2 屋里：坐满（座位 76 个，玩家那把空着），原来后厅麻将室那几位（能聊的长辈）搬进来了；电视三帧在换；从门走得到玩家那把
##   3 摸两把：走到玩家那把出「坐下」，坐下开「摸两把」：真麻将牌面、第一把 4×4 = 16 张、不限时；消完一把不给金币（出「这一把摸完了」）；点「离开」起身回屋
##   4 出屋：南门出去回到后厅走廊娱乐室门口外，站着不弹回去
##   5 后厅：原来那间封起来（门洞挡上、门牌「娱乐室」），那 14 位不在后厅了
## 用法：Godot --headless --path . --script res://tools/test_mahjong_room.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const LLK = preload("res://scripts/games/lianliankan.gd")
const DT := 1.0 / 60.0

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func walk_to(target: Vector2, secs := 30.0) -> void:
    var c = m.cv
    c.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv != c or c.path.is_empty():
            break
    for i in 60:
        if not m.switching:
            break
        await process_frame

func frames(n: int) -> void:
    for i in n:
        await process_frame

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.cloud.fake_no_news = true
    m.nickname = "小李"
    m.court_save.local_path = "user://test_mahjong_room_court.json"
    m.games_save.local_path = "user://test_mahjong_room_games.json"
    m.ensure_canvas("backhall")
    m.ensure_canvas("mahjong")
    await m._enter_court()
    m.dialog.visible = false
    var b = m.backhall
    var r = m.areas["mahjong"]

    print("5 后厅（先看）")
    var bh_mj: Array = []
    for n in b.cfg["npcs"]:
        if str(n.get("life", "")) == "mahjong":
            bh_mj.append(n["id"])
    check("后厅里没有原来麻将室那几位了（%s）" % str(bh_mj), bh_mj.is_empty())
    var sign_ok := false
    for sg in b.cfg.get("signs", []):
        if str(sg.get("text", "")) == "娱乐室":
            sign_ok = true
    check("后厅门牌改成「娱乐室」", sign_ok)
    check("门洞挡上了（mahjong_door）、门口有 to_mahjong", b.points.has("to_mahjong") and b.cfg["items"].any(func(it): return str(it.get("id", "")) == "mahjong_door"))

    print("1 进屋")
    m._show_canvas("backhall")
    m._goto("backhall")
    b.walking_enabled = true
    b.reset_to(Vector2(696, 790))
    tick(3)
    await walk_to(b.spot_pos("to_mahjong"))
    check("走进娱乐室门口整屏换进屋（%s）" % m.state, m.state == "mahjong" and m.cv == r and r.visible and not b.visible)
    await frames(4)
    check("画面上方出屋名「娱乐室」", m.room_title_box.visible)

    print("2 屋里")
    var seats_n := 0
    var movers := 0
    for n in r.cfg["npcs"]:
        if bool(n.get("sit", false)):
            seats_n += 1
        if str(n.get("life", "")) == "mahjong":
            movers += 1
    check("坐满：%d 位坐着（座位 76 个，玩家那把空着）" % seats_n, seats_n == 75)
    check("原来后厅麻将室那几位搬进来了（%d 位挂 life: mahjong）" % movers, movers == 14)
    check("能聊的那几位归娱乐室管（%d 位）" % r.lives[0].people.size(), not r.lives.is_empty() and r.lives[0].people.size() == 14)
    var tv: Sprite2D = r.world.get_node_or_null("px_tv_screen")
    var seen := {}   # 半秒里每帧记一下放的是哪张（只等一下再比一次，机器卡的时候正好转一圈回原帧会误判）
    for i in 30:
        if tv != null:
            seen[tv.texture] = true
        await create_timer(1.0 / 60.0).timeout
    check("电视三帧在换（半秒里见到 %d 种）" % seen.size(), tv != null and seen.size() >= 2)

    for id in r.lives[0].people:
        var ap: Vector2 = r.lives[0].approach_of(str(id))
        check("%s 说话位置可达（%s）" % [id, str(ap)], ap != Vector2.ZERO and r._free(ap))
    for p in r.cfg.get("stand_points", []):
        var at := Vector2(float(p["x"]), float(p["y"]))
        check("%s 走动站点可达" % p["id"], r._free(at))
    print("3 摸两把")
    var seat: Dictionary = {}
    for s in r.lives[0].seats:
        if str(s["id"]) == "seat_mahjong_play":
            seat = s
    check("坐下位置在南椅旁的过道", not seat.is_empty() and seat["stand"].y > float(seat["y"]))
    check("玩家那把在（%s）" % str(seat.get("stand", "没有")), not seat.is_empty() and seat["stand"] != Vector2.ZERO)
    await walk_to(seat["stand"])
    tick(3)
    var ui = m.lounge_ui
    check("走到跟前出「坐下」（%s）" % ui.seat_btn.text, ui.seat_btn.visible)
    ui.seat_btn.pressed.emit()
    tick(30)
    await frames(3)
    check("坐下了，开「摸两把」", r.seated and is_instance_valid(m.game_host) and str(m.game_host.game_id) == "mahjong_pair")
    var gh = m.game_host
    gh._start()
    await frames(3)
    var gm = gh.game
    check("真麻将牌面、第一把 4×4（%d×%d、%d 种牌：%s）" % [gm.cols, gm.rows, gm.mj_faces.size(), ", ".join(gm.mj_faces.map(func(f): return gm.MJ.name_of(f)))],
        gm.mj_faces.size() == 4 and gm.cols == 4 and gm.rows == 4)
    check("不限时（状态那行：「%s」）" % gm.status_text(), gm.unlimited and not gm.status_text().contains("秒"))
    var coins0: int = m.games_save.coins
    # 一对一对消完（照规则：找连得上的一对点两下）
    for step in 40:
        var pr: Array = _any_pair(gm)
        if pr.is_empty():
            break
        gm.tap(pr[0])
        gm.tap(pr[1])
        await frames(1)
    await create_timer(0.8).timeout
    var left := 0
    for row in gm.board:
        for v in row:
            if int(v) != 0:
                left += 1
    var card_text := ""
    for l in gh.find_children("*", "Label", true, false):
        card_text += (l as Label).text + " "
    check("牌都消完了（剩 %d 张），结算卡说「这一把摸完了」、没有「+0 金」" % left, left == 0 and card_text.contains("这一把摸完了") and not card_text.contains("+0 金"))
    check("一把摸完、不给金币（手上 %d → %d 金）" % [coins0, m.games_save.coins], m.games_save.coins == coins0)
    gh._close()
    await frames(3)
    tick(30)
    check("点「离开」起身回屋", not r.seated and not is_instance_valid(m.game_host) and m.state == "mahjong")

    print("4 出屋")
    await walk_to(r.spot_pos("to_backhall"))
    check("南门出去回到后厅走廊娱乐室门口外（%s，%s）" % [m.state, str(b.pos)], m.state == "backhall" and b.pos.distance_to(Vector2(696, 790)) < 40.0)
    tick(60)
    check("站着不弹回娱乐室", m.state == "backhall")
    print("RESULT %s" % ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)

## 找一对连得上的（棋盘上同一种、能用两拐以内的线连）
func _any_pair(gm) -> Array:
    var cells: Array = []
    for y in gm.rows:
        for x in gm.cols:
            if int(gm.board[y][x]) != 0:
                cells.append(Vector2i(x, y))
    for i in cells.size():
        for j in range(i + 1, cells.size()):
            var a: Vector2i = cells[i]
            var c: Vector2i = cells[j]
            if int(gm.board[a.y][a.x]) == int(gm.board[c.y][c.x]) and not LLK.can_link(gm.board, a, c).is_empty():
                return [a, c]
    return []
