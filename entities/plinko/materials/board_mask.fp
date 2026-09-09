#version 140

in mediump vec2 var_texcoord0;
in mediump vec4 var_color;
out vec4 out_fragColor;

uniform lowp sampler2D texture_sampler;

void main()
{
    vec4 texel = texture(texture_sampler, var_texcoord0);
    // Discard prevents transparent parts of the parent texture from
    // writing to stencil. The node's tint/opacity must not change the mask.
    if (texel.a < 0.5) {
        discard;
    }
    out_fragColor = texel * var_color;
}
