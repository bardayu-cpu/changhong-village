extends SceneTree
const S=preload("res://ayu_home/v4/core/state.gd")
const C=preload("res://ayu_home/v4/core/config.gd")
const Home=preload("res://ayu_home/v4/home.gd")
var failed:=false
var checks:=0
func check(ok:bool,label:String) -> void:
	checks+=1;failed=failed or not ok;print(("PASS " if ok else "FAIL ")+label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var dir:=ProjectSettings.globalize_path("res://../测试数据/C2/economy/");DirAccess.make_dir_recursive_absolute(dir)
	var file:=dir+"shared"
	for ext in [".a",".b"]:DirAccess.remove_absolute(file+ext)
	var s:=S.new();s.now_override=1791273600;check(s.open({"id":"economy-r1"},file),"new independent save")
	var count_before:=0
	for n in s.data.village.items.values():count_before+=int(n)
	for id in C.PETS:check(s.act("animal",{"id":id}).ok,"first animal "+id)
	var count_after:=0
	for n in s.data.village.items.values():count_after+=int(n)
	check(count_after-count_before==16 and s.count("stone")>=2 and s.count("bamboo")>=3 and s.count("tool")>=1,"first 16 slots guarantee only replaces slots")
	var fresh:=S.new();fresh.now_override=s.now_override;fresh.open({"id":"economy-r1"},file)
	check(int(fresh.data.village.first_supply)==16 and not fresh.act("animal",{"id":"xiduo"}).ok,"reopen cannot replay starting supply")
	var days:Array=[];var all_keys:Dictionary={}
	for day in 9:
		s.now_override=1791273600+day*86400;var list:=s.orders();var keys:Array=[]
		check(list.size()==4,"four dated orders day "+str(day))
		for order in list:keys.append(order.key);all_keys[order.key]=true
		days.append(keys)
		if day>=2:
			var union:Dictionary={}
			for earlier in range(day-2,day+1):
				for key in days[earlier]:union[key]=true
			check(union.size()==12,"rolling three-day uniqueness ending "+str(day))
	check(all_keys.size()==12,"12 distinct stable order cards")
	check(C.FURNITURE.size()==12,"12 craftable furniture definitions")
	var texture_hashes:Dictionary={}
	for id in C.FURNITURE:
		var cfg:Dictionary=C.FURNITURE[id]
		if cfg.has("texture"):
			var img:=Image.load_from_file(ProjectSettings.globalize_path(cfg.texture));check(not img.is_empty() and img.get_used_rect().has_area(),"real transparent cutout "+id);texture_hashes[FileAccess.get_sha256(cfg.texture)]=true
	check(texture_hashes.size()==9,"nine new furniture artworks are distinct")
	var before_coins:int=s.data.wallet.coins
	s.act("visit");s.data.village.items.honey=1;s.act("neighbour",{"id":"honey"});s.data.village.items.fruit=1;s.act("season_help",{"weather":"clear","season":"秋"})
	check(s.data.wallet.coins==before_coins and s.data.renqing.size()==2,"visits and neighbour/season favours grant only relationships")
	# 有意义的制摆收存事务测试，材料在此隔离逻辑测试中设置；不冒充首日计时。
	s.data.village.blueprints=C.FURNITURE.keys();s.data.village.items.bamboo=100;s.data.village.items.stone=100;s.data.village.land=[s.now()-1,s.now()-1,s.now()-1]
	for id in C.FURNITURE:
		var ok:bool=s.act("craft",{"id":id}).ok;var f:Dictionary=s.data.village.furniture.back();ok=ok and s.act("place",{"id":f.id,"x":0,"y":0}).ok and s.act("store",{"id":f.id}).ok;check(ok,"craft place store "+id)
	var reopened:=S.new();reopened.now_override=s.now_override;reopened.open({"id":"economy-r1"},file);check(reopened.data==JSON.parse_string(JSON.stringify(s.data)),"economy and all furniture survive reopen")
	var rows:Array=["类别,键,名称,需求或内容,金币或秒数"]
	for order in C.ORDERS:rows.append("订单,%s,%s·%s,%s,%s"%[order.key,order.who,order.title,s.describe(order.items),order.coins])
	for id in C.FURNITURE:rows.append("家具,%s,%s,%s,0"%[id,C.FURNITURE[id].name,s.describe(C.FURNITURE[id].items)])
	for id in C.CROPS:rows.append("作物,%s,%s,每次产%d,%s"%[id,C.CROPS[id].name,C.CROPS[id].yield,C.CROPS[id].seconds])
	rows.append("入驻,RESIDENCY,先交%d单,%s,%s"%[C.RESIDENCY.orders,s.describe(C.RESIDENCY.items),C.RESIDENCY.coins])
	for i in C.LAND.size():rows.append("开地,LAND_%d,第%d块,%s,%s"%[i,i+1,s.describe(C.LAND[i].items),C.LAND[i].coins])
	var out:=FileAccess.open("res://../回执/第1轮/经济可改表.csv",FileAccess.WRITE);out.store_string("\ufeff"+"\n".join(rows)+"\n");out.close()
	print("ECONOMY_ROUND1 ","FAIL" if failed else "PASS"," ",checks," checks; headless only, no first-day real-time claim")
	quit(1 if failed else 0)
