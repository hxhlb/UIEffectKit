// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let baseTarget: Target = .target(name: "UIEffectKitBase")

var effectTargets: [Target] = [
    .target(name: "UIEffectKit+ParticleTransition", resources: [
        .process("Resources/main.metal"),
    ]),
]
for target in effectTargets {
    target.dependencies.append(.init(stringLiteral: baseTarget.name))
}

let package = Package(
    name: "UIEffectKit",
    platforms: [
        .iOS(.v13),
        .macCatalyst(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(name: "UIEffectKit", targets: ["UIEffectKit"]),
    ],
    dependencies: [
    ],
    targets: [
        baseTarget,
        .target(name: "UIEffectKit", dependencies: [
            .init(stringLiteral: baseTarget.name),
        ] + effectTargets.map {
            .init(stringLiteral: $0.name)
        }),
    ] + effectTargets
)
