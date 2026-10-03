#version 330
#extension GL_ARB_separate_shader_objects : require

uniform sampler2D InSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

void main() {
    ivec2 source = textureSize(InSampler, 0);
    vec2 cell = vec2(source) / vec2(64.0, 32.0);
    float total = 0.0;
    for (int y = 0; y < 3; y++) {
        for (int x = 0; x < 3; x++) {
            vec2 position = (floor(gl_FragCoord.xy) + (vec2(float(x), float(y)) + 0.5) / 3.0) * cell;
            vec3 color = texelFetch(InSampler, clamp(ivec2(position), ivec2(0), source - 1), 0).rgb;
            total += log(dot(color, vec3(0.2126, 0.7152, 0.0722)) + 0.01);
        }
    }
    fragColor = vec4(vec3(clamp((total / 9.0 + 4.7) / 5.0, 0.0, 1.0)), 1.0);
}
