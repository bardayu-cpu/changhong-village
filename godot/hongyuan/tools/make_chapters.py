"""生成第三章到终章的章节 JSON（可操控场景）。剧情文字只引用 copy.json 的编号。"""
import json, os
D = os.path.join(os.path.dirname(__file__), "..", "chapters")

def scene(id, sid, sc):
    return {"id": id, "type": "scene", "sceneId": sid, "speaker": "system", "actorMode": "none",
            "actorSlot": None, "background": "scene", "visibleActors": [], "scene": sc}

def N(k, **kw): return {"narrate": k, **kw}
def T(k): return {"say": k, "who": "toretto"}
def A(k): return {"say": k, "who": "ayu"}
def auto(k, s=2.6): return {"narrate": k, "auto": s}

def write(cid, title, steps):
    json.dump({"chapterId": cid, "titleId": title, "steps": steps}, open(os.path.join(D, cid + ".json"), "w"), ensure_ascii=False, indent=1)

ROOM_AREA = [[150, 372], [282, 368], [282, 445], [350, 452], [350, 620], [20, 620], [20, 470], [150, 462]]
write("call", "G-08", [scene("night_call", "call_room", {
    "badge": "G-02", "bg": "w2/call/bg_room_night.png|l3_computer.webp", "fill": "#1a120e", "night": 0.0,
    "personHeight": 128, "walkArea": ROOM_AREA, "start": [200, 545],
    "actors": [{"id": "phone", "tex": "w2/call/phone_ring_1.png|phone_prop.png", "at": [215, 300]}],
    "hotspots": [{"id": "phone", "at": [215, 378], "snap": [215, 378], "face": 1, "pose": "back", "icon": "phone"}],
    "beats": [
        {"card": "G-08", "duration": 2.0},
        N("A3-1a"), N("A3-1b"),
        {"go": "phone"},
        {"game": "call", "aside": "A3-D1", "lines": [
            {"say": "A3-2a"}, {"say": "A3-2b"}, {"say": "A3-2c"}, {"say": "A3-2d", "who": "toretto"},
            {"say": "A3-2e", "who": "ayu"}, {"say": "A3-2f"}, {"say": "A3-2g", "who": "ayu"}, {"say": "A3-2h", "who": "toretto"}]},
        {"bg": "w2/call/bg_cbd_desk.png|bg_cbd_birthday_desk_r1.png", "night": 0.0, "hideAyu": True, "actors": [], "hotspots": []},
        N("A3-2i"), T("A3-2j"), N("A3-2k"), T("A3-2l"), A("A3-2m"), T("A3-2n"), T("A3-2o"), A("A3-2p"),
        {"bg": "", "fill": "#2a1414", "badge": "G-02"},
        auto("A3-2q"), auto("A3-2r"), auto("A3-2s"), auto("A3-2t"), auto("A3-3a"), auto("A3-3b"),
        {"material": "paper"},
    ]})])

write("shizuoka", "G-09", [scene("pier", "shizuoka", {
    "personHeight": 128, "badge": "G-02", "bg": "w2/shizuoka/bg_pier.png|bg_shizuoka_pier_r1.png",
    "walkArea": [[16, 376], [344, 376], [344, 590], [16, 590]], "start": [60, 540],
    "hotspots": [
        {"id": "spot", "at": [200, 382], "snap": [200, 382], "face": 1, "icon": "rod"},
        {"id": "boat", "at": [326, 500], "icon": "sit"}],
    "beats": [
        {"card": "G-09", "duration": 2.0},
        N("A4-1a"), N("A4-1b"), N("A4-1c"),
        {"go": "spot", "hint": "A4-P1"},
        {"game": "fishing"},
        {"go": "boat"},
        {"personHeight": 128, "bg": "w2/shizuoka/bg_boat.png|bg_shizuoka_boat_cabin_r1.png", "walkArea": [[30, 418], [330, 418], [340, 620], [20, 620]],
         "start": [300, 570], "pose": "",
         "actors": [{"id": "toretto", "tex": "w2/common/toretto_sit.png|w2/common/toretto_stand.png", "at": [160, 408]}],
         "hotspots": [{"id": "seat", "at": [228, 418], "snap": [228, 408], "face": -1, "pose": "sit", "icon": "sit"}]},
        T("A4-2a"), A("A4-2b"), T("A4-2c"), T("A4-2d"), T("A4-2e"), T("A4-2f"),
        {"go": "seat", "hint": "A4-P3"},
        N("A4-2g"), A("A4-2h"),
        {"card": "A4-T1", "duration": 1.8},
        {"bg": "w2/shizuoka/bg_cert.png", "fill": "#5e2929", "actors": [], "hideAyu": True, "hotspots": []},
        N("A4-3a"), N("A4-3b"),
        {"material": "stamp"},
    ]})])

