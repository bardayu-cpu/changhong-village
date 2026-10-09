extends "res://scripts/entrance.gd"
## 后厅的空起点（01 D 10/1 派：后厅厨房整块交给 GPT 试接手，GPT 从这儿开始搭）：一块空地 + 两个出口，别的什么都没有。
## 走路、镜头、交互点、出入口都是迎宾院那一套（entrance.gd），只换布局 assets/layered/scene_backhall_start/layout.json。
## main.gd 默认搭灰盒后厅（backhall.gd）；启动参数带 --backhall=start 才搭这块（见 main.gd 的 backhall_script）

func _init() -> void:
    layout_path = "res://assets/layered/scene_backhall_start/layout.json"
