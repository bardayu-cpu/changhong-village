extends SceneTree
const H=preload("res://ayu_home/v4/home.gd")
var h
var ui
var s
var bad:Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1;print("CHECK ",ok," ",label)
	if not ok:bad.append(label)
func tap_at(p:Vector2) -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=p;e.global_position=p;e.pressed=true;root.push_input(e,true)
	await process_frame
	e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=p;e.global_position=p;e.pressed=false;root.push_input(e,true)
	await create_timer(.08).timeout
func tap(copy:String) -> bool:
	await process_frame
	var button:Button
	for b in ui.root.find_children("*","Button",true,false):
		if b.text==copy:button=b;break
	if button==null:check(false,"找不到按钮 "+copy);return false
	var parent:Node=button.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(button)
		parent=parent.get_parent()
	await create_timer(.08).timeout
	await tap_at(button.get_global_rect().get_center())
	return true
func page(name:String) -> void:
	await tap(name);await create_timer(.08).timeout
	check(ui.page==name,"导航到 "+name+" 实际 "+ui.page)
func advance(seconds:float) -> void:
	s.now_override+=seconds;ui.tick()
func screenshot(name:String) -> void:
	await create_timer(.08).timeout
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../交付/流程-"+name+".png"))
func plant(crop:String,index:int) -> void:
	await create_timer(.1).timeout
	await tap(preload("res://ayu_home/v4/core/config.gd").CROPS[crop].name+" %d"%s.count(crop+"_seed"))
	var b:Button=ui.farm_canvas.plots[index]
	var scroll:ScrollContainer=ui.content.get_parent();scroll.ensure_control_visible(b);await create_timer(.08).timeout
	await tap_at(b.get_global_rect().get_center())
func harvest(index:int) -> void:
	await create_timer(.1).timeout
	var b:Button=ui.farm_canvas.plots[index];var scroll:ScrollContainer=ui.content.get_parent();scroll.ensure_control_visible(b);await create_timer(.08).timeout
	await tap_at(b.get_global_rect().get_center())
func run() -> void:
	for ext in [".a",".b"]:DirAccess.remove_absolute("/tmp/core-touch"+ext)
	h=H.new();h.town_profile={"id":"touch-qa","avatar":2};h.save_path="/tmp/core-touch-old.json";root.add_child(h);await create_timer(.5).timeout
	h.close_modal();ui=h.village_ui;s=ui.state;s.now_override=s.now();s.rng.seed=1006;s.data.village.rng=str(s.rng.state)
	await create_timer(.15).timeout
	await tap_at(ui.hud_button.get_global_rect().get_center());check(ui.opened,"实际点击院门口入口")
	for id in ["喜多","求求","落落","天天"]:await tap(id)
	check(s.data.village.animals.xiduo.trips==1,"真实按钮收动物")
	await plant("radish",0);await plant("pepper",1);await plant("grain",2);await plant("grain",3);await plant("radish",4);await plant("pepper",5)
	check(not s.data.village.crops[5].is_empty(),"六块地实际种下")
	if not bad.is_empty():print(s.data.village.crops);quit(1);return
	advance(240);await screenshot("菜熟了")
	for i in 6:await harvest(i)
	check(s.count("grain")==8,"实际点击收谷子")
	await page("灶屋");await tap("开始做谷粉");advance(60);await tap("谷粉 · 好了 · 点收取")
	await tap("开始做谷香粥");advance(90);await tap("谷香粥 · 好了 · 点收取")
	await tap("开始做海椒拌楼卜");advance(90);await tap("海椒拌楼卜 · 好了 · 点收取")
	await page("牌子")
	for who in ["妈妈","隔壁婆婆","牛肉店伙计","阿鱼"]:await tap("交给"+who)
	check(s.data.wallet.coins==260 and s.data.renqing.size()==2,"实际交四单，钱袋与人情簿一致")
	if not bad.is_empty():quit(1);return
	await screenshot("四件订单")
	# 测试时钟只存在本脚本，生产没有加速按钮；重复真实UI动物收取。
	await page("田边");var turns:=0
	while (s.count("bamboo")<25 or s.count("stone")<15 or s.count("tool")<3 or s.count("parcel")<12) and turns<100:
		advance(300)
		for id in ["喜多","求求","落落","天天"]:await tap(id)
		turns+=1
	await page("村长");await tap("交申请，入驻村子");await tap("湖边");check(s.data.village.location=="lake","村长申请、选住处走通")
	await page("院子");await tap("开第 1 块地");await tap("确认开这块地");advance(3)
	for day in 3:
		advance(86400);await page("田边")
		await plant("pepper",0);await plant("grain",1);await plant("grain",2);advance(240)
		for i in 3:await harvest(i)
		await page("牌子");await tap("交给妈妈");await tap("交给牛肉店伙计")
	await page("院子")
	for i in [2,3]:await tap("开第 %d 块地"%i);await tap("确认开这块地");advance(3)
	check(s.data.village.land[2]>0,"三块地正常成本走通")
	await page("篮子")
	while s.data.village.blueprints.is_empty() and s.count("parcel")>0:await tap("打开动物包（%d）"%s.count("parcel"))
	var kind:String=s.data.village.blueprints[0];var name:String=preload("res://ayu_home/v4/core/config.gd").FURNITURE[kind].name
	await tap("制作"+name);await page("院子");await tap(name+" #1 · 待摆")
	var board=ui.yard;var sc:ScrollContainer=ui.content.get_parent();sc.ensure_control_visible(board);await process_frame
	await tap_at(board.global_position+board.cell_rect(1,1).get_center())
	check(s.data.village.furniture[0].x==1,"实际点格摆家具")
	# 拖动已摆家具，按下和松开分处两个地块。
	board=ui.yard;sc=ui.content.get_parent();sc.ensure_control_visible(board);await process_frame
	var start:Vector2=board.global_position+board.cell_rect(1,1).get_center();var finish:Vector2=board.global_position+board.cell_rect(2,4).get_center()
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=start;e.pressed=true;root.push_input(e,true);await process_frame
	var motion:=InputEventMouseMotion.new();motion.position=finish;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;motion.relative=finish-start;root.push_input(motion,true);await process_frame
	e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=finish;e.pressed=false;root.push_input(e,true);await create_timer(.08).timeout
	check(s.data.village.furniture[0].x==2 and s.data.village.furniture[0].y==4,"实际拖动跨地块")
	await tap("收起选中的家具");check(s.data.village.furniture[0].x==-1,"实际按钮收起")
	await tap(name+" #1 · 待摆");board=ui.yard;sc=ui.content.get_parent();sc.ensure_control_visible(board);await process_frame
	await tap_at(board.global_position+board.cell_rect(0,0).get_center());await screenshot("自己的院子")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(s.data))
	for i in 2:
		var again=preload("res://ayu_home/v4/core/state.gd").new();again.now_override=s.now_override;again.open(h.profile,"/tmp/core-touch");check(again.data==saved,"连续流程重开存档一致 "+str(i+1))
	for size in [Vector2i(540,960),Vector2i(540,1200)]:
		root.size=size;await process_frame;ui.show_page("田边");await process_frame
		check(ui.root.get_global_rect().size.x<=root.size.x,"竖屏宽度适配 "+str(size));await screenshot("竖屏"+str(size.y))
	print("RESULT ","PASS" if bad.is_empty() else "FAIL"," ",checks," ",bad)
	h.stop_audio();h.queue_free();await process_frame;quit(0 if bad.is_empty() else 1)
