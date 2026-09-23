shader_type canvas_item;
// 一整张图里几个人各自跟着拍子轻轻摇（乐队 v4 那块整舞台：地毯、钢琴、四个乐手连在一张图上，没法单独动某个人）。
// 每个区域 r = (左 x, 上 y, 右 x, 支点 y)，单位是这张图的像素；支点那一行不动，越往上摇得越多（像坐着上半身跟着拍子晃）。
// 只左右挪，挪出去的地方是透明底或者这个人自己，地毯在支点下面不动。区域最多 4 个，没用的填 0
uniform vec4 r0 = vec4(0.0);
uniform vec4 r1 = vec4(0.0);
uniform vec4 r2 = vec4(0.0);
uniform vec4 r3 = vec4(0.0);
uniform vec4 phase = vec4(0.0);   // 每个人的节拍错开一点
uniform float amp = 1.5;          // 顶上最多挪几像素
uniform float speed = 5.0;        // 摇的快慢（弧度/秒）

float off(vec2 p, vec4 r, float ph) {
    if (r.w <= r.y || p.x < r.x || p.x >= r.z || p.y < r.y || p.y >= r.w) {
        return 0.0;
    }
    float k = (r.w - p.y) / (r.w - r.y);
    return sin(TIME * speed + ph) * amp * k;
}

void fragment() {
    vec2 p = UV / TEXTURE_PIXEL_SIZE;
    float d = off(p, r0, phase.x) + off(p, r1, phase.y) + off(p, r2, phase.z) + off(p, r3, phase.w);
    COLOR = texture(TEXTURE, UV - vec2(round(d), 0.0) * TEXTURE_PIXEL_SIZE);
}
