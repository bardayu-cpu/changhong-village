#!/usr/bin/env python3
"""Rebuild the internal R1 comparison from actual committed banquet assets.
Legacy inputs are read from Git objects (works with sparse checkout); new R1
inputs are read from the current working files. No production files are changed.
Only integer NEAREST enlargement is used; no fit-to-cell, recoloring or redraw.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont

ART = Path(__file__).resolve().parents[1]
ROOT = ART.parents[2]
OUTPUT_NAME = 'R1-现有宴会厅对照'
TABLE_BOX = (204, 194, 290, 230)
CHAIR_BOX = (164, 184, 186, 230)
PANEL = (512, 416)
BG = (237, 234, 222, 255)
INK = (48, 53, 62, 255)
MUTED = (88, 91, 95, 255)
GUESTS = [('LM-GUEST-01', 'photographer_w.png', '摄影师'),
          ('LM-GUEST-02', 'farmer_2.png', '农夫'),
          ('LM-GUEST-10', 'elder.png', '老人')]


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def png(data):
    with Image.open(io.BytesIO(data)) as im:
        return im.convert('RGBA')


def font(size):
    for path in ['/System/Library/Fonts/STHeiti Medium.ttc',
                 '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
                 '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc']:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    raise RuntimeError('Chinese label font unavailable; install Noto Sans CJK or use macOS STHeiti')


def text(image, xy, value, size=14, fill=INK, center=False):
    draw = ImageDraw.Draw(image)
    draw.fontmode = '1'  # Crisp, binary glyph masks; no smoothing added to art.
    ft = font(size)
    x, y = xy
    if center:
        x -= draw.textbbox((0, 0), value, font=ft)[2] // 2
    draw.text((int(x), int(y)), value, font=ft, fill=fill)


def paste_bottom(panel, im, center_x, baseline):
    x, y = center_x - im.width // 2, baseline - im.height
    if x < 0 or y < 0 or x + im.width > panel.width or baseline > panel.height:
        raise ValueError('Asset no longer fits native-size panel; update layout, never auto-rescale it')
    panel.alpha_composite(im, (x, y))
    return [x, y, x + im.width, baseline]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ref', default='HEAD', help='Committed formal source revision; resolved to a full SHA')
    parser.add_argument('--r1-dir', type=Path, default=ART)
    parser.add_argument('--output', type=Path, default=ART / (OUTPUT_NAME + '.png'))
    args = parser.parse_args()
    revision = git('rev-parse', args.ref + '^{commit}').decode().strip()
    tracked = {}
    new_inputs = {}

    def source(path):
        data = git('show', revision + ':' + path)
        tracked[path] = {'git_revision': revision, 'sha256': sha(data)}
        return data

    def obj(path):
        return json.loads(source(path))

    def current(name):
        path = args.r1_dir / name
        data = path.read_bytes()
        new_inputs[name] = {'path': path.resolve().relative_to(ROOT).as_posix(), 'sha256': sha(data)}
        return png(data)

    # Verify the actual formal default rather than choosing the prettier hall.
    hall_cfg = obj('godot/assets/hall.json')
    main_code = source('godot/scripts/main.gd').decode()
    hall_code = source('godot/scripts/layered_hall.gd').decode()
    life_code = source('godot/scripts/hall_life.gd').decode()
    people_code = source('godot/scripts/lm_people.gd').decode()
    canvas_code = source('godot/scripts/canvas_assets.gd').decode()
    wedding_code = source('godot/hongyuan/wedding.gd').decode()
    assert hall_cfg['hall55'] is True, 'Formal default changed; re-review the source selection'
    assert 'const USE_LAYERED := true' in main_code
    assert 'hall.data_path = LayeredHall.DATA_55' in main_code
    assert 'var hall_variant_once := "?"' in main_code
    assert 'hall_variant_once =' not in wedding_code, 'Invitation now overrides the formal hall; re-review'
    assert 'await _enter_banquet()' in wedding_code
    assert 'return load(path)' in canvas_code
    assert 's.texture = Canvas.texture(o["image"])' in hall_code
    assert 's.offset = Vector2(o["x"], float(o["y"]) - foot)' in hall_code
    occluder_code = hall_code.split('func _occluders()', 1)[1].split('\nfunc ', 1)[0]
    assert '.scale' not in occluder_code, 'Furniture scale changed; update evidence before composing'
    assert 'float(r["sc"])' in life_code and 'target / maxf(1.0, float(r["h"]))' in life_code
    assert 'floorf(float(r["h"]) * hall.SIT_KEEP)' in life_code
    assert 'const SIT_KEEP := 0.62' in hall_code
    assert 'ga.get("codes", []) == codes' in people_code
    scene_path = 'godot/assets/layered/scene_roman_banquet_55/scene.json'
    scene = obj(scene_path)
    pp = scene['person_px']
    assert pp['far_h'] == pp['near_h'] == 84
    index = obj('godot/assets/characters/lm/lm_index.json')
    atlas_cfg = index['guest_atlas']
    fw, fh = atlas_cfg['fw'], atlas_cfg['fh']
    assert (fw, fh) == (64, 84)
    atlas_path = 'godot/assets/characters/lm/' + atlas_cfg['file']
    atlas = png(source(atlas_path))
    assert atlas.size == (fw * atlas_cfg['hframes'], fh * len(atlas_cfg['codes']))
    guest_images, guest_records, new_guests = [], [], []
    for code, new_name, label in GUESTS:
        spec = obj(f'godot/assets/characters/lm/chr_{code}.json')
        ix = index['looks'][code]
        row = atlas_cfg['codes'].index(code)
        frame = spec['frames']['down'][0]
        box = (frame * fw, row * fh, (frame + 1) * fw, (row + 1) * fh)
        im = atlas.crop(box)
        scale = 84 * spec.get('height_m', 1.75) / 1.75 / ix['h']
        assert scale == 1, 'Guest runtime scale changed; do not silently normalize source art'
        alpha_bbox = im.getchannel('A').point(lambda x: 255 if x > 127 else 0).getbbox()
        assert alpha_bbox and alpha_bbox[1] == ix['top'] and alpha_bbox[3] - alpha_bbox[1] == ix['h']
        # Atlas is the shipping texture; the corresponding source sheet must agree.
        original = png(source(f'godot/assets/characters/lm/chr_{code}.png'))
        assert im.tobytes() == original.crop((frame * fw, 0, (frame + 1) * fw, fh)).tobytes()
        guest_images.append(im)
        guest_records.append({'code': code, 'atlas_path': atlas_path, 'atlas_row_zero_based': row,
                              'frame_zero_based': frame, 'direction': 'down idle', 'crop_exclusive': box,
                              'native_frame': [fw, fh], 'body_top': ix['top'], 'body_height': ix['h'],
                              'height_m': spec.get('height_m', 1.75), 'runtime_scale': scale,
                              'seated_source_height': int(ix['h'] * .62),
                              'usage': 'seated upper-body/turning via _kit_frame; full frame when standing/leaving via _kit_body/_kit_pose'})
        new = current(new_name)
        assert new.size == (64, 84), 'New person size changed; preserve dimensions and review panel layout'
        new_guests.append(new)
        new_inputs[new_name]['native_size'] = list(new.size)

    furniture = []
    furniture_records = []
    for file in ['art_table.png', 'art_bench.png']:
        path = 'godot/assets/layered/scene_roman_banquet_55/' + file
        occurrences = [o for o in scene['occluders'] if o.get('image') == 'res://' + path[6:]]
        assert occurrences, 'Selected furniture is not referenced by the formal scene'
        im = png(source(path))
        furniture.append(im)
        furniture_records.append({'path': path, 'native_size': list(im.size), 'runtime_scale': 1,
                                  'semantic_label': '圆桌和椅（原图整件）' if file == 'art_table.png' else '补充长凳（非单椅）',
                                  'visible_content': '桌面周围的就座椅已画在同一张原图内' if file == 'art_table.png' else '独立长凳，仅作补充家具参照，不对应右侧单椅',
                                  'crop_exclusive': [0, 0, im.width, im.height], 'instance_count': len(occurrences),
                                  'example_instance': occurrences[0], 'extraction': 'whole texture, no tight-crop or rescale'})
    assert furniture[0].size == (180, 150) and furniture[1].size == (72, 54)
    board = current('比例尺.png')
    assert board.size == (560, 448), 'R1 scale-board size changed; V1-approved crop coordinates must be reviewed'
    new_table, new_chair = board.crop(TABLE_BOX), board.crop(CHAIR_BOX)
    new_inputs['比例尺.png'].update({'native_size': list(board.size), 'table_crop_exclusive': TABLE_BOX,
                                  'chair_crop_exclusive': CHAIR_BOX, 'source_baseline_y': 230,
                                  'note': 'V1-approved crops; original paper color retained'})

    panels = [Image.new('RGBA', PANEL, BG), Image.new('RGBA', PANEL, BG)]
    for side, panel in enumerate(panels):
        draw = ImageDraw.Draw(panel)
        draw.rectangle((0, 0, PANEL[0]-1, PANEL[1]-1), outline=(181, 178, 166), width=1)
        text(panel, (20, 14), '旧宴会厅：正式默认 55 桌' if side == 0 else '新 R1：当前源稿文件', 21)
        text(panel, (20, 43), '成人完整正面帧，运行 scale = 1' if side == 0 else '同尺度样本；身份不作一一对应', 14, MUTED)
        for i, im in enumerate(guest_images if side == 0 else new_guests):
            cx = [96, 256, 416][i]
            paste_bottom(panel, im, cx, 156)
            text(panel, (cx, 163), GUESTS[i][0] if side == 0 else GUESTS[i][2], 14, center=True)
        draw.line((20, 187, 492, 187), fill=(197, 193, 180))
        text(panel, (20, 194), '原图“圆桌和椅”＋补充长凳（非单椅）' if side == 0 else '比例尺板中的圆桌及椅子原尺寸裁切', 14)
        for im, cx in zip(furniture if side == 0 else [new_table, new_chair], [182, 382]):
            paste_bottom(panel, im, cx, 364)
        text(panel, (182, 372), '圆桌和椅 180×150' if side == 0 else '86 × 36', 14, center=True)
        text(panel, (382, 372), '补充长凳 72×54' if side == 0 else '22 × 46', 14, center=True)
        text(panel, (20, 397), '单位：画布像素；不按物件大小自动缩放', 12, MUTED)

    canvas = Image.new('RGBA', (2144, 1592), (249, 248, 243, 255))
    text(canvas, (32, 18), 'R1 内审｜现有宴会厅与新源稿对照', 30)
    text(canvas, (32, 61), f'旧图取自正式提交 {revision[:12]}；右侧读取当前 R1。此图为取材对照，不代表审定通过。', 18, MUTED)
    placements = []
    for scale, title_y, top in [(1, 103, 142), (2, 590, 630)]:
        text(canvas, (32, title_y), f'{scale}×  /  ' + ('原尺寸：1 图像像素 = 1 画布像素' if scale == 1 else '最近邻精确放大：每个原像素变为 2×2 方块'), 23)
        for side, panel in enumerate(panels):
            image = panel if scale == 1 else panel.resize((PANEL[0]*2, PANEL[1]*2), Image.Resampling.NEAREST)
            x = 32 + side * 1056 + (1024-image.width)//2
            canvas.alpha_composite(image, (x, top))
            crop = canvas.crop((x, top, x+image.width, top+image.height))
            assert crop.tobytes() == image.tobytes(), 'Unexpected panel resampling or clipping'
            placements.append({'side': 'old' if side == 0 else 'new', 'scale': scale, 'rect': [x, top, x+image.width, top+image.height]})
    text(canvas, (32, 1482), '旧图从实际出货宾客图集和场景引用中取材；55 桌坐席只显示上方 52px，站立/离席使用完整 84px 帧。', 18)
    text(canvas, (32, 1514), '两列在每一档严格同尺度；桌椅尺寸差异按原样保留。透明像素仅合成到同一中性底色，无调色、重画或平滑。', 18)
    text(canvas, (32, 1546), '右侧圆桌/椅子保留比例尺板纸色。坐标、调用链、输入哈希及复跑方式见同名“取材”记录。', 18, MUTED)
    # Reject torn input while another worker regenerates R1. Existing output stays intact.
    for item in new_inputs.values():
        assert sha((ROOT / item['path']).read_bytes()) == item['sha256'], 'R1 changed during composition; rerun after regeneration finishes'
    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.output, optimize=True)
    evidence = {'legacy_revision': revision, 'formal_variant': '55 (fresh/default, no local debug override)',
                'source_method': 'git show <resolved SHA>:<path>, read into memory; no sparse-checkout expansion',
                'guests': guest_records, 'furniture': furniture_records, 'legacy_input_hashes': tracked,
                'new_inputs': new_inputs, 'panel_size_1x': PANEL, 'placements': placements,
                'output_size': canvas.size, 'output_sha256': sha(args.output.read_bytes()),
                'validation': {'atlas_matches_source_frames': True, 'body_metrics_match_index': True,
                               'all_guest_runtime_scales': 1, 'furniture_runtime_scale': 1,
                               'same_scale_both_columns': True, 'nearest_only': True, 'new_inputs_stable': True},
                'scope': 'static call-chain and pixel extraction verification, not a new Godot runtime test or art approval'}
    args.output.with_name(args.output.stem + '-取材.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2)+'\n')
    def line(code, token):
        return next(i for i, s in enumerate(code.splitlines(), 1) if token in s)
    lines = [
        '# R1 对照图取材证据', '', f'正式旧图基准：`{revision}`。右侧为运行脚本时当前 R1 文件，哈希见同名 JSON。', '',
        '## 加载与缩放依据', '',
        f'- `godot/assets/hall.json`：hall55=true。`godot/scripts/main.gd:{line(main_code,"func hall_variant()")}` 优先级为一次性/同版本调试覆盖，未覆盖时读此正式配置；`_make_hall` 选择 DATA_55。',
        '- `godot/hongyuan/wedding.gd` 继承 main，正式邀请调用 `_enter_banquet()`，没有覆盖 hall_variant_once。此处核验默认路径，不假设个人调试存档。',
        f'- `godot/scripts/lm_people.gd:{line(people_code,"static func guest_atlas")}`：读取 lm_index 的 guest_atlas；`hall_life.gd:{line(life_code,"func _kit()")}` 调用 guests_present/guest_atlas。',
        f'- `godot/scripts/layered_hall.gd:{line(hall_code,"func _px_h")}` 按 person_px 插值；55 场景 far_h=near_h=84。成人 height_m=1.75，index.h=84，实际 scale=84×1.75/1.75/84=1。',
        f'- `godot/scripts/hall_life.gd:{line(life_code,"func _kit_frame")}` 坐席截 floor(84×0.62)=52px；`_kit_body/_kit_pose` 站立/离席使用完整帧。本板展示完整正面 idle 帧，没有把坐席截图拉高。',
        f'- `godot/scripts/layered_hall.gd:{line(hall_code,"func _occluders")}` 通过 Canvas.texture 加载真实家具，centered=false、offset=(x,y-foot)、父节点=(0,foot)，未赋 scale，故原图1:1。Canvas.texture 直接 load。', '',
        '## 原图及截取（右/下界不含）', '',
    ]
    for g in guest_records:
        lines.append(f'- {g["code"]}：`{g["atlas_path"]}`，图集行 {g["atlas_row_zero_based"]}、down idle 帧 {g["frame_zero_based"]}，crop={g["crop_exclusive"]}，64×84，scale=1；已逐像素核对同编号 chr PNG 首帧一致。')
    for f in furniture_records:
        lines.append(f'- **{f["semantic_label"]}**：`{f["path"]}`，{f["visible_content"]}。完整图 {f["native_size"]}，场景引用 {f["instance_count"]} 次；样例 {f["example_instance"]}。保留原透明边界，不裁成更紧的包围盒。')
    lines += ['', '## 新 R1 与复跑', '',
              '- 人物按原名读取 photographer_w.png、farmer_2.png、elder.png，均不缩放。三组是画风样本，并非相同角色身份配对。',
              f'- 比例尺板保持 560×448、基线 y=230；圆桌 crop={TABLE_BOX}，椅 crop={CHAIR_BOX}，严格使用 V1 指定坐标。保留原纸色，不另画替代物。',
              '- 全部旧图从 Git 对象读入内存，不展开稀疏目录，不落临时素材；输入哈希可复核来源。没有修改正式场景或其他源稿。',
              '- 每档左右严格同尺度；原尺寸与 2 倍同时在一图中，2 倍仅 Image.Resampling.NEAREST。原素材颜色与尺寸不做归一化。',
              '- 这是静态调用链/图像取材核验，不是新一轮游戏运行或 Claude 审定。此对照图含旧素材颜色，不属于 R1 新素材色板审计集合。', '',
              '```sh', 'python3 回执/山庄收尾/画风/source/compare_r1.py', '```', '',
              'V1 重生成三个人物和比例尺后执行同一命令即可；脚本会重新取当前文件并更新取材 JSON。输入若在拼图期间变化会拒绝写出，避免半新半旧。', '',
              '阿鱼要做的事：暂时不用做。', '']
    args.output.with_name(args.output.stem + '-取材.md').write_text('\n'.join(lines))
    print(json.dumps({'output': str(args.output), 'size': canvas.size, 'legacy_revision': revision,
                      'guest_frames': len(guest_records), 'furniture_images': len(furniture_records),
                      'sha256': evidence['output_sha256']}, ensure_ascii=False))


if __name__ == '__main__':
    main()
