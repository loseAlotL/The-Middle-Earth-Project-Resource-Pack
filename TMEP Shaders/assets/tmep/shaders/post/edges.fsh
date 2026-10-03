#version 330
#extension GL_ARB_separate_shader_objects : require

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform EdgeConfig {
    vec4 LineColor;
    vec4 BackgroundColor;
    float DepthThreshold;
    float ColorThreshold;
    float SceneTint;
    float LineWidth;
};

layout(location = 0) out vec4 fragColor;

ivec2 screenSize;

float depthAt(ivec2 p) {
    return texelFetch(DepthSampler, clamp(p, ivec2(0), screenSize - 1), 0).r;
}

float lumaAt(ivec2 p) {
    vec3 c = texelFetch(InSampler, clamp(p, ivec2(0), screenSize - 1), 0).rgb;
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float depthEdge(ivec2 p, ivec2 dir, float center) {
    float a = depthAt(p - dir);
    float b = depthAt(p + dir);
    float m = max(max(a, b), center);
    if (m <= 0.0) {
        return 0.0;
    }
    return abs(a + b - 2.0 * center) / m;
}

void main() {
    screenSize = textureSize(DepthSampler, 0);
    ivec2 p = ivec2(texCoord * vec2(screenSize));
    int stride = max(int(LineWidth + 0.5), 1);

    float center = depthAt(p);
    float d = 0.0;
    d = max(d, depthEdge(p, ivec2(stride, 0), center));
    d = max(d, depthEdge(p, ivec2(0, stride), center));
    d = max(d, depthEdge(p, ivec2(stride, stride), center) * 0.7071);
    d = max(d, depthEdge(p, ivec2(stride, -stride), center) * 0.7071);
    d /= float(stride);

    float edge = smoothstep(DepthThreshold, DepthThreshold * 2.0, d);

    if (ColorThreshold > 0.0) {
        float tl = lumaAt(p + ivec2(-stride, stride));
        float t = lumaAt(p + ivec2(0, stride));
        float tr = lumaAt(p + ivec2(stride, stride));
        float l = lumaAt(p + ivec2(-stride, 0));
        float r = lumaAt(p + ivec2(stride, 0));
        float bl = lumaAt(p + ivec2(-stride, -stride));
        float b = lumaAt(p + ivec2(0, -stride));
        float br = lumaAt(p + ivec2(stride, -stride));
        float gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);
        float gy = (tl + 2.0 * t + tr) - (bl + 2.0 * b + br);
        float c = length(vec2(gx, gy));
        edge = max(edge, smoothstep(ColorThreshold, ColorThreshold * 2.0, c));
    }

    vec3 scene = texelFetch(InSampler, p, 0).rgb;
    vec3 background = mix(scene, BackgroundColor.rgb, BackgroundColor.a);
    vec3 line = mix(LineColor.rgb, scene, SceneTint);
    fragColor = vec4(mix(background, line, edge * LineColor.a), 1.0);
}
