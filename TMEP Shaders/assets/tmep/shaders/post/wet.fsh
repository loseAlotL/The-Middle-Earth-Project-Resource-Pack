#version 330
#extension GL_ARB_separate_shader_objects : require

#define CAMERA_FROM_QUAD

#include <tmep:water_post.glsl>
#include <tmep:atmosphere.glsl>
#include <tmep:precision.glsl>

uniform sampler2D InSampler;
uniform sampler2D MarkerSampler;
uniform sampler2D DepthSampler;
uniform sampler2D ProbeSampler;
uniform sampler2D WetnessSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform WetConfig {
    vec4 Wet;
};

layout(location = 0) out vec4 fragColor;

vec2 rainRipple(vec2 xz, float time) {
    vec2 cell = floor(xz * 2.0);
    vec2 slope = vec2(0.0);
    for (int y = 0; y <= 1; y++) {
        for (int x = 0; x <= 1; x++) {
            vec2 c = cell + vec2(float(x), float(y)) - 0.5;
            vec3 h = atmos_star_hash(vec3(c, 19.0));
            float phase = fract(time * (0.9 + h.z * 0.6) + h.x);
            vec2 center = (c + 0.2 + 0.6 * h.xy) * 0.5;
            vec2 offset = xz - center;
            float d = length(offset);
            float radius = phase * 0.35;
            float ring = sin((d - radius) * 60.0) * exp(-pow((d - radius) * 18.0, 2.0)) * (1.0 - phase);
            slope += offset / max(d, 1e-3) * ring;
        }
    }
    return slope;
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    vec4 raw = texelFetch(InSampler, pixel, 0);
    fragColor = raw;
    if (Wet.w <= 0.0) {
        return;
    }
    cameraScreenSize = textureSize(InSampler, 0);
    if (camera_is_data_pixel(pixel)) {
        return;
    }
    float wetness = precise_decode(texelFetch(WetnessSampler, ivec2(0), 0)) * Wet.x;
    if (wetness < 0.01) {
        return;
    }
    float marker = texelFetch(MarkerSampler, water_post_scene_pixel(DepthSampler, pixel), 0).a;
    if (abs(marker - 0.5) > 0.1) {
        return;
    }
    float exposure = clamp((marker - 0.42) / 0.16, 0.0, 1.0);
    float damp = wetness * mix(0.6, 1.0, exposure);
    wetness *= smoothstep(0.9, 0.98, exposure);
    float depth = water_post_scene_depth(DepthSampler, pixel);
    if (depth <= 0.0 || water_post_is_water_depth(depth) || water_post_is_hand_depth(depth)) {
        return;
    }
    Camera camera = camera_load(InSampler);
    if (!camera.valid) {
        return;
    }
    vec3 point = camera_relative(camera, texCoord, depth);
    float distance = length(point);
    vec3 view = point / distance;
    vec3 world = point + camera_world_origin();
    float time = GameTime * 1200.0;

    vec3 color = raw.rgb * mix(1.0, 0.86, damp);
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luma), color, 1.0 + 0.25 * damp);
    if (wetness < 0.01) {
        fragColor = vec4(color, raw.a);
        return;
    }

    float pools = atmos_fbm(world.xz * 0.16 + 3.7, 3);
    float threshold = 1.0 - wetness * Wet.y * 0.5;
    float puddle = smoothstep(threshold, threshold + 0.12, pools);
    float sheen = 0.06 * wetness;
    float reflective = max(puddle, sheen);
    if (reflective > 0.01) {
        vec2 ripple = rainRipple(world.xz, time) * puddle * 0.25;
        vec3 normal = normalize(vec3(-ripple.x, 1.0, -ripple.y));
        vec3 direction = reflect(view, normal);
        direction.y = max(direction.y, 0.02);
        direction = normalize(direction);
        vec3 reflection = texture(ProbeSampler, water_post_probe_uv(direction)).rgb;
        mat4 viewProjection = camera.projection * camera.view;
        ivec2 screen = textureSize(DepthSampler, 0);
        vec4 row = vec4(camera.inverseProjection[0][3], camera.inverseProjection[1][3], camera.inverseProjection[2][3], camera.inverseProjection[3][3]);
        float travelled = 0.3;
        float stepLength = 0.4;
        int steps = int(Wet.z);
        for (int i = 0; i < 24; i++) {
            if (i >= steps) {
                break;
            }
            vec3 probe = point + direction * travelled;
            vec4 clip = viewProjection * vec4(probe, 1.0);
            if (clip.w <= 1e-3) {
                break;
            }
            vec2 ndc = clip.xy / clip.w;
            if (any(greaterThan(abs(ndc), vec2(1.0)))) {
                break;
            }
            ivec2 tap = clamp(ivec2((ndc * 0.5 + 0.5) * vec2(screen)), ivec2(0), screen - 1);
            float tapDepth = water_post_scene_depth(DepthSampler, tap);
            if (tapDepth > 0.0 && !water_post_is_hand_depth(tapDepth) && !camera_is_data_pixel(tap)) {
                float gap = clip.w - 1.0 / dot(row, vec4(ndc, tapDepth, 1.0));
                if (gap > 0.0 && gap < stepLength * 2.0 + 0.3) {
                    vec2 edge = min(ndc * 0.5 + 0.5, 0.5 - ndc * 0.5);
                    reflection = mix(reflection, texelFetch(InSampler, tap, 0).rgb, smoothstep(0.0, 0.08, min(edge.x, edge.y)));
                    break;
                }
            }
            travelled += stepLength;
            stepLength *= 1.3;
        }
        float nv = max(dot(normal, -view), 0.0);
        float fresnel = 0.03 + 0.97 * pow(1.0 - nv, 5.0);
        color *= mix(1.0, 0.8, puddle);
    color = mix(color, reflection, clamp(fresnel * reflective * 1.4 + puddle * 0.12, 0.0, 0.9));
    }
    fragColor = vec4(color, raw.a);
}
