extends RefCounted
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
static func ensure(owner:Node,group:String) -> bool:
	var tree:=owner.get_tree()
	var loader=tree.root.get_node_or_null("VillageDownloads")
	if loader==null or loader.is_ready(group):return true
	if tree.root.get_meta("village_loading",false):return false
	tree.root.set_meta("village_loading",true)
	var layer:=CanvasLayer.new();layer.layer=100;owner.add_child(layer)
	var shade:=ColorRect.new();shade.color=Color(.1,.08,.05,.94);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(shade)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,28)
	shade.add_child(margin)
	var col:=VBoxContainer.new();col.size_flags_vertical=Control.SIZE_SHRINK_CENTER;col.theme=UI.theme();margin.add_child(col)
	var line:=UI.paragraph("正在准备这里的画…");col.add_child(line)
	var result:Dictionary=await loader.wait_group(group,func(i,n):line.text="正在准备这里的画… %d / %d"%[i,n])
	if not result.get("ok",false):
		line.text="这里的画还没下载好。已下载的会保留，稍后再点一次就能接着下。"
		var back:=UI.button("回去，稍后再试",func():layer.set_meta("closed",true));col.add_child(back);back.grab_focus()
		while not layer.get_meta("closed",false):await tree.process_frame
	layer.queue_free();tree.root.set_meta("village_loading",false)
	return result.get("ok",false)
