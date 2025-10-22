#include <metal_stdlib>
using namespace metal;

struct ShimmerParticle {
    float2 position;
    float2 velocity;
    float2 fade;
    float2 size;
    float2 flicker;
};

struct VertexIn {
    float2 position;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 size;
    float type;
};

vertex VertexOut SHM_ParticleVertex(const device VertexIn *vertices [[buffer(0)]],
                                    const device ShimmerParticle *particles [[buffer(1)]],
                                    constant float2 &drawableSize [[buffer(2)]],
                                    constant float &time [[buffer(3)]],
                                    uint vertexId [[vertex_id]],
                                    uint particleId [[instance_id]]) {
    VertexIn vin = vertices[vertexId];
    ShimmerParticle particle = particles[particleId];

    float2 normalizedPos = float2(
        (particle.position.x / drawableSize.x) * 2.0 - 1.0,
        1.0 - (particle.position.y / drawableSize.y) * 2.0
    );

    float2 scale = particle.size.xx;
    float2 offset = vin.position * scale;
    if (drawableSize.y > 0.0) {
        float aspect = drawableSize.x / drawableSize.y;
        offset.x /= aspect;
    }

    VertexOut vout;
    vout.position = float4(normalizedPos + offset, 0.0, 1.0);

    float fade = 0.5 + 0.5 * sin(time * particle.fade.y + particle.fade.x);
    float flicker = 1.0 + particle.flicker.y * sin(time * 3.0 + particle.flicker.x);

    float opacity = clamp(fade * flicker, 0.05, 0.85);

    vout.color = float4(1.0, 1.0, 1.0, opacity * 0.8);
    vout.size = particle.size;
    vout.type = particle.size.y;
    return vout;
}

fragment float4 SHM_ParticleFragment(VertexOut in [[stage_in]]) {
    float alpha = in.color.a;
    float brightness = 0.8 + 0.2 * in.type;
    float3 color = float3(brightness);
    return float4(color * alpha, alpha);
}

kernel void SHM_ParticleUpdate(device ShimmerParticle *particles [[buffer(0)]],
                               constant float2 &drawableSize [[buffer(1)]],
                               constant float &time [[buffer(2)]],
                               uint index [[thread_position_in_grid]]) {
    ShimmerParticle particle = particles[index];

    float delta = 1.0 / 60.0;
    particle.position += particle.velocity * delta * 60.0;

    particle.position.x += sin(time * 0.1 + particle.fade.x) * 0.05;

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
