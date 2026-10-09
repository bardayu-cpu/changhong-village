extends Sprite2D
## A cropped original window pane; only its viewing offset changes, not its art.
var origin:=Vector2.ZERO
func sync(camera_x:float) -> void:
	if material:material.set_shader_parameter("shift",clampf(camera_x*.025,-1.0,1.0)/float(texture.get_width()))
