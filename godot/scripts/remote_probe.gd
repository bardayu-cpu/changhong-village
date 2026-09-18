extends RefCounted
## 远程加载的最小验证（HANDOFF §0.9，01 9/19 派；回执 godot/回执/远程加载-最小验证.md）。只证明路通，不是正式加载器：
##   本地 user:// 里有这张图（而且大小对）就直接读；没有就让微信那一层（wxgame/remote.js）从云存储下载、
##   用模板的 GODOTSDK.copy_to_fs 写进 user://，再在这边读出来、解码、传显卡。
## 每一步用时打进「[suqi] 远程加载」日志。哪张图、File ID 在 assets/remote_probe.json（阿鱼上传以后才有 File ID）。
## 只往显卡传图，不从显卡读回（微信禁用写法）。只有调试版的日志面板里有入口（main.gd 的 _run_remote_probe）

const MANIFEST := "res://assets/remote_probe.json"
const FETCH_TIMEOUT := 90.0   # 下载 2MB 的图，网慢时比云函数的 12 秒长得多

var file_id := ""
var local_path := "user://canvas/scene_roman_banquet/base.png"
var expect_bytes := 0

func _init() -> void:
    var cfg = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
    if cfg is Dictionary:
        file_id = str(cfg.get("file_id", ""))
        local_path = "user://" + str(cfg.get("path", "canvas/scene_roman_banquet/base.png"))
        expect_bytes = int(cfg.get("bytes", 0))

## 跑一遍。done.call(r)：r 里有 ok、downloaded（这次下载了没有）、texture（成功时）、text（给人看的一行）、reason（失败时）
func run(cloud: Node, done: Callable) -> void:
    var t0 := Time.get_ticks_msec()
    _log("开始 本地 %s → %s" % [local_path, ProjectSettings.globalize_path(local_path)])
    if FileAccess.file_exists(local_path):
        var t_read := Time.get_ticks_msec()
        var bytes := FileAccess.get_file_as_bytes(local_path)
        var read_ms := Time.get_ticks_msec() - t_read
        if expect_bytes > 0 and bytes.size() != expect_bytes:
            _log("本地副本大小不对（%d 字节，应是 %d），删掉重下" % [bytes.size(), expect_bytes])
            DirAccess.remove_absolute(local_path)
        else:
            _log("本地有，不下载；读本地 %d 毫秒 %d 字节" % [read_ms, bytes.size()])
            var r := _decode(bytes, t0, false, "读本地 %d 毫秒" % read_ms)
            if bool(r["ok"]):
                done.call(r)
                return
            _log("本地副本解不开，删掉重下")
            DirAccess.remove_absolute(local_path)
    if file_id == "":
        _log("本地没有，也还没填 File ID（assets/remote_probe.json）")
        done.call({"ok": false, "downloaded": false, "reason": "no_file_id",
            "text": "还没填 File ID：等阿鱼把图传到云存储"})
        return
    var abs_path := ProjectSettings.globalize_path(local_path)
    _log("本地没有，去云存储下载")
    cloud.call_fn("@fetchFile", {"fileID": file_id, "path": abs_path}, func(r): _on_fetched(r, t0, done), FETCH_TIMEOUT)

func _on_fetched(r: Dictionary, t0: int, done: Callable) -> void:
    var bridge_ms := Time.get_ticks_msec() - t0
    if not bool(r.get("ok", false)):
        var why := "%s %s" % [str(r.get("reason", "network")), str(r.get("detail", ""))]
        _log("下载失败 %s（等了 %d 毫秒）" % [why, bridge_ms])
        done.call({"ok": false, "downloaded": false, "reason": str(r.get("reason", "network")), "text": "下载失败：" + why})
        return
    var jsline := "下载 %d 毫秒 读临时文件 %d 毫秒 写进 user:// %d 毫秒 %d 字节" % [
        int(r.get("download_ms", 0)), int(r.get("read_ms", 0)), int(r.get("write_ms", 0)), int(r.get("bytes", 0))]
    _log(jsline + "，桥来回共 %d 毫秒" % bridge_ms)
    if not FileAccess.file_exists(local_path):
        _log("写完了这边却看不到 %s" % local_path)
        done.call({"ok": false, "downloaded": true, "reason": "not_visible", "text": "写进去了但 Godot 看不到文件"})
        return
    var t_read := Time.get_ticks_msec()
    var bytes := FileAccess.get_file_as_bytes(local_path)
    var read_ms := Time.get_ticks_msec() - t_read
    _log("读回 %d 毫秒 %d 字节" % [read_ms, bytes.size()])
    if expect_bytes > 0 and bytes.size() != expect_bytes:
        # 云存储上的文件和清单对不上（比如底图重新烘过、传的是新图）：这次照样显示，但下次会被当成坏副本重下
        _log("注意：下载下来 %d 字节，清单写的是 %d 字节，清单要跟着改" % [bytes.size(), expect_bytes])
    done.call(_decode(bytes, t0, true, "下载 %d 毫秒" % int(r.get("download_ms", 0))))

## 解码、传显卡，量用时。按扩展名挑解码器：真机上 PNG 以外的能不能解还没验证
func _decode(bytes: PackedByteArray, t0: int, downloaded: bool, head: String) -> Dictionary:
    var t_dec := Time.get_ticks_msec()
    var img := Image.new()
    var err := ERR_FILE_UNRECOGNIZED
    match local_path.get_extension().to_lower():
        "png": err = img.load_png_from_buffer(bytes)
        "jpg", "jpeg": err = img.load_jpg_from_buffer(bytes)
        "webp": err = img.load_webp_from_buffer(bytes)
    var dec_ms := Time.get_ticks_msec() - t_dec
    if err != OK or img.is_empty():
        _log("解码失败 错误 %d（%d 字节）" % [err, bytes.size()])
        return {"ok": false, "downloaded": downloaded, "reason": "decode_failed", "text": "图解不开（错误 %d）" % err}
    var t_gpu := Time.get_ticks_msec()
    var tex := ImageTexture.create_from_image(img)
    var gpu_ms := Time.get_ticks_msec() - t_gpu
    var total := Time.get_ticks_msec() - t0
    var text := "%s，解码 %d 毫秒，传显卡 %d 毫秒，共 %d 毫秒，%dx%d（%s）" % [
        head, dec_ms, gpu_ms, total, img.get_width(), img.get_height(), "这次下载了" if downloaded else "读的本地，没下载"]
    _log("解码 %d 毫秒 传显卡 %d 毫秒 %dx%d，完成 共 %d 毫秒（%s）" % [
        dec_ms, gpu_ms, img.get_width(), img.get_height(), total, "这次下载了" if downloaded else "读的本地，没下载"])
    return {"ok": true, "downloaded": downloaded, "texture": tex, "text": text}

## 删掉本地副本：再点「远程加载」就会重新下载，方便反复验下载那一路
func clear_local() -> bool:
    if not FileAccess.file_exists(local_path):
        return false
    var err := DirAccess.remove_absolute(local_path)
    _log("删掉本地副本 %s 结果 %d" % [local_path, err])
    return err == OK

static func _log(s: String) -> void:
    print("[suqi] 远程加载 " + s)
