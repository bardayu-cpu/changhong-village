import copy
import importlib.util
import json
from pathlib import Path

root=Path(__file__).resolve().parents[3]
path=root/'godot/ayu_home/v4/tools/prepare_village_layout.py'
spec=importlib.util.spec_from_file_location('layout_candidate',path)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
assets=module.ASSETS
v=module.read(assets/'village.json');houses=module.read(assets/'village/houses.json')
roads=module.read(assets/'village/topology.json')['roads']
layout={'size':[5000,5000], 'houses':[{'id':h['id'],'pos':[h['bounds'][0]+20,h['bounds'][1]+80]} for h in houses],
        'public':{h['id']:[h['pos'][0]+20,h['pos'][1]+80] for h in v['hotspots'] if h['id']!='visit_laowu'},
        'roads':roads, 'field_paths':[], 'fields':[], 'trees':[], 'mountain_rect':[0,0,5000,180],
        'water_polygon':[[4900,180],[5000,180],[5000,5000],[4900,5000]],
        'location_points':{'lake':[1320,4160],'bamboo':[1770,4160],'hill':[1320,4560],'garden':[1770,4560]}}
result=module.prepare(layout);new=result['village.json'];checks=0
for before,after in zip(houses,result['village/houses.json']):
    assert after['bounds'][:2]==[before['bounds'][0]+20,before['bounds'][1]+80]
    assert after['at']==[before['at'][0]+20,before['at'][1]+80]
    assert after['bounds'][2:]==before['bounds'][2:];checks+=3
for before,after in zip(v['doors'],new['doors']):
    for key in ['pos','approach','arrival']:
        if key in before:assert after[key]==[before[key][0]+20,before[key][1]+80];checks+=1
old_props={p['id']:p for p in v['props']}
for after in new['props']:
    before=old_props[after['id']]
    assert after['file']==before['file'] and after.get('scale')==before.get('scale');checks+=1
    assert after['foot']==before['foot']+80;checks+=1
assert len(new['obstacles'])==21 and new['rebuild_navigation'];checks+=1
assert result['rooms.json']['rooms']['village']==new;checks+=1
assert new['blocked_polygons']==[layout['water_polygon']];checks+=1
for field in ['houses','public']:
    invalid=copy.deepcopy(layout)
    if field=='houses':invalid[field].pop()
    else:invalid[field].pop('loach_memory')
    try:module.prepare(invalid)
    except ValueError:checks+=1
    else:raise AssertionError('Missing mapping accepted: '+field)
proof={'checks':checks,'pass':True,'fixture':'20 houses shifted by (20,80); candidate objects only, production unchanged',
       'boundary':'No real village layout or visual acceptance; final C4 manifest still required'}
(Path(__file__).parent/'layout-candidate-checks.json').write_text(json.dumps(proof,indent=2)+'\n')
print(json.dumps(proof))
