extends SceneTree
## Camera2D integration test: resize the SAME camera, with smoothing, pan targets,
## negative bleed origin, both small canvases and the 55-table hall.
const Policy = preload("res://scripts/estate_camera.gd")
var failures := 0
var checks := 0
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var v := SubViewport.new()
    v.world_2d = World2D.new()
    root.add_child(v)
    var camera := Camera2D.new()
    camera.position_smoothing_enabled = true
    v.add_child(camera)
    camera.make_current()
    for rect in [Rect2(0, 0, 1152, 1024), Rect2(-136, -136, 1424, 1296), Rect2(0, 0, 1536, 2091)]:
        for size in [Vector2i(540, 960), Vector2i(540, 1169), Vector2i(540, 1170), Vector2i(540, 1260), Vector2i(540, 960)]:
            v.size = size
            Policy.apply(camera, Vector2(size), rect)
            for at in [Vector2(-10000, -10000), Vector2(10000, 10000), Vector2(-10000, 10000), Vector2(10000, -10000), Vector2(768, 512)]:
                camera.position = at
                for frame in 3:
                    await process_frame
                    camera.force_update_scroll()
                    var xf := v.get_canvas_transform().affine_inverse()
                    var p := xf * Vector2.ZERO
                    var visible := Rect2(p, xf * Vector2(size) - p)
                    checks += 1
                    if not rect.grow(0.05).encloses(visible):
                        failures += 1
                        print("OUTSIDE ", rect, " ", size, " ", visible)
    print("R0 CAMERA BOUNDS checks=", checks, " failures=", failures)
    quit(0 if failures == 0 else 1)
