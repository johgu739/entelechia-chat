// @EntelechiaHeaderStart
// Signifier: Package
// Substance: TODO_AGENT_FILL
// Genus: TODO_AGENT_FILL
// Differentia: TODO_AGENT_FILL
// Form: TODO_AGENT_FILL
// Matter: TODO_AGENT_FILL
// Powers: TODO_AGENT_FILL
// FinalCause: TODO_AGENT_FILL
// Relations: TODO_AGENT_FILL
// CausalityType: TODO_AGENT_FILL
// @EntelechiaHeaderEnd

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EntelechiaOntologyGenerator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "entelechia-ontology",
            targets: ["EntelechiaOntologyGenerator"]
        )
    ],
    targets: [
        .executableTarget(
            name: "EntelechiaOntologyGenerator",
            path: "Sources/EntelechiaOntologyGenerator"
        )
    ]
)
