extends RefCounted
## 迎宾院存在本机的东西（蓝图 2.4：喜糖领了、拍过照、大门开了、回忆册翻到哪页存本机，重进从上次的状态继续）。
## 签到名字、礼金数存服务器（saveProfile），这里只记「签过了」好让签到桌直接显示「已签到」，和断网时的草稿

const LOCAL := "user://suqi_court.json"

var local_path := LOCAL          # 测试里改成别的文件，别写进真存档
var welcomed := false            # 新娘妈妈在门口迎过了（只迎一次）
var signed_in := false           # 签过到了（服务端存成功才算）
var candy := false               # 喜糖收好了（签到后自动给，只弹一次）
var draft: Dictionary = {}       # 断网没交上的签到草稿 {name, gift}（蓝图 3.1 异常表：本机留草稿）
const PHOTO_KEEP := 3            # 合影最多留 3 张，旧的顶掉（蓝图 3.1 异常表）
var photos: Array = []           # 收好的相纸：[{pose, preset, at}]，只记怎么拍的，不存图（微信里不能读显卡截图）
var whisper_done := false        # 在宴会厅给新人写过悄悄话了：大门开不开看它和签到（蓝图 3.1「大门只在悄悄话写完后开」）
var gloss_seen := false          # 休息区老人那句的方言词弹过普通话了（只自动弹第一次，蓝图 3.1）
var door_hint := false           # 宴会厅东侧门的金光、箭头开了（第一次坐下或玩完第一个小游戏以后，01 E 10/3）
var backhall_seen := false       # 进过一次后厅了：东侧门的金光、箭头、进厅小卡那行「西边侧门通后厅」都收
var court_seen := false          # 进过一次迎宾院了（10/3 停车场起）：再开游戏不从停车场出生、停车场指大门的箭头不再出
var drive_seen := false          # 看过一次自动开车进山庄了（10/4 连图）：第二次起点一下屏幕能跳过

func load_local() -> void:
    if not FileAccess.file_exists(local_path):
        return
    var d = JSON.parse_string(FileAccess.get_file_as_string(local_path))
    if not d is Dictionary:
        return
    welcomed = bool(d.get("welcomed", false))
    signed_in = bool(d.get("signed_in", false))
    candy = bool(d.get("candy", false))
    var dr = d.get("draft", {})
    draft = dr if dr is Dictionary else {}
    var ph = d.get("photos", [])
    photos = ph if ph is Array else []
    whisper_done = bool(d.get("whisper_done", false))
    gloss_seen = bool(d.get("gloss_seen", false))
    door_hint = bool(d.get("door_hint", false))
    backhall_seen = bool(d.get("backhall_seen", false))
    court_seen = bool(d.get("court_seen", false))
    drive_seen = bool(d.get("drive_seen", false))

func save() -> void:
    var f := FileAccess.open(local_path, FileAccess.WRITE)
    if f == null:
        return
    f.store_string(JSON.stringify({"welcomed": welcomed, "signed_in": signed_in, "candy": candy, "draft": draft, "photos": photos,
        "whisper_done": whisper_done, "gloss_seen": gloss_seen, "door_hint": door_hint, "backhall_seen": backhall_seen,
        "court_seen": court_seen, "drive_seen": drive_seen}))
    f.close()

## 收好一张相纸：最多留 PHOTO_KEEP 张，多了把最早的顶掉
func keep_photo(pose: String, preset: int) -> void:
    photos.append({"pose": pose, "preset": preset, "at": int(Time.get_unix_time_from_system())})
    while photos.size() > PHOTO_KEEP:
        photos.pop_front()
    save()

## 进没进过迎宾院（10/3 停车场：进过的再开游戏不从停车场出生，照原来从迎宾院进；「中途退出再进来从哪开始」还在待讨论，先照这个）。
## 停车场以前的老存档没有 court_seen：迎过、签过到的也算进过
func seen_court() -> bool:
    return court_seen or welcomed or signed_in

## 大门开没开（蓝图 3.1、2.3）：写过悄悄话、也签过到。写了悄悄话没签到的，大门不开，新娘妈妈提醒先签到
func gate_open() -> bool:
    return whisper_done and signed_in
