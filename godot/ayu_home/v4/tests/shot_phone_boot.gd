extends SceneTree
## 截手机开头那页（下载到一半的样子），540×960：版本号、那句话、进度条、几个/几个
class Boot extends "res://ayu_home/v4/phone_boot.gd":
	func start() -> void:
		line.text="第一次要下载阿鱼家的画\n要等几分钟，下完以后就不用等了";done=62;total=166;count.text="62 / 166";bar.queue_redraw()
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var out:="";for a in OS.get_cmdline_user_args():if a.begins_with("--out="):out=a.substr(6)
	var b:=Boot.new();root.add_child(b)
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out);print("SHOT");quit()
