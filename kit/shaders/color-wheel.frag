// Vitrail's colour wheel: the hue goes around the circle and the saturation
// grows from the centre to the rim, at one lightness.
//
// Baked for the QML scene graph with:
//   /usr/lib/qt6/bin/qsb --qt6 -o color-wheel.frag.qsb color-wheel.frag
// (or `scripts/build-shaders.sh`). Edit the .frag, never the .qsb.
//
// The hue is the angle from the right, growing clockwise on screen, exactly as
// `wheelAt` in kit/color.js reads it. `edge` is the soft rim, in radii.
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float lightness;
    float edge;
} ubuf;

vec3 hsl(float h, float s, float l) {
    vec3 rgb = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return l + s * (rgb - 0.5) * (1.0 - abs(2.0 * l - 1.0));
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * 2.0;
    float radius = length(p);
    float hue = fract(atan(p.y, p.x) / 6.28318530718);
    float cover = 1.0 - smoothstep(1.0 - ubuf.edge, 1.0, radius);
    vec3 rgb = hsl(hue, min(radius, 1.0), ubuf.lightness);
    fragColor = vec4(rgb * cover, cover) * ubuf.qt_Opacity;
}
