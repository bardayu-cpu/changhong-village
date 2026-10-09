extends SceneTree
## 同一份存档开两个窗口：A 一直闲着，B 留宿、摘果子并存；A 换房间（存一次）、再关掉（再存一次）。B 做的事不能被盖掉；A 打开时看得出另一个开着
const Life=preload("res://ayu_home/v4/life_state.gd")
func _initialize() -> void:
	var path:=OS.get_user_data_dir()+"/two-windows.json"
	for f in [path,path+".bak",path+".open"]:DirAccess.remove_absolute(f)
	var a=Life.new();a.open({"id":"tw"},path);a.save()
	var b=Life.new();b.open({"id":"tw"},path)
	var fails:=[]
	print("B 打开时看到 A 开着=",b.another_open)
	b.data.resident=true;b.data.basket["apple"]=int(b.data.basket.get("apple",0))+3;b.data.effects["fruit_x"]=true;b.data.found.append("garden:fruit");b.save()
	a.data.effects["rooms"]={"living":{"lamp":true}};a.data.found.append("living:tv");a.save()
	a.data.last_seen=a.now();a.save()
	var c=Life.new();c.open({"id":"tw"},path)
	var ok:bool=c.data.resident and int(c.data.basket.get("apple",0))>=3 and c.data.effects.has("fruit_x") and c.data.effects.has("rooms") and "garden:fruit" in c.data.found and "living:tv" in c.data.found
	print("读回 留宿=",c.data.resident," 苹果=",c.data.basket.get("apple",0)," 两边找到的=",c.data.found)
	print("RESULT ","PASS" if ok and b.another_open else "FAIL")
	quit()
