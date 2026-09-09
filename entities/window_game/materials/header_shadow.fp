#version 140

in mediump vec2 var_texcoord0;
in mediump vec4 var_color;
out vec4 out_fragColor;

uniform fs_uniforms {
    // x: node height, y: bottom line width, z: shadow depth, w: shadow opacity.
    vec4 bottom_shadow;
};

void main()
{
    float depth = var_texcoord0.y * bottom_shadow.x;
    float aa = max(fwidth(depth), 0.0001);
    float line = 1.0 - smoothstep(bottom_shadow.y - aa * 0.5,
        bottom_shadow.y + aa * 0.5, depth);
    float shadow = 1.0 - smoothstep(0.0, max(bottom_shadow.z, 0.001), depth);
    shadow = shadow * shadow * clamp(bottom_shadow.w, 0.0, 1.0);
    float coverage = line + shadow * (1.0 - line);
    out_fragColor = var_color * coverage;
}
