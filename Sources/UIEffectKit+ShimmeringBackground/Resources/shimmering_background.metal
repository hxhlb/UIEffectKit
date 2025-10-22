#include <metal_stdlib>
using namespace metal;

struct ShimmerParticle {
    float2 position;
    float2 velocity;
    float2 fade;        // (phase, speed)
    float2 size;        // (radius, blur)
    float2 flicker;     // (phase, amplitude)
    float2 properties;  // (type, baseIntensity)
};

struct VertexIn {
    float2 position;
    float2 uv;
};

struct VertexOut {
    float4 position [[position]];
    float2 localPos;
    float blur;
    float type;
    float intensity;
};

vertex VertexOut SHM_ParticleVertex(const device VertexIn *vertices [[buffer(0)]],
                                    const device ShimmerParticle *particles [[buffer(1)]],
                                    constant float2 &drawableSize [[buffer(2)]],
                                    constant float &time [[buffer(3)]],
                                    uint vertexId [[vertex_id]],
                                    uint particleId [[instance_id]]) {
    VertexIn vin = vertices[vertexId];
    ShimmerParticle particle = particles[particleId];

    float radius = max(particle.size.x, 0.5);
    float blur = clamp(particle.size.y, 0.01, 1.0);

    float2 offset = vin.position * radius * 2.0;
    if (drawableSize.y > 0.0) {
        float aspect = drawableSize.x / drawableSize.y;
        offset.x /= aspect;
    }

    float2 ndcPosition = float2(
        (particle.position.x / max(drawableSize.x, 1.0)) * 2.0 - 1.0,
        1.0 - (particle.position.y / max(drawableSize.y, 1.0)) * 2.0
    );

    VertexOut outVertex;
    outVertex.position = float4(ndcPosition + offset, 0.0, 1.0);
    outVertex.localPos = vin.position;
    outVertex.blur = blur;
    outVertex.type = particle.properties.x;

    float baseIntensity = clamp(particle.properties.y, 0.2, 1.0);
    float fade = 0.5 + 0.5 * sin(time * particle.fade.y + particle.fade.x);
    float flicker = 1.0 + particle.flicker.y * sin(time * 3.0 + particle.flicker.x);
    outVertex.intensity = saturate(baseIntensity * fade * flicker);

    return outVertex;
}

fragment float4 SHM_ParticleFragment(VertexOut in [[stage_in]]) {
    float2 pos = in.localPos * 2.0;
    float softness = mix(in.blur * 0.5, in.blur * 1.5, step(0.5, in.type));

    float mask;
    if (in.type < 0.5) {
        float radius = 1.0;
        float feather = max(softness, 0.02);
        float dist = length(pos);
        mask = smoothstep(radius, radius - feather, dist);
    } else {
        float edge = max(abs(pos.x), abs(pos.y));
        float feather = max(softness * 0.8, 0.02);
        mask = smoothstep(1.0, 1.0 - feather, edge);
    }

    float alpha = clamp(mask * in.intensity, 0.02, 0.9);
    float sparkle = 0.9 + 0.1 * in.intensity;
    float3 color = float3(sparkle);
    return float4(color * alpha, alpha);
}

kernel void SHM_ParticleUpdate(device ShimmerParticle *particles [[buffer(0)]],
                               constant float2 &drawableSize [[buffer(1)]],
                               constant float &time [[buffer(2)]],
                               constant uint &count [[buffer(3)]],
                               uint index [[thread_position_in_grid]]) {
    if (index >= count) {
        return;
    }

    ShimmerParticle particle = particles[index];

    float delta = 1.0 / 60.0;
    particle.position += particle.velocity * delta * 60.0;

    float sway = sin(time * 0.1 + particle.fade.x) * 0.5;
    particle.position.x += sway * delta;

    if (particle.position.y + particle.size.x < 0.0) {
        particle.position.y = drawableSize.y + particle.size.x;
        particle.position.x = fmod(particle.position.x + drawableSize.x, drawableSize.x);
    }

    if (particle.position.x < -particle.size.x) {
        particle.position.x += drawableSize.x + particle.size.x * 2.0;
    } else if (particle.position.x > drawableSize.x + particle.size.x) {
        particle.position.x -= drawableSize.x + particle.size.x * 2.0;
    }

    particles[index] = particle;
}
