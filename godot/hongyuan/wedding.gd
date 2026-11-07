extends "res://scripts/main.gd"
## Enter the existing Luoman estate with the invitation's guest.
signal venue_ready
var guest_profile: Dictionary = {}
var resume_location: Dictionary = {}

func _ready() -> void:
    nickname = str(guest_profile.get("nick", ""))
    preset = int(guest_profile.get("avatar", 0))
    await super._ready()
    title_screen.hide()
    # A standalone browser has no WeChat cloud bridge; use the estate's existing
    # local seating implementation, as the desktop version does.
    if OS.has_feature("web") and cloud._js == null:
        cloud._in_wx = false
    if resume_location.is_empty():
        # The invitation already completed the journey. Enter the original
        # wedding hall, not the estate's unfinished parking/drive greybox.
        # Only announce readiness after the original hall and fade are ready.
        await _enter_banquet()
    else:
        await _enter_parking()
        var area := str(resume_location.get("area", "parking"))
        if area in ["court", "banquet", "plaza", "backhall", "lawn", "lake", "orchard"] + AREA_IDS:
            ensure_canvas(area)
            _show_canvas(area)
            _goto(area)
            if area == "banquet":
                _enter_hall_net()
        var at: Array = resume_location.get("position", [])
        if at.size() == 2:
            cv.reset_to(Vector2(float(at[0]), float(at[1])))
    venue_ready.emit()

func location() -> Dictionary:
    if cv == null or driving or state not in ["parking", "court", "banquet", "plaza", "backhall", "lawn", "lake", "orchard"] + AREA_IDS:
        return {}
    return {"area": state, "position": [cv.pos.x, cv.pos.y]}

func enter_banquet() -> void:
    # The invitation can already arrive in the hall. Re-entering it rebuilds
    # seated guests while their UI callbacks are pending; keep this idempotent.
    if state == "banquet":
        return
    if driving:
        drive.skipped = true
        while driving:
            await get_tree().process_frame
    await _enter_banquet()
