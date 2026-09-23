extends Node
## 云函数调用。真机上只用两种确定能用的写法（和日志面板读 __suqiLog.text() 是同一种）：
##   1) 送出去：JavaScriptBridge.get_interface("名字")，名字是任意字符串。请求先转成纯 ASCII 的
##      一行 JSON，再一个字符一个字符当名字「查」过去，换行符表示这条完了。见 wxgame/cloud.js
##   2) 取回来：无参方法返回字符串。__suqiCloud.pop() 取结果、openid() 取自己的 id
## 不带参数调 JS 方法、不用 eval、不读显卡。
## 电脑上没有微信层，用内存里的假席位应付流程，方便开发和截图（fake 开头的都是）。
## 用法：Cloud.call_fn("enterHall", {}, func(r): ...)。r 是 Dictionary，至少有 ok；失败 reason="network"。

const TX_PREFIX := "__sqT"
const TIMEOUT := 12.0           # 超过这么久没回来就按「没连上」回调，界面不会一直没反应
const POP_PER_FRAME := 8

var _js = null                  # 故意不写类型：JS 对象上的方法都是动态调的
var _in_wx := false
var _seq := 0
var _pending: Dictionary = {}   # 编号 -> {"cb": Callable, "t": float}
var _bank := false
var _ok_once := false           # 有过一次成功往返，探针才允许跑
var _probed := false

# ---- 电脑上的假数据：两个人坐着，自己第一次进厅会被分到 T1 ----
var fake_me := {"table_id": "", "chair_no": 0}
var fake_seats := {"T1": [{"openid": "fake_wang", "chair_no": 1}], "T2": [{"openid": "fake_li", "chair_no": 4}]}
## inviter 照服务端的字段（enterHall/index.js）：没有邀请人是 null，不是空字符串。
## fake_li 的邀请人是 fake_wang，这样电脑上截图能看到看人卡片「老王 带进来的」（第 22 版）
var fake_names := {
    "fake_wang": {"nick": "老王", "avatar": 1, "inviter": null},
    "fake_li": {"nick": "小李", "avatar": 5, "inviter": "fake_wang"},
}
var fake_toasts_today: Array = []   # 我今天敬出去的杯数，敬过谁：[to openid, ...]（电脑上没有日期，跑一次当一天）
var fake_toasted_me: Array = ["fake_wang"]   # 敬过我的人：和 enterHall 进厅提示里「老王敬了你一杯」对上；hallPulse 带回去的也记进来
var fake_meet_sent: Array = []      # 我说过「想认识你」的人（wantToMeet；服务端是 friend_request 表）
## 坐长凳的人（openid 列表，和服务端 enterHall 回的 bench 一样）。默认没人；长凳的测试、截图往里塞，
## 要假装自己坐长凳就把 fake_me 设成 {"table_id": "bench", "chair_no": null}（和服务端一样是 null）再把 fake_me 放进来
var fake_bench: Array = []
## 进厅先见人（01 9/23）：假 enterHall 回的 arrival。"card" 出三行小卡（老王敬了你、小李在你这桌写了 2 句、还有 3 位来过）；
## "first" 当第一次进厅（只说坐谁那桌、谁带你来的）；fake_no_news 为 true 时什么都没有
var fake_arrival_mode := "card"
var fake_no_news := false   # true：进厅提示里什么都没有（测「分到长凳」那句提示时用，不然被「老王敬了你一杯」顶掉）
## 翻簿子假数据（第 24 版）：T1 两条方便看接龙，T2 空的方便截空簿子截图。字段名照真实服务端
## readBook 的返回（`at`，不是 `created_at`——之前这里写错过，main.gd 读的是 `at`）
var fake_book: Dictionary = {
    "T1": [
        {"openid": "fake_wang", "text": "新婚快乐", "at": 0},
        {"openid": "fake_li", "text": "百年好合 常来坐坐", "at": 1},
    ],
}

func _ready() -> void:
    # 不按 OS.has_feature 判断：读得到 __suqiCloud 就是接上了，读不到再看是不是在微信里
    _js = JavaScriptBridge.get_interface("__suqiCloud")
    _in_wx = _js != null or OS.has_feature("web") or OS.has_feature("wechat")
    if _js == null:
        if _in_wx:
            print("[suqi] 云桥没接上：__suqiCloud 读不到，席位功能不可用")
        else:
            print("[suqi] 电脑上没有微信层，席位走假数据")
    else:
        print("[suqi] 云桥接上了")
    set_process(false)

