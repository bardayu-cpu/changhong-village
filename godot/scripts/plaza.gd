extends "res://scripts/entrance.gd"
## 罗曼山庄 · 喷泉雕塑广场（蓝图 v0.3 第 1.0 节新总图第 ② 步，阿鱼 10/4「行」；01 F 派）：山庄正中一块空地，正中喷泉雕塑，
## 四周通各处：东口去迎宾院（新总图的迎宾厅）、西口去草坪、南口去后厅走廊；北边三个口（儿童乐园、小卖部、休息区）还没做，
## 走过去说一句还在布置（main.gd 的 _on_plaza_spot，话在 assets/plaza/lines.json）。
## 搭法、走路、交互点和迎宾院一样（entrance.gd），布局 assets/layered/scene_luoman_plaza/layout.json（tools/layout_court/make_plaza.py 出）

var FROM_COURT := Vector2.ZERO       # 从迎宾院西口过来站哪
var FROM_LAWN := Vector2.ZERO        # 从草坪过来站哪
var FROM_BACKHALL := Vector2.ZERO    # 从后厅走廊过来站哪

func _init() -> void:
    layout_path = "res://assets/layered/scene_luoman_plaza/layout.json"

func build(preset: int, nickname: String, f: Font) -> void:
    super(preset, nickname, f)
    for k in ["from_court", "from_lawn", "from_backhall"]:
        var v: Vector2 = Vector2(cfg[k][0], cfg[k][1]) if cfg.has(k) else SPAWN
        set(k.to_upper(), v)
