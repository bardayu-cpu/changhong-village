extends SceneTree
const Packs := preload("res://hongyuan/content_packs.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value: failures += 1
func run() -> void:
	var directory := OS.get_cmdline_user_args()[0]
	var entries: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory + "/manifest.json"))
	var loader := Packs.service()
	loader.cache_root = directory + "/cache/"
	loader.stall_seconds = 0.7
	var config := {"mode": "remote", "development": true, "baseUrl": "http://127.0.0.1:18986/", "groups": {}}
	for key in entries: config.groups[key] = [entries[key]]
	loader.configure(config)
	check(not await Packs.ensure(["retry"]), "HTTP 503 returns instead of hanging")
	check(await Packs.ensure(["retry"]), "retry mounts the same requested chapter")
	check(FileAccess.get_file_as_string("res://hongyuan/tests/probe_retry.txt") == "fixture retry", "downloaded resource is mounted and readable")
	check(not await Packs.ensure(["stall"]), "stalled transfer times out")
	check(not await Packs.ensure(["corrupt"]), "same-size corrupt body rejected by SHA256")
	check(await Packs.ensure(["valid"]), "normal download succeeds after errors")
	loader.mounted.clear()
	loader.config.baseUrl = "http://127.0.0.1:1/"
	check(await Packs.ensure(["valid"]), "verified disk cache works without server")
	check(not await Packs.ensure(["absent"]), "missing group fails explicitly")
	print("FAILURES ", failures)
	quit(failures)
