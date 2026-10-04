extends Node
## 小船起伏（05 10/4，01 H 派）：船的图整格往上提 1 像素、再放回来，一上一下各停一会儿，每条船节奏错开。
## 只挪图（offset），不挪着地线（position.y），跟人排前后不变；不多画，船本来就在画。档位 0（全关）停在原位

var boats: Array = []      # 每条：{"s": Sprite2D, "y": 原来的 offset.y, "half": 一上一下各几秒, "t0": 错开多少秒}
var amb: Script
var _t := 0.0

func setup(sprites: Array, g: Dictionary) -> void:
    amb = load("res://scripts/ambient/ambient.gd")
    var pr: Array = g.get("period", [1.6, 2.4])
    var rng := RandomNumberGenerator.new()
    rng.seed = 1004
    for s in sprites:
        var per := rng.randf_range(float(pr[0]), float(pr[1]))
        boats.append({"s": s, "y": s.offset.y, "half": per / 2.0, "t0": rng.randf() * per})

## 第 i 条船这一刻往上提几像素（0 或 1）
func lift_of(i: int, t: float) -> int:
    if amb.level <= 0:
        return 0
    var b: Dictionary = boats[i]
    return int(floor((t + float(b["t0"])) / float(b["half"]))) % 2

func _process(dt: float) -> void:
    _t += dt
    for i in boats.size():
        var b: Dictionary = boats[i]
        var s: Sprite2D = b["s"]
        var want := float(b["y"]) - float(lift_of(i, _t))
        if s.offset.y != want:
            s.offset.y = want
