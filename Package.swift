// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "GameModeBar",
	platforms: [.macOS(.v14)],
	products: [
		.library(name: "GameModeCore", targets: ["GameModeCore"]),
		.executable(name: "GameModeBar", targets: ["GameModeBar"]),
	],
	targets: [
		.target(name: "GameModeCore"),
		.executableTarget(
			name: "GameModeBar",
			dependencies: ["GameModeCore"],
			swiftSettings: [.swiftLanguageMode(.v5)]
		),
		.testTarget(
			name: "GameModeCoreTests",
			dependencies: ["GameModeCore"]
		),
	]
)
