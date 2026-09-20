extends "res://scripts/entrance.gd"
## 罗曼山庄 · 草坪（蓝图 3.4，灰盒，01 9/19 派任务 8）：整块草地；东北角孩童玩闹区（秋千、滑梯、两个小孩）；
## 西北角草坪婚礼拱门和几排白椅子（预留，阶段 1 没人、没交互）；小路从西南口到北口、西北口横过来；四周是树。
## 搭法、走路、交互点和迎宾院一样（entrance.gd，布局 assets/layered/scene_luoman_lawn/layout.json），这里多的是踢球：
## 只在本机，不计数、不上服务器，踢几次都行（蓝图 3.4 功能需求）。
##   走到球旁 60 像素出「踢一脚」（按钮在 lawn_ui.gd，这里发 spot("ball", 进没进)）；球朝人面朝的方向滚 1 秒停住，先快后慢；
##   滚不出草坪、滚进东西的占地都弹回上一格停住（蓝图 3.4 交互说明、异常处理；草坪边上和东西四周都是不能走的格子，一个规矩）；
##   停了喜多跑过去叼起来，放回人脚前；人在走的话叼着跟着，人停下才放；喜多走不过去就直接出现在球旁，回来的路走不通就直接出现在人跟前。
##   第一次走近（离球 GREET_R 以内），喜多叼着球跑过来放下（用户故事）。离开这块画布球和喜多回起始点（main 调 reset_ball）。
## 喜多把球放回脚边时发 fetched(是不是踢完球回来的)：踢完那一次 main 让孩童区的小孩喊一句「再踢一个」（蓝图 3.4 用户故事的顺序，01 9/20 定）
signal fetched(after_kick: bool)

const BALL_START := Vector2(760, 580)    # 蓝图 3.4：球 (760, 580)
const DOG_START := Vector2(700, 540)     # 蓝图 3.4：喜多 (700, 540)
const BALL_NEAR := 60.0                  # 走到球旁多近出「踢一脚」（蓝图 3.4 交互点 ball：球的当前位置，半径 60）
const ROLL_SECS := 1.0                   # 球滚 1 秒停住（蓝图 3.4）
const ROLL_M := 4.0                      # 一脚滚多远，米；左右 1 米 48 像素、前后 1 米 32 像素（蓝图开头的坐标约定）
const STEP := 4.0                        # 球每次最多挪几像素就查一次格子，帧卡的时候也不会一下跨过窄东西
const GREET_R := 240.0                   # 人走到离球这么近，喜多叼着球跑过来（每回到草坪一次）
const DOG_SPEED_M := 4.5                 # 喜多跑多快，米/秒（比人快一点）
const DROP_AHEAD := 30.0                 # 球放在人脚前面多远，下一脚好踢
const RETARGET := 40.0                   # 喜多叼着球往回跑时，人走开这么远就改道
const FACE_DIR := {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}

var ball: Node2D
var ball_spin: Node2D
var ball_pos := BALL_START
var ball_state := "rest"      # rest 停着、roll 在滚、held 喜多叼着
var roll_vec := Vector2.ZERO  # 这一脚一共滚多远（方向 × 长度）
var roll_t := 0.0
var bounced := false          # 这一脚是撞到东西弹回来停的（测试看）
var dog: Sprite2D
var dog_pos := DOG_START
var dog_state := "idle"       # idle 待着、to_ball 去叼球、to_player 叼回来
var dog_path: Array = []
var dog_anim := 0.0
var dog_right := true         # 喜多朝右（图是朝右画的）
var dog_jumped := 0           # 喜多被挡住、直接出现过几次（测试看）
var drop_at := Vector2.ZERO   # 这次把球放在哪
var drop_for := Vector2.ZERO  # 算 drop_at 的时候人站在哪：人走开了（RETARGET 以外）喜多跟着改道，放到人现在的脚边
var retarget_t := 0.0
var greeted := false          # 这次来草坪，喜多迎过了
var ball_near := false        # 「踢一脚」现在出着没有（spot("ball") 的进出）
var kicks := 0                # 这次踢了几脚：只给测试看，不上服务器，不限次数
var fetch_after_kick := false # 这趟叼球是踢完球去叼的（不是第一次迎人）

func _init() -> void:
    layout_path = "res://assets/layered/scene_luoman_lawn/layout.json"

