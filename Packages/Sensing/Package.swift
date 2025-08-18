// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "Sensing",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "Sensing", targets: ["Sensing"]),
  ],
  targets: [
    .target(
      name: "Sensing",
      dependencies: [],
      linkerSettings: [
        .linkedFramework("ARKit")
      ]
    ),
    .testTarget(
      name: "SensingTests",
      dependencies: ["Sensing"]
    ),
  ]
)
