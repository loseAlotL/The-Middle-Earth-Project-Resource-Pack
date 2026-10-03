#ifndef TMEP_WATER_DEPTH_GLSL
#define TMEP_WATER_DEPTH_GLSL

const float WATER_DEPTH_RANGE = 12.0;
const float WATER_DEPTH_FLAG_SCALE = 1048576.0;
const float WATER_DEPTH_DEEP_MARK = 1.0e-6;

float water_depth_threshold(ivec2 pixel) {
    const int bayer[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
    int index = bayer[(pixel.y & 3) * 4 + (pixel.x & 3)];
    float f = (float(index) + 0.5) / 16.0;
    return WATER_DEPTH_RANGE * f * f;
}

const float WATER_DEPTH_UNDERSIDE_MARK = 2.0e-6;

bool water_bounds_marked(float a) {
    return a > 0.5e-6 && a < 3.0e-6;
}

bool water_bounds_underside(float a) {
    return a > 1.5e-6 && a < 3.0e-6;
}

float water_depth_mark_flag(float deviceDepth, float flag) {
    return (floor(deviceDepth * WATER_DEPTH_FLAG_SCALE) + flag) / WATER_DEPTH_FLAG_SCALE;
}

float water_depth_mark(float deviceDepth, bool water) {
    return water_depth_mark_flag(deviceDepth, water ? 0.5 : 0.0);
}

bool water_depth_is_rain(float markedDepth) {
    return abs(fract(markedDepth * WATER_DEPTH_FLAG_SCALE) - 0.125) < 0.01;
}

bool water_depth_is_water(float markedDepth) {
    return fract(markedDepth * WATER_DEPTH_FLAG_SCALE) > 0.25;
}

#endif
