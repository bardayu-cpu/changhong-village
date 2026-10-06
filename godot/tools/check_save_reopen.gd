extends SceneTree
## （文件名不叫 test_ 开头：它要连着跑三趟、在导出包上用，不进 run_tests.sh 的全套）
## 存档关掉重开还在（庄Z1 10/6 出码前把关加的一条：存一次档 → 关掉重开 → 再关掉重开，存档还在）。03 / 庄Z3 写，在导出包上跑，不改游戏代码。
## 不用测试专用的存档路径——走游戏真用的 user://suqi_court.json、suqi_games.json、suqi_orchard.json（所以要给它一个独立的 HOME，别写进这台机器上真存档）。
## 分三趟、每趟一个新进程（所以真的是「关掉重开」）：
##   --phase=write  ：存一次档：金币、小游戏通关、连连看解锁的菜、迎宾院几个标记、果园收成和果篮，写完把期望值另存一份（user://rcm_expected.json）后退出
##   --phase=read   ：重开：游戏自己启动时读存档，把读到的跟期望值逐项比；不写任何东西
## 用法（要连着跑三趟，每趟同一个 HOME）：
##   Godot --headless --main-pack 包.pck --script res://tools/check_save_reopen.gd -- --phase=write
##   Godot … -- --phase=read    （跑两遍）
## 每趟最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const EXPECT := "user://rcm_expected.json"

var m
var started := false
var ok := true
var phase := "read"

func _initialize() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--phase="):
            phase = a.substr(8)
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(120.0).timeout.connect(func():
        print("RESULT FAIL 120 秒没跑完")
        quit(1))

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await process_frame
    print("== 第一步：%s（存档文件在 %s）" % [phase, ProjectSettings.globalize_path("user://")])
    if phase == "write":
        write_phase()
    else:
        read_phase()
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)

func snapshot() -> Dictionary:
    return {
        "coins": m.games_save.coins, "games": m.games_save.games, "dishes": m.games_save.dishes, "gift": m.games_save.gift_coins,
        "welcomed": m.court_save.welcomed, "signed_in": m.court_save.signed_in, "court_seen": m.court_save.court_seen, "backhall_seen": m.court_save.backhall_seen,
        "drive_seen": m.court_save.drive_seen, "map_used": m.court_save.map_used, "whisper_done": m.court_save.whisper_done,
        "plots": m.orchard_save.plots, "basket": m.orchard_save.basket, "sold": m.orchard_save.sold,
    }

func write_phase() -> void:
    # 起点：这个 HOME 里原来什么都没有
    var fresh: bool = not FileAccess.file_exists("user://suqi_court.json") and not FileAccess.file_exists("user://suqi_games.json")
    check("起点是干净的（这个 HOME 里原来没有存档）", fresh)
    m.games_save.clear_level("lianliankan", 3, 50, 2)
    m.games_save.clear_level("lianliankan", 4, 60, 5)
    m.games_save.clear_level("memory", 2, 30)
    m.games_save.earn(15)
    m.court_save.welcomed = true
    m.court_save.signed_in = true
    m.court_save.court_seen = true
    m.court_save.backhall_seen = true
    m.court_save.drive_seen = true
    m.court_save.map_used = true
    m.court_save.whisper_done = true
    m.court_save.save()
    m.orchard_save.mark_plot("ridge_0", 1789876800.0)
    m.orchard_save.mark_plot("loquat_1_2", 1789876900.0)
    m.orchard_save.add_basket("枇杷", 3)
    m.orchard_save.add_basket("草莓", 2)
    m.orchard_save.save()
    var snap := snapshot()
    var f := FileAccess.open(EXPECT, FileAccess.WRITE)
    f.store_string(JSON.stringify(snap))
    f.close()
    check("三份存档文件都写出来了（court %s、games %s、orchard %s）" % [str(FileAccess.file_exists("user://suqi_court.json")), str(FileAccess.file_exists("user://suqi_games.json")), str(FileAccess.file_exists("user://suqi_orchard.json"))],
        FileAccess.file_exists("user://suqi_court.json") and FileAccess.file_exists("user://suqi_games.json") and FileAccess.file_exists("user://suqi_orchard.json"))
    check("存进去的内容：金币 %d、小游戏 %s、菜 %s、迎宾院 7 个标记都开、果园地 %d 块、果篮 %s" % [snap["coins"], str(snap["games"]), str(snap["dishes"]), (snap["plots"] as Dictionary).size(), str(snap["basket"])],
        int(snap["coins"]) >= 155 and (snap["dishes"] as Array).size() == 2 and bool(snap["map_used"]) and (snap["plots"] as Dictionary).size() == 2)

func read_phase() -> void:
    check("期望值文件在（上一趟写的）", FileAccess.file_exists(EXPECT))
    if not FileAccess.file_exists(EXPECT):
        return
    var want = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
    var got := snapshot()
    var bad: Array = []
    for k in want:
        var a = want[k]
        var b = got.get(k)
        # JSON 里整数会变成小数：两边都转成 JSON 字符串比
        if JSON.stringify(a) != JSON.stringify(JSON.parse_string(JSON.stringify(b))):
            bad.append("%s：存的 %s、读回来 %s" % [k, str(a), str(b)])
    for x in bad:
        print("    ", x)
    check("重开以后读回来的存档跟上次存的一致（%d 项里 %d 项不一样）" % [want.size(), bad.size()], bad.is_empty())
    # 重开没把存档洗掉：文件还在、内容还能解析
    var parse_bad: Array = []
    for p in ["user://suqi_court.json", "user://suqi_games.json", "user://suqi_orchard.json"]:
        if not FileAccess.file_exists(p) or typeof(JSON.parse_string(FileAccess.get_file_as_string(p))) != TYPE_DICTIONARY:
            parse_bad.append(p)
    check("三份存档文件都还在、能解析（%s）" % str(parse_bad), parse_bad.is_empty())
