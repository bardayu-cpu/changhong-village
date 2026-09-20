extends RefCounted
## 果园存在本机的（蓝图 3.6：每天每种只能摘一颗，本机记）：上次摘草莓、摘枇杷各是哪天。
## 只记日期，别的什么都不存——摘了没有奖励、不进背包、不上服务器

const LOCAL := "user://suqi_orchard.json"

var local_path := LOCAL      # 测试里改成别的文件，别写进这台机器上的真存档
var picked: Dictionary = {}  # 果子 -> 上次摘的日期（本地日期 2026-12-05 这样）

func load_local() -> void:
    if not FileAccess.file_exists(local_path):
        return
    var d = JSON.parse_string(FileAccess.get_file_as_string(local_path))
    if d is Dictionary:
        var p = d.get("picked", {})
        picked = p if p is Dictionary else {}

func save() -> void:
    var f := FileAccess.open(local_path, FileAccess.WRITE)
    if f == null:
        return
    f.store_string(JSON.stringify({"picked": picked}))
    f.close()

## 上次摘这种果子是哪天（没摘过是空串）
func picked_on(kind: String) -> String:
    return str(picked.get(kind, ""))

func mark(kind: String, day: String) -> void:
    picked[kind] = day
    save()
