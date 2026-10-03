#version 330
#extension GL_ARB_separate_shader_objects : require

#define CAMERA_FROM_QUAD

#include <tmep:water_post.glsl>
#include <tmep:heightmap.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D PreviousSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform HeightConfig {
    vec4 Height;
};

layout(location = 0) out vec4 fragColor;

float probe(Camera camera, mat4 viewProjection, vec3 point, ivec2 screen, out bool valid) {
    valid = false;
    vec4 clip = viewProjection * vec4(point, 1.0);
    if (clip.w <= 1e-3) {
        return 0.0;
    }
    vec2 ndc = clip.xy / clip.w;
    if (any(greaterThan(abs(ndc), vec2(0.999)))) {
        return 0.0;
    }
    ivec2 pixel = clamp(ivec2((ndc * 0.5 + 0.5) * vec2(screen)), ivec2(0), screen - 1);
    if (camera_is_data_pixel(pixel)) {
        return 0.0;
    }
    float depth = water_post_scene_depth(DepthSampler, pixel);
    if (water_post_is_hand_depth(depth) || water_post_is_water_depth(depth) || water_post_is_underside_depth(depth)) {
        return 0.0;
    }
    valid = true;
    if (depth <= 0.0) {
        return 1e6;
    }
    vec4 row = vec4(camera.inverseProjection[0][3], camera.inverseProjection[1][3], camera.inverseProjection[2][3], camera.inverseProjection[3][3]);
    return 1.0 / dot(row, vec4(ndc, depth, 1.0)) - clip.w;
}

void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);
    vec4 previous = texelFetch(PreviousSampler, texel, 0);
    fragColor = previous;
    if (Height.w <= 0.0 || EXPERIMENTAL_SHADOWS_BROKEN_DO_NOT_ENABLE == 0) {
        return;
    }
    Camera camera = camera_load(InSampler);
    if (!camera.valid || camera.underwater) {
        return;
    }
    vec3 origin = camera_world_origin();
    vec2 base = floor(origin.xz) - HEIGHTMAP_SIZE * 0.5;
    vec2 column = base + mod(vec2(texel) - base, HEIGHTMAP_SIZE);
    float tag = heightmap_tag(column);
    bool known = previous.a > 0.25 && abs(previous.b * 255.0 - tag) < 0.5;
    bool measured = known && previous.a > 0.75;
    if (!known) {
        fragColor = vec4(0.0);
    }
    if (!measured) {
        float total = 0.0;
        float count = 0.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                if (x == 0 && y == 0) {
                    continue;
                }
                vec2 neighbour = column + vec2(float(x), float(y));
                vec4 cell = texelFetch(PreviousSampler, ivec2(mod(neighbour, HEIGHTMAP_SIZE)), 0);
                if (cell.a > 0.25 && abs(cell.b * 255.0 - heightmap_tag(neighbour)) < 0.5) {
                    total += heightmap_decode(cell);
                    count += 1.0;
                }
            }
        }
        if (count >= 4.0) {
            fragColor = heightmap_encode_state(total / count, tag, 0.5);
        }
    }
    vec2 relative = column + 0.5 - origin.xz;
    if (length(relative) > Height.z) {
        return;
    }
    ivec2 screen = textureSize(DepthSampler, 0);
    mat4 viewProjection = camera.projection * camera.view;
    float top = min(origin.y + Height.z, 330.0) - origin.y;
    float bottom = max(origin.y - Height.z, -64.0) - origin.y;
    int steps = int(Height.y);
    float abovePrevious = top;
    bool haveAbove = false;
    float lower = 0.0;
    float upper = 0.0;
    bool bracket = false;
    for (int i = 0; i < 48; i++) {
        if (i >= steps) {
            break;
        }
        float y = mix(top, bottom, float(i) / float(steps - 1));
        bool valid;
        float gap = probe(camera, viewProjection, vec3(relative.x, y, relative.y), screen, valid);
        if (!valid) {
            haveAbove = false;
            continue;
        }
        if (gap > 0.0) {
            haveAbove = true;
            abovePrevious = y;
        } else if (haveAbove) {
            upper = abovePrevious;
            lower = y;
            bracket = true;
            break;
        }
    }
    if (!bracket) {
        return;
    }
    for (int i = 0; i < 7; i++) {
        float middle = 0.5 * (upper + lower);
        bool valid;
        float gap = probe(camera, viewProjection, vec3(relative.x, middle, relative.y), screen, valid);
        if (valid && gap > 0.0) {
            upper = middle;
        } else {
            lower = middle;
        }
    }
    vec3 surface = vec3(relative.x, upper, relative.y);
    vec4 clip = viewProjection * vec4(surface, 1.0);
    vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
    ivec2 pixel = clamp(ivec2(uv * vec2(screen)), ivec2(0), screen - 1);
    float depth = water_post_scene_depth(DepthSampler, pixel);
    if (depth <= 0.0) {
        return;
    }
    vec3 scene = camera_relative(camera, (vec2(pixel) + 0.5) / vec2(screen), depth);
    if (any(greaterThan(abs(scene.xz - relative), vec2(0.9)))) {
        return;
    }
    fragColor = heightmap_encode(upper + origin.y, tag);
}
