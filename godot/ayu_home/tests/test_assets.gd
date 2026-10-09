extends SceneTree
const Store = preload("res://ayu_home/asset_store.gd")
class FakeCloud extends Node:
 var calls := 0
 var corrupt := false
 var fail := false
 func call_fn(_method: String, data: Dictionary, done: Callable, _timeout: float) -> void:
  calls += 1
  if fail:
   done.call({"ok":false,"reason":"offline"})
   return
  var bytes := FileAccess.get_file_as_bytes("res://ayu_home/assets/pets.png")
  if corrupt: bytes = PackedByteArray([1,2,3])
  var f := FileAccess.open(data.path,FileAccess.WRITE)
  f.store_buffer(bytes)
  f.close()
  done.call({"ok":true})
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var store := Store.new()
 root.add_child(store)
 var bridge := FakeCloud.new()
 root.add_child(bridge)
 var result := await store.ensure_all(bridge)
 assert(result.ok and result.downloaded == 0 and bridge.calls == 0)
 var config: Dictionary = Store.manifest().duplicate(true)
 config.files["pets.png"].file_id = "test-local-fixture"
 store.config = config
 store.cache_root = "/private/tmp/ayu-assets-test-%s/" % Time.get_ticks_usec()
 store.allow_source = false
 result = await store.ensure_all(bridge,["pets.png"])
 assert(result.ok and result.downloaded == 1 and bridge.calls == 1)
 result = await store.ensure_all(bridge,["pets.png"])
 assert(result.ok and result.downloaded == 0 and bridge.calls == 1)
 var cached := Store.cache_path("pets.png",store.cache_root,config)
 var f := FileAccess.open(cached,FileAccess.WRITE)
 f.store_string("broken")
 f.close()
 result = await store.ensure_all(bridge,["pets.png"])
 assert(result.ok and bridge.calls == 2)
 DirAccess.remove_absolute(cached)
 bridge.corrupt = true
 result = await store.ensure_all(bridge,["pets.png"])
 assert(not result.ok and result.reason == "checksum_mismatch" and not FileAccess.file_exists(cached))
 bridge.corrupt = false
 bridge.fail = true
 result = await store.ensure_all(bridge,["pets.png"])
 assert(not result.ok and result.reason == "offline")
 config.files["pets.png"].file_id = ""
 result = await store.ensure_all(bridge,["pets.png"])
 assert(not result.ok and result.reason == "cloud_unconfigured")
 # Decode an asset that does not exist under res:// at all: exported cloud path.
 var original_manifest: Dictionary = Store.manifest_cache
 config.files["cloud-only.png"] = config.files["pets.png"].duplicate(true)
 config.files["cloud-only.png"].file_id = "test-local-fixture"
 bridge.fail = false
 Store.manifest_cache = config
 result = await store.ensure_all(bridge,["cloud-only.png"])
 assert(result.ok)
 var decoded := Store.image("cloud-only.png")
 assert(decoded != null and decoded.get_size() == Vector2i(1024,1536))
 Store.manifest_cache = original_manifest
 Store.verified_paths.clear()
 Store.active_cache = "user://ayu_home_art/"
 store.queue_free()
 bridge.queue_free()
 await process_frame
 print("RESULT PASS assets local hash + download + offline cache + corruption retry + bad hash + failure + missing ID")
 quit()
