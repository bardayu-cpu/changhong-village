extends SceneTree
## 第八轮第 2 条（总002）：提示条只占一行，文案 12 字左右。把代码里所有进提示条的字（note=、last_error=）拿出来，
## 按 24 号字量宽：一行放得下（540 宽屏，提示条最宽 540-48，左右边距 28），而且不超过 14 个字
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
func _initialize() -> void:
	var re:=RegEx.new();re.compile('(?:note|last_error)\\s*=\\s*("[^"]*")(?:\\s*if[^"]*else\\s*("[^"]*"))?')
	var bad:Array=[];var n:=0
	for f in ["res://ayu_home/v4/home.gd","res://ayu_home/v4/life_state.gd"]:
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			for g in [1,2]:
				var copy:=m.get_string(g)
				if copy.length()<2:continue
				copy=copy.substr(1,copy.length()-2)
				if copy.is_empty():continue
				# 拼名字、节目名的：按最长的拼进去量
				var full:=copy.replace("电视在播 · ","电视在播 · 雨落在花园").replace("去找","去找妈妈").replace("出门了","妈妈出门了")
				n+=1
				var w:float=UI.FONT.get_string_size(full,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x+28
				if w>540-48 or full.length()>14:bad.append("%s（%d 字，宽 %d）"%[full,full.length(),w])
	print("量了 %d 条提示"%n)
	for b in bad:print("不行 ",b)
	print("RESULT PASS" if bad.is_empty() and n>15 else "RESULT FAIL")
	quit()