write("hainan", "G-10", [scene("wanning", "hainan", {
    "personHeight": 120, "badge": "G-02", "bg": "w2/hainan/bg_wanning.png", "sky": "#86cfe8", "ground": "#e8d6a8", "horizon": 250,
    "decor": [{"r": [0, 250, 360, 36], "c": "#4fb3c8"}],
    "walkArea": [[20, 400], [340, 400], [340, 560], [20, 560]], "start": [70, 550],
    "hotspots": [{"id": "stall", "at": [180, 520], "snap": [180, 520], "face": 1, "icon": "pick"}],
    "beats": [
        {"card": "G-10", "duration": 2.0},
        N("A5-0"), N("A5-1a"), N("A5-1b"),
        {"go": "stall", "hint": "A5-P1"},
        {"game": "ringtoss"},
        {"card": "A5-T1", "duration": 1.6},
        {"personHeight": 120, "bg": "w2/hainan/bg_wenchang_night.png", "sky": "#141a3a", "ground": "#22202e", "horizon": 470,
         "decor": [{"r": [0, 462, 360, 10], "c": "#2c3a5a"}],
         "place": [150, 585], "pose": "back",
         "actors": [{"id": "toretto", "tex": "w2/common/toretto_stand.png", "at": [215, 587]}], "hotspots": []},
        N("A5-2"), T("A5-3a"), A("A5-3b"),
        {"game": "fireworks", "count": 5},
        {"pose": ""},
        {"material": "wax"},
    ]})])

write("hongkong", "G-11", [scene("hk", "hongkong", {
    "badge": "G-02", "bg": "", "fill": "#2a1c18", "hideAyu": True,
    "beats": [
        {"card": "G-11", "duration": 2.0},
        N("A6-0"),
        {"hint": "A6-P1"},
        {"game": "mail"},
        {"hint": ""},
        N("A6-1"),
        {"personHeight": 112, "bg": "w2/hongkong/bg_arrival.png", "sky": "#cfe3ee", "ground": "#d8d2c6", "horizon": 330,
         "decor": [{"r": [0, 120, 360, 200], "c": "#a9c9dc"}, {"r": [0, 300, 360, 30], "c": "#7d8c7a"},
                   {"r": [296, 300, 54, 118], "c": "#3f7d5a"}, {"r": [306, 312, 34, 22], "c": "#f2f2f2"}],
         "hideAyu": False, "start": [50, 590], "follow": "w2/hongkong/suitcase_1.png",
         "walkArea": [[20, 380], [345, 380], [345, 615], [20, 615]],
         "actors": [{"id": "gate", "tex": "w2/hongkong/exit_gate.png", "at": [300, 400]}],
         "hotspots": [{"id": "exit", "at": [300, 405], "snap": [300, 402], "icon": "exit"}]},
        {"go": "exit", "hint": "A6-P3"},
        {"follow": ""},
        {"material": "envelope"},
        {"badge": ""},
        {"button": "A6-B2"},
    ]})])

write("finale", "G-12", [scene("finale", "finale", {
    "bg": "", "fill": "#3a1414", "hideAyu": True,
    "beats": [
        {"card": "G-12", "duration": 2.0},
        {"game": "finale"},
        {"bg": "bg_invite_desk.png", "hideAyu": False, "place": [180, 520], "pose": ""},
        A("A7-2b"), A("A7-2c"),
        {"choice": ["G-WEDDING", "G-VILLAGE"], "to": [None, "res://ayu_home/v4/phone_boot.tscn"]},
        {"bg": "", "fill": "#2a1210", "hideAyu": True},
        {"game": "seat"},
    ]}),
    {"id": "next", "type": "terminal", "sceneId": "finale_end", "speaker": "system", "actorMode": "none",
     "actorSlot": None, "background": "phone", "visibleActors": [], "copyId": "W-NEXT"}])
print("ok")
