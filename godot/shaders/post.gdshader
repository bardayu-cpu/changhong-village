shader_type canvas_item;
// HD-2D 的后期：移轴模糊（上下两头虚、中间实）、暗角、稍微提饱和
// 只用一次采样循环，手机上也扛得住

uniform float focus = 0.64;
uniform float strength = 2.2;
uniform float vig = 0.38;
uniform float sat = 1.08;

const vec2 K[12] = vec2[12](
    vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
    vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893),
    vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598));

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    float d = abs(UV.y - focus);
    float r = strength * smoothstep(0.12, 0.5, d);
    if (r > 0.05) {
        vec4 acc = c;
        for (int i = 0; i < 12; i++) {
            acc += texture(TEXTURE, UV + K[i] * r * TEXTURE_PIXEL_SIZE * 2.0);
        }
        c = acc / 13.0;
    }
    float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    c.rgb = mix(vec3(l), c.rgb, sat);
    vec2 q = UV - 0.5;
    q.x *= 0.7;
    c.rgb *= 1.0 - vig * smoothstep(0.3, 0.8, length(q));
    COLOR = vec4(c.rgb, 1.0);
}
