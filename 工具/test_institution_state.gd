extends SceneTree
const State=preload("res://ayu_home/v4/core/state.gd")
const Home=preload("res://ayu_home/v4/home.gd")
var s
var failed:=false
var checks:=0
func check(ok:bool,label:String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label);failed=failed or not ok
func _initialize() -> void:
	var folder:=ProjectSettings.globalize_path("res://../测试数据/C2/");DirAccess.make_dir_recursive_absolute(folder)
	var path:=folder+"institution-"+str(Time.get_ticks_usec());var profile:={"openid":"c2-institution"}
	s=State.new();check(s.open(profile,path),"isolated new save")
	check(not s.act("institution_begin",{"game":"mill"}).ok,"mill requires grain without spending it")
	s.put("grain",4);s.persist()
	var before:Dictionary=s.data.village.items.duplicate(true)
	check(s.act("institution_begin",{"game":"mill"}).ok,"begin mill")
	var run:String=s.data.village.active_institution.run
	check(s.data.village.items==before,"start changes no inventory")
	check(not s.act("institution_complete",{"run":run}).ok,"cannot complete before work")
	check(s.act("institution_step",{"run":run,"step":0}).ok,"first quarter turn")
	check(not s.act("institution_step",{"run":run,"step":0}).ok,"repeated input cannot advance twice")
	check(s.act("institution_cancel",{"run":run}).ok,"cancel in progress")
	check(s.data.village.items==before and int(s.data.wallet.coins)==0,"cancel consumes and awards nothing")
	check(s.act("institution_begin",{"game":"mill"}).ok,"new mill run after cancel")
	run=s.data.village.active_institution.run
	for i in 12:check(s.act("institution_step",{"run":run,"step":i}).ok,"quarter turn "+str(i+1))
	check(s.act("institution_complete",{"run":run}).ok,"completed mill transaction")
	check(s.count("grain")==2 and s.count("flour")==1 and int(s.data.wallet.coins)==0,"exactly two grain to one flour in shared inventory")
	check(not s.act("institution_complete",{"run":run}).ok,"finish replay rejected")
	var loaded:=State.new();check(loaded.open(profile,path),"reopen completed save")
	check(loaded.count("grain")==2 and loaded.count("flour")==1,"shared inventory survives reopen")
	check(not loaded.act("institution_complete",{"run":run}).ok,"reopen cannot repeat payout")
	check(loaded.act("institution_begin",{"game":"honey"}).ok,"daily activity starts")
	run=loaded.data.village.active_institution.run
	for i in 6:loaded.act("institution_step",{"run":run,"step":i})
	check(loaded.act("institution_complete",{"run":run}).ok and loaded.count("honey")==1,"daily output goes to shared inventory")
	check(not loaded.act("institution_begin",{"game":"honey"}).ok,"daily activity cannot be claimed twice")
	print("INSTITUTION_STATE "+("FAIL" if failed else "PASS")+" "+str(checks));quit(1 if failed else 0)
