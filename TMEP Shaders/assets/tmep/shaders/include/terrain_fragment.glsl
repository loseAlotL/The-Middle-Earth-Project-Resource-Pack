#ifndef TMEP_TERRAIN_FRAGMENT_GLSL
#define TMEP_TERRAIN_FRAGMENT_GLSL


#if WATER_MEASURED_DEPTH == 1 && defined(OIT) && (defined(OIT_TRANSMITTANCE) || defined(OIT_ACCUMULATE))
#define WATER_HAS_DEPTH
float waterMeasuredThickness(float surfaceLinearDepth) {
    ivec2 center = ivec2(gl_FragCoord.xy);
    float tolerance = 0.6 + surfaceLinearDepth * 0.02;
    float lower = 0.0;
    float upper = WATER_DEPTH_RANGE;
    int samples = 0;
    for (int y = -2; y < 2; y++) {
        for (int x = -2; x < 2; x++) {
            ivec2 pixel = center + ivec2(x, y);
            vec4 bounds = texelFetch(DepthBoundsSampler, pixel, 0);
            bool direct = water_depth_is_water(bounds.b) && abs(-bounds.r - surfaceLinearDepth) <= tolerance;
            bool behindRain = water_depth_is_rain(bounds.b) && abs(bounds.g - surfaceLinearDepth) <= tolerance;
            float threshold = water_depth_threshold(pixel);
            if (!direct && !behindRain) {
                if (bounds.b <= 0.0) {
                    upper = min(upper, threshold);
                }
                continue;
            }
            samples++;
            if (water_bounds_marked(bounds.a)) {
                lower = max(lower, threshold);
            } else {
                upper = min(upper, threshold);
            }
        }
    }
    if (samples == 0) {
        return -1.0;
    }
    return lower <= upper ? (lower + upper) * 0.5 : lower;
}
#endif

float waterLiftAlongRay() {
    float distance = max(length(v_ViewPos), 1e-4);
    float down = max(-v_ViewPos.y / distance, 0.05);
    return v_Lift / down;
}

float skyLevel() {
    return clamp(v_Light.y * 16.0 / 15.5, 0.0, 1.0);
}

float terrainMarker = 1.0;

vec4 shadeTerrain(vec4 texel, vec3 geometric, ivec2 exactPixel) {
    vec3 normal = dot(geometric, v_ViewPos) > 0.0 ? -geometric : geometric;
    vec3 axis = abs(normal);
    float shade = 1.0;
    bool aligned = true;
    if (axis.y > 0.98) {
        shade = normal.y > 0.0 ? 1.0 : 0.5;
    } else if (axis.z > 0.98) {
        shade = 0.8;
    } else if (axis.x > 0.98) {
        shade = 0.6;
    } else {
        aligned = false;
    }
    bool tinted = v_Vert.g > v_Vert.r * 1.15 && v_Vert.g > v_Vert.b * 1.15;
    bool foliage = !aligned || tinted;
    vec3 base = texel.rgb * v_Vert.rgb / shade;
    float sky = clamp((v_Light.y * 16.0 - 0.5) / 15.0, 0.0, 1.0);
    float block = clamp((v_Light.x * 16.0 - 0.5) / 15.0, 0.0, 1.0);
    LightState state = vertexLightState();
    terrainMarker = normal.y > 0.9 && sky > 0.55 ? 0.42 + 0.16 * smoothstep(0.55, 0.99, sky) : 1.0;
#if LIGHTING_STYLE == 0
#ifndef OIT_ALPHA_ONLY
    vec3 lightmap = texture(TERRAIN_LIGHT_TEX, v_Light).rgb;
#else
    vec3 lightmap = vec3(1.0);
#endif
    float face = light_soft_face(normal);
    vec3 color = base * lightmap * face;
    float brightness = dot(lightmap, vec3(0.2126, 0.7152, 0.0722));
    color *= mix(SOFT_COOL, vec3(1.0), smoothstep(0.12, 0.7, brightness));
    color *= mix(vec3(1.0), SOFT_WARM, smoothstep(0.55, 1.0, brightness) * (face > 0.85 ? 1.0 : 0.3));
    if (foliage) {
        float skyL = max(sky - 0.125, 0.0) * 1.142857;
        float backlit = pow(max(dot(normalize(v_ViewPos), state.sun), 0.0), 4.0) * skyL * skyL * skyL * state.sunVisibility * (1.0 - state.rain);
        color += base * vec3(1.0, 0.86, 0.6) * backlit * SOFT_LEAF_GLOW;
    }
    if (block > 0.12 || foliage) {
        int marker = light_marker(texelFetch(TERRAIN_BLOCK_TEX, exactPixel, 0).rgb, texelFetch(TERRAIN_BLOCK_TEX, exactPixel ^ ivec2(1, 0), 0).rgb, exactPixel);
        if (marker == 1 || marker == 3) {
            color += base * SOFT_EMISSIVE;
            terrainMarker = marker == 3 ? LIGHT_HEAT_ALPHA : 0.75;
        } else if (marker == 2) {
            color += base * light_bioluminescence(v_RegionPos, v_ViewPos, v_TimeDay.x);
            terrainMarker = 0.75;
        }
    }
    return vec4(clamp(light_soft_grade(color), 0.0, 1.0), texel.a * v_Vert.a);
#else
    vec3 albedo = light_to_linear(base);
    vec3 light = light_world(state, normal, sky, block, foliage);
    if (foliage) {
        light += light_translucency(state, normalize(v_ViewPos), sky);
    }
    vec3 lit = albedo * light;
    if (block > 0.12 || foliage) {
        int marker = light_marker(texelFetch(TERRAIN_BLOCK_TEX, exactPixel, 0).rgb, texelFetch(TERRAIN_BLOCK_TEX, exactPixel ^ ivec2(1, 0), 0).rgb, exactPixel);
        if (marker == 1 || marker == 3) {
            lit += albedo * LIGHT_EMISSIVE_STRENGTH;
            terrainMarker = marker == 3 ? LIGHT_HEAT_ALPHA : 0.75;
        } else if (marker == 2) {
            lit += albedo * LIGHT_EMISSIVE_STRENGTH * light_bioluminescence(v_RegionPos, v_ViewPos, v_TimeDay.x);
            terrainMarker = 0.75;
        }
    }
    return vec4(light_tonemap(lit), texel.a * v_Vert.a);
#endif
}

