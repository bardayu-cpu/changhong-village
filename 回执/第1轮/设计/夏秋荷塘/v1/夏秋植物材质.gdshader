shader_type canvas_item;
uniform int season = 2;
uniform float rain = 0.0;
uniform float summer_sun = 0.0;
uniform int plant_kind = 0;
uniform sampler2D spring_plant_mask : filter_nearest, repeat_disable;
uniform bool spring_mask_enabled = false;
// 0 = baked ground, 1 = leaves/courtyard, 2 = evergreen bamboo.
uniform int spring_layer_kind = 1;

vec3 spring_palette(float l, int kind) {
    float t = clamp((l - 0.04) / 0.72, 0.0, 1.0);
    vec3 shade = kind == 0 ? vec3(0.29,0.46,0.20) : vec3(0.10,0.29,0.12);
    vec3 mid = kind == 0 ? vec3(0.64,0.81,0.36) : vec3(0.57,0.75,0.25);
    vec3 light = kind == 0 ? vec3(0.82,0.93,0.48) : vec3(0.78,0.94,0.39);
    return t < 0.48 ? mix(shade,mid,t/0.48) : mix(mid,light,(t-0.48)/0.52);
}

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    vec3 col = c.rgb;
    float green = clamp((col.g-max(col.r,col.b))*5.0,0.0,1.0);
    float lum = dot(col,vec3(.3,.59,.11));
    // Winter and spring retained; autumn targets vegetation masks only.
    if (season==3) {
        vec3 snow=vec3(.86,.9,.96)*(.72+lum*.55);
        col=mix(col,snow,green*.8);
        col*=vec3(.94,.97,1.04);
    } else if (season==2) {
        if (spring_mask_enabled) {
            vec3 mask=texture(spring_plant_mask,UV).rgb;
            float eligible=step(.016,col.g-col.r)*step(col.b*1.22,col.g)*step(.92,c.a);
            float t=clamp((lum-.04)/.72,0.0,1.0);
            vec3 shade=spring_layer_kind==0?vec3(.42,.29,.09):vec3(.29,.12,.035);
            vec3 mid=spring_layer_kind==0?vec3(.88,.65,.19):vec3(.95,.49,.065);
            vec3 light=spring_layer_kind==0?vec3(1.0,.88,.43):vec3(1.0,.81,.28);
            vec3 gold=t<.48?mix(shade,mid,t/.48):mix(mid,light,(t-.48)/.52);
            col=mix(col,gold,mask.r*eligible*(plant_kind==2?.22:.98));
        } else {
            float k=plant_kind==2?.04:(plant_kind==1?.88:(plant_kind==3?.68:.52));
            col=mix(col,vec3(col.g*1.22,col.g*.70,col.b*.46),green*k);
        }
    } else if (season==0) {
        if (spring_mask_enabled) {
            vec3 mask = texture(spring_plant_mask, UV).rgb;
            // Recheck source green pixels at full resolution: no bleed onto walls/roads.
            float eligible = step(0.016,col.g-col.r)*step(col.b*1.22,col.g)*step(.92,c.a);
            float weight = mask.r*eligible*(spring_layer_kind==2?.58:.94);
            col = mix(col,spring_palette(lum,spring_layer_kind),weight);
            if (mask.g>.1 && eligible>.5) {
                vec3 petal = mask.g<.5 ? vec3(.95,.69,.75) : vec3(.99,.95,.81);
                if (mask.b>.5) petal=vec3(.91,.77,.39);
                col = mix(col,petal,mask.r*.94);
            }
        } else {
            // For other outdoor areas, preserve their original spring behavior.
            col=mix(col,vec3(col.r*.9+.13,col.g*.88+.17,col.b*.85+.07),green*.82);
        }
    }
    if(season==1 && spring_mask_enabled && summer_sun>0.0) {
        vec3 mask=texture(spring_plant_mask,UV).rgb;
        float eligible=step(.016,col.g-col.r)*step(col.b*1.22,col.g)*step(.92,c.a);
        float highlight=clamp((lum-.18)/.55,0.0,1.0);
        col+=vec3(.075,.060,.012)*mask.r*eligible*highlight*summer_sun;
    }
    if(rain>0.0) col*=mix(vec3(1.0),vec3(.8,.86,.95),rain);
    COLOR=vec4(col,c.a);
}
