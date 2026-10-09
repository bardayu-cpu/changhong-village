extends SceneTree
## 两个阿鱼家窗口同时开着、抢同一个存档：各自连存 400 次，数一数冒了几次「没能保存」，最后存档能不能读
const Life=preload("res://ayu_home/v4/life_state.gd")
func _initialize() -> void:
	var path:="/private/tmp/claude-501/-Users-kayra-ayu-Desktop------/0ddb8b51-e3a3-4e3b-8c71-447ab7c79283/scratchpad/race-save.json"
	var t=Life.new();t.open({"id":"race"},path);var shown:=0;var failed:=0
	for i in 400:
		t.data.completed["race"]=i
		if not t.save():failed+=1
		if not t.last_error.is_empty():shown+=1
	var check=Life.new();check.open({"id":"race"},path)
	print("RACE pid=",OS.get_process_id()," 存失败=",failed," 冒提示=",shown," 读回=",not check.data.is_empty() and check.last_error.is_empty())
	quit()