func openid() -> String:
    if _js != null:
        return str(_js.openid())
    return "fake_me"

## 点谁的分享卡片进来的（邀请链，wxgame/share.js 记下的）；没有、或者电脑上，都是空串
func inviter() -> String:
    if _js != null:
        return str(_js.inviter())
    return fake_inviter

var fake_inviter := ""   # 电脑上假装是点谁的卡片进来的，测试用
var fake_mine := {"coins": 0, "games": {}, "dishes": [], "gift_coins": 0}   # 小游戏存档（saveProfile 新字段、enterHall 的 mine）
var fake_pulse_toasts: Array = []   # 电脑上假装「刚有人敬我」：截图、测试往这里塞 {from}，下一次 hallPulse 带回去
var fake_fetch_count := 0           # 电脑上假装从云存储下载（@fetchFile）了几次：测「第二次打开读本地、不下载」用
var fake_fetch_fail := ""           # 不是空串就假装下载失败，回这个 reason（测试失败那一路用）
var fake_fetch_diag: Dictionary = {}   # 假装下载失败时一起带回的临时链接回话（真机上是 wxgame/remote.js 的 diagnose）
var fake_no_function := false       # 走云函数那条路（@fetchChunks）时假装 canvasFile 还没部署
var fake_fetch_last := ""           # 最后一次假下载走的哪条路（@fetchFile / @fetchChunks）
var fake_fail_next := ""            # 不是空串：下一次调任何云函数都假装失败、回这个 reason（测断网那一路用），用一次就清掉
var fake_check_in: Dictionary = {}  # 电脑上签到存下来的 {name, gift_value}（迎宾院签到，服务端是 resident 的 check_in_name、gift_value）

## timeout：等多少秒没回来就按「没连上」回调。名字以 @ 开头的不是云函数，是微信那一层自己做的事
## （wxgame/remote.js 的 @fetchFile：从云存储下载文件写进 user://，远程加载最小验证用，下载慢，要给长一点）
func call_fn(name: String, data: Dictionary, cb: Callable, timeout := TIMEOUT) -> void:
    if _js == null:
        # 真机上桥断了也要给回调，不然界面什么都不显示（第 17、18 版就是这样五步全哑）
        if _in_wx:
            print("[suqi] 云桥没接上，", name, " 直接按没连上处理")
            cb.call({"ok": false, "reason": "network"})
        else:
            cb.call(_fake(name, data))
        return
    _seq += 1
    var id := _seq
    # 送出时记一下时间：回来（或超时）时算用时多少毫秒，助理 01 要靠它决定云函数超时要不要调
    _pending[id] = {"cb": cb, "t": 0.0, "limit": timeout, "sent_ms": Time.get_ticks_msec()}
    _send({"id": id, "fn": name, "d": data})
    print("[suqi] 云函数 ", name, " 送出 编号 ", id)
    set_process(true)

## 把一条请求送过去：每个字符查一次 get_interface。A、B 两套名字轮流用，
## 因为适配层查一个名字会把属性读两遍，JS 那边靠「名字和上一个一样就忽略」去重，
## 轮流用才不会把连着两个一样的字符吃掉一个。
func _send(msg: Dictionary) -> void:
    for n in encode_names(msg):
        JavaScriptBridge.get_interface(n)

## 送一条请求要查的名字，按顺序。单独拆出来是为了在电脑上能测（tools/test_bridge.gd）
func encode_names(msg: Dictionary) -> PackedStringArray:
    var text := ascii_only(JSON.stringify(msg)) + "\n"
    var names := PackedStringArray()
    for i in text.length():
        _bank = not _bank
        names.append(TX_PREFIX + ("A" if _bank else "B") + text[i])
    return names

## 转成纯 ASCII：中文、表情都写成 \uXXXX。这样每个字符都在我们注册好的 96 个名字里，
## JS 那边 JSON.parse 会自己还原，不用在 JS 里解 UTF-8
static func ascii_only(s: String) -> String:
    var out := ""
    for i in s.length():
        var c := s.unicode_at(i)
        if c >= 0x20 and c < 0x7F:
            out += char(c)
        elif c <= 0xFFFF:
            out += "\\u%04x" % c
        else:
            var v := c - 0x10000
            out += "\\u%04x\\u%04x" % [0xD800 + (v >> 10), 0xDC00 + (v & 0x3FF)]
    return out

