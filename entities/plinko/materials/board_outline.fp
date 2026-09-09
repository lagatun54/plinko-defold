#version 140

in mediump vec2 var_texcoord0;
in mediump vec4 var_color;
out vec4 out_fragColor;

uniform fs_uniforms {
    vec4 outline;
    vec4 inner_shadow;
};

void main()
{
    vec2 half_size = outline.xy * 0.5;
    vec2 p = (var_texcoord0 - vec2(0.5)) * outline.xy;

    float inset = outline.w * 0.5 + 0.5;
    float radius = max(outline.z - inset, 0.0);
    vec2 q = abs(p) - (half_size - vec2(inset + radius));

    float distance_to_edge = length(max(q, vec2(0.0)))
        + min(max(q.x, q.y), 0.0) - radius;
    float aa = max(fwidth(distance_to_edge), 0.0001);
    float coverage = 1.0 - smoothstep(outline.w * 0.5 - aa * 0.5,
        outline.w * 0.5 + aa * 0.5, abs(distance_to_edge));

    float inside = 1.0 - smoothstep(-aa * 0.5, aa * 0.5,
        distance_to_edge);
    float depth = max(-distance_to_edge, 0.0);
    float shadow = 1.0 - smoothstep(0.0, max(inner_shadow.x, 0.001), depth);
    shadow = shadow * shadow * clamp(inner_shadow.y, 0.0, 1.0) * inside;
    float combined = coverage + shadow * (1.0 - coverage);
    out_fragColor = var_color * combined;
}
