#version 330
#extension GL_ARB_separate_shader_objects : require

uniform sampler2D InSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

void main() {
    vec2 texel = 1.0 / vec2(textureSize(InSampler, 0));
    vec3 color = vec3(0.0);
    float alpha = 0.0;
    float total = 0.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float w = exp(-float(x * x + y * y) / 1.2);
            vec4 s = texture(InSampler, texCoord + vec2(x, y) * texel);
            color += s.rgb * s.a * w;
            alpha += s.a * w;
            total += w;
        }
    }
    fragColor = vec4(alpha > 1e-4 ? color / alpha : vec3(0.0), alpha / total);
}
