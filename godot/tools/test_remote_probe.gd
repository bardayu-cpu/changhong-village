extends SceneTree
## 验收：远程加载的最小验证，Godot 这一半（scripts/remote_probe.gd，HANDOFF §0.9）。无界面跑。
## 电脑上没有微信层，下载走 cloud.gd 的假 @fetchFile（从工程里拷 assets/remote_probe.json 的 source）；
## 微信那一半（wxgame/remote.js、cloud.js 的 @ 转发）用 node 测：node tools/test_remote_js.js
## 用法：Godot --headless --path . --script res://tools/test_remote_probe.gd
## 最后一行 RESULT PASS 才算过

const Cloud = preload("res://scripts/cloud.gd")
const Probe = preload("res://scripts/remote_probe.gd")

var ok := true

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

## 跑一遍，等回调（假数据是同步回的，这里照样按回调写）
func probe_once(c: Node, file_id := "cloud://test-env.test-bucket/canvas/scene_roman_banquet/base.png") -> Dictionary:
    var box := {}
    var p = Probe.new()
    p.file_id = file_id
    p.run(c, func(r): box["r"] = r)
    return box.get("r", {})

func _init() -> void:
    var c: Node = Cloud.new()
    c._ready()
    var p0 = Probe.new()
    var local: String = p0.local_path
    print("本地副本放在 ", local, " → ", ProjectSettings.globalize_path(local))

    # 0. 清场：删掉上次测试留下的本地副本
    p0.clear_local()
    check("开始前本地没有", not FileAccess.file_exists(local))
    check("清单里写了图的大小", p0.expect_bytes > 0)

    # 1. 还没填 File ID（阿鱼还没上传）：不下载，说清楚还没填
    print("1 还没填 File ID")
    var r0 := probe_once(c, "")
    check("回 no_file_id：" + str(r0.get("text", "")), str(r0.get("reason", "")) == "no_file_id" and c.fake_fetch_count == 0)

    # 2. 第一次：本地没有，下载、写进 user://、解码成图
    print("2 第一次打开")
    var r1 := probe_once(c)
    var tex1 = r1.get("texture", null)
    check("成功：" + str(r1.get("text", "")), bool(r1.get("ok", false)))
    check("这次下载了（下载 1 次）", bool(r1.get("downloaded", false)) and c.fake_fetch_count == 1)
    check("本地有了、大小对", FileAccess.file_exists(local) and FileAccess.get_file_as_bytes(local).size() == p0.expect_bytes)
    check("有图 1536x1024", tex1 is Texture2D and tex1.get_width() == 1536 and tex1.get_height() == 1024)

    # 3. 第二次打开（新的一次，照样先看本地）：读本地，不再下载
    print("3 第二次打开")
    var r2 := probe_once(c)
    check("成功：" + str(r2.get("text", "")), bool(r2.get("ok", false)))
    check("没下载（下载次数还是 1）", not bool(r2.get("downloaded", true)) and c.fake_fetch_count == 1)
    check("说的是读本地", str(r2.get("text", "")).contains("读的本地"))

    # 4. 本地副本不完整（比如写到一半被关掉）：大小不对，删掉重下
    print("4 本地副本不完整")
    var f := FileAccess.open(local, FileAccess.WRITE)
    f.store_buffer(PackedByteArray([1, 2, 3]))
    f.close()
    var r3 := probe_once(c)
    check("重下成功", bool(r3.get("ok", false)) and bool(r3.get("downloaded", false)) and c.fake_fetch_count == 2)

    # 5. 本地副本大小对但解不开：删掉重下
    print("5 本地副本解不开")
    var junk := PackedByteArray()
    junk.resize(p0.expect_bytes)
    f = FileAccess.open(local, FileAccess.WRITE)
    f.store_buffer(junk)
    f.close()
    var r4 := probe_once(c)
    check("重下成功", bool(r4.get("ok", false)) and bool(r4.get("downloaded", false)) and c.fake_fetch_count == 3)

    # 6. 下载失败：说清原因，不留坏的本地副本
    print("6 下载失败")
    p0.clear_local()
    c.fake_fetch_fail = "download_failed"
    var r5 := probe_once(c)
    check("回失败原因：" + str(r5.get("text", "")), not bool(r5.get("ok", true)) and str(r5.get("reason", "")) == "download_failed")
    check("本地没留东西", not FileAccess.file_exists(local))
    c.fake_fetch_fail = ""

    # 7. 删掉本地副本那个按钮
    print("7 删掉本地副本")
    probe_once(c)
    check("删之前有", FileAccess.file_exists(local))
    check("删掉了", p0.clear_local() and not FileAccess.file_exists(local))
    check("再删说没有", not p0.clear_local())

    # 8. 等多久算没连上：@fetchFile 给 90 秒，普通云函数还是 12 秒
    print("8 超时")
    check("下载给的比云函数长", Probe.FETCH_TIMEOUT > Cloud.TIMEOUT)

    # 收尾：本地副本上面删过了，空目录也收掉（这是本机 Godot 给这个游戏的 user:// 目录）
    DirAccess.remove_absolute(local.get_base_dir())
    DirAccess.remove_absolute(local.get_base_dir().get_base_dir())
    c.free()
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
