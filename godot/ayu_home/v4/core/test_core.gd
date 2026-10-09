extends SceneTree
const S=preload("res://ayu_home/v4/core/state.gd")
const C=preload("res://ayu_home/v4/core/config.gd")
var s
var fails:Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1;print("CHECK ",ok," ",label)
	if not ok:fails.append(label)
func action(cmd:String,a:Dictionary={}) -> Dictionary:
	var r:Dictionary=s.act(cmd,a);check(r.ok,cmd+" "+str(a)+" "+str(r));return r
func reset(path:String) -> void:
	for ext in [".a",".b"]:DirAccess.remove_absolute(path+ext)
func run() -> void:
	var file:=ProjectSettings.globalize_path("res://../测试数据/village-core-test");reset(file)
	s=S.new();s.now_override=1791273600;check(s.open({"id":"qa"},file),"新玩家存档")
	check(s.data.wallet.coins==0,"从做客起步，金币零")
	for pet in C.PETS:
		var before:=0
		for n in s.data.village.items.values():before+=int(n)
		action("animal",{"id":pet})
		var after:=0
		for n in s.data.village.items.values():after+=int(n)
		check(after-before==4,"每只恰好四件")
		check(not s.act("animal",{"id":pet}).ok,"不能连续重领")
	for pair in [[0,"radish"],[1,"pepper"],[2,"grain"],[3,"grain"],[4,"radish"],[5,"pepper"]]:action("plant",{"plot":pair[0],"crop":pair[1]})
	check(not s.act("harvest",{"plot":0}).ok,"不能提前收菜")
	s.now_override+=240
	for i in 6:action("harvest",{"plot":i})
	action("produce",{"recipe":"flour"})
	check(not s.act("produce",{"recipe":"flour"}).ok,"石磨满位不重复扣原料")
	s.now_override+=60;action("collect",{"station":"mill"});action("produce",{"recipe":"porridge"})
	s.now_override+=90;action("collect",{"station":"stove"});action("produce",{"recipe":"meal"})
	s.now_override+=90;action("collect",{"station":"stove"})
	for order in s.orders():action("order",{"id":order.id});check(not s.act("order",{"id":order.id}).ok,"同日订单不可重领")
	check(s.data.wallet.coins==260 and s.data.renqing.size()==2,"四单收入260、家人两笔人情")
	# 正常循环收动物，最多200轮保障统计测试终止；不直接发工具材料。
	var turns:=0
	while (s.count("bamboo")<20 or s.count("stone")<12 or s.count("tool")<3 or s.count("parcel")<8) and turns<200:
		s.now_override+=300
		for pet in C.PETS:s.act("animal",{"id":pet})
		turns+=1
	check(turns<200,"动物概率链供给工具、材料、动物包，轮数 "+str(turns))
	action("reside");action("location",{"id":"lake"});action("land",{"plot":0})
	var coins:int=s.data.wallet.coins
	check(not s.act("land",{"plot":0}).ok and s.data.wallet.coins==coins,"重复开地不重复扣钱")
	# 第二日继续实际交单，积累足够金币开三块地。
	s.now_override+=86400
	for day in 3:
		for pair in [[0,"pepper"],[1,"grain"],[2,"grain"]]:action("plant",{"plot":pair[0],"crop":pair[1]})
		s.now_override+=240
		for i in 3:action("harvest",{"plot":i})
		for order in s.orders():
			if s.has_items(order.items):s.act("order",{"id":order.id})
		s.now_override+=86400
	check(s.data.wallet.coins>=250,"跨日谷子和海椒订单攒开地金币")
	action("land",{"plot":1});s.now_override+=3;action("land",{"plot":2});s.now_override+=3
	while s.data.village.blueprints.is_empty() and s.count("parcel")>0:action("parcel")
	if s.data.village.blueprints.is_empty():fails.append("未抽到图纸");quit(1);return
	var blueprint:String=s.data.village.blueprints[0];action("craft",{"id":blueprint})
	var id:int=s.data.village.furniture[0].id
	action("place",{"id":id,"x":1,"y":1});action("place",{"id":id,"x":2,"y":7});action("store",{"id":id});action("place",{"id":id,"x":0,"y":8})
	var snapshot:Dictionary=JSON.parse_string(JSON.stringify(s.data))
	for i in 2:
		var reopened=S.new();reopened.now_override=s.now_override;check(reopened.open({"id":"qa"},file),"重开 "+str(i+1));check(reopened.data==snapshot,"重开后钱/库存/计时/家具/订单全部一致");s=reopened
	var before_clock:float=s.now();s.now_override-=86400*100
	check(s.now()==before_clock,"时钟回拨不倒退")
	var old_id:String=s.orders()[0].id
	s.now_override=before_clock+86400*365
	action("animal",{"id":"xiduo"});check(not s.act("animal",{"id":"xiduo"}).ok,"离线一年仍只一趟")
	check(s.orders()[0].id!=old_id,"下一真实日刷新订单")
	# 双槽回退 + 乐观并发。
	var stale=S.new();stale.now_override=s.now_override;stale.open({"id":"qa"},file)
	action("visit");check(not stale.act("visit").ok,"过时窗口拒绝覆盖新存档")
	var newest:=file+(".a" if int(s.data.village.revision)%2==1 else ".b")
	FileAccess.open(newest,FileAccess.WRITE).store_string("broken")
	var recovered=S.new();recovered.now_override=s.now_override;check(recovered.open({"id":"qa"},file),"坏一槽可以从另一有效槽恢复")
	var wrong=S.new();check(not wrong.open({"id":"other"},file),"身份不同不读别人的存档")
	print("RESULT ","PASS" if fails.is_empty() else "FAIL", " ",checks," checks ",fails)
	quit(0 if fails.is_empty() else 1)
