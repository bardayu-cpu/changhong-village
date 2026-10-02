extends RefCounted
## 登记表保留 pending；开发参数仅为内部制作测试，不能推断为已确认。
static func read_json(path: String):
    if path.is_empty() or not FileAccess.file_exists(path): return null
    return JSON.parse_string(FileAccess.get_file_as_string(path))

static func is_gameplay_confirmed(record: Dictionary) -> bool:
    if str(record.get("status","")) != "gameplay_confirmed": return false
    for key in ["steps","cook_seconds","ready_window_seconds","reward_coins","unlock_rule","station_id"]:
        if record.get(key) == null: return false
    return record.steps is Array and not record.steps.is_empty() and float(record.cook_seconds) > 0 and float(record.ready_window_seconds) > 0 and int(record.reward_coins) >= 0

static func resolve_setup(setup: Dictionary) -> Dictionary:
    if not setup.has("registry_path"): return setup.duplicate(true)
    var registry = read_json(str(setup.registry_path))
    var overrides = read_json(str(setup.get("development_overrides_path","")))
    var legacy = read_json(str(setup.get("legacy_candidates_path","")))
    var drafts: Array = overrides.get("recipes",[]) if overrides is Dictionary else []
    var component_rows = read_json(str(setup.get("components_path","")))
    var components: Dictionary = {}
    if component_rows is Array:
        for component in component_rows:
            if component is Dictionary: components[str(component.id)] = component
    var rows: Array = []
    var visual = read_json("res://data/kitchen/visual_assets.json")
    var visual_map: Dictionary = visual.get("recipe_visual_map",{}) if visual is Dictionary else {}
    var allow_drafts := bool(setup.get("allow_development_overrides",false))
    if registry is Array:
        for record in registry:
            if not record is Dictionary: continue
            var matching: Array = drafts.filter(func(d): return str(d.id) == str(record.id))
            var draft: Dictionary = matching[0] if not matching.is_empty() else {}
            var row := resolve_record(record,draft,allow_drafts,components)
            if visual_map.has(str(record.id)):
                row.visual_group = str(visual_map[str(record.id)])
                row.visual_station_id = row.visual_group
            rows.append(row)
    if legacy is Array:
        for record in legacy:
            var row: Dictionary = record.duplicate(true)
            row.enabled = false
            row.gameplay_confirmed = false
            row.runtime_value_status = "inactive_legacy_candidate"
            rows.append(row)
    var result := setup.duplicate(true)
    result.recipes = rows
    return result

static func resolve_record(record: Dictionary, draft: Dictionary, allow_drafts: bool, components: Dictionary = {}) -> Dictionary:
    var confirmed := is_gameplay_confirmed(record)
    var use_draft := not confirmed and allow_drafts and not draft.is_empty()
    var runtime: Dictionary = draft.duplicate(true) if use_draft else {}
    runtime.id = str(draft.get("runtime_id",record.id))
    runtime.dish_id = str(record.id)
    runtime.name = str(record.name)
    runtime.cooking_family = str(record.get("cooking_family",""))
    runtime.finished_art = str(record.get("finished_art",""))
    if not runtime.finished_art.begins_with("res://"):
        runtime.finished_art = "res://assets/kitchen/mobile/"+runtime.finished_art
    runtime.registry_record = record.duplicate(true)
    for field in ["steps","cook_seconds","ready_window_seconds","reward_coins","unlock_rule"]:
        if not runtime.registry_record.has(field): runtime.registry_record[field] = null
    runtime.status = str(record.get("status","pending_recipe_details"))
    runtime.gameplay_confirmed = confirmed
    runtime.runtime_value_status = "confirmed" if confirmed else "development_draft" if use_draft else "pending"
    runtime.enabled = confirmed or use_draft
    runtime.station_id = record.get("station_id") if record.get("station_id") != null else draft.get("station_id","") if use_draft else ""
    runtime.station_value_status = "registered" if record.get("station_id") != null else "development_draft" if use_draft else "pending"
    if confirmed:
        var ingredients: Array = []
        for step in record.steps:
            var component: Dictionary = components.get(str(step.get("component_id","")),{})
            ingredients.append(str(step.get("label",component.get("name",step.get("component_id","")))))
        runtime.ingredients = ingredients
        runtime.component_steps = record.steps.duplicate(true)
        runtime.variants = [ingredients]
        runtime.seconds = float(record.cook_seconds)
        runtime.window = float(record.ready_window_seconds)
        runtime.coins = int(record.reward_coins)
        var unlock = record.unlock_rule
        runtime.unlock = int(unlock.get("min_level",1)) if unlock is Dictionary else int(unlock)
        runtime.heat = 2
    elif not use_draft:
        runtime.ingredients = []
        runtime.variants = []
        runtime.seconds = 0.0
        runtime.window = 0.0
        runtime.coins = 0
        runtime.unlock = 2147483647
    return runtime
