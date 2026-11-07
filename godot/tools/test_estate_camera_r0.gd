extends SceneTree
## Internal R0 runner: native render targets, existing scene builders and real
## go_to/_process movement at 1/60 s. No teleport/reset between destinations.
const Policy = preload("res://scripts/estate_camera.gd")
const SIZES := [Vector2i(360, 640), Vector2i(390, 844), Vector2i(430, 932), Vector2i(360, 840)]
const IDS := ["parking", "frontgate", "court", "plaza", "banquet", "backhall", "lawn", "lake", "orchard", "garden", "backgate", "kids", "shop", "rest2", "wkitchen", "banquet_55", "banquet_v11"]
var output := "res://../scratch/r0"
var rows: Array = []
var failures: Array = []
var viewport: SubViewport
var shots := true
var only := ""

func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg == "--no-shots": shots = false
        if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
    call_deferred("run")

func vec(v: Vector2) -> Array:
    return [v.x, v.y]

func geometry_checks() -> void:
    # Continuous supported aspect interval plus external bleed origin and pan.
    for height in range(960, 1261):
        for bounds in [Rect2(0, 0, 1152, 1024), Rect2(-136, -136, 1424, 1296), Rect2(0, 0, 1536, 2091)]:
            var fit := Policy.fit(Vector2(540, height), bounds)
            for target in [Vector2(-9999, -9999), Vector2(9999, 9999), Vector2(768, 512)]:
                var center := Policy.center(target, fit.visible, bounds)
                var visible := Rect2(center - fit.visible * 0.5, fit.visible)
                if not bounds.grow(0.001).encloses(visible):
                    failures.append("geometry %s %s" % [height, bounds])

func make_canvas(id: String):
    var script := id
    if id.begins_with("banquet"): script = "layered_hall"
    elif id == "court": script = "entrance"
    elif id in ["frontgate", "garden", "backgate", "kids", "shop", "rest2", "wkitchen"]: script = "area"
    var c = load("res://scripts/%s.gd" % script).new()
    if script == "area": c.setup_area(id)
    if id == "banquet_55": c.data_path = c.DATA_55
    if id == "banquet_v11": c.data_path = c.DATA_V11
    viewport.add_child(c)
    c.build(0, "R0", load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"))
    c.set_process(false)
    # Initial scene spawn only; every subsequent leg is ordinary navigation.
    if id.begins_with("banquet"):
        c.pos = c.SPAWN
        c.snap_cam()
    c.cam.make_current()
    c._process(1.0 / 60.0)
    return c

func edge_targets(c) -> Array:
    var out: Array = []
    var size := Vector2(c.cfg.size[0], c.cfg.size[1])
    var wanted := [Vector2(0, size.y / 2), Vector2(size.x, size.y / 2), Vector2(size.x / 2, 0), Vector2(size.x / 2, size.y)]
    var names := ["left", "right", "top", "bottom"]
    for side in 4:
        var best := Vector2.ZERO
        var score := INF
        # Geometric extremum of existing free grid, tie-break toward mid-edge.
        # If disconnected we report failure, never choose a more convenient edge.
        for y in c.rows:
            for x in c.cols:
                if not c._cell_ok(Vector2i(x, y)): continue
                var p: Vector2 = c._cell_pos(Vector2i(x, y))
                var d := absf(p.x - wanted[side].x) if side < 2 else absf(p.y - wanted[side].y)
                var tie := absf(p.y - wanted[side].y) if side < 2 else absf(p.x - wanted[side].x)
                var s := d * 100000.0 + tie
                if s < score:
                    score = s
                    best = p
        out.append({"id": "edge_" + names[side], "at": best, "radius": 2.0, "kind": "walkable_edge", "canvas_edge": vec(wanted[side])})
    return out

func capture(c, id: String, label: String, size: Vector2i) -> Dictionary:
    # Let Camera2D's actual smoothed transform settle, without moving the player.
    for i in 5: await process_frame
    c.cam.reset_smoothing()
    c.cam.force_update_scroll()
    await process_frame
    var logical := viewport.get_visible_rect().size
    var transform := viewport.get_canvas_transform().affine_inverse()
    var start := transform * Vector2.ZERO
    var finish := transform * logical
    var visible := Rect2(start, finish - start)
    var contained: bool = c.camera_bounds().grow(0.05).encloses(visible)
    if not contained: failures.append("camera %s %s %s" % [id, size, label])
    var file := "%s/%s/%dx%d/%s.png" % [output, id, size.x, size.y, label]
    if shots:
        await RenderingServer.frame_post_draw
        var img := viewport.get_texture().get_image()
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(file.get_base_dir()))
        if img.get_size() != size or img.save_png(file) != OK:
            failures.append("screenshot " + file)
    return {"logical_viewport": vec(logical), "visible_rect": [start.x, start.y, visible.size.x, visible.size.y], "zoom": c.cam.zoom.x, "contained": contained}

