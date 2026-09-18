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

func save() -> void:
    var f := FileAccess.open(local_path, FileAccess.WRITE)
    if f == null:
        return
    f.store_string(JSON.stringify({"welcomed": welcomed, "signed_in": signed_in, "candy": candy, "draft": draft, "photos": photos}))
    f.close()

## 收好一张相纸：最多留 PHOTO_KEEP 张，多了把最早的顶掉
func keep_photo(pose: String, preset: int) -> void:
    photos.append({"pose": pose, "preset": preset, "at": int(Time.get_unix_time_from_system())})
    while photos.size() > PHOTO_KEEP:
        photos.pop_front()
    save()
