extends CanvasLayer
## A photo is a scene recipe, never a GPU readback. Safe to reconstruct on the web.
signal closed
signal kept
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
const World=preload("res://ayu_home/v4/world.gd")
const Actor=preload("res://ayu_home/v4/actor.gd")
var root:Control
var paper:PanelContainer
var frame:Control
var stage_world
var photo:Dictionary={}
var poses:=["比耶","自然站好","抱着猫咪","和喜多一起"]
var pose_index:=0
var elapsed:=0.0
var developed:=false
var saved:=false
var life
var caption:Label
var take_button:Button
var keep_button:Button
var flash:ColorRect
var actor_nodes:Array=[]
var source_state:Dictionary={}
var captured_life
func _ready() -> void:layer=45;set_process(false)
func open(state,snapshot:Dictionary,view_only:=false) -> void:
	close(false);life=state;photo=snapshot.duplicate(true);source_state=photo.duplicate(true);developed=view_only;saved=view_only;elapsed=0;pose_index=int(photo.get("pose",0))
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.theme=UI.theme(true);add_child(root)
	var shade:=ColorRect.new();shade.color=Color("695544");shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(shade)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,25)
	for side in ["top","bottom"]:margin.add_theme_constant_override("margin_"+side,34)
	root.add_child(margin);var col:=VBoxContainer.new();col.add_theme_constant_override("separation",18);margin.add_child(col)
	var heading:=HBoxContainer.new();col.add_child(heading);var title:=UI.label("这一刻的拍立得",25);title.add_theme_color_override("font_color",Color("fff3d8"));title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(title);heading.add_child(UI.button("收起",close))
	paper=PanelContainer.new();paper.size_flags_vertical=Control.SIZE_EXPAND_FILL;paper.add_theme_stylebox_override("panel",UI.box(Color("fffaf0"),Color("e0d3b9")));col.add_child(paper)
	var inner:=VBoxContainer.new();inner.add_theme_constant_override("separation",18);paper.add_child(inner)
	frame=Control.new();frame.clip_contents=true;frame.size_flags_vertical=Control.SIZE_EXPAND_FILL;frame.custom_minimum_size.y=400;inner.add_child(frame)
	caption=UI.label(str(photo.get("title","阿鱼家"))+" · "+str(photo.get("date","")),19);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.custom_minimum_size.y=57;inner.add_child(caption)
	var row:=HBoxContainer.new();col.add_child(row)
	if not view_only:
		row.add_child(UI.button("换姿势",change_pose));take_button=UI.button("咔嚓，拍一张",shoot);take_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(take_button)
		keep_button=UI.button("收进相册",keep);keep_button.disabled=true;row.add_child(keep_button)
	else:row.add_child(UI.label("相片留住了当时的天气、光线和身边的人。",17))
	flash=ColorRect.new();flash.color=Color(1,1,.93,0);flash.mouse_filter=Control.MOUSE_FILTER_IGNORE;flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(flash)
	build_scene();frame.resized.connect(layout_scene);set_process(true)
func build_scene() -> void:
	for node in frame.get_children():frame.remove_child(node);node.queue_free()
	actor_nodes=[];stage_world=World.new();frame.add_child(stage_world);stage_world.load_room(str(photo.room));stage_world.local_lighting=true;stage_world.hour=float(photo.hour);stage_world.month=int(photo.month);stage_world.weather=str(photo.weather);captured_life=preload("res://ayu_home/v4/life_state.gd").new();captured_life.data=life.data.duplicate(true);captured_life.now_override=float(photo.get("at",life.now()))
	for key in ["effects","trees","plots","flower_vase","harvest_history"]:
		if photo.has(key):captured_life.data[key]=photo[key].duplicate(true)
	stage_world.life=captured_life;stage_world.camera_center=Vector2(photo.center[0],photo.center[1]);stage_world.parallax_origin=stage_world.camera_center
	for snapshot in photo.actors:
		var a=Actor.new();a.preset=int(photo.get("preset",2));stage_world.actors.add_child(a);a.setup(str(snapshot.id));a.position=Vector2(snapshot.pos[0],snapshot.pos[1]);a.face=str(snapshot.face);a.action=str(snapshot.action);a.lift=float(snapshot.get("lift",0));a.blanket=Color.from_string(str(snapshot.get("blanket","00000000")),Color(0,0,0,0));a.in_bed=bool(snapshot.get("in_bed",false));a.head_down=bool(snapshot.get("head_down",false));a.freeze=true;actor_nodes.append(a)
	apply_pose();layout_scene()
