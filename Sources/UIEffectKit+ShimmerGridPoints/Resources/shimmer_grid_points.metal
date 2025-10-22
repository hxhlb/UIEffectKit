#include <metal_stdlib>
using namespace metal;

// Grid point shaped as either circle (star-like with sparkle) or diamond
// with subtle wiggle and synchronized wave rhythms.

struct GridPoint {
    float2 origin;      // grid origin in pixels
    float2 jitter;      // per-point jitter phase seeds
    float2 size;        // (baseRadius, blur)
    float2 props;       // (shapeType 0=circle 1=diamond, baseIntensity)
    float2 wave;        // (rowPhase, colPhase)
};

struct VertexIn {
    float2 position;    // quad -0.5..0.5
};

struct VertexOut {
    float4 position [[position]];
    float2 localPos;    // -1..1 quad space
    float blur;
    float type;
    float intensity;
};

vertex VertexOut SGP_Vertex(const device VertexIn *vertices [[buffer(0)]],
                            const device GridPoint *points [[buffer(1)]],
                            constant float2 &drawableSize [[buffer(2)]],
                            constant float &time [[buffer(3)]],
                            uint vertexId [[vertex_id]],
                            uint instanceId [[instance_id]]) {
    VertexIn vin = vertices[vertexId];
    GridPoint p = points[instanceId];

    float baseRadius = clamp(p.size.x, 4.0, 8.0);
    float blur = clamp(p.size.y, 0.05, 0.8);

    // Global wave to create ordered rhythm; combine row/col phases
    float wave = 0.5 + 0.5 * sin(time * 1.2 + p.wave.x) * cos(time * 0.9 + p.wave.y);
    float radius = baseRadius * mix(0.9, 1.1, wave);

    // Small wiggle of position within 4–8 px neighborhood (in pixels)
    float rand01 = fract(sin(p.jitter.x * 12.9898 + p.jitter.y * 78.233) * 43758.5453);
    float wiggleAmp = mix(4.0, 8.0, rand01);
    float2 wiggle = float2(
        sin(time * 2.3 + p.jitter.x),
        cos(time * 2.0 + p.jitter.y)
    ) * wiggleAmp;

    float2 offsetPx = vin.position * (radius * 2.0);
    float2 ndc = float2(
        (p.origin.x + wiggle.x) / max(drawableSize.x, 1.0) * 2.0 - 1.0,
        1.0 - (p.origin.y + wiggle.y) / max(drawableSize.y, 1.0) * 2.0
    );

    VertexOut outv;
    float2 offsetNdc = float2(
        (offsetPx.x / max(drawableSize.x, 1.0)) * 2.0,
        -(offsetPx.y / max(drawableSize.y, 1.0)) * 2.0
    );
    outv.position = float4(ndc + offsetNdc, 0.0, 1.0);
    outv.localPos = vin.position * 2.0; // -1..1
    outv.blur = blur;
    outv.type = p.props.x;

    float baseIntensity = clamp(p.props.y, 0.25, 1.0);
    float flicker = 0.85 + 0.30 * sin(time * 3.0 + p.jitter.x * 1.7 + p.jitter.y * 0.6);
    outv.intensity = saturate(baseIntensity * mix(0.8, 1.2, wave) * flicker);
    return outv;
}

fragment float4 SGP_Fragment(VertexOut in [[stage_in]]) {
    float2 pos = in.localPos; // -1..1

    float mask;
    if (in.type < 0.5) {
        // Circular point with soft sparkle falloff
        float r = length(pos);
        float feather = max(in.blur, 0.03);
        mask = smoothstep(1.0, 1.0 - feather, r);
        float sparkle = 1.0 + 0.25 * pow(max(0.0, 1.0 - r), 8.0);
        mask *= sparkle;
    } else {
        // Diamond (rhombus) via L-infinity in rotated space -> max(|x|, |y|)
        float edge = max(abs(pos.x), abs(pos.y));
        float feather = max(in.blur * 0.9, 0.03);
        mask = smoothstep(1.0, 1.0 - feather, edge);
    }

    float a = clamp(mask * in.intensity, 0.02, 0.95);
    float3 c = float3(0.95, 0.96, 1.0) * (0.8 + 0.2 * in.intensity);
    return float4(c * a, a);
}
