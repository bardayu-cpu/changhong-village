#!/usr/bin/env python3
"""Translate one C4 layout into reviewable JSON candidates. Never writes the live assets."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

ASSETS = Path(__file__).resolve().parents[1] / "assets"

def read(path):
    return json.loads(path.read_text())

def move(point, delta):
    return [point[0] + delta[0], point[1] + delta[1], *point[2:]]

def within(point, rect):
    return rect[0] <= point[0] <= rect[0] + rect[2] and rect[1] <= point[1] <= rect[1] + rect[3]

def translate_record(row, delta):
    row = copy.deepcopy(row)
    for key in ("pos", "approach", "arrival", "at", "bounds"):
        if key in row:
            row[key] = move(row[key], delta)
    if "foot" in row:
        row["foot"] += delta[1]
    return row

def prepare(layout, assets=ASSETS):
    village = read(assets / "village.json")
    houses = read(assets / "village/houses.json")
    old_houses = {h["id"]: h for h in houses}
    wanted = {h["id"]: h for h in layout["houses"]}
    if set(wanted) != set(old_houses) or len(wanted) != len(layout["houses"]):
        raise ValueError("Layout must contain each of the 20 existing house IDs exactly once")
    size = layout["size"]
    shifts = {}
    for ident, house in old_houses.items():
        pos = wanted[ident]["pos"]
        shifts[ident] = [pos[i] - house["bounds"][i] for i in range(2)]
        if not within(pos, [0, 0, *size]) or not within([pos[0]+house["bounds"][2], pos[1]+house["bounds"][3]], [0, 0, *size]):
            raise ValueError("House exceeds world: " + ident)
    output_houses = [translate_record(h, shifts[h["id"]]) for h in houses]
    public = layout.get("public", {})
    spots = {h["id"]: h for h in village["hotspots"]}
    public_ids = set(spots) - {"visit_laowu"}
    missing = public_ids - set(public)
    if missing:
        raise ValueError("Missing public interaction anchors: " + ", ".join(sorted(missing)))
    public_shifts = {ident: [public[ident][i]-spots[ident]["pos"][i] for i in range(2)] for ident in public_ids}
    village["hotspots"] = [translate_record(row, shifts["laowu"] if row["id"]=="visit_laowu" else public_shifts[row["id"]]) for row in village["hotspots"]]
    village["doors"] = [translate_record(row, shifts[row["id"].removeprefix("visit_")]) for row in village["doors"]]
    prop_bindings = {"house_community": "community", **{ident:ident for ident in old_houses if ident!="community"}}
    public_props = {"honeybox":"honey", "notice":"map", "orchard0":"orchard", "orchard1":"orchard", "orchard2":"orchard", "public_pond":"pond", "site_pond":"home_site"}
    props = []
    old_props = {row["id"]:row for row in village["props"]}
    for row in village["props"]:
        ident = row["id"]
        if ident in prop_bindings:
            props.append(translate_record(row, shifts[prop_bindings[ident]]))
        elif ident in public_props:
            props.append(translate_record(row, public_shifts[public_props[ident]]))
        elif not ident.startswith(("c4_", "ground_courtyard_tree_", "wildtree")):
            raise ValueError("Unmapped prop, refuse to strand it: " + ident)
    for row in props:
        if row["id"] in layout.get("prop_positions",{}):
            target=layout["prop_positions"][row["id"]]
            delta=[target[i]-row["pos"][i] for i in range(2)]
            row.update(translate_record(row,delta))
    obstacles, obstacle_owners = [], {}
    for ident, house in old_houses.items():
        candidates = [b for b in village["obstacles"] if within([b[0]+b[2]/2,b[1]+b[3]/2],house["bounds"]) and house["bounds"][2]*.5<b[2]<=house["bounds"][2] and 100<b[3]<=house["bounds"][3]]
        if len(candidates)!=1:
            raise ValueError("Ambiguous building collision: " + ident)
        b = candidates[0]
        if tuple(b) in obstacle_owners:
            raise ValueError("Collision belongs to two houses")
        obstacle_owners[tuple(b)] = ident
        obstacles.append(move(b, shifts[ident]))
    for index, tree in enumerate(layout.get("trees", [])):
        row = copy.deepcopy(old_props[tree["template"]]) if "template" in tree else {}
        row.update({k:v for k,v in tree.items() if k not in ("template","obstacle")})
        row.setdefault("id", "layout_tree_"+str(index))
        if not all(k in row for k in ("file","pos","foot")):
            raise ValueError("Tree requires file, pos and foot")
        props.append(row)
        if "obstacle" in tree:obstacles.append(tree["obstacle"])
    mountain = layout["mountain_rect"]
    obstacles.append([0,0,size[0],mountain[1]+mountain[3]])
    village.update(size=size, walk_rect=[30,30,size[0]-60,size[1]-60], props=props, obstacles=obstacles,
                   blocked_polygons=[layout["water_polygon"]], rebuild_navigation=True,
                   landscape_obstacles=[], landscape_legacy_trees=[],
                   spawn=move(village["spawn"],shifts["ayu"]), location_points=layout["location_points"])
    village["npcs"] = [translate_record(row,public_shifts[row["id"]]) for row in village["npcs"]]
    topology = read(assets / "village/topology.json")
    topology.update(world_size=size, roads=[r["points"] if isinstance(r,dict) else r for r in layout["roads"]],
                    houses={h["id"]:h["bounds"] for h in output_houses},
                    public={h["id"]:h["approach"] for h in village["hotspots"]})
    terrain = read(assets / village["ground_layers"].removeprefix("res://ayu_home/v4/assets/"))
    terrain["layout"] = "res://ayu_home/v4/assets/village/layout-1025.json"
    index = read(assets / "rooms.json")
    index["rooms"]["village"] = copy.deepcopy(village)
    return {"village.json":village, "rooms.json":index, "village/houses.json":output_houses,
            "village/topology.json":topology, "village/layout-1025.json":layout,
            village["ground_layers"].removeprefix("res://ayu_home/v4/assets/"):terrain}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("layout",type=Path)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    out=args.output.resolve()
    if out==ASSETS.resolve() or ASSETS.resolve() in out.parents:
        parser.error("Use an isolated review directory, not production assets")
    files=prepare(read(args.layout))
    if out.exists():parser.error("Output already exists; preserve the earlier candidate")
    out.mkdir(parents=True)
    for name,value in files.items():
        dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_text(json.dumps(value,ensure_ascii=False,indent=2)+"\n")
    report={"source_sha256":hashlib.sha256(args.layout.read_bytes()).hexdigest(),"files":list(files),
            "houses":len(files["village/houses.json"]),"status":"candidate: navigation and visual review required; no production write"}
    (out/"candidate-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(report,ensure_ascii=False))

if __name__=="__main__":main()
