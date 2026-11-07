# D3 全篇缺图接入表（2026-11-07）

## 登记室画风定向返修

scene_interactions指出旧登记室人物/木纹/墙线偏平滑插画，故只重画registry画风，未改其他八张。首轮像素化画幅漂为928×1695，未接入；第二轮使用原841×1870作为几何基准、首轮作笔法参考，实际输出841×1870，已替换registry.png。新图有明确阶梯轮廓、木纹色块、像素人物和地面硬边光影。主要互动锚点保持原范围；生成式编辑不是像素级配准，细小装饰线位置仍有差异，接入需看盖章点/手/桌沿对齐，不宣称坐标完全零差。

最终编辑提示词：
Precise two-reference STYLE TRANSFER. IMAGE1 is the TARGET and absolute locked layout: extremely tall narrow9:20 portrait room, 841x1870, use its exact full-frame composition. IMAGE2 is ONLY a pixel-art brushwork reference, NOT its framing or object positions. Redraw IMAGE1 with the chunky hard-edged mosaic pixel style of IMAGE2. Do not use image2's wider and shorter canvas! Output must have IMAGE1's narrow tall9:20 aspect and identical framing: substantial lower foreground floor; registration desk in upper half, clerk sitting behind it; all objects stay at the exact same relative screen coordinates as IMAGE1. Compare image1 and your result: desk corners, flag, wall board, windows and lights must align when overlaid at equal dimensions. No rearrangement, no zoom, no cropping, no changed proportions. Same Chinese Shanghai registration office and same THREE people, same warm colors. Pixel technique: stepped square contours, crisp 3-4px pixel clusters, 4-7 discreet solid shades per material, no smooth gradients, no antialiasing, no painted textures. Pixel characters like old farming RPG sprites. Keep blank wall panel, no text, no UI. The whole output is a pixel-restyled copy of IMAGE1 on the same extremely tall 9:20 canvas.

使用**内置 image_gen**逐张生成/编辑并查看，未用CLI/API。九张PNG均实际写入：
`/Users/kayra_ayu/Documents/Codex/2026-11-05/1-11-5-11-9-gpt/work/round1/repo/godot/hongyuan/assets/round1/scenes/`。
未修改代码、git或已认可的desk_r4。旧生成来源保留。本文为接图说明，**不代表Claude/D4验收通过**。

## 九张已落地素材

| 文件 | 实际像素 | 构图与接入说明 |
|---|---|---|
| shanghai_drive.png | 841×1870 | 9:20硬像素。道路x=90–270（360逻辑宽），车道中心120/180/240，上下贯通，路上无烘焙车。江水/栏杆/树/外滩楼/侧边路人。道路上下对齐，侧建筑不严格无缝，滚动可轻交叠，不能宣称无缝贴图。 |
| shanghai_parking.png | 813×1935 | 加高版。两个纵向朝前空车位，按360宽中心cover：车位中心x约118/250，y约300–445；前景y465以下站人。自动尺寸比9:20略高，等比cover、不拉伸。无车或主角，远景3人静态。 |
| panda_garden.png | 841×1870 | 卧龙山林、竹林、木架、草地，40%以下开放草地与土路；熊猫由程序叠加。初版过宽已定向修为9:20。无烘焙熊猫，两个背景游客在上方栏杆后。 |
| hk_street.png | 841×1870 | 香港楼宇、面包店/茶座、红的士/绿电车。背景游客脚点约图38%–47%，双人近景可站图66%–78%。招牌无字，动态NPC另叠。 |
| university.png | 841×1870 | 香港山景校园、门楼/门卫/学生，下半砖路可走/合照。原创香港校园氛围，不代表某所真实大学实景，勿附会具体校名。 |
| disney_toys.png | 841×1870 | 玩具主题园区、积木/玩具士兵/彩球，上半游客、下半可走。无主角，动态NPC另叠。 |
| disney_garden.png | 841×1870 | 旋转木马/园林/远处城堡，上半游客、前景长步道。用于逛园；主合照可继续用已有专用城堡场景。 |
| registry.png | 841×1870 | 上海民政局登记室，登记员/等候客人/柜台/前景可走，无主角，不含日本元素。正确地点文字由程序绘制。 |
| wanning_beach.png | 841×1870 | 万宁白天真沙滩、椰树、近岸泳客、游客、右上中泳池、左木栈道。池中两只装饰泳圈是静态，交互目标请放真实水面。 |

