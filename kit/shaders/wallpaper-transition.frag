// Vitrail's wallpaper change: two pictures, one short animation.
//
// Baked for the QML scene graph with:
//   /usr/lib/qt6/bin/qsb --qt6 -o wallpaper-transition.frag.qsb wallpaper-transition.frag
// (or `scripts/build-shaders.sh`). Edit the .frag, never the .qsb.
//
// mode 0: ink      organic blobs of the incoming picture grow from `origin`
// mode 1: outline  the incoming contours are traced over the old picture, then
//                  the picture fills in
// mode 2: fade     a plain crossfade
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float mode;
    vec2 origin;
    float seed;
    vec2 texel;
} ubuf;

layout(binding = 1) uniform sampler2D previous;
layout(binding = 2) uniform sampler2D incoming;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec3 before = texture(previous, uv).rgb;
    vec3 after = texture(incoming, uv).rgb;

    if (ubuf.mode < 0.5) {
        // The field leans towards the origin, so the blobs grow from it; the
        // noise breaks the front into separate drops.
        float field = fbm(uv * 4.0 + vec2(ubuf.seed * 37.0, ubuf.seed * 19.0)) * 1.25
                      - length((uv - ubuf.origin) * vec2(1.0, 1.15)) * 0.55;
        // The threshold falls: at progress 0 no field is high enough, at 1
        // every field passes. The band above it is the bright rim.
        float threshold = mix(1.30, -0.75, ubuf.progress);
        float inside = smoothstep(threshold, threshold + 0.06, field);
        float rim = smoothstep(threshold, threshold + 0.04, field)
                    * (1.0 - smoothstep(threshold + 0.04, threshold + 0.12, field));
        vec3 glow = clamp(after * 1.55 + 0.12, 0.0, 1.0);
        vec3 color = mix(before, after, inside);
        color += glow * rim * 0.75 * (1.0 - smoothstep(0.85, 1.0, ubuf.progress));
        fragColor = vec4(color, 1.0) * ubuf.qt_Opacity;
        return;
    }

    if (ubuf.mode < 1.5) {
        // Sobel over the incoming picture: its own colours become the ink.
        vec2 px = ubuf.texel;
        float tl = luma(texture(incoming, uv + px * vec2(-1.0, -1.0)).rgb);
        float tc = luma(texture(incoming, uv + px * vec2(0.0, -1.0)).rgb);
        float tr = luma(texture(incoming, uv + px * vec2(1.0, -1.0)).rgb);
        float ml = luma(texture(incoming, uv + px * vec2(-1.0, 0.0)).rgb);
        float mr = luma(texture(incoming, uv + px * vec2(1.0, 0.0)).rgb);
        float bl = luma(texture(incoming, uv + px * vec2(-1.0, 1.0)).rgb);
        float bc = luma(texture(incoming, uv + px * vec2(0.0, 1.0)).rgb);
        float br = luma(texture(incoming, uv + px * vec2(1.0, 1.0)).rgb);

        float gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
        float gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;
        float edge = smoothstep(0.045, 0.22, length(vec2(gx, gy)));

        // The line travels across the picture before the fill arrives.
        float draw = smoothstep(0.0, 0.42, ubuf.progress);
        float sweep = smoothstep(uv.x - 0.28, uv.x + 0.08, draw * 1.30);
        float line = edge * sweep * (1.0 - smoothstep(0.82, 0.98, ubuf.progress));

        float fill = smoothstep(0.38, 0.92, ubuf.progress);
        vec3 ink = clamp(after * 1.45 + 0.16, 0.0, 1.0);
        vec3 color = mix(before, after, fill);
        color = mix(color, ink, line);
        color += ink * line * 0.35;
        fragColor = vec4(color, 1.0) * ubuf.qt_Opacity;
        return;
    }

    float fade = smoothstep(0.0, 1.0, ubuf.progress);
    fragColor = vec4(mix(before, after, fade), 1.0) * ubuf.qt_Opacity;
}
