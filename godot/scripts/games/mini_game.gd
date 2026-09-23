extends Control
## 席间小游戏的底子（蓝图 3.2，阿鱼 9/19 定）：六个游戏都继承它，由 game_host.gd 摆进游戏区、开始、收结果。
##
## 写一个新游戏要做的（照 g2048.gd）：
##   1. extends "res://scripts/games/mini_game.gd"
##   2. _build()：按 size（游戏区大小，host 已经设好）和 params（这一关的难度参数）搭棋盘
##   3. goal_text()：开始前那张卡上写的这一关目标，比如「合出 跷脚牛肉」「90 秒内连完」。
##      外壳是造一个只 setup、没 _build 的「探子」来读它的，所以只能读 params（p_int / p_float），别读 _build 里才赋值的成员
##   4. status_text()：玩的时候顶栏右边那一小行，比如「剩 45 秒」「还差 3 步」，每帧都会读
##      （要在那行放小图就再写 status_parts()，见下面；小菜合大菜用了）
##   5. 赢了调 win()，输了调 lose("为什么输")；计时放 _game_tick(dt)（暂停时 host 不调它）
##   6. 触摸：用 gui_input 收 InputEventMouseButton / InputEventMouseMotion（手机上触摸会转成鼠标事件），
##      或 InputEventScreenTouch / InputEventScreenDrag，两种都来的话别重复处理
## 随机数用 rng（host 给了种子，同一关每次开局不一样，但测试可以固定）
signal finished(won: bool, why: String)   # 这一关打完：赢了 why 是空的；输了 why 是给玩家看的一句

const Tiles = preload("res://scripts/games/tiles.gd")

var level := 1
var params: Dictionary = {}
var font: Font
var rng := RandomNumberGenerator.new()
## 这个游戏用哪一套菜牌图（minigames.json 每个游戏的 art_set，host 开局时塞进来）：
## shared 五个游戏共用那 12 张、ladder 小菜合大菜的成长阶梯、pattern 翻牌配对的喜庆纹样
var art_set := "shared"
var over := false            # 已经赢了或输了：不再收操作
var paused := false

func setup(p_level: int, p_params: Dictionary, p_font: Font, p_seed: int) -> void:
    level = p_level
    params = p_params
    font = p_font
    rng.seed = p_seed
    mouse_filter = Control.MOUSE_FILTER_STOP
    clip_contents = true

## host 把游戏区大小设好、加进树以后调
func start() -> void:
    _build()

func _process(dt: float) -> void:
    if over or paused:
        return
    _game_tick(dt)

func win() -> void:
    if over:
        return
    over = true
    finished.emit(true, "")

func lose(why: String) -> void:
    if over:
        return
    over = true
    finished.emit(false, why)

## 取一个整数参数（json 里 int=true 的也是 float 存的）
func p_int(name: String, fallback := 0) -> int:
    return int(params.get(name, fallback))

func p_float(name: String, fallback := 0.0) -> float:
    return float(params.get(name, fallback))

# ---------- 子类要写的 ----------
func _build() -> void:
    pass

func _game_tick(_dt: float) -> void:
    pass

func goal_text() -> String:
    return ""

func status_text() -> String:
    return ""

## 顶栏那行要放小图时用（B10，阿鱼 9/23「有图就别叠字」）：返回一串，每一项是字（String）或小图（Texture2D），
## 外壳从左到右摆、右对齐，图垫一层浅米色小牌底。**返回空数组就照旧写 status_text()**——五个游戏都不用管它。
## 每帧都会读；外壳只在内容变了才重摆
func status_parts() -> Array:
    return []

## 过关给多少金。-1 = 照奖励表（六个游戏里五个都这样）；接彩头是「接到的全拿走」，自己报
func won_coins() -> int:
    return -1

## 过关结算卡上多说的几句（接彩头的吉利话）；默认没有
func win_lines() -> Array:
    return []