func apply_pose() -> void:
	var player_pos:=Vector2(photo.player[0],photo.player[1])
	var pet_chosen:=false
	for i in actor_nodes.size():
		var a=actor_nodes[i];var snap:Dictionary=photo.actors[i];a.position=Vector2(snap.pos[0],snap.pos[1])
		if not pet_chosen and a.position.distance_to(player_pos)<150 and ((pose_index==2 and a.id in ["qiuqiu","luoluo","tiantian"]) or (pose_index==3 and a.id=="xiduo")):
			a.position=player_pos+Vector2(2,-23) if pose_index==2 else player_pos+Vector2(40,6);a.action="happy";a.face="down";pet_chosen=true
	for a in actor_nodes:
		if a.id=="visitor":a.action="photo" if pose_index==0 else ("hug" if pose_index==2 else "idle");a.face="down";a.pose();a.queue_redraw()
func layout_scene() -> void:
	if not stage_world or not frame:return
	var center:=Vector2(photo.center[0],photo.center[1]);var zoom:float=float(photo.get("zoom",1.6))
	var ratio:float=frame.size.x/440.0;stage_world.scale=Vector2.ONE*zoom*ratio;stage_world.position=frame.size*.5-center*stage_world.scale
func change_pose() -> void:
	if developed:return
	# Poses involving an animal require that animal to actually be beside the player.
	for attempt in 4:
		pose_index=(pose_index+1)%4
		var player_pos:=Vector2(photo.player[0],photo.player[1]);var has_pet:=false
		for a in photo.actors:
			if Vector2(a.pos[0],a.pos[1]).distance_to(player_pos)<150:
				if pose_index==2 and a.id in ["qiuqiu","luoluo","tiantian"]:has_pet=true
				if pose_index==3 and a.id=="xiduo":has_pet=true
		if pose_index<2 or has_pet:break
	photo.pose=pose_index;apply_pose();caption.text=poses[pose_index]+" · "+str(photo.title)+"\n"+str(photo.date)
func shoot() -> void:
	if developed:return
	developed=true;elapsed=0;photo.pose=pose_index;take_button.disabled=true;keep_button.disabled=true;frame.modulate=Color("f9ead3");frame.modulate.a=.08
	flash.color.a=.95;var tween:=create_tween();tween.tween_property(flash,"color:a",0,.22)
	paper.position.y+=28;paper.create_tween().tween_property(paper,"position:y",paper.position.y-28,.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	caption.text="相纸慢慢显影…";shutter()
func _process(dt:float) -> void:
	if not root:return
	elapsed+=dt
	if developed and not saved and elapsed<=4:
		frame.modulate=Color.WHITE;frame.modulate.a=clampf(elapsed/3,0,1)
		if elapsed>=3:keep_button.disabled=false;caption.text=str(photo.title)+" · "+str(photo.date)+"\n"+poses[pose_index]
func keep() -> void:
	if not developed or saved or elapsed<3:return
	saved=true;photo.erase("runtime");life.keep_photo(photo);keep_button.disabled=true;caption.text="收好了，下次回来也能翻到这一张。";kept.emit()
func shutter() -> void:
	if not life.data.settings.sound:return
	# 咔—嚓：两下机械声（sfx.gd 合成）
	var player:=AudioStreamPlayer.new();add_child(player);player.stream=preload("res://ayu_home/v4/sfx.gd").get_sound("shutter");player.volume_db=-4;player.play();player.finished.connect(player.queue_free)
func close(emit:=true) -> void:
	if root:remove_child(root);root.queue_free();root=null
	stage_world=null;actor_nodes=[];set_process(false)
	if emit:closed.emit()