func _process(dt: float) -> void:
    if _js == null or _pending.is_empty():
        set_process(false)
        return
    for _i in POP_PER_FRAME:
        var txt := str(_js.pop())
        if txt == "":
            break
        var m = JSON.parse_string(txt)
        if typeof(m) != TYPE_DICTIONARY:
            print("[suqi] 云桥返回看不懂 ", txt.substr(0, 120))
            continue
        var id := int(m.get("id", 0))
        if not _pending.has(id):
            continue
        var cb: Callable = _pending[id]["cb"]
        var sent_ms: int = int(_pending[id].get("sent_ms", 0))
        _pending.erase(id)
        _ok_once = true
        var r = m.get("r", null)
        var elapsed := Time.get_ticks_msec() - sent_ms
        print("[suqi] 云函数 编号 ", id, " 返回 用时 ", elapsed, " 毫秒 ", txt.substr(0, 120))
        cb.call(r if typeof(r) == TYPE_DICTIONARY else {"ok": false, "reason": "network"})
    for id in _pending.keys():
        _pending[id]["t"] += dt
        var limit := float(_pending[id].get("limit", TIMEOUT))
        if _pending[id]["t"] > limit:
            var cb2: Callable = _pending[id]["cb"]
            var sent_ms2: int = int(_pending[id].get("sent_ms", 0))
            _pending.erase(id)
            var elapsed2 := Time.get_ticks_msec() - sent_ms2
            print("[suqi] 云函数 编号 ", id, " 用时 ", elapsed2, " 毫秒 等了 ", limit, " 秒没回来，按没连上处理")
            cb2.call({"ok": false, "reason": "network"})

## 日志面板打开时叫一次：先报 JS 那边的自查，再单独试一次「带参数调 JS 方法」。
## 探针只为查清适配层的能力，玩法一概不走它。万一这一句在真机上把函数打断或者更糟，
## 也只影响这个函数，五步验收已经在前面走完了。
func diagnose() -> String:
    if _js == null:
        return "云桥没接上"
    var caps := str(_js.caps())
    print("[suqi] ", caps)
    if _ok_once and not _probed:
        _probed = true
        print("[suqi] 探针：准备试带参调用 echo(\"ping\")")
        var r = _js.echo("ping")
        print("[suqi] 探针：带参调用回来了，返回 ", str(r), " 类型 ", typeof(r))
    return caps

