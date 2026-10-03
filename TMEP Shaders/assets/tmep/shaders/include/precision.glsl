#ifndef TMEP_PRECISION_GLSL
#define TMEP_PRECISION_GLSL

vec4 precise_encode(float value) {
    float scaled = clamp(value, 0.0, 1.0) * 65535.0;
    float high = floor(scaled / 256.0);
    return vec4(high / 255.0, (scaled - high * 256.0) / 255.0, 0.0, 1.0);
}

float precise_decode(vec4 color) {
    return (floor(color.r * 255.0 + 0.5) * 256.0 + floor(color.g * 255.0 + 0.5)) / 65535.0;
}

#endif