vec4 shadeWater(vec4 texel, float kind, vec3 geometric, vec2 dpdx, vec2 dpdy, vec2 duvdx, vec2 duvdy) {
    float time = v_TimeDay.x;
    float day = clamp(v_TimeDay.y, 0.0, 1.0);
    float distance = max(length(v_ViewPos), 1e-4);
    vec3 view = v_ViewPos / distance;
    vec3 toCamera = -view;

    bool top = abs(geometric.y) > 0.6;
    bool below = top && v_ViewPos.y > 0.0;

    float sky = skyLevel();
    float skyVisibility = sky * sky;

    vec3 surface = vec3(0.0);
    float textureHeight = 0.5;
    vec3 normal;
    vec3 alphaNormal = geometric.y < 0.0 ? -geometric : geometric;
    if (top) {
        surface = water_surface(v_RegionPos.xz, time, distance) * vec3(v_WaveWeight, v_WaveWeight, v_WaveWeight);
        vec2 gradient = surface.xy;
        alphaNormal = normalize(vec3(-gradient.x, 1.0, -gradient.y));
        if (below) {
            alphaNormal = -alphaNormal;
        }
        vec2 spriteMin = TERRAIN_SPRITE_MIN;
        bool rippled = kind < 1.5;
        if (kind > 1.5) {
            mat2 worldToScreen = mat2(dpdx, dpdy);
            if (abs(determinant(worldToScreen)) > 1e-12) {
                mat2 worldToUv = mat2(duvdx, duvdy) * inverse(worldToScreen);
                vec2 local = v_RegionPos.xz - (floor(v_RegionPos.xz) + 0.5);
                vec2 center = v_TexCoord - worldToUv * local;
                spriteMin = center - 0.5 * WATER_SPRITE_PIXELS_VERTEX * TERRAIN_TEXEL_SIZE;
                rippled = true;
            }
        }
        #ifdef OIT_ALPHA_ONLY
        rippled = false;
        #endif
        if (rippled) {
            WaterSampler waterSampler = water_sampler(TERRAIN_BLOCK_TEX, spriteMin, dpdx, dpdy);
            vec2 p = below ? v_RegionPos.xz : water_parallax(TERRAIN_BLOCK_TEX, waterSampler, v_RegionPos.xz, time, view);
            vec2 textureGradient = water_ripple_gradient(TERRAIN_BLOCK_TEX, waterSampler, p, time, textureHeight);
            if (WATER_DEBUG == 1) {
                return vec4(vec3(textureHeight + 0.5), 1.0);
            }
            if (WATER_DEBUG == 2) {
                return vec4(waterSampler.lods.xyz / float(max(waterSampler.maxLod, 1)), 1.0);
            }
            float grazing = 1.0 - pow(1.0 - abs(view.y), 8.0);
            gradient += textureGradient * WATER_TEXTURE_NORMAL * grazing * mix(WATER_CALM_RIPPLES, 1.0, v_WaveWeight);
        }
        normal = normalize(vec3(-gradient.x, 1.0, -gradient.y));
        if (below) {
            normal = -normal;
        }
    } else {
        normal = dot(geometric, toCamera) < 0.0 ? -geometric : geometric;
    }

    float nv = clamp(dot(normal, toCamera), 0.0, 1.0);
    float fresnel = WATER_F0 + (1.0 - WATER_F0) * pow(1.0 - nv, 5.0);
    float alphaNv = top ? clamp(dot(alphaNormal, toCamera), 0.0, 1.0) : nv;
    float alphaFresnel = WATER_F0 + (1.0 - WATER_F0) * pow(1.0 - alphaNv, 5.0);

    vec3 lightColor = v_Color.rgb;
    bool sheet = kind > 1.5 && !top;
    float fallPattern = 0.5;
    if (sheet) {
        float along = v_RegionPos.x + v_RegionPos.z;
        vec2 fast = vec2(along * 3.0, v_RegionPos.y * 0.5 + time * 32.0 * WATER_FALL_SPEED / WATER_TIME_WINDOW);
        vec2 slow = vec2(along * 1.5 + 7.0, v_RegionPos.y * 0.25 + time * 16.0 * WATER_FALL_SLOW_SPEED / WATER_TIME_WINDOW);
        fallPattern = water_fbm(fast, vec2(384.0, 32.0)) * 0.6 + water_fbm(slow, vec2(192.0, 16.0)) * 0.4;
    }
    float detail = top ? 1.0 : (sheet ? 1.0 + (fallPattern - 0.5) * 2.0 * WATER_FALL_STREAKS : mix(1.0, dot(texel.rgb, vec3(0.3333)) * 1.4, WATER_TEXTURE_DETAIL));
    float lightLevel = max(max(lightColor.r, lightColor.g), max(lightColor.b, 1e-3));
    vec3 hue = mix(WATER_SCATTER_COLOR, lightColor / lightLevel, WATER_BIOME_TINT);
    float path = sheet ? WATER_FALL_THICKNESS / max(nv, 0.3) : min(WATER_ASSUMED_DEPTH / max(abs(view.y), 0.05), WATER_MAX_PATH);
    float thickness = -1.0;
    #ifdef WATER_HAS_DEPTH
    if (top && !below) {
        float surfaceLinearDepth = max(deviceToLinearDepth(gl_FragCoord.z), 1e-3);
        thickness = waterMeasuredThickness(surfaceLinearDepth);
        if (thickness >= 0.0) {
            path = clamp(thickness / max(-view.y, 0.05) + waterLiftAlongRay(), 0.0, WATER_MAX_PATH);
            thickness = max(thickness + v_Lift, 0.0);
        }
    }
    #endif
    if ((WATER_DEBUG == 4 || WATER_DEBUG == 5) && top && !below) {
        vec2 border = min(fract(v_RegionPos.xz / WATER_REGION), 1.0 - fract(v_RegionPos.xz / WATER_REGION)) * WATER_REGION;
        float stripes = step(0.5, fract(v_Lift * 40.0));
        vec3 shade = vec3(0.15 + 0.7 * stripes);
        return vec4(min(border.x, border.y) < 0.08 ? vec3(1.0, 0.0, 0.0) : shade, 1.0);
    }
    if (WATER_DEBUG == 3 && top && !below) {
        return thickness < 0.0 ? vec4(1.0, 0.0, 0.0, 1.0) : vec4(vec3(thickness / WATER_DEPTH_RANGE), 1.0);
    }
    vec3 transmittance = exp(-WATER_EXTINCTION * path * WATER_PATH_SCALE);
    float bodyAlpha = clamp(1.0 - dot(transmittance, vec3(1.0 / 3.0)), WATER_MIN_ALPHA, 0.97);
    vec3 inscatter = (1.0 - transmittance) / WATER_EXTINCTION * WATER_INSCATTER_SCALE;
    vec3 body = hue * lightLevel * WATER_BODY_BRIGHTNESS * detail * inscatter / bodyAlpha;
    float crest = max(surface.z, 0.0);
    vec3 forward = -vec3(TERRAIN_MODEL_VIEW[0][2], TERRAIN_MODEL_VIEW[1][2], TERRAIN_MODEL_VIEW[2][2]);
    float sunSide = water_sun_side(day, forward, TERRAIN_FOG_COLOR.rgb);
    vec3 sunDirection = water_sun_direction(day, sunSide);
    float backlight = pow(max(dot(view, sunDirection), 0.0), 3.0);
    body += WATER_DEEP_TINT * smoothstep(0.0, 0.2 * WATER_WAVE_HEIGHT, crest) * backlight * WATER_BACKLIT_CRESTS * water_sun_up(day) * skyVisibility;

    vec3 reflected = reflect(view, normal);
    #ifdef OIT_ALPHA_ONLY
    vec3 specular = vec3(0.0);
    #else
    float sunSpecular = water_ggx(normal, toCamera, sunDirection, WATER_F0, WATER_SUN_ROUGHNESS) * WATER_SUN_GLINT
        + water_ggx(normal, toCamera, sunDirection, WATER_F0, WATER_SHEEN_ROUGHNESS) * WATER_SUN_SHEEN;
    vec3 sunLight = water_sun_color(day) * sunSpecular;
    vec3 moonLight = vec3(0.55, 0.62, 0.85) * (1.0 - water_sun_up(day)) * water_ggx(normal, toCamera, water_moon_direction(sunSide), WATER_F0, WATER_SUN_ROUGHNESS * 2.0) * WATER_MOON_GLINT;
    vec3 specular = below ? vec3(0.0) : (sunLight + moonLight) * skyVisibility * WATER_CORE_SUN_GLINT;
    #endif

    float foam = 0.0;
    #ifndef OIT_ALPHA_ONLY
    if (kind > 1.5 && !top) {
        foam = smoothstep(0.5, 0.8, fallPattern) * WATER_FOAM_FLOW;
    } else if (top) {
        float churn = water_fbm(v_RegionPos.xz * 2.0, vec2(256.0));
        foam = smoothstep(0.075, 0.115, crest / WATER_WAVE_HEIGHT) * churn * WATER_FOAM_CREST;
        if (WATER_SHORE_FOAM > 0.0 && thickness >= 0.0) {
            vec2 drift = vec2(time * 256.0 * 6.0, -time * 256.0 * 4.0) / WATER_TIME_WINDOW;
            float lace = water_fbm(v_RegionPos.xz * 2.0 + drift, vec2(256.0));
            float shore = 1.0 - smoothstep(0.05, WATER_SHORE_WIDTH, thickness);
            foam = max(foam, shore * smoothstep(0.35, 0.65, lace) * WATER_SHORE_FOAM);
        }
    }
    #endif

    vec3 rgb;
    float alpha;
    if (below) {
        float window = smoothstep(0.55, 0.9, alphaNv);
        vec3 skyAbove = mix(vec3(0.02, 0.03, 0.06), vec3(0.62, 0.80, 1.0), day) * max(skyVisibility, 0.05);
        rgb = mix(mix(body, skyAbove * 0.35, 0.35), skyAbove * 0.6, window);
        alpha = mix(0.95, 0.3, window);
    } else {
        vec3 skyReflection = water_sky(reflected, TERRAIN_FOG_COLOR.rgb, skyVisibility, lightColor * 0.3, day, time);
        alpha = mix(bodyAlpha, 1.0, alphaFresnel);
        rgb = mix(body, skyReflection, top || sheet ? fresnel : fresnel * 0.25) + specular;
        #if WATER_BED_CAUSTICS_ENABLED == 1
        if (thickness >= 0.0) {
            vec3 refracted = refract(view, vec3(0.0, 1.0, 0.0), 1.0 / 1.333);
            float verticalDepth = path * max(-view.y, 0.05);
            vec2 bedXZ = v_RegionPos.xz + refracted.xz / max(-refracted.y, 0.3) * verticalDepth;
            float bedVisibility = dot(transmittance, vec3(1.0 / 3.0)) * (1.0 - fresnel);
            float depthRamp = clamp(verticalDepth, 0.0, 1.0);
            float bedLight = water_caustics(vec3(bedXZ.x, 0.0, bedXZ.y), time, 0.0, distance) * depthRamp * WATER_BED_CAUSTICS * bedVisibility * day * skyVisibility;
            rgb += lightColor * bedLight * (1.0 - alpha) / max(alpha, 0.15);
        }
        #endif
    }

    rgb = mix(rgb, WATER_FOAM_COLOR * max(lightColor * 1.4, vec3(0.04)), foam);
    alpha = max(alpha, foam);
    alpha = max(alpha, clamp(max(specular.r, max(specular.g, specular.b)), 0.0, 1.0));
    #ifdef OIT_DEPTH_BOUNDS
    alpha = min(alpha, 0.98);
    #endif
    return vec4(rgb, clamp(alpha, 0.0, 1.0));
}

