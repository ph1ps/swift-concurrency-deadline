// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "swift-concurrency-deadline",
  platforms: [.iOS(.v16), .macOS(.v13), .macCatalyst(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
  products: [
    .library(name: "Deadline", targets: ["Deadline"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-clocks", from: "1.0.0")
  ],
  targets: [
    .target(
      name: "Deadline"
    ),
    .testTarget(
      name: "DeadlineTests",
      dependencies: [
        "Deadline",
        .product(name: "Clocks", package: "swift-clocks")
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
