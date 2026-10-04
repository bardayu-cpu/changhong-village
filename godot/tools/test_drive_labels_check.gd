extends SceneTree
## 第 69 版开车时路牌藏起来（07 做，04 看第 68 版：车压住「去前门 ↓」），03 自己重测（01 H 10/4 派，不改游戏代码）：
##   开一趟车：车在跑的每一帧里，那一段所在块的路牌层看不见（一帧都不能看得见）；开完下车，前门、广场、停车场三块的路牌层都又出来了；
##   看过开车的在前门点一下屏幕跳过：跳完下车，三块路牌也都出来了（不能停在藏着的状态）；
##   开车时「点地面走路」提示和摇杆照旧藏着；下车以后路牌上的字还是原来的、数量不变
## 用法：Godot --headless --path . --script res://tools/test_drive_labels_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const SAVE := "user://test_dlc_court.json"
const BLOCKS := ["frontgate", "plaza", "parking"]
var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(200.0).timeout.connect(func():
        print("RESULT FAIL 200 秒没跑完")
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

func set_save(d: Dictionary) -> void:
    var f := FileAccess.open(SAVE, FileAccess.WRITE)
    f.store_string(JSON.stringify(d))
    f.close()
    m.court_save.local_path = SAVE
    m.court_save.load_local()

func real_click() -> void:
    var e := InputEventMouseButton.new()
    e.button_index = MOUSE_BUTTON_LEFT
    e.pressed = true
    e.position = Vector2(270, 480)
    Input.parse_input_event(e)

func texts() -> Dictionary:
    var out := {}
    for k in BLOCKS:
        var arr: Array = []
        for lb in m._canvas_by(k).labels.get_children():
            if lb is Label:
                arr.append(str((lb as Label).text))
        arr.sort()
        out[k] = arr
    return out

func drive(click_at: int) -> Dictionary:
    m.drive_in_fast = true
    m.dialog.visible = false
    var vis := 0
    var hid := 0
    var other_vis := 0   # 没在开的那两块的路牌层，开车时也不该在眼前出现的：只记，不判（它们是藏起来的块）
    var hint_vis := 0
    var stick_vis := 0
    var n := 0
    var clicked := false
    var legs: Array = []
    m._start_play()
    for i in 8000:
        await process_frame
        n += 1
        if m.drive.leg != "" and (legs.is_empty() or legs[-1] != m.drive.leg):
            legs.append(m.drive.leg)
        if m.driving and m.drive.leg != "" and m.cv != null and m.cv.get("labels") != null and not m.cv.player.visible:
            if m.cv.labels.visible:
                vis += 1
            else:
                hid += 1
            if m.hint != null and m.hint.visible:
                hint_vis += 1
            if m.stick_base != null and m.stick_base.visible:
                stick_vis += 1
        if click_at >= 0 and n == click_at and not clicked:
            clicked = true
            real_click()
        if not m.driving and m.state == "parking" and not m.switching:
            break
    for i in 30:
        await process_frame
    m.drive_in_fast = false
    var after_hidden: Array = []
    for k in BLOCKS:
        if not m._canvas_by(k).labels.visible:
            after_hidden.append(k)
    return {"vis": vis, "hid": hid, "hint_vis": hint_vis, "stick_vis": stick_vis, "frames": n, "legs": legs, "after_hidden": after_hidden}

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.games_save.local_path = "user://test_dlc_games.json"
    m.cloud.fake_no_news = true
    m.nickname = "小李"
    for k in BLOCKS:
        m.ensure_canvas(k)
    var before := texts()
    var nlab := 0
    for k in before:
        nlab += (before[k] as Array).size()

    print("1 新号开一趟")
    set_save({})
    var r1 := await drive(-1)
    var after := texts()
    check("三段 %s 开完；车在跑的帧里路牌层看得见 %d 帧、藏着 %d 帧；下车后三块路牌层还藏着的 %s" % [str(r1["legs"]), r1["vis"], r1["hid"], str(r1["after_hidden"])], r1["legs"] == BLOCKS and int(r1["vis"]) == 0 and int(r1["hid"]) > 200 and (r1["after_hidden"] as Array).is_empty())
    check("下车以后路牌上的字、数量跟开车前一样（开车前 %d 块；变了的 %s）" % [nlab, str(after.keys().filter(func(k): return after[k] != before[k]))], after == before)
    check("开车时「点地面走路」提示和摇杆也藏着（%d、%d 帧出现）" % [r1["hint_vis"], r1["stick_vis"]], int(r1["hint_vis"]) == 0 and int(r1["stick_vis"]) == 0)

    print("2 看过开车的老号：整趟开完、前门点跳过、广场点跳过")
    set_save({"welcomed": true, "signed_in": true, "court_seen": true, "drive_seen": true})
    var r2 := await drive(-1)
    check("老号整趟：路牌看得见 %d 帧、藏着 %d 帧；下车后还藏着的 %s" % [r2["vis"], r2["hid"], str(r2["after_hidden"])], int(r2["vis"]) == 0 and int(r2["hid"]) > 200 and (r2["after_hidden"] as Array).is_empty())
    set_save({"welcomed": true, "signed_in": true, "court_seen": true, "drive_seen": true})
    var r3 := await drive(40)
    check("前门那段真点屏幕跳过（开了 %s、%d 帧）：路牌看得见 %d 帧；下车后还藏着的 %s（不能停在藏着）" % [str(r3["legs"]), r3["frames"], r3["vis"], str(r3["after_hidden"])], int(r3["vis"]) == 0 and (r3["after_hidden"] as Array).is_empty() and (r3["legs"] as Array).size() <= 1)
    set_save({"welcomed": true, "signed_in": true, "court_seen": true, "drive_seen": true})
    var r4 := await drive(300)
    check("广场那段点跳过（开了 %s、%d 帧）：路牌看得见 %d 帧；下车后还藏着的 %s" % [str(r4["legs"]), r4["frames"], r4["vis"], str(r4["after_hidden"])], int(r4["vis"]) == 0 and (r4["after_hidden"] as Array).is_empty() and (r4["legs"] as Array).size() <= 2)
    var after2 := texts()
    check("跳过以后路牌字也没变", after2 == before)
    DirAccess.remove_absolute(SAVE)
    DirAccess.remove_absolute("user://test_dlc_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
