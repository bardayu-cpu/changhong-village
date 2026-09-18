extends RefCounted
## 迎宾院的话（蓝图 3.1）：全在 assets/entrance/lines.json，改文案只改那份 json，不用改代码

const PATH := "res://assets/entrance/lines.json"

static var _d: Dictionary = {}

static func _lines() -> Dictionary:
    if _d.is_empty():
        var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        _d = d if d is Dictionary else {"lines": {}}
    return _d.get("lines", {})

## 这句话的字；没有这条就原样返回 key（一眼看得出漏了哪条）
static func text(key: String) -> String:
    return str((_lines().get(key, {}) as Dictionary).get("text", key))

## 谁说的：「新娘妈妈」「新娘爸爸」「摄影师」「老人」；空的是提示框
static func who(key: String) -> String:
    return str((_lines().get(key, {}) as Dictionary).get("who", ""))

static func has(key: String) -> bool:
    return _lines().has(key)
