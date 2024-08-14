// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "swift-concurrency-deadline",
  platforms: [.iOS(.v16), .macOS(.v13), .macCatalyst(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
  products: [
    .library(name: "Deadline", targets: ["Deadline"]),
  ],
  targets: [
    .target(
      name: "Deadline",
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "DeadlineTests",
      dependencies: ["Deadline"],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
