// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GaiaPluginManager",
    platforms: [
      .iOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "GaiaPluginManager",
            targets: ["GaiaPluginManager"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(path: "../..Plugins/PluginBase")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "GaiaPluginManager",
            dependencies: ["PluginBase"]),
        .testTarget(
            name: "GaiaPluginManagerTests",
            dependencies: ["GaiaPluginManager"]),
    ]
)
