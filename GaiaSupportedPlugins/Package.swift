// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GaiaSupportedPlugins",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "GaiaSupportedPlugins",
            targets: ["GaiaSupportedPlugins"]),
    ],
    dependencies: [
        .package(path: "../Core/GaiaPluginManager"),
        .package(path: "../Plugins/PluginBase"),
        .package(path: "../Plugins/CorePlugin"),
        .package(path: "../Plugins/EarbudFitPlugin"),
        .package(path: "../Plugins/AudioCurationPlugin"),
        .package(path: "../Plugins/UpdaterPlugin"),
        .package(path: "../Plugins/LegacyANCPlugin"),
        .package(path: "../Plugins/BatteryPlugin"),
        .package(path: "../Plugins/EarbudPlugin"),
        .package(path: "../Plugins/EarbudUIPlugin"),
        .package(path: "../Plugins/EQPlugin"),
        .package(path: "../Plugins/HandsetPlugin"),
        .package(path: "../Plugins/StatisticsPlugin"),
        .package(path: "../Plugins/VoiceAssistantPlugin"),
        .package(path: "../Plugins/VoiceProcessingPlugin")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "GaiaSupportedPlugins",
            dependencies: ["PluginBase", "GaiaPluginManager",
                           "CorePlugin", "EarbudFitPlugin", "AudioCurationPlugin", "LegacyANCPlugin",
                           "UpdaterPlugin", "BatteryPlugin", "EarbudPlugin", "EarbudUIPlugin",
                           "EQPlugin", "HandsetPlugin", "StatisticsPlugin", "VoiceAssistantPlugin", "VoiceProcessingPlugin"]),
        .testTarget(
            name: "GaiaSupportedPluginsTests",
            dependencies: ["GaiaSupportedPlugins"]),
        ]
)
