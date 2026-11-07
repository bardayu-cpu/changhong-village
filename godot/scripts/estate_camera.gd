extends RefCounted
## R0: camera geometry only. Never changes world, navigation, or foot coordinates.
## The caller supplies the rectangle actually painted, not the planned bleed extent.
const CONTENT_WIDTH := 540.0

static func fit(viewport: Vector2, painted: Rect2) -> Dictionary:
    assert(painted.size.x > 0.0 and painted.size.y > 0.0)
    var zoom := maxf(viewport.x / CONTENT_WIDTH,
        maxf(viewport.x / painted.size.x, viewport.y / painted.size.y))
    return {"zoom": zoom, "visible": viewport / zoom}

static func center(target: Vector2, visible: Vector2, painted: Rect2) -> Vector2:
    var half := visible * 0.5
    return Vector2(
        clampf(target.x, painted.position.x + half.x, painted.end.x - half.x),
        clampf(target.y, painted.position.y + half.y, painted.end.y - half.y))

static func apply(camera: Camera2D, viewport: Vector2, painted: Rect2) -> void:
    var result := fit(viewport, painted)
    camera.zoom = Vector2.ONE * float(result.zoom)
    camera.limit_left = ceili(painted.position.x)
    camera.limit_top = ceili(painted.position.y)
    camera.limit_right = floori(painted.end.x)
    camera.limit_bottom = floori(painted.end.y)
    # Limits apply during smoothing as well, including resize and camera panning.
    camera.limit_smoothed = false

