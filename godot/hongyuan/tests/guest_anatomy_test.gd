extends SceneTree
const Scale = preload("res://hongyuan/world_scale.gd")
var failed := 0
var checked := 0
func _initialize() -> void:
	for guest in range(1,13):
		var tex: Texture2D = load("res://assets/characters/lm/chr_LM-GUEST-%02d.png"%guest)
		for frame in range(16):
			var used := Rect2(tex.get_image().get_region(Rect2i(frame*64,0,64,84)).get_used_rect())
			for height in [60.0,110.0,170.0]:
				var parts := Scale.guest_parts(used,height,guest)
				var good := is_equal_approx(parts[0].size.x/parts[0].size.y,parts[2].size.x/parts[2].size.y)
				good = good and is_zero_approx(parts[1].end.y)
				good = good and is_equal_approx(parts[0].end.y,parts[1].position.y)
				good = good and is_equal_approx(parts[3].end.y,used.end.y)
				good = good and parts[2].size.y>0 and parts[3].size.y>0
				if guest in [11,12]: good = good and is_equal_approx(-parts[0].position.y,height*0.7) and parts[2].position.y>=30
				checked += 1
				if not good: failed+=1;print("FAIL guest=",guest," frame=",frame," height=",height)
	print("GUEST_ANATOMY cases=",checked," failures=",failed)
	quit(failed)