## 最终锚点

841×1870图在360逻辑宽居中cover时，高约800，原点y约-80（未拖镜头）。
- **registry**：原图工作人员头顶(440,595)，手(440,700)，桌前沿y730、桌底y850；逻辑头约(188,175)、盖章桌面(188,220)、桌底y284。双人到柜台建议脚点(145,365)/(218,365)、身高约110；合照脚点(145,470)/(215,470)。左侧等候客人、右侧椅子不可穿越。红牌逻辑约x95–278,y58–120可绘地点文字。
- **wanning**：池面原图x560–840,y580–745，逻辑约x240–360,y168–239。投圈主角需走近池边；不要把交互漂浮物放在前景沙地。
- **parking**：813×1935按宽度360等比后高约857、居中原点y=-108；车位中心x约118/250、y300–445。必须从下向上驶入，不能沿用横停车位置。
- **panda/hk/disney/university**：图内人群都在较远区域；新NPC必须按景深缩放，不能把近景基准身高直接放远景旁。

## 复核边界

九个PNG都已解码校验并查看主体、画风、场地留白、是否烘焙主角。环境用明确色块/阶梯边缘，暖色和自然绿统一。背景游客只是静态环境，不能算动态NPC已实现。程序接入后的比例/遮挡/移动路径由D2实跑，Claude/D4最终审批。没有动用户既有代码或提交git。

## 完整提示词（内置image_gen）

带final/fixed的条目是比例修正编辑，输入图均已先查看。不是CLI/API，不用程序拼画代替生成。

### shanghai_drive

Use case: stylized-concept. Production mobile game background, original hard-edged pixel art, portrait 9:20. Create a vertically scrolling top-down driving road along Shanghai's Bund in warm daylight. Strict orthographic overhead view, absolutely no vanishing-point road perspective. A straight asphalt carriageway occupies exactly x=25% through x=75% of the full width, three equal lanes centered at x=33.33%,50%,66.67%, all lanes extend continuously from top edge to bottom edge. White dashed lane dividers, warm gray finely pixel-textured asphalt, no cars anywhere on the road and no baked-in protagonist. To left: narrow brick promenade, green trees in raised planters, black-and-gold lamps, low riverside railing, slim strip of blue river on very left. To right: old Shanghai Bund stone facades seen from overhead, tiled sidewalk with flower planters, lamp posts, tree crowns, occasional tiny distant pedestrians on sidewalk only, NEVER in lanes. Keep vehicle travel width clear. Main readable silhouette is the open road. Upper and lower road edges align exactly so this can scroll vertically. Authentic chunky 16-bit Stardew-like mosaic pixel clusters with clear stepped edges and a limited rich palette, matching warm Shanghai street game art, not soft digital illustration, not flat vector blocks, not 3D, no smooth antialiasing or blur, no text, no border, no UI. Landscape detail should remain legible at 360x800. Full-bleed 9:20.

### panda_garden

Use case: stylized-concept. Production mobile game background, original hard-edged pixel art, portrait 9:20. A peaceful giant-panda garden inspired by Wolong Shenshuping in Sichuan: green mountain forest and hazy distant hills across top 20%, abundant bamboo groves along left and right edges, natural lawns, a few broad mossy stones and tree roots, small rustic wooden climbing platform at upper center-left, small shaded wooden resting platform upper right, rough low timber fences at far middle edges. Main middle and lower 60% is open grass and a winding warm packed-earth caretaker path, with two subtly defined lawn islands and accessible approach spaces. Six pandas will be separate moving game sprites so DO NOT draw any pandas or other animals; DO NOT draw the player or any close-up human. A couple of tiny distant visitors may appear behind distant fence at top third only. Keep foreground x=10%-90% and y=50%-88% open for people to walk around feeding positions; do not fill with rocks or water. Slightly elevated 3/4 top-down cozy farming RPG environment, grounded believable scale, no giant foreground bamboo obscuring gameplay. Hand placed chunky pixel clusters, warm sunlight, crisp stepped outlines, restrained natural greens and golden earth, visible 16-bit mosaic texture at 360x800, Star-dew-like pixel world not anime illustration, not photorealistic, no smooth painting, no readable text, no UI, full-bleed 9:20.

