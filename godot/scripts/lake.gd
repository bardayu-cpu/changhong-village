extends "res://scripts/entrance.gd"
## 罗曼山庄 · 湖边（蓝图 3.5，灰盒，01 9/20 派任务 9；10/3 阿鱼改成一条往西延伸的长湖岸，东头照效果图 2、西头照翻转的效果图 1，
## 西头月亮门出去是停车场）：湖占北半（不能走），东头一座曲桥通到湖心亭；湖岸一条石板小路连着东西两头，一条长凳朝湖。搭法、走路、交互点和迎宾院一样（entrance.gd，布局
## assets/layered/scene_luoman_lake/layout.json），这里多的是长凳能坐：
##   走到长凳旁出「坐下」（按钮在 lake_ui.gd），点一下人滑到凳子上、面朝湖换成坐姿，再点起来（蓝图 3.5 交互说明）。
##   镜头不做别的动作（不推远、不拉近），只照常跟着人；一推摇杆、一点地面就站起来（layered_hall 里本来的规矩）
## 亭子那句走进去自动出、走出去收，话在 assets/lake/lines.json，阿鱼写好之前是「【待补】」（蓝图 3.5 异常处理）

## 长凳坐哪、起来站哪、从果园过来站哪：照布局（10/3 长湖岸以后长凳挪了，tools/layout_court/make_lake_long.py 出）。
## 布局没写的照第一版（蓝图 3.5：长凳 (400, 700)；9/20 加高，玩法区 +256）
var BENCH_SEAT := Vector2(400, 956)     # 坐上去坐在哪（东头那张，交互点 bench）
var BENCH_STAND := Vector2(400, 994)    # 起来站在哪（凳子南边，能站）
var FROM_ORCHARD := Vector2.ZERO        # 从果园 A 走西头月亮门进来站在哪（10/4 西半边接图前叫 FROM_PARKING，通停车场）
## 10/4 西半边接图（01 G 派）：两张长凳都能坐。交互点 id → {坐哪, 起来站哪}；东头 bench（bench_seat / bench_stand），西半边 bench_w（bench_seat_w / bench_stand_w）
var benches := {}
var bench_id := "bench"                 # 现在站在哪张长凳旁边（lake_ui 走进长凳交互点时设）

func _init() -> void:
    layout_path = "res://assets/layered/scene_luoman_lake/layout.json"

func build(preset: int, nickname: String, f: Font) -> void:
    super(preset, nickname, f)
    if cfg.has("bench_seat"):
        BENCH_SEAT = Vector2(cfg["bench_seat"][0], cfg["bench_seat"][1])
    if cfg.has("bench_stand"):
        BENCH_STAND = Vector2(cfg["bench_stand"][0], cfg["bench_stand"][1])
    if cfg.has("from_orchard"):
        FROM_ORCHARD = Vector2(cfg["from_orchard"][0], cfg["from_orchard"][1])
    benches["bench"] = {"seat": BENCH_SEAT, "stand": BENCH_STAND}
    if cfg.has("bench_seat_w") and cfg.has("bench_stand_w"):
        benches["bench_w"] = {"seat": Vector2(cfg["bench_seat_w"][0], cfg["bench_seat_w"][1]), "stand": Vector2(cfg["bench_stand_w"][0], cfg["bench_stand_w"][1])}

## 坐到长凳上：滑过去（和宴会厅坐椅子一样 SIT_ANIM 秒），面朝湖（朝上），只画上半身
func sit() -> void:
    if seated:
        return
    path.clear()
    stick = Vector2.ZERO
    sit_from = pos
    var bn: Dictionary = benches.get(bench_id, {"seat": BENCH_SEAT, "stand": BENCH_STAND})
    sit_seat = bn["seat"]
    sit_t = 0.0
    face = "up"
    seated = true
    seat_front = false          # 按脚点排前后：靠背（在南边）画在人前面，看着像坐在凳子上
    seat_stand_spot = bn["stand"]
