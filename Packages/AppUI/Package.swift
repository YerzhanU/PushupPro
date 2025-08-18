// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "AppUI",
  platforms: [.iOS(.v17)],
  products: [.library(name: "AppUI", targets: ["AppUI"])],
  dependencies: [
    .package(path: "../Sensing")
  ],
  targets: [
    .target(
      name: "AppUI",
      dependencies: ["Sensing"]
    ),
    .testTarget(name: "AppUITests", dependencies: ["AppUI"])
  ]
)
