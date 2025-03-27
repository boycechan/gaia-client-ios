// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Packets",
    platforms: [
      .iOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Packets",
            targets: ["Packets"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(path: "../GaiaBase"),
        .package(path: "../../Plugins/PluginBase"),
        .package(path: "../ByteUtils"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Packets",
            dependencies: ["GaiaBase", "PluginBase", "ByteUtils"]),
        .testTarget(
            name: "PacketsTests",
            dependencies: ["Packets"]),
    ]
)
