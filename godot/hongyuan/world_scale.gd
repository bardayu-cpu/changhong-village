extends RefCounted
## All coordinates are logical 360×640. Values are standing body height at two
## floor depths, calibrated against cars, furniture and doors in each camera.
## Top-down banquet art intentionally keeps a constant scale.
const PROFILES := {
	"shanghai_street": [370.0, 55.0, 555.0, 112.0],
	"shanghai_parking": [379.0, 47.0, 555.0, 117.0],
	"chengdu": [310.0, 90.0, 560.0, 150.0],
	"room": [368.0, 185.0, 620.0, 270.0],
	"office": [432.0, 220.0, 568.0, 275.0],
	"pier": [376.0, 115.0, 590.0, 190.0],
	"boat": [430.0, 180.0, 610.0, 256.0],
	"pool": [290.0, 72.0, 580.0, 165.0],
	"beach": [450.0, 95.0, 620.0, 170.0],
	"airport": [400.0, 98.0, 615.0, 175.0],
	"banquet": [198.0, 50.0, 600.0, 50.0],
}

static func profile(scene_id: String, background := "") -> String:
	if scene_id in ["shanghai_street", "shanghai_parking"]: return scene_id
	if "chengdu" in scene_id or "chengdu" in background: return "chengdu"
	if "bg_cbd_office" in background: return "office"
	if "bg_room" in background or "l3_computer" in background: return "room"
	if "bg_pier" in background or "shizuoka_pier" in background: return "pier"
	if "bg_boat" in background or "boat_cabin" in background: return "boat"
	if "bg_wanning" in background: return "pool"
	if "bg_wenchang" in background: return "beach"
	if "bg_arrival" in background: return "airport"
	return ""

static func height_at(key: String, floor_y: float, fallback := 128.0) -> float:
	if not PROFILES.has(key): return fallback
	var p: Array = PROFILES[key]
	return lerpf(p[1], p[3], clampf((floor_y - p[0]) / (p[2] - p[0]), 0.0, 1.0))

static func pose_ratio(file: String) -> float:
	# Sitting shortens the body on screen; do not stretch a seated image to the
	# full standing height. Source canvas resolution never determines world size.
	return 0.844 if file.get_file().ends_with("_sit.png") else 1.0

static func foot_x(file: String, texture_width: float) -> float:
	return float({"toretto_neutral_r2.png": 505.0, "toretto_gifts_r2.png": 462.5,
		"toretto_back_r2.png": 491.5}.get(file.get_file(), texture_width * 0.5))

static func visible_rect(texture: Texture2D) -> Rect2:
	# Generated transparent PNGs contain almost invisible (alpha < 16/255)
	# pixels outside the figure. Content bounds omit that fringe, not the body.
	var bounds := {"toretto_neutral_r2.png": Rect2(299, 61, 412, 1457),
		"toretto_gifts_r2.png": Rect2(251, 66, 546, 1459),
		"toretto_back_r2.png": Rect2(299, 64, 386, 1458)}
	return bounds.get(texture.resource_path.get_file(), Rect2(texture.get_image().get_used_rect()))

static func local_rect(file: String, texture_width: float, used: Rect2, standing_height: float) -> Rect2:
	var height := standing_height * pose_ratio(file)
	var k := height / maxf(used.size.y, 1)
	return Rect2(Vector2((used.position.x - foot_x(file, texture_width)) * k, -height), used.size * k)
