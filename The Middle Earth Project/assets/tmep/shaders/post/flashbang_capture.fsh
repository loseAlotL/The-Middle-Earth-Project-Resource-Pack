#version 330

#extension GL_ARB_separate_shader_objects : require

uniform sampler2D InSampler;
uniform sampler2D PreviousSampler;
uniform sampler2D StateSampler;

layout(location = 0) in vec2 texCoord;
layout(location = 0) out vec4 fragColor;

void main() {
    bool started = texelFetch(StateSampler, ivec2(0), 0).a > 0.5;
    fragColor = started ? texture(PreviousSampler, texCoord) : vec4(texture(InSampler, texCoord).rgb, 1.0);
}
