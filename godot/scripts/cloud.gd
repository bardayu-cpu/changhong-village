extends Node
## 云函数调用：微信里走 wxgame/cloud.js 的 __suqiCloud（call 拿编号、每帧 poll 结果）；
## 电脑上没有微信层，用内存里的假席位应付流程，方便开发和截图（fake 开头的都是）。
## 用法：Cloud.call_fn("enterHall", {}, func(r): ...)。r 是 Dictionary，至少有 ok；失败 reason="network"。

var _js: JavaScriptObject = null
var _pending: Dictionary = {}   # 编号 -> Callable

# ---- 电脑上的假数据：两个人坐着，自己第一次进厅会被分到 T1 ----
var fake_me := {"table_id": "", "chair_no": 0}
var fake_seats := {"T1": [{"openid": "fake_wang", "chair_no": 1}], "T2": [{"openid": "fake_li", "chair_no": 4}]}
var fake_names := {"fake_wang": {"nick": "老王", "avatar": 1}, "fake_li": {"nick": "小李", "avatar": 5}}
var fake_changed_today := false

func _ready() -> void:
    if OS.has_feature("web") or OS.has_feature("wechat"):
        _js = JavaScriptBridge.get_interface("__suqiCloud")
        if _js == null:
            print("[suqi] 云桥没接上：__suqiCloud 读不到，席位功能不可用")

func openid() -> String:
    if _js != null:
        return str(_js.openid())
    return "fake_me"

func call_fn(name: String, data: Dictionary, cb: Callable) -> void:
    if _js != null:
        var id := int(_js.req(name, JSON.stringify(data)))
        print("[suqi] 云函数 ", name, " 发出 编号 ", id)
        _pending[id] = cb
        set_process(true)
        return
    cb.call(_fake(name, data))

func _process(_dt: float) -> void:
    if _js == null or _pending.is_empty():
        set_process(false)
        return
    for id in _pending.keys():
        var txt := str(_js.poll(id))
        if txt == "":
            continue
        var cb: Callable = _pending[id]
        _pending.erase(id)
        var r = JSON.parse_string(txt)
        print("[suqi] 云函数 编号 ", id, " 返回 ", txt.substr(0, 120))
        cb.call(r if typeof(r) == TYPE_DICTIONARY else {"ok": false, "reason": "network"})

# ---- 电脑上的假实现：规则和服务端一致的最小子集，只为跑通流程 ----
func _fake(name: String, data: Dictionary) -> Dictionary:
    match name:
        "saveProfile":
            return {"ok": true}
        "enterHall":
            if fake_me["table_id"] == "":
                fake_me = {"table_id": "T1", "chair_no": 2}
                fake_seats["T1"].append({"openid": "fake_me", "chair_no": 2})
            var tables := []
            for tid in ["T1", "T2"]:
                tables.append({"id": tid, "reserved": tid == "T1" or tid == "T2", "seats": fake_seats.get(tid, [])})
            return {"ok": true, "data": {"me": fake_me, "tables": tables, "bench": [],
                "digest": {"toasts": [{"from": "fake_wang", "at": 0}], "toastCount": 1, "bookLineCount": 2, "hasNews": true},
                "names": fake_names}}
        "changeSeat":
            if fake_changed_today:
                return {"ok": false, "reason": "changed_today"}
            for tid in fake_seats:
                var arr: Array = fake_seats[tid]
                for i in range(arr.size() - 1, -1, -1):
                    if arr[i]["openid"] == "fake_me":
                        arr.remove_at(i)
            fake_me = {"table_id": data["table_id"], "chair_no": data["chair_no"]}
            if not fake_seats.has(data["table_id"]):
                fake_seats[data["table_id"]] = []
            fake_seats[data["table_id"]].append({"openid": "fake_me", "chair_no": data["chair_no"]})
            fake_changed_today = true
            return {"ok": true}
        "toast":
            return {"ok": true}
        "writeBook":
            return {"ok": true}
        "readBook":
            return {"ok": true, "data": {"lines": [{"openid": "fake_wang", "text": "新婚快乐", "created_at": 0}]}}
    return {"ok": false, "reason": "network"}
