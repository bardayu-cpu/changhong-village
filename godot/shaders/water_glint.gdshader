shader_type canvas_item;
// 湖面波光，像素光（画风页第 0 节：硬边，不叠半透明，在同一色带里调亮一档）：
// 把这块水面的底图再画一遍，但只留几格——水面上隔一阵冒出一小段 2～4 格长的横亮线，那几格换成同一色带里亮一档的颜色
// （主水色 → 浅倒影色、深水纹 → 主水色，颜色都是这张图本来有的），其余全透明（discard）。不读屏幕。
// 水面切成 cell 大小的格子，每格每一拍（1/rate 秒）按随机数决定亮不亮（density）、亮的那段在第几行、从哪起、多长。
uniform float density = 0.05;
uniform float rate = 3.0;
uniform vec2 cell = vec2(12.0, 6.0);
uniform vec4 from0 = vec4(0.0);
uniform vec4 to0 = vec4(0.0);
uniform vec4 from1 = vec4(0.0);
uniform vec4 to1 = vec4(0.0);

// 不用 sin 的随机数（手机上精度低时 sin 版会出条纹）
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    vec3 outc = vec3(0.0);
    bool water = false;
    if (distance(c.rgb, from0.rgb) < 0.01) {
        outc = to0.rgb;
        water = true;
    } else if (distance(c.rgb, from1.rgb) < 0.01) {
        outc = to1.rgb;
        water = true;
    }
    if (!water) {
        discard;
    }
    vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);   // 这张图上第几格
    vec2 cid = floor(px / cell);
    float beat = mod(floor(TIME * rate + hash12(cid) * 17.0), 997.0);
    if (hash12(cid + vec2(beat * 1.37, beat * 0.71)) > density) {
        discard;
    }
    float len = 2.0 + floor(hash12(cid + 5.7) * 3.0);
    float row = floor(hash12(cid + 3.1) * cell.y);
    float start = floor(hash12(cid + 9.3) * (cell.x - len));
    vec2 local = px - cid * cell;
    if (local.y != row || local.x < start || local.x >= start + len) {
        discard;
    }
    COLOR = vec4(outc, 1.0);
}