func build(preset: int, nickname: String, f: Font) -> void:
    super(preset, nickname, f)
    _make_ball()
    _make_dog()
    reset_ball()

# ---------- 球和喜多的样子（灰盒占位，代码画的） ----------
func _make_ball() -> void:
    ball = Node2D.new()
    ball.name = "ball"
    ball.add_child(_poly(_ellipse_pts(0, 0, 7, 2.5, 12), Color(0, 0, 0, 0.25)))
    ball.add_child(_poly(_ellipse_pts(0, -6, 6.8, 6.8, 16), Color("#26202c")))
    ball.add_child(_poly(_ellipse_pts(0, -6, 6, 6, 16), Color("#f4f1ea")))
    ball_spin = Node2D.new()
    ball_spin.position = Vector2(0, -6)
    for a in [0.0, 2.1, 4.2]:
        ball_spin.add_child(_poly(_ellipse_pts(cos(a) * 3.0, sin(a) * 3.0, 1.6, 1.6, 6), Color("#26202c")))
    ball.add_child(ball_spin)
    world.add_child(ball)

func _make_dog() -> void:
    dog = Sprite2D.new()
    dog.name = "xiduo"
    dog.texture = ImageTexture.create_from_image(Spr.corgi_sheet())
    dog.hframes = 3
    dog.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    dog.centered = true
    dog.offset = Vector2(0, -float(Spr.CORGI_H) * 0.5)   # 原点在脚底
    dog.scale = Vector2(2, 2)
    world.add_child(dog)

## 球、喜多回起始点（离开草坪、刚到草坪时 main 调；蓝图 3.4「玩家离开画布时球回到起始点」）
func reset_ball() -> void:
    ball_pos = BALL_START
    ball_state = "rest"
    roll_t = 0.0
    bounced = false
    dog_pos = DOG_START
    dog_state = "idle"
    dog_path.clear()
    dog_right = true
    greeted = false
    ball_near = false
    _place()

# ---------- 踢球 ----------
## 能不能踢：球停着、喜多没在跑、人在球旁 BALL_NEAR 以内
func can_kick() -> bool:
    return ball_state == "rest" and dog_state == "idle" and pos.distance_to(ball_pos) < BALL_NEAR

## 踢一脚：朝人面朝的方向滚 ROLL_SECS 秒（先快后慢），停了喜多去叼
func kick() -> void:
    if not can_kick():
        return
    var d: Vector2 = FACE_DIR.get(face, Vector2(0, 1))
    roll_vec = Vector2(d.x * ROLL_M * 48.0, d.y * ROLL_M * 32.0)
    roll_t = 0.0
    bounced = false
    ball_state = "roll"
    kicks += 1
    print("[suqi] 草坪 踢了一脚 朝 ", face)

func _roll(dt: float) -> void:
    if ball_state != "roll":
        return
    var t0 := roll_t
    roll_t = minf(roll_t + dt, ROLL_SECS)
    var move := roll_vec * (_ease(roll_t / ROLL_SECS) - _ease(t0 / ROLL_SECS))
    var n := maxi(1, int(ceil(move.length() / STEP)))
    for i in n:
        var nxt := ball_pos + move / float(n)
        if not _free(nxt):
            # 滚进东西的占地、或者到了草坪边上：弹回上一格停住（这一格的中心，一定能站）
            ball_pos = _cell_pos(_cell_of(ball_pos))
            bounced = true
            _stop_roll()
            return
        ball_pos = nxt
    var sgn := signf(roll_vec.x) if absf(roll_vec.x) > 0.0 else signf(roll_vec.y)
    ball_spin.rotation += move.length() / 6.0 * sgn
    if roll_t >= ROLL_SECS:
        _stop_roll()

## 先快后慢：滚到最后正好停住
static func _ease(k: float) -> float:
    return 1.0 - (1.0 - k) * (1.0 - k)

func _stop_roll() -> void:
    ball_state = "rest"
    fetch_after_kick = true
    _fetch()

# ---------- 喜多 ----------
## 去叼球：沿能走的格子跑过去；走不到（被挡住）就直接出现在球旁（蓝图 3.4 异常处理）
func _fetch() -> void:
    dog_state = "to_ball"
    dog_path = find_path(dog_pos, ball_pos)
    if dog_path.is_empty() or (dog_path[dog_path.size() - 1] as Vector2).distance_to(ball_pos) > 14.0:
        dog_pos = _beside(ball_pos)
        dog_path.clear()
        dog_jumped += 1
        _pick_up()