### hk_street

Use case: stylized-concept. Production mobile game background, original hard-edged pixel art, portrait 9:20. A warm beautiful Hong Kong street memory, lively but with spacious pedestrian foreground for two main characters to walk and take a photo. Slightly elevated 3/4 RPG view. Stacked Hong Kong apartment facades and colorful small awnings in upper half, a red taxi and green tram small in a distant cross street, hanging shop-sign shapes WITHOUT ANY LETTERS OR TEXT, green hillside visible through upper distance. A bakery window with pineapple-bun shapes, cafe seating and plants at side edges. A handful of small background pedestrians naturally conversing or walking in far middle ground, no central protagonist couple baked in. The bottom half is a continuous attractive tiled pedestrian plaza with clear path, only a few pots at edges, keep center x=20%-80%, y=50%-85% empty enough for game characters. Consistent scale between doors, people, street furniture. Rich but organized hard pixel clusters, readable stepped edges, warm coral/teal/amber palette, crisp Stardew-like 16-bit mosaic pixel art, no soft painted illustration, no smooth gradients, no 3D, no lens blur, no text, no UI or border. Full-bleed vertical 9:20.

### panda_garden_fixed

Edit the supplied panda-garden background. Preserve the exact hard-edged pixel-art environment, bamboo borders, Wolong mountain atmosphere, timber climbing platforms, grassy clearings and packed-earth paths. Correct ONLY the canvas and composition to an EXTREMELY TALL NARROW 9:20 portrait game background, width less than half height, target 900x2000 (same 9:20 format as a modern phone screen). The previous output was too square. Recompose with mountain/forest backdrop and platforms in upper 30%, main open lawn and meandering walkable path stretching vertically through lower 70%; do not shrink a square picture inside margins and do not stretch objects. Keep vegetation at side edges, foreground center open. No pandas, no protagonists, no UI, no text, no frame. Use consistent crisp chunky 16-bit pixel clusters with stepped outlines and no soft painting. Fill entire 9:20 image.

### university

Production asset for a cozy pixel game: extremely tall narrow PORTRAIT 9:20, target 900x2000, width less than half height. Full-bleed Hong Kong university campus entrance viewed slightly from above in a 3/4 farming RPG camera. Bright warm afternoon. Upper 30% has a green hillside, broad trees and a handsome cream brick university academic building with symmetrical windows and a modest entrance arch, deliberately no lettering. Middle has an accessible gateway, side guard station, flowerbeds, an information board without text, a few tiny college students chatting far to the sides. The entire lower half is a broad sunlit cream/red brick pedestrian plaza where a couple can walk and be photographed; leave central area x=20%-80% y=50%-88% unobstructed, no protagonist couple. Soft leaf shadow rendered as clear pixel clusters, greenery framing both edges. Match original Shanghai game background: authentic hard-edged Stardew-like pixel mosaic, warm structured shading, visible stair-step outlines at 360x800 scale, not smooth anime, not a painted illustration, not 3D, no gradients or blur, no readable text, no UI, no border. Environment should look inviting and inhabited, accurate sizes for doors/benches/students.

### disney_toys

Production asset for a cozy pixel mobile game. EXTREMELY TALL NARROW 9:20 portrait, target900x2000, width less than half height, full-bleed. A joyful Hong Kong Disneyland toy-themed land with giant brightly colored toy building blocks, a playful toy soldier lookout and oversized interlocking construction toys at background and side edges, warm yellow/orange/red/blue structures with green tropical landscaping. Slightly elevated three-quarter farming RPG camera, coherent scale. Sky and distant green hills top20%, toy structures upper40%; a curved well-kept tan paved walkway extends throughout lower55%, central broad space for game characters to walk. Several small background tourists at upper-middle edges, one parent with a child and another pair taking a photo, but no main protagonist couple baked into image, no large foreground people. Keep x20%-80% y50%-88% free of structures for walkable area. Only signs shaped as icons, ABSOLUTELY NO LETTERING OR WORDS. Authentic chunky 16-bit pixel art with crisp mosaic clusters and stepped contours, organized warm palette matching a cozy Shanghai pixel street; not vector flat blocks, not smooth cartoon illustration, no painterly strokes, no 3D, no blur. No UI, border or inset panels.

