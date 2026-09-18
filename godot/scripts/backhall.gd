extends "res://scripts/entrance.gd"
## 罗曼山庄 · 后厅（蓝图 3.3，灰盒，01 9/19 派任务 7）：宴会楼后面，南边一条走廊，四个房间一字排开、门朝南，像剖开的房子。
## 全部代码画的占位（assets/layered/scene_luoman_backhall/layout.json），搭法、走路、交互点进出信号都和迎宾院一样（entrance.gd），
## 只换布局。西口回宴会厅、东口是厨房后门去草坪（草坪没做，出「还没修好」）；四个房间各一句话，按钮在 backhall_ui.gd

func _init() -> void:
    layout_path = "res://assets/layered/scene_luoman_backhall/layout.json"