## 叼起来，跑回人跟前；回来的路走不通就直接出现在那儿
func _pick_up() -> void:
    ball_state = "held"
    dog_state = "to_player"
    _aim_home()

## 往回跑的目标：人脚前 DROP_AHEAD（那儿不能站就放人脚下），喜多站在球的另一边面朝人放下。
## 人在走的话喜多叼着跟着（_dog 里人走开 RETARGET 就再算一次），人停下才放；路走不通就直接出现在那儿
func _aim_home() -> void:
    retarget_t = 0.0
    var d: Vector2 = FACE_DIR.get(face, Vector2(0, 1))
    drop_for = pos
    drop_at = pos + d * DROP_AHEAD
    if not _free(drop_at):
        drop_at = _cell_pos(_nearest_free(_cell_of(pos))) if not _free(pos) else pos
    var goal := drop_at + d * 26.0
    if not _free(goal):
        goal = drop_at
    dog_path = find_path(dog_pos, goal)
    if dog_path.is_empty():
        dog_pos = goal
        dog_jumped += 1

## 人在走（点了地面还没走到、或者推着摇杆）
func _player_moving() -> bool:
    return not path.is_empty() or stick.length() > 0.15

func _drop() -> void:
    ball_pos = drop_at
    ball_state = "rest"
    dog_state = "idle"
    dog_path.clear()
    if absf(pos.x - dog_pos.x) > 1.0:
        dog_right = pos.x > dog_pos.x    # 放下以后朝着人
    fetched.emit(fetch_after_kick)
    fetch_after_kick = false

## 挨着某点的一个能站的地方（先试左边、右边、上下，都不行就找最近的空格）
func _beside(p: Vector2) -> Vector2:
    for off in [Vector2(-22, 0), Vector2(22, 0), Vector2(0, 16), Vector2(0, -16)]:
        if _free(p + off):
            return p + off
    return _cell_pos(_nearest_free(_cell_of(p)))

func _dog(dt: float) -> void:
    var moving := false
    if dog_state == "to_player":
        retarget_t += dt
        if retarget_t >= 0.25 and pos.distance_to(drop_for) > RETARGET:
            _aim_home()
    if dog_state != "idle":
        if dog_path.is_empty():
            if dog_state == "to_ball":
                _pick_up()
            elif dog_state == "to_player" and not _player_moving():
                # 到了、人也停下了：人停的地方和上次算的一样就放，挪过一点就再跑两步，放在他现在的脚前
                if pos.distance_to(drop_for) > 4.0:
                    _aim_home()
                else:
                    _drop()
        else:
            var tgt: Vector2 = dog_path[0]
            var to := tgt - dog_pos
            var dist := to.length()
            var speed := DOG_SPEED_M * px_per_m(dog_pos.y)
            if dist < 2.0:
                dog_pos = tgt
                dog_path.pop_front()
            else:
                dog_pos += to / dist * minf(dist, speed * dt)
                moving = true
                if absf(to.x) > 0.5:
                    dog_right = to.x > 0.0
    dog_anim = dog_anim + dt if moving else 0.0
    dog.frame = (1 + int(dog_anim * 10.0) % 2) if moving else 0

## 球、喜多画到现在的位置：叼着的球在喜多嘴上（盖在喜多前面）
func _place() -> void:
    dog.position = dog_pos
    dog.flip_h = not dog_right
    if ball_state == "held":
        ball.position = dog_pos + Vector2(18.0 if dog_right else -18.0, -10.0)
        ball.z_index = 1
    else:
        ball.position = ball_pos
        ball.z_index = 0

func _process(dt: float) -> void:
    super(dt)
    # 第一次走近：喜多叼着球跑过来放下（用户故事）
    if not greeted and ball_state == "rest" and dog_state == "idle" and pos.distance_to(ball_pos) < GREET_R:
        greeted = true
        fetch_after_kick = false
        _fetch()
    _roll(dt)
    _dog(dt)
    _place()
    var near := can_kick()
    if near != ball_near:
        ball_near = near
        spot.emit("ball", near)
