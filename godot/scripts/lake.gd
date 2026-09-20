extends "res://scripts/entrance.gd"
## 罗曼山庄 · 湖边（蓝图 3.5，灰盒，01 9/20 派任务 9）：湖占北半（不能走），栈道从南岸伸到湖里，尽头一座亭子；
## 南半是草坡和小路，几棵柳树、一条长凳。搭法、走路、交互点和迎宾院一样（entrance.gd，布局
## assets/layered/scene_luoman_lake/layout.json），这里多的是长凳能坐：
##   走到长凳旁出「坐下」（按钮在 lake_ui.gd），点一下人滑到凳子上、面朝湖换成坐姿，再点起来（蓝图 3.5 交互说明）。
##   镜头不做别的动作（不推远、不拉近），只照常跟着人；一推摇杆、一点地面就站起来（layered_hall 里本来的规矩）
## 亭子那句走进去自动出、走出去收，话在 assets/lake/lines.json，阿鱼写好之前是「【待补】」（蓝图 3.5 异常处理）

const BENCH_SEAT := Vector2(400, 700)    # 坐上去坐在哪（蓝图 3.5：长凳 (400, 700)）
const BENCH_STAND := Vector2(400, 738)   # 起来站在哪（凳子南边，能站）

func _init() -> void:
    layout_path = "res://assets/layered/scene_luoman_lake/layout.json"

## 坐到长凳上：滑过去（和宴会厅坐椅子一样 SIT_ANIM 秒），面朝湖（朝上），只画上半身
func sit() -> void:
    if seated:
        return
    path.clear()
    stick = Vector2.ZERO
    sit_from = pos
    sit_seat = BENCH_SEAT
    sit_t = 0.0
    face = "up"
    seated = true
    seat_front = false          # 按脚点排前后：靠背（在南边）画在人前面，看着像坐在凳子上
    seat_stand_spot = BENCH_STAND
