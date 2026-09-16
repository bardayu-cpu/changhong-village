extends SceneTree
## 云桥的逻辑测试。跑法：
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/test_bridge.gd
## 最后一行 RESULT PASS 才算过。
## 这一半只测 Godot 这边：请求转成纯 ASCII、拆成一串 get_interface 名字、假数据回调。
## 另一半（JS 那边把名字还原成请求）用 node 回放：tools/replay_bridge.js，
## 两半一起跑用 tools/test_bridge.sh。

const Cloud = preload("res://scripts/cloud.gd")

func _init() -> void:
    var ok := true
    var c: Node = Cloud.new()

    # 1. 纯 ASCII：中文、表情、引号、反斜杠都要变成能当名字的字符
    var esc: String = Cloud.ascii_only("{\"nick\":\"阿鱼😀\"}")
    var all_ok := true
    for i in esc.length():
        var u := esc.unicode_at(i)
        if u < 0x20 or u >= 0x7F:
            all_ok = false
    print("1 纯 ASCII：", esc)
    print("  全在可打印范围 ", all_ok)
    ok = ok and all_ok and esc.find("\\u963f") >= 0 and esc.find("\\ud83d\\ude00") >= 0

    # 2. 拆名字：个数 = 字符数 + 1（结束符），A/B 轮流，前缀对
    var msg := {"id": 1, "fn": "enterHall", "d": {}}
    var names: PackedStringArray = c.encode_names(msg)
    var text: String = Cloud.ascii_only(JSON.stringify(msg)) + "\n"
    var shape_ok := names.size() == text.length()
    var alt_ok := true
    for i in names.size():
        var n: String = names[i]
        if not n.begins_with(Cloud.TX_PREFIX):
            shape_ok = false
        var bank: String = n.substr(Cloud.TX_PREFIX.length(), 1)
        if bank != "A" and bank != "B":
            shape_ok = false
        if n.substr(Cloud.TX_PREFIX.length() + 1) != text[i]:
            shape_ok = false
        if i > 0 and names[i] == names[i - 1]:
            alt_ok = false   # 连着两个一样的名字会被 JS 那边当成重复读，吃掉一个
    print("2 名字个数 ", names.size(), " 该是 ", text.length(), " 形状对 ", shape_ok, " 没有连着重名 ", alt_ok)
    ok = ok and shape_ok and alt_ok

    # 3. 换桌请求里带中文桌号也要能拆（昵称走 saveProfile，同一条路）
    var msg2 := {"id": 2, "fn": "saveProfile", "d": {"nick": "阿鱼", "avatar": 2}}
    var names2: PackedStringArray = c.encode_names(msg2)
    var alt2 := true
    for i in range(1, names2.size()):
        if names2[i] == names2[i - 1]:
            alt2 = false
    print("3 带中文的请求 名字 ", names2.size(), " 个 没有连着重名 ", alt2)
    ok = ok and alt2 and names2.size() > 40

    # 4. 电脑上的假数据：桥读不到 __suqiCloud 时要照常回调，流程不断
    # 回调的结果收在一个字典里：GDScript 的匿名函数是按值捕获的，不能直接往外层变量赋值
    var box := {}
    c._ready()
    c.call_fn("enterHall", {}, func(r): box["hall"] = r)
    var got: Dictionary = box.get("hall", {})
    var seats_ok: bool = bool(got.get("ok", false)) and got.get("data", {}).has("tables")
    print("4 电脑假数据 enterHall 回来了 ", seats_ok, " openid ", c.openid())
    ok = ok and seats_ok and c.openid() == "fake_me"
    c.call_fn("changeSeat", {"table_id": "T2", "chair_no": 3}, func(r): box["s1"] = r)
    c.call_fn("changeSeat", {"table_id": "T1", "chair_no": 5}, func(r): box["s2"] = r)
    var got2: Dictionary = box.get("s1", {})
    var got3: Dictionary = box.get("s2", {})
    print("5 换桌第一次 ", got2, " 第二次（今天换过了）", got3)
    ok = ok and bool(got2.get("ok", false)) and str(got3.get("reason", "")) == "changed_today"

    # 6. 把两条请求的名字写出去，交给 node 回放（tools/replay_bridge.js）
    var out_path := OS.get_environment("SUQI_BRIDGE_OUT")
    if out_path == "":
        out_path = "user://bridge_names.json"
    var f := FileAccess.open(out_path, FileAccess.WRITE)
    if f == null:
        print("6 写不出名字文件 ", out_path)
        ok = false
    else:
        var c2: Node = Cloud.new()
        f.store_string(JSON.stringify({
            "cases": [
                {"msg": msg, "names": c2.encode_names(msg)},
                {"msg": msg2, "names": c2.encode_names(msg2)},
            ]}))
        f.close()
        print("6 名字写到 ", ProjectSettings.globalize_path(out_path))

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