void terrain_main() {
    vec4 texel = TERRAIN_SAMPLE_TEXEL;
    vec3 geometric = normalize(cross(dFdx(v_ViewPos), dFdy(v_ViewPos)));
    vec2 dpdx = dFdx(v_RegionPos.xz);
    vec2 dpdy = dFdy(v_RegionPos.xz);
    vec2 duvdx = dFdx(v_TexCoord);
    vec2 duvdy = dFdy(v_TexCoord);
    ivec2 exactPixel = ivec2(v_TexCoord * vec2(textureSize(TERRAIN_BLOCK_TEX, 0)));
    float kind = water_kind(texelFetch(TERRAIN_BLOCK_TEX, exactPixel, 0).a);

    vec4 color;
    if (kind > 0.5) {
        #ifdef OIT_DEPTH_BOUNDS
        color = vec4(0.0, 0.0, 0.0, 0.5);
        #else
        color = shadeWater(texel, kind, geometric, dpdx, dpdy, duvdx, duvdy);
        #endif
    } else {
        #ifdef OIT_ALPHA_ONLY
        color = texel * v_Color;
        #else
        color = v_TimeDay.z >= 0.0 ? shadeTerrain(texel, geometric, exactPixel) : texel * v_Color;
        #endif
        if (TERRAIN_UNDERWATER) {
            float sky = skyLevel();
            float depthBelow = (1.0 - sky) * 15.0;
            vec3 depthTint = mix(vec3(1.0), WATER_UNDERWATER_TINT, 1.0 - exp(-depthBelow * WATER_UNDERWATER_DEPTH_FADE));
            float wallSlant = 1.0 - smoothstep(0.3, 0.7, abs(geometric.y));
            color.rgb *= depthTint * (1.0 + WATER_CAUSTICS * water_caustics(v_RegionPos, v_TimeDay.x, wallSlant, length(v_ViewPos)) * sky * sky * clamp(v_TimeDay.y, 0.0, 1.0));
        }
    }

#ifdef TERRAIN_COLOR_HOOK
    TERRAIN_COLOR_HOOK(color);
#endif

#ifdef ALPHA_CUTOUT
    if (color.a < ALPHA_CUTOUT) {
        discard;
    }
#endif

    #if defined(OIT_DEPTH_BOUNDS) && defined(TMEP_OIT_FLAGS)
    bool waterTop = kind > 0.5 && abs(geometric.y) > 0.6 && v_ViewPos.y < 0.0;
    bool waterUnder = kind > 0.5 && abs(geometric.y) > 0.6 && v_ViewPos.y >= 0.0;
    bool depthProbe = WATER_MEASURED_DEPTH == 1 && waterTop;
    oitDepthBoundsWater = waterTop;
    oitDepthBoundsUnderside = waterUnder;
    float surfaceLinearDepth = deviceToLinearDepth(gl_FragCoord.z);
    float probeDistance = max(length(v_ViewPos), 1e-4);
    float probeDown = max(-v_ViewPos.y / probeDistance, 0.05);
    float probeRayOffset = waterLiftAlongRay() + water_depth_threshold(ivec2(gl_FragCoord.xy)) / probeDown;
    float probeLinearDepth = surfaceLinearDepth * (1.0 + probeRayOffset / probeDistance);
    float probeDeviceDepth = ProjMat[3][2] / probeLinearDepth - ProjMat[2][2];
    #ifndef RENDERPEARL_DEPTH_IS_ZERO_TO_ONE
    probeDeviceDepth = probeDeviceDepth * 0.5 + 0.5;
    #endif
    gl_FragDepth = depthProbe ? probeDeviceDepth : gl_FragCoord.z;
    #endif

    #ifdef OIT_ALPHA_ONLY
    executeAlphaOnlyPhase(gl_FragCoord.z, color.a);
    #else
    fragColor = calculateFinalColor(color);
#ifndef OIT
    if (fragColor.a > 0.99) {
        fragColor.a = terrainMarker;
        if (terrainMarker == LIGHT_HEAT_ALPHA) {
            fragColor.rgb = light_heat_stamp(fragColor.rgb);
        }
    }
#endif
    #endif
}

#endif