# ---- 电脑上的假实现：规则和服务端一致的最小子集，只为跑通流程 ----
func _fake(name: String, data: Dictionary) -> Dictionary:
    if fake_fail_next != "":
        var why := fake_fail_next
        fake_fail_next = ""
        return {"ok": false, "reason": why}
    match name:
        "saveProfile":
            # 敏感词模块假数据（回执 05）：nick 里含"测试敏感"就回 sensitive，方便电脑上截图
            # nick_rejected（起昵称被服务端拒，main.gd 的 _setup_shot 用得到）；签到的名字一样过（迎宾院，蓝图 3.1）
            if str(data.get("nick", "")).contains("测试敏感") or str(data.get("check_in_name", "")).contains("测试敏感"):
                return {"ok": false, "reason": "sensitive"}
            if data.has("check_in_name"):
                fake_check_in = {"name": str(data["check_in_name"]), "gift_value": clampi(int(data.get("gift_value", 0)), 0, 9999)}
            for k in ["coins", "games", "dishes", "gift_coins"]:
                if data.has(k):
                    fake_mine[k] = data[k]
            return {"ok": true, "checked_in": not fake_check_in.is_empty()}   # 和服务端一样回签过到没有
        "enterHall":
            if fake_me["table_id"] == "":
                fake_me = {"table_id": "T1", "chair_no": 2}
                fake_seats["T1"].append({"openid": "fake_me", "chair_no": 2})
            var tables := []
            for i in range(1, 13):   # 和服务端一样回 12 张桌（9/19 起，原来只回试点的两张）
                var tid := "T%d" % i
                tables.append({"id": tid, "reserved": tid == "T1" or tid == "T2", "seats": fake_seats.get(tid, [])})
            return {"ok": true, "data": {"me": fake_me, "tables": tables, "bench": fake_bench,
                "digest": {"toasts": [], "toastCount": 0, "bookLineCount": 0, "hasNews": false} if fake_no_news else
                    {"toasts": [{"from": "fake_wang", "at": 0}], "toastCount": 1, "bookLineCount": 2, "hasNews": true},
                "arrival": _fake_arrival(),
                "mine": fake_mine,
                "names": fake_names}}
        "changeSeat":
            # 入参跟服务端一样是驼峰 tableId、chairNo（cloudfunctions/changeSeat/index.js）。
            # 少一个就和服务端一样回 bad_request，这样字段名发错在电脑上就能测出来
            if not data.has("tableId") or not data.has("chairNo"):
                return {"ok": false, "reason": "bad_request"}
            # 9/18 起和服务端一样不限每天次数（蓝图 3.2）；有人坐的椅子回 seat_taken
            var tid_new := str(data["tableId"])
            var no_new := int(data["chairNo"])
            for other in fake_seats.get(tid_new, []):
                if int(other["chair_no"]) == no_new and other["openid"] != "fake_me":
                    return {"ok": false, "reason": "seat_taken"}
            for tid in fake_seats:
                var arr: Array = fake_seats[tid]
                for i in range(arr.size() - 1, -1, -1):
                    if arr[i]["openid"] == "fake_me":
                        arr.remove_at(i)
            fake_bench.erase("fake_me")   # 从长凳换到椅子
            fake_me = {"table_id": tid_new, "chair_no": no_new}
            if not fake_seats.has(tid_new):
                fake_seats[tid_new] = []
            fake_seats[tid_new].append({"openid": "fake_me", "chair_no": no_new})
            return {"ok": true}
        "toast":
            # 规则照抄服务端 server-claude/src/banquet.js 的 canToast + toast/index.js 的 to 校验：
            # 缺 to → bad_request；敬自己 → toast_self；今天敬满 5 杯（config.BANQUET_TOAST_DAILY）
            # → toast_limit；今天敬过这个人（BANQUET_TOAST_PER_PERSON_DAILY=1）→ toast_same_person
            var to := str(data.get("to", ""))
            if to == "":
                return {"ok": false, "reason": "bad_request"}
            if to == "fake_me":
                return {"ok": false, "reason": "toast_self"}
            if fake_toasts_today.size() >= 5:
                return {"ok": false, "reason": "toast_limit"}
            if fake_toasts_today.has(to):
                return {"ok": false, "reason": "toast_same_person"}
            fake_toasts_today.append(to)
            return {"ok": true}
        "wantToMeet":
            # 规则照抄服务端 server-claude/src/banquet.js 的 canWantToMeet + wantToMeet/index.js：缺 to → bad_request；
            # 对自己 → meet_self；说过了 → meet_already；现在同一桌（长凳不算）或者敬过酒（谁敬谁都算）才行，不然 meet_not_met
            var mto := str(data.get("to", ""))
            if mto == "":
                return {"ok": false, "reason": "bad_request"}
            if mto == "fake_me":
                return {"ok": false, "reason": "meet_self"}
            if fake_meet_sent.has(mto):
                return {"ok": false, "reason": "meet_already"}
            var their_table := ""
            for tid in fake_seats:
                for st in fake_seats[tid]:
                    if st["openid"] == mto:
                        their_table = tid
            var my_table := str(fake_me.get("table_id", ""))
            var same_table := my_table != "" and my_table != "bench" and my_table == their_table
            if not same_table and not fake_toasts_today.has(mto) and not fake_toasted_me.has(mto):
                return {"ok": false, "reason": "meet_not_met"}
            fake_meet_sent.append(mto)
            return {"ok": true}
        "writeBook":
            # 规则照抄服务端 9/18 改过的 canWriteBook（src/banquet.js）：少字段 bad_request；
            # 桌子不是 fake_me 当前坐的桌 not_sat_here；空文本 bad_request；超过 100 字 book_too_long
            if not data.has("table") or not data.has("text"):
                return {"ok": false, "reason": "bad_request"}
            var w_table := str(data["table"])
            var w_text := str(data["text"])
            if w_table != str(fake_me.get("table_id", "")):
                return {"ok": false, "reason": "not_sat_here"}
            if w_text == "":
                return {"ok": false, "reason": "bad_request"}
            if w_text.length() > 100:
                return {"ok": false, "reason": "book_too_long"}
            # 敏感词模块假数据（回执 05），跟 saveProfile 用同一个触发词，方便电脑上测
            if w_text.contains("测试敏感"):
                return {"ok": false, "reason": "sensitive"}
            if not fake_book.has(w_table):
                fake_book[w_table] = []
            (fake_book[w_table] as Array).append({"openid": "fake_me", "text": w_text, "at": Time.get_ticks_msec()})
            return {"ok": true}
        "readBook":
            var r_table := str(data.get("table", ""))
            var lines: Array = (fake_book.get(r_table, []) as Array).duplicate()
            var names := {}
            for l in lines:
                var oid := str((l as Dictionary)["openid"])
                if fake_names.has(oid):
                    names[oid] = fake_names[oid]
            return {"ok": true, "data": {"lines": lines, "names": names}}
        "hallPulse":
            # 第一次（since 是 0）只对表；之后把 fake_pulse_toasts 里攒的一次性带回去（服务端规格见 cloudfunctions/hallPulse）
            var now := Time.get_ticks_msec() + 1000000
            if int(data.get("since", 0)) <= 0:
                return {"ok": true, "now": now, "toasts": [], "names": {}}
            var out: Array = []
            var nm := {}
            for ft in fake_pulse_toasts:
                out.append({"from": ft["from"], "created_at": now})
                if not fake_toasted_me.has(ft["from"]):
                    fake_toasted_me.append(ft["from"])
                nm[ft["from"]] = fake_names.get(ft["from"], {"nick": "", "avatar": -1})
            fake_pulse_toasts.clear()
            return {"ok": true, "now": now, "toasts": out, "names": nm}
        "@fetchFile", "@fetchChunks":
            # 假装从云存储下载（真机上是 wxgame/remote.js）：把 assets/remote_probe.json 的 source 拷到要的位置。
            # 只在工程目录里跑（编辑器、无界面测试、截图）时拿得到 source 原图，导出的包里没有，也用不到
            fake_fetch_count += 1
            fake_fetch_last = name
            if name == "@fetchChunks" and fake_no_function:
                return {"ok": false, "reason": "no_function", "detail": "云函数 canvasFile 还没部署：电脑上假装的"}
            var fid := str(data.get("fileID", ""))
            var dst := str(data.get("path", ""))
            if fid == "" or dst == "":
                return {"ok": false, "reason": "bad_request"}
            if fake_fetch_fail != "":
                var failed := {"ok": false, "reason": fake_fetch_fail, "detail": "电脑上假装失败"}
                if not fake_fetch_diag.is_empty():
                    failed["diag"] = fake_fetch_diag
                return failed
            var man = JSON.parse_string(FileAccess.get_file_as_string("res://assets/remote_probe.json"))
            var src := str((man as Dictionary).get("source", "")) if man is Dictionary else ""
            var bytes := FileAccess.get_file_as_bytes(src)
            if bytes.is_empty():
                return {"ok": false, "reason": "download_failed", "detail": "电脑上读不到 " + src}
            DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
            var f := FileAccess.open(dst, FileAccess.WRITE)
            if f == null:
                return {"ok": false, "reason": "copy_failed", "detail": "写不进 " + dst}
            f.store_buffer(bytes)
            f.close()
            return {"ok": true, "bytes": bytes.size(), "download_ms": 0, "read_ms": 0, "write_ms": 0}
    return {"ok": false, "reason": "network"}

func _fake_arrival() -> Dictionary:
    if fake_no_news:
        return {"first_visit": false, "table_was_empty": false, "rows": [], "hasNews": false, "visitors": [], "book_lines": []}
    if fake_arrival_mode == "first":
        return {"first_visit": true, "table_was_empty": false, "rows": [], "hasNews": false, "visitors": [], "book_lines": []}
    return {"first_visit": false, "table_was_empty": false, "hasNews": true,
        "rows": [{"kind": "toast", "who": "fake_wang", "at": 0, "count": 1},
            {"kind": "book", "who": "fake_li", "at": 0, "count": 2},
            {"kind": "more", "count": 3}],
        "visitors": [], "book_lines": []}
