extends SceneTree
## 验收：桌牌（蓝图 3.2「XX那桌」，XX 是这桌最早坐下的人）和邀请链存资料的字段（9/18）。无界面跑。
## 用法：Godot --headless --path . --script res://tools/test_signs_invite.gd

var hall
var started := false

func _initialize() -> void:
    hall = load("res://scripts/layered_hall.gd").new()
    get_root().add_child(hall)

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    hall.build(2, "测试", SystemFont.new())
    run()
    return false

func run() -> void:
    var ok := true
    # 1. 桌牌取这桌 sat_at 最早的人，不看列表顺序
    var data := {
        "me": {"table_id": "T1", "chair_no": 2},
        "tables": [
            {"id": "T1", "seats": [
                {"openid": "late", "chair_no": 1, "sat_at": 2000},
                {"openid": "early", "chair_no": 3, "sat_at": 1000},
                {"openid": "me", "chair_no": 2, "sat_at": 3000}]},
            {"id": "T2", "seats": []},
        ],
        "names": {"late": {"nick": "后来的"}, "early": {"nick": "先来的"}, "me": {"nick": "我"}},
    }
    hall.set_seats(data, "me")
    print("1 桌牌 ", hall.table_names)
    ok = ok and hall.table_names.get("T1", "") == "先来的" and not hall.table_names.has("T2")
    # 2. 牌子真的挂上了；9/19 起带这桌的小游戏名（蓝图 3.2），没人坐的桌只写游戏名
    await process_frame
    var sign1 = hall.seat_tags.get_node_or_null("sign_T1")
    var sign2 = hall.seat_tags.get_node_or_null("sign_T2")
    print("2 T1 牌子 ", sign1.text if sign1 else "没有", "  T2 牌子 ", sign2.text if sign2 else "没有")
    ok = ok and sign1 != null and sign1.text == "先来的那桌·连连看" and sign2 != null and sign2.text == "连连看"
    # 3. 旧数据没有 sat_at：按列表里第一个有昵称的
    hall.set_seats({"me": {"table_id": "T2", "chair_no": 1}, "tables": [
        {"id": "T1", "seats": [{"openid": "a", "chair_no": 1}, {"openid": "b", "chair_no": 2}]}],
        "names": {"a": {"nick": "老王"}, "b": {"nick": "小李"}}}, "me")
    print("3 没有 sat_at 的桌牌 ", hall.table_names)
    ok = ok and hall.table_names.get("T1", "") == "老王"

    # 4. 存资料的字段：点别人卡片进来带 inviter；没有邀请人、邀请人是自己都不带
    var Main = load("res://scripts/main.gd")
    var p1: Dictionary = Main.profile_payload("小李", 3, "o_inviter", "o_me")
    var p2: Dictionary = Main.profile_payload("小李", 3, "", "o_me")
    var p3: Dictionary = Main.profile_payload("小李", 3, "o_me", "o_me")
    print("4 存资料 ", p1, " ", p2, " ", p3)
    ok = ok and p1.get("inviter", "") == "o_inviter" and p1["nick"] == "小李" and int(p1["avatar"]) == 3
    ok = ok and not p2.has("inviter") and not p3.has("inviter")

    # 5. 走路速度两档：默认 3.2，备选 2.4
    print("5 走路速度 ", hall.speed_m, " 两档 ", hall.SPEED_CHOICES)
    ok = ok and is_equal_approx(hall.speed_m, 3.2) and hall.SPEED_CHOICES.has(2.4)

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
