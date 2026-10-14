shader_type canvas_item;
uniform float heat_strength = 0.0;
uniform vec2 field_world_size = vec2(585.0,215.0);
uniform float rain = 0.0;
void fragment() {
    vec2 uv=UV;
    float band=smoothstep(.04,.65,UV.y);
    float wave=sin(TIME*1.7+UV.y*31.0+UV.x*5.0)+.35*sin(TIME*.9+UV.y*57.0);
    uv.x+=wave*.75/max(field_world_size.x,1.0)*heat_strength*band;
    uv=clamp(uv,vec2(.001),vec2(.999));
    vec4 c=texture(TEXTURE,uv);
    if(rain>0.0)c.rgb*=mix(vec3(1.0),vec3(.8,.86,.95),rain);
    COLOR=c;
}
