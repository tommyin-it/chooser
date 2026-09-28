// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Chooser",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Chooser", targets: ["Chooser"])],
    targets: [.executableTarget(name: "Chooser")]
)
