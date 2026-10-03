#version 330
#extension GL_ARB_separate_shader_objects : require

#include <tmep:water_post.glsl>

uniform sampler2D InSampler;
uniform sampler2D MaskSampler;
uniform sampler2D DepthSampler;
uniform sampler2D CloudShadowSampler;
uniform sampler2D BounceSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform ShadowConfig {
    vec4 Occlusion;
    vec4 SunShadow;
    vec4 Extra;
    vec4 Terrain;
    vec4 Lighting;
};

layout(location = 0) out vec4 fragColor;

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    vec4 raw = texelFetch(InSampler, pixel, 0);
    fragColor = raw;
    if (Occlusion.x <= 0.0 && SunShadow.x <= 0.0 && Lighting.x <= 0.0 && Lighting.y <= 0.0) {
        return;
    }
    cameraScreenSize = textureSize(InSampler, 0);
    if (camera_is_data_pixel(pixel)) {
        return;
    }
    float depth = water_post_scene_depth(DepthSampler, pixel);
    if (depth <= 0.0) {
        return;
    }
    if (abs(Occlusion.x) < 0.5 && SunShadow.x <= 0.0) {
        vec3 plain = raw.rgb;
        float plainCloud = texture(CloudShadowSampler, texCoord).r * Lighting.x;
        plain *= mix(vec3(1.0), mix(vec3(1.0), vec3(0.86, 0.93, 1.08), Extra.w) * Lighting.z, plainCloud);
        vec4 plainBounce = texture(BounceSampler, texCoord);
        plain += plain * plainBounce.rgb * plainBounce.a * Lighting.y;
        fragColor = vec4(plain, raw.a);
        return;
    }
    ivec2 full = textureSize(DepthSampler, 0);
    ivec2 screen = textureSize(MaskSampler, 0);
    vec2 maskScale = vec2(screen) / vec2(full);
    vec4 center = texture(MaskSampler, (vec2(pixel) + 0.5) / vec2(full));
    if (Terrain.w > 0.0 && center.b > 0.5) {
        fragColor = vec4(1.0, 0.0, 1.0, raw.a);
        return;
    }
    float stride = maskScale.y < 0.99 ? 0.5 / maskScale.y : max(1.0, float(full.y) / 1080.0);
    vec2 total = vec2(0.0);
    float weights = 0.0;
    int blurSize = Occlusion.x < -0.5 ? 0 : 4;
    for (int y = 0; y < blurSize; y++) {
        for (int x = 0; x < blurSize; x++) {
            vec2 offset = (vec2(float(x), float(y)) - 1.5) * 2.0 * stride;
            ivec2 tap = clamp(pixel + ivec2(round(offset)), ivec2(0), full - 1);
            float tapDepth = water_post_scene_depth(DepthSampler, tap);
            float relative = abs(tapDepth - depth) / max(depth, 1e-7);
            float weight = exp(-relative * relative / 0.0004) * exp(-dot(offset, offset) / (18.0 * stride * stride));
            vec4 mask = texture(MaskSampler, (vec2(tap) + 0.5) / vec2(full));
            total += mask.rg * weight;
            weights += weight;
        }
    }
    vec2 blurred = weights > 1e-4 ? total / weights : center.rg;
    if (Occlusion.x < -0.5) {
        blurred = center.rg;
    }
    float shadow = blurred.r;
    float occlusion = blurred.g;
    vec3 shadeTint = mix(vec3(1.0), vec3(0.86, 0.93, 1.08), Extra.w);
    vec3 shaded = raw.rgb * mix(vec3(1.0), shadeTint * SunShadow.z, shadow);
    shaded *= mix(vec3(1.0), shadeTint, min(occlusion * 3.0, 1.0)) * (1.0 - occlusion);
    float cloudShadow = texture(CloudShadowSampler, texCoord).r * Lighting.x;
    shaded *= mix(vec3(1.0), shadeTint * Lighting.z, cloudShadow);
    vec4 bounce = texture(BounceSampler, texCoord);
    shaded += shaded * bounce.rgb * bounce.a * Lighting.y;
    fragColor = vec4(shaded, raw.a);
}
