// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "Hamon",
  platforms: [
    .iOS(.v13)
  ],
  products: [
    .library(
      name: "Hamon",
      targets: ["Hamon"]),
  ],
  targets: [
    .target(
      name: "Hamon",
      dependencies: []),
    .testTarget(
      name: "HamonTests",
      dependencies: ["Hamon"]
    ),
  ]
)
