//
//  MetalHelpers.swift
//  UIEffectKitBase
//
//  Shared helper methods for common Metal setup patterns.
//

import Foundation
import MetalKit

public enum MetalHelpers {
    public static func blendedPipelineDescriptor(
        vertexFunction: MTLFunction,
        fragmentFunction: MTLFunction,
        pixelFormat: MTLPixelFormat = .bgra8Unorm,
        vertexDescriptor: MTLVertexDescriptor? = nil
    ) -> MTLRenderPipelineDescriptor {
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertexFunction
        desc.fragmentFunction = fragmentFunction
        desc.vertexDescriptor = vertexDescriptor
        desc.colorAttachments[0].pixelFormat = pixelFormat
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].rgbBlendOperation = .add
        desc.colorAttachments[0].alphaBlendOperation = .add
        desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        desc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        return desc
    }

    public static func makeLinearClampSampler(device: MTLDevice) -> MTLSamplerState? {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.mipFilter = .notMipmapped
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        return device.makeSamplerState(descriptor: descriptor)
    }

    // Intentionally no defaultLibrary convenience here to avoid Bundle.module
    // dependency in base target without resources.
}