### disney_garden

Production background for a cozy pixel mobile game. EXTREMELY TALL NARROW portrait 9:20, target900x2000, width less than half height, full-bleed. Beautiful Hong Kong Disneyland garden and carousel memory in warm late afternoon: ornate pastel carousel with small horses and glowing golden bulbs in the upper-middle background, tropical palms, carefully shaped flowerbeds, cheerful small fantasy-style Victorian lampposts, a glimpse of colorful castle spires far above treetops. Slightly elevated 3/4 farming-RPG perspective. Curved peach stone path connects carousel to foreground; entire bottom55% is spacious walkable stone path and small grass borders. A few small background families strolling around carousel and seated on distant benches, no central protagonist couple. Clear open center x20%-80% y50%-88% for two game sprites and picture taking. Crisp Stardew-like hard pixel clusters, delightful detailed mosaic texture, stepped edges, warm golden/light peach/leaf green palette, no smooth painted illustration, no blur, no 3D, no readable words, no UI, no frame.

### registry

Production game background, extremely tall narrow full-bleed 9:20 portrait, target 900x2000, width less than half height. Original hard-edged pixel art of a warm modern Shanghai Jing'an civil marriage registration office in China, NOT Japan. Slightly elevated three-quarter interior camera. Cream walls, red heart motif and elegant blank red wall panel high on back wall, small Chinese national flag to side, warm wooden doors, plants, paper files and softly sunlit windows. A single broad wooden registration counter across upper-middle, from x20%-80% and y35%-51% of full picture, with ONE friendly middle-aged registrar in modest formal office clothing seated behind counter. A pair of plain empty guest chairs to side, a couple of small background waiting visitors along the far left wall, no main couple baked in, no bride/groom. Foreground lower half is empty warm patterned tile floor, enough for two game sprites to walk from bottom and stand at counter and then take a photo. Clear central walkable corridor x25%-75% y52%-90%, no blocking furniture. Natural scale, staff head about 6% of picture width, not a portrait closeup. Rich hard pixel clusters and stepped outlines like a polished 16-bit cozy RPG, visible mosaic at 360x800 display, warm red/wood/cream palette, no smooth anime or painted illustration, no 3D. Absolutely NO readable text or numbers anywhere, no UI, no frames. The blank red panel will get correct Chinese text in code.

### shanghai_parking

Production mobile game background. EXTREMELY TALL NARROW 9:20 portrait, target900x2000, width less than half height, full bleed. Beautiful Shanghai riverside parking court by the Oriental Pearl Tower in warm late-afternoon daylight, hard-edged mosaic pixel art matching a cozy Shanghai street game. High-angle three-quarter view, much higher camera than ordinary street photo, so cars overlaid in top-down-ish sprites will fit. Top25% has blue sky, a slim recognisable Oriental Pearl Tower across the river and small skyline. Middle has low riverside railing, trees in planters, bronze street lamps, 3 small distant pedestrians behind the lot near railing. Below railing TWO EMPTY VERTICAL LONGITUDINAL PARKING BAYS side by side: both point UP towards railing, NOT horizontal sideways. Exactly two U-shaped pale yellow parking outlines and dark asphalt inside, first bay spans x25%-44% of width, second bay x61%-80% of width. Both extend vertically from y47% to y65% of full image; head stops at top, mouths open downward to foreground. NO CARS anywhere, no protagonist. Lower30% is a spacious sunlit terracotta stone plaza/walkway where two people can stand between and below car fronts, with flowers only at far edges. Ground perspective and bay sizes should be coherent, no obstacles in central walking area. Crisp stepped pixel contours, textured warm paving, cool river blues, leaf shadows as hard clusters, authentic 16-bit Stardew-like pixels, not a smooth illustration, not flat vector, no blur, no text, no UI or border.

