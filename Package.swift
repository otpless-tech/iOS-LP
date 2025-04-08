// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OtplessSwiftLP",
    platforms: [.iOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OtplessSwiftLP",
            targets: ["OtplessSwiftLP"]),
    ],
    dependencies: [
        // Adding Socket.IO dependency
        .package(url: "https://github.com/socketio/socket.io-client-swift.git", from: "16.1.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OtplessSwiftLP",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift")
            ]
        ),
        .testTarget(
            name: "OtplessSwiftLPTests",
            dependencies: ["OtplessSwiftLP"]
        ),
    ]
)