func walk_to(c, target: Dictionary) -> Dictionary:
    var before: Vector2 = c.pos
    c.go_to(target.at)
    var ticks := 0
    var distance := 0.0
    var max_step := 0.0
    var invalid_steps := 0
    while not c.path.is_empty() and ticks < 24000:
        var prev: Vector2 = c.pos
        c._process(1.0 / 60.0)
        var step: float = prev.distance_to(c.pos)
        distance += step
        max_step = maxf(max_step, step)
        if not c._free(c.pos): invalid_steps += 1
        ticks += 1
        if ticks % 120 == 0: await process_frame
    var remaining: float = c.pos.distance_to(target.at)
    return {"from": vec(before), "target": vec(target.at), "arrived": vec(c.pos), "distance_walked": distance, "ticks": ticks, "max_step": max_step, "invalid_steps": invalid_steps, "remaining": remaining, "reached": remaining <= float(target.radius), "kind": target.kind}

func run() -> void:
    geometry_checks()
    viewport = SubViewport.new()
    viewport.world_2d = World2D.new()
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    for id in IDS:
        if only != "" and id != only: continue
        for size in SIZES:
            viewport.size = size
            viewport.size_2d_override = Vector2i(540, roundi(540.0 * size.y / size.x))
            viewport.size_2d_override_stretch = true
            var c = make_canvas(id)
            var spawn_capture := await capture(c, id, "spawn", size)
            rows.append({"scene": id, "size": [size.x, size.y], "id": "spawn", "camera": spawn_capture, "position": vec(c.pos)})
            var goals := edge_targets(c)
            # Includes every point, so unlabelled exits (banquet door/side_door,
            # court gate, out) and all interactions cannot silently be omitted.
            for p in c.cfg.get("points", []):
                goals.append({"id": str(p.id), "at": Vector2(p.x, p.y), "radius": float(p.get("r", 16)), "kind": "point"})
            for goal in goals:
                var movement := await walk_to(c, goal)
                var cam := await capture(c, id, goal.id, size)
                rows.append({"scene": id, "size": [size.x, size.y], "id": goal.id, "movement": movement, "camera": cam})
                print("R0 ", id, " ", size, " ", goal.id, " reached=", movement.reached, " remaining=", movement.remaining, " contained=", cam.contained)
            c.free()
            await process_frame
    var path := output + ("/results.json" if only == "" else "/results-" + only + ".json")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    var f := FileAccess.open(path, FileAccess.WRITE)
    f.store_string(JSON.stringify({"rows": rows, "failures": failures, "shots": shots, "geometry_cases": 2709}, "  "))
    var unreachable := rows.filter(func(row): return row.has("movement") and not row.movement.reached).size()
    print("R0 COMPLETE rows=", rows.size(), " failures=", failures.size(), " unreachable=", unreachable)
    quit(1 if not failures.is_empty() else (2 if unreachable > 0 else 0))
