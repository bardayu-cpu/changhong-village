extends RefCounted
## 迎宾院的话（蓝图 3.1）：全在 assets/entrance/lines.json，改文案只改那份 json，不用改代码。
## 后厅（蓝图 3.3）、草坪（蓝图 3.4）的在 assets/backhall/、assets/lawn/ 的 lines.json，读法一样，多传一个 path

const PATH := "res://assets/entrance/lines.json"
const BACKHALL := "res://assets/backhall/lines.json"
const LAWN := "res://assets/lawn/lines.json"

static var _d: Dictionary = {}   # 文件路径 -> 那份的 lines

static func _lines(path := PATH) -> Dictionary:
    if not _d.has(path):
        var d = JSON.parse_string(FileAccess.get_file_as_string(path))
        _d[path] = d.get("lines", {}) if d is Dictionary else {}
    return _d[path]

## 这句话的字；没有这条就原样返回 key（一眼看得出漏了哪条）
static func text(key: String, path := PATH) -> String:
    return str((_lines(path).get(key, {}) as Dictionary).get("text", key))

## 谁说的：「新娘妈妈」「新娘爸爸」「摄影师」「老人」「长辈」「厨师」「小孩」；空的是提示框
static func who(key: String, path := PATH) -> String:
    return str((_lines(path).get(key, {}) as Dictionary).get("who", ""))

static func has(key: String, path := PATH) -> bool:
    return _lines(path).has(key)
