// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SerienVollstaendigkeitspruefer",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SerienVollstaendigkeitspruefer", targets: ["SerienVollstaendigkeitspruefer"])
    ],
    targets: [
        .executableTarget(
            name: "SerienVollstaendigkeitspruefer",
            exclude: ["Assets.xcassets"]
        ),
        .testTarget(
            name: "SerienVollstaendigkeitsprueferTests",
            dependencies: ["SerienVollstaendigkeitspruefer"]
        )
    ]
)
