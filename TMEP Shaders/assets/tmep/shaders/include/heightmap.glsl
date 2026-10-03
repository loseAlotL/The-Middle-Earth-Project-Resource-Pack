#ifndef TMEP_HEIGHTMAP_GLSL
#define TMEP_HEIGHTMAP_GLSL

const float HEIGHTMAP_SIZE = 256.0;

float heightmap_tag(vec2 column) {
    vec2 chunk = floor(column / HEIGHTMAP_SIZE);
    return mod(chunk.x, 16.0) + mod(chunk.y, 16.0) * 16.0;
}

vec4 heightmap_encode_state(float height, float tag, float state) {
    float value = clamp(floor((height + 64.0) * 128.0 + 0.5), 0.0, 65535.0);
    return vec4(floor(value / 256.0) / 255.0, mod(value, 256.0) / 255.0, tag / 255.0, state);
}

vec4 heightmap_encode(float height, float tag) {
    return heightmap_encode_state(height, tag, 1.0);
}

float heightmap_decode(vec4 color) {
    return (floor(color.r * 255.0 + 0.5) * 256.0 + floor(color.g * 255.0 + 0.5)) / 128.0 - 64.0;
}

float heightmap_lookup(sampler2D map, vec2 world) {
    vec2 column = floor(world);
    vec4 color = texelFetch(map, ivec2(mod(column, HEIGHTMAP_SIZE)), 0);
    if (color.a < 0.25 || abs(color.b * 255.0 - heightmap_tag(column)) > 0.5) {
        return -1e9;
    }
    return heightmap_decode(color);
}

#endif
