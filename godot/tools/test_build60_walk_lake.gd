extends "res://tools/walk60_core.gd"
## 第 60 版走路测试拆小：只测「lake」这一块（03 10/5：原来整份单跑 7～8 分钟，超过全套里每份 5 分钟的上限）。内容、判断条件都在 walk60_core.gd，这里只指定块
## 用法：Godot --headless --path . --script res://tools/test_build60_walk_lake.gd     最后一行 RESULT PASS 才算过

func _initialize() -> void:
    only = "lake"
    super._initialize()
