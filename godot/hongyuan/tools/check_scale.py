"""比例检查：每个场景里画出来的人、车、物件，按真实尺寸核对比例。

规则（见 回执/W2工位/规格-统一比例尺.md）：
  场景里的人和物件统一按「这一排地面 1.65 米的人有多高」来换算，
  物件画出来的高度 = person_height_at(脚下 y) × 真实高度 / 1.65。
  现在 actors 用的是手调的 scale（= 画出高度 / 人高），这里把它换算成「隐含真实高度」，
  跟 REAL 表比，偏差超过 TOL 就报。俯视图（*_top.png）出现在正视场景里也报。

用法：python3 godot/hongyuan/tools/check_scale.py         只报告
      python3 godot/hongyuan/tools/check_scale.py --strict 有问题退出码 1（接进 run_all 后用）
"""
import json
import sys
from pathlib import Path

PERSON_M = 1.65
TOL = 0.15
# 贴图文件名（去掉目录）→ 画面里可见部分的真实高度（米）。新素材进来先登记一行。
REAL = {
    'car_street.png': 1.45,        # 侧面轿车，车身高
    'g42_side.png': 1.45,
    'axiao_idle.png': 1.65,
    'toretto_sit.png': 1.30,       # 坐姿
    'exit_gate.png': 2.40,         # 机场出口门
    'phone_ring_1.png': None,      # 道具特写，不参与比例
    'phone_prop.png': None,
}
TOP_DOWN_OK = {'drive', 'parking_top'}  # 允许俯视贴图的场景（开车小游戏本身）

root = Path(__file__).resolve().parents[1]
problems = []
checked = 0


def scene_steps(chapter):
    for scene in chapter.get('scenes', []) if isinstance(chapter.get('scenes'), list) else []:
        yield scene
    for step in chapter.get('steps', []) if isinstance(chapter.get('steps'), list) else []:
        yield step


def walk(node, where):
    global checked
    if isinstance(node, dict):
        sid = str(node.get('id', ''))
        for a in node.get('actors', []) if isinstance(node.get('actors'), list) else []:
            tex = str(a.get('tex', '')).split('|')[0]
            name = tex.split('/')[-1]
            scale = float(a.get('scale', 1.0))
            loc = '%s/%s actor %s' % (where, sid, a.get('id', name))
            if name.endswith('_top.png') and sid not in TOP_DOWN_OK:
                problems.append((loc, '俯视贴图 %s 放在正视场景里，透视对不上，需要正视/侧视版本' % name))
                continue
            if name not in REAL:
                problems.append((loc, '%s 没登记真实尺寸（REAL 表）' % name))
                continue
            real = REAL[name]
            if real is None:
                continue
            checked += 1
            implied = scale * PERSON_M * (0.844 if name.endswith('_sit.png') else 1.0)  # 同 world_scale.pose_ratio
            if abs(implied - real) / real > TOL:
                problems.append((loc, '%s scale=%.2f → 画出来相当于 %.2f 米，应为 %.2f 米（scale 应约 %.2f）'
                                 % (name, scale, implied, real, real / PERSON_M)))
        for w in node.get('walkers', []) if isinstance(node.get('walkers'), list) else []:
            checked += 1
            s = float(w.get('scale', 0.94))
            if not 0.9 <= s <= 1.12:
                problems.append(('%s/%s walker %s' % (where, sid, w.get('guest')), '路人 scale=%.2f，成年人应在 0.90～1.12' % s))
        for v in node.values():
            walk(v, where)
    elif isinstance(node, list):
        for x in node:
            walk(x, where)


for f in sorted((root / 'chapters').glob('*.json')):
    walk(json.loads(f.read_text()), f.stem)

seen = set()
for loc, msg in problems:
    key = msg
    if key in seen:
        continue
    seen.add(key)
    print('SCALE', loc, '：', msg)
print('检查 %d 项，问题 %d 类' % (checked, len(seen)))
if '--strict' in sys.argv and seen:
    sys.exit(1)