### wanning_beach

Production mobile game background, extremely tall narrow full-bleed 9:20 portrait, target900x2000, width less than half height. Sunny Wanning Hainan island holiday beach, a lively beautiful memory in original hard-edged mosaic pixel art. Slightly elevated 3/4 farming-RPG camera with horizon high in upper20%. Turquoise ocean with a few gentle white wave edges, distant islands, a handful of tiny swimmers in near-shore shallows. Palm trees and lush tropical green along side edges. At upper-middle RIGHT side a small elegant beachfront resort swimming pool, pale stone rim, loungers and umbrellas, a few distant holiday guests around it. Most center and lower half MUST be genuine warm golden sand with subtle footprints, occasional tiny shells, one narrow wooden boardwalk along far left edge, NOT a huge stone-paved plaza. Several small background beachgoers walking, relaxing or carrying towels in upper-middle, no main protagonist couple baked in. Keep central lower x20%-80%, y55%-85% open sand for two game sprites to walk or throw floating rings; leave pool water visible at middle-right for ring targets, no kiosk or prize stall. Good life and scale, no giant foreground people. Crisp chunky 16-bit pixel clusters with stepped contours, warm sand/coral and clear teal palette, no smooth gradient, no soft painted or anime illustration, no 3D, no text, no UI, no border.

### registry_final

Edit only the aspect-ratio/canvas of the supplied finished pixel-art marriage registration office. REQUIRED OUTPUT CANVAS: exact aspect ratio 9:20, extremely narrow tall portrait, 841 pixels wide by1870 pixels high. The current picture is 897x1752 and therefore TOO WIDE relative to height. Preserve the entire office, all people, desk, red blank wall panel, plants, windows and Chinese setting unchanged in design and relative sizes. Outpaint additional matching floor below and a little ceiling above to make true9:20; do not stretch objects, do not invent furniture or new people. Keep the clerk and desk in upper half and big clear walkable floor below. Crisp hard-edged pixel mosaic, not soft painting. No text or UI. Full-bleed canvas with no blank margins.

### shanghai_parking_final

Edit only the aspect-ratio/canvas of this finished pixel-art Shanghai parking scene. REQUIRED OUTPUT CANVAS: exact9:20 very tall portrait, 841 pixels wide by1870 pixels high. Current897x1752 is too wide. Preserve both EMPTY VERTICAL parking bays, Oriental Pearl skyline, riverside, tree shadows, lamps and background visitors. Outpaint some matching blue sky at top and sunlit tiled walkway below to make true9:20, do not stretch objects, do not change bay orientation or introduce cars. Bays must remain in middle-to-lower part and front pedestrian space stays open. Same hard-edged pixel mosaic. No text, UI, border, or protagonist.

### university_final

Edit only the aspect ratio/canvas of this finished Hong Kong university pixel-art background. REQUIRED OUTPUT CANVAS exact9:20 very tall narrow portrait, 841 pixels wide by1870 pixels high. Current897x1752 is too wide. Preserve the complete academic building, gate, staff and background students, trees and flowers in the same visual design, size relationships and positions relative to one another. Outpaint a little blue sky and more warm brick foreground plaza until ratio is9:20; never stretch objects, never place a square image inside borders. Lower half must be open walkable plaza for game sprites. Same hard-edged pixel mosaic, no smooth illustration. No text, no new people, no UI.

### wanning_beach_final

Edit the supplied Wanning beach game background to a much TALLER NARROWER PHONE CANVAS ONLY. Output extremely tall portrait, width must be less than45% of the height (target841x1870 or taller), NOT the current roughly1:2 ratio. Preserve the scenery, pool, all tourists, shoreline, trees and their relative sizes. Add some clear blue sky above and more open pixel-art sand with subtle footprints below, while keeping the resort pool, ocean and people in upper half. Do not stretch or distort anything, do not introduce any main characters, no cars, no buildings in foreground. The added sand is walkable space for game sprites. Same warm crisp hard-edged chunky pixel mosaic style. No labels, no text, no border, no UI. Full bleed.
