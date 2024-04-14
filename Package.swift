// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "RequirementMachine",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "RequirementMachine", targets: ["RequirementMachine"]),
  ],
  targets: [
    .executableTarget(name: "RequirementMachine", dependencies: []),
  ])
