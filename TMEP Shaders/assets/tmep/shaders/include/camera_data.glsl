#ifndef TMEP_CAMERA_DATA_GLSL
#define TMEP_CAMERA_DATA_GLSL

const vec3 CAMERA_DATA_SIGNATURE = vec3(19.0, 199.0, 165.0);
const int CAMERA_DATA_PARAM_SLOT = 41;
const int CAMERA_DATA_PARAM_COUNT = 12;
const int CAMERA_DATA_SKY_SLOT = CAMERA_DATA_PARAM_SLOT + CAMERA_DATA_PARAM_COUNT;
const int CAMERA_DATA_SLOTS = CAMERA_DATA_SKY_SLOT + 1;
const vec3 CAMERA_PARAM_SIGNATURE = vec3(173.0, 41.0, 229.0);
const int CAMERA_DATA_MAGIC_SLOT = 32;
const int CAMERA_DATA_DAYTIME_SLOT = 33;
const int CAMERA_DATA_FOG_START_SLOT = 34;
const int CAMERA_DATA_FOG_END_SLOT = 35;
const int CAMERA_DATA_FOG_COLOR_SLOT = 36;
const int CAMERA_DATA_WEATHER_SLOT = 39;
const int CAMERA_DATA_MARKER_DISTANCE_SLOT = 40;
const float CAMERA_DATA_MAGIC = 3000.5;

const float CAMERA_STRIP_WIDTH = 0.1;
const float CAMERA_STRIP_HEIGHT = 0.006;

bool camera_data_is_marker(vec4 color) {
    vec3 bytes = round(color.rgb * 255.0);
    bool signature = bytes.r == 19.0 || bytes.r == 20.0;
    bool defaultTint = bytes.g == 199.0 && bytes.b == 165.0;
    return signature && (bytes.g <= 93.0 || defaultTint);
}

int camera_param_index(vec4 color) {
    int index = int(round(color.r * 255.0)) - 32;
    return index >= 0 && index < CAMERA_DATA_PARAM_COUNT ? index : -1;
}

float camera_param_value(vec4 color) {
    vec3 bytes = round(color.rgb * 255.0);
    return (bytes.g * 256.0 + bytes.b) / 65535.0;
}

bool camera_data_reversed(vec4 color) {
    return round(color.r * 255.0) == 20.0;
}

const vec3 CAMERA_TRANSPARENCY_FLAG = vec3(51.0, 153.0, 102.0) / 255.0;

ivec2 camera_transparency_flag_pixel(ivec2 size) {
    return ivec2(2, int(ceil(CAMERA_STRIP_HEIGHT * float(size.y))));
}

ivec2 camera_data_slot_pixel(int slot, ivec2 size) {
    float x = (float(slot) + 0.5) / float(CAMERA_DATA_SLOTS) * CAMERA_STRIP_WIDTH * float(size.x);
    float y = 0.5 * CAMERA_STRIP_HEIGHT * float(size.y);
    return ivec2(x, y);
}

bool camera_data_in_strip(ivec2 pixel, ivec2 size) {
    return float(pixel.x) < CAMERA_STRIP_WIDTH * float(size.x) + 1.0 && float(pixel.y) < CAMERA_STRIP_HEIGHT * float(size.y) + 1.0;
}

float camera_data_daytime(vec4 color) {
    vec3 bytes = round(color.rgb * 255.0);
    return bytes.g <= 93.0 ? bytes.g * 256.0 + bytes.b : -1.0;
}

vec3 camera_data_encode(float value) {
    uint bits = floatBitsToUint(value);
    return vec3(float((bits >> 24u) & 255u), float((bits >> 16u) & 255u), float((bits >> 8u) & 255u)) / 255.0;
}

float camera_data_decode(vec3 color) {
    uvec3 b = uvec3(round(color * 255.0));
    return uintBitsToFloat((b.r << 24u) | (b.g << 16u) | (b.b << 8u));
}

#endif
