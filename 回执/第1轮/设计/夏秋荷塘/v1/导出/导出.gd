extends SceneTree
const D="/Users/kayra_ayu/Desktop/苏七镇奇缘/cursor-claude-1010/裳泓村/回执/第1轮/设计/夏秋荷塘/v1/"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(D+"assets")
	var exports=[
		["夏荷-透明源图-v1.png","lotus-summer-v1.png",Rect2i(132,119,1709,569),Vector2i(265,88)],
		["盛夏花带-透明源图-v1.png","flowers-summer-v1.png",Rect2i(62,99,1741,698),Vector2i(80,32)],
		["盛夏树冠-透明源图-v1.png","crown-summer-v1.png",Rect2i(2,25,1394,1060),Vector2i(180,137)],
		["盛夏麦田-源图-v1.png","wheat-summer-v1.png",Rect2i(0,0,2066,761),Vector2i(585,215)]
	]
	for spec in exports:
		var original=Image.load_from_file(D+spec[0])
		if original==null:push_error("Missing source "+spec[0]);quit(1);return
		var export=original.get_region(spec[2]);export.resize(spec[3].x,spec[3].y,Image.INTERPOLATE_NEAREST)
		var err=export.save_png(D+"assets/"+spec[1])
		if err!=OK:push_error("Export failed "+spec[1]);quit(1);return
	print("4 generated assets mechanically cropped/resized nearest; source images and alpha preserved.")
	quit()
