extends SceneTree
## 看星星 / 看云：流星时间、提示圈会不会带到下一次打开
var h
func _initialize() -> void:call_deferred("run")
func click(p:Vector2) -> void:
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=p;e.global_position=p;e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;root.push_input(e,true);await process_frame
	await process_frame
func gp(p:Vector2) -> Vector2:return h.games.canvas.get_global_rect().position+h.games.offset()+p*h.games.scale_factor()
func wait_el(t:float) -> void:
	while h.games.elapsed<t:await process_frame
func run() -> void:
	await process_frame;root.size=Vector2i(1080,1920);await process_frame;await process_frame
	var save:=OS.get_user_data_dir()+"/probe-stars.json";DirAccess.remove_absolute(save)
	h=load("res://ayu_home/home.tscn").instantiate();h.town_profile={"id":"ps","avatar":2};h.save_path=save;root.add_child(h);await process_frame;h.close_modal();h.sound_on=false
	# 1 第一次白天看云：10.5 秒时点一朵云
	h.set_test_clock(12.25);h.enter_room("terrace",false);h.interact("stars");for i in 5:await process_frame
	await wait_el(10.5)
	var c=h.games.clouds[1];await click(gp(h.games.cloud_pos(c)))
	print("白天第一次打开 10.5 秒点云：许愿框=",h.games.wish_input!=null," 云找到=",c.found," 状态「",h.games.status.text,"」")
	h.games.close(false)
	# 2 晚上看星星，玩 30 秒后收起，再打开：前几秒点星星
	h.set_test_clock(21.0);h.enter_room("grove",false);h.games.open("stars",h.life,{"month":10,"hour":21.0,"area":"grove","sound":false});for i in 5:await process_frame
	await wait_el(30.0);print("第一次夜里 30 秒 meteor_at=",h.games.meteor_at," meteor_until=",h.games.meteor_until)
	h.games.close(false);h.games.open("stars",h.life,{"month":10,"hour":21.0,"area":"grove","sound":false});for i in 5:await process_frame
	await wait_el(1.0);await click(gp(h.games.stars[0]))
	print("再打开 1 秒点第一颗星：许愿框=",h.games.wish_input!=null," 点亮=",h.games.found_stars," 状态「",h.games.status.text,"」 meteor_until=",h.games.meteor_until)
	quit()
