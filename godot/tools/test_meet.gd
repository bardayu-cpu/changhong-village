extends SceneTree
## 验收：看人卡片上的「想认识你」（蓝图 3.2 加好友，01 9/19 派）。无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据
## （假数据的规则照抄服务端 canWantToMeet；真的规则在 server-claude 的 rules.test.js、cf-mock.test.js 里测）。
## 卡片还是三样（形象、昵称、「XX 带进来的」），底下一排「敬一杯」「想认识你」；现在同一桌能发、顶部「想认识 XX 记下了」；
## 同一对再发「这句说过了」；不同桌没敬过酒「先坐到一桌 或者敬一杯」；敬一杯以后就能发；对自己「自己就不用认识了」；
## 断网「没连上 再试一下」、没记上、再点能发；结果回来卡片关掉、能接着走；按钮置灰时点了不发
## 用法：Godot --headless --path . --script res://tools/test_meet.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true   # 淡入淡出直接跳过
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

func frames(n: int) -> void:
    for i in n:
        await process_frame

## 打开这个人的卡片，点「想认识你」
func meet(openid: String) -> void:
    m._open_person_card(openid)
    await frames(1)
    m._on_meet_pressed()
    await frames(2)

func labels_under(n: Node) -> Array:
    var out := []
    for c in n.get_children():
        if c is Label:
            out.append(c)
        out.append_array(labels_under(c))
    return out

func run() -> void:
    # 等 main 开场走完（不然它会在测试中途切回开场）
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "阿花"
    await m._enter_banquet()
    await frames(3)
    m._note("")   # 进厅提示（老王敬了你一杯）先清掉，下面只看想认识你的那句

    # 1. 卡片：还是三样（形象、昵称、带进来的），底下一排两个按钮，敬一杯在左、想认识你在右
    print("1 卡片")
    m._open_person_card("fake_li")
    await frames(2)
    var texts := []
    for l in labels_under(m.person_card):
        if (l as Label).visible and (l as Label).text != "":
            texts.append((l as Label).text)
    check("字只有昵称和带进来的 %s" % [texts], texts == ["小李", "老王 带进来的"])
    check("有形象", m.person_card_portrait.texture != null)
    check("按钮字：敬一杯、想认识你", m.person_card_toast_btn.text == "敬一杯" and m.person_card_meet_btn.text == "想认识你")
    var tr: Rect2 = m.person_card_toast_btn.get_global_rect()
    var mr: Rect2 = m.person_card_meet_btn.get_global_rect()
    check("同一排、想认识你在右边 %s %s" % [tr, mr], is_equal_approx(tr.position.y, mr.position.y) and mr.position.x > tr.end.x)
    check("两个都能点", not m.person_card_toast_btn.disabled and not m.person_card_meet_btn.disabled)
    m._close_person_card()

    # 2. 老王和我现在都坐 T1：发得出去，顶部一句，卡片关了，能接着走
    print("2 同桌")
    check("我坐 T1、老王也在 T1", str(m.cloud.fake_me["table_id"]) == "T1")
    await meet("fake_wang")
    check("顶部：" + m.note.text, m.note.text == "想认识 老王 记下了")
    check("服务端记下了", m.cloud.fake_meet_sent == ["fake_wang"])
    check("卡片关了、能走", not m.card_open and not m.person_card.visible and m.hall.walking_enabled)

    # 3. 同一对再发：拒，不多记
    print("3 说过了")
    await meet("fake_wang")
    check("顶部：" + m.note.text, m.note.text == "这句说过了")
    check("没多记", m.cloud.fake_meet_sent.size() == 1)

    # 4. 小李在 T2、没敬过酒：拒
    print("4 不同桌、没敬过酒")
    await meet("fake_li")
    check("顶部：" + m.note.text, m.note.text == "先坐到一桌 或者敬一杯")
    check("没记", not m.cloud.fake_meet_sent.has("fake_li"))
    check("卡片关了", not m.card_open)

    # 5. 在卡片上先敬小李一杯，再点想认识你：能发
    print("5 敬过酒以后")
    m._open_person_card("fake_li")
    await frames(1)
    m._on_toast_pressed()
    await frames(2)
    check("敬了小李：" + m.note.text, m.note.text == "敬了 小李 一杯" and m.cloud.fake_toasts_today.has("fake_li"))
    await meet("fake_li")
    check("顶部：" + m.note.text, m.note.text == "想认识 小李 记下了")
    check("记下了", m.cloud.fake_meet_sent.has("fake_li"))

    # 6. 对自己：拒
    print("6 对自己")
    await meet(m.cloud.openid())
    check("顶部：" + m.note.text, m.note.text == "自己就不用认识了")

    # 7. 断网：「没连上 再试一下」，没记上；再点一次发得出去
    print("7 断网")
    m.cloud.fake_toasted_me.append("fake_new")   # 阿强敬过我（不在我这桌），能发
    m.hall.resident_names["fake_new"] = {"nick": "阿强", "avatar": 3, "inviter": null}
    m.cloud.fake_fail_next = "network"
    await meet("fake_new")
    check("顶部：" + m.note.text, m.note.text == "没连上 再试一下")
    check("没记上", not m.cloud.fake_meet_sent.has("fake_new"))
    await meet("fake_new")
    check("再点：" + m.note.text, m.note.text == "想认识 阿强 记下了")

    # 8. 服务端回了没见过的原因：按没连上说，不空着
    print("8 没见过的原因")
    m._on_meet_result({"ok": false, "reason": "something_new"}, "fake_wang")
    check("顶部：" + m.note.text, m.note.text == "没连上 再试一下")

    # 9. 按钮置灰（请求还没回来）时再点不发；点了想认识你，敬一杯也一起置灰
    print("9 防连点")
    m.cloud.fake_meet_sent.clear()
    m._open_person_card("fake_wang")
    await frames(1)
    m.person_card_meet_btn.disabled = true
    m._on_meet_pressed()
    check("置灰时点了不发", m.cloud.fake_meet_sent.is_empty() and m.card_open)
    m._close_person_card()
    var calls := []
    var real_cloud = m.cloud
    m._open_person_card("fake_wang")
    await frames(1)
    # 请求发出去、还没回来的样子：换一个不回话的 cloud，看两个按钮的状态
    var mute := MuteCloud.new()
    mute.calls = calls
    m.cloud = mute
    m._on_meet_pressed()
    check("发出去一次：%s" % [calls], calls == ["wantToMeet"])
    check("等回话时两个按钮都置灰", m.person_card_meet_btn.disabled and m.person_card_toast_btn.disabled)
    m._on_meet_pressed()
    m._on_toast_pressed()
    check("这时候再点哪个都不发", calls.size() == 1)
    m.cloud = real_cloud
    mute.free()
    m._close_person_card()
    m._open_person_card("fake_wang")
    await frames(1)
    check("重开卡片两个按钮又能点", not m.person_card_meet_btn.disabled and not m.person_card_toast_btn.disabled)
    m._close_person_card()

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)

## 只记下调了哪个云函数、不回话，像请求还在路上
class MuteCloud extends Node:
    var calls: Array
    func call_fn(name: String, _data: Dictionary, _cb: Callable, _timeout := 12.0) -> void:
        calls.append(name)
    func openid() -> String:
        return "fake_me"
