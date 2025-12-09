// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChatUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ChatUI",
            targets: ["ChatUI"]
        )
    ],
    dependencies: [
        .package(name: "AppCoreEngine", path: "../AppCoreEngine"),
        .package(name: "UIConnections", path: "../UIConnections"),
        .package(name: "AppAdapters", path: "../AppAdapters")
    ],
    targets: [
        .target(
            name: "ChatUI",
            dependencies: [
                .product(name: "AppCoreEngine", package: "AppCoreEngine"),
                .product(name: "UIConnections", package: "UIConnections"),
                .product(name: "AppAdapters", package: "AppAdapters")
            ],
            exclude: [
                "AppComposition/Folder.ent",
                "AppComposition/Folder.topology.json",
                "Support/Folder.ent",
                "Support/Folder.topology.json",
                "Support/AI/Folder.ent",
                "Support/AI/Folder.topology.json",
                "Support/Rendering/Folder.ent",
                "Support/Rendering/Folder.topology.json",
                "Support/Persistence/Folder.ent",
                "Support/Persistence/Folder.topology.json",
                "UI/Folder.ent",
                "UI/Folder.topology.json",
                "UI/ConversationUI/Folder.ent",
                "UI/ConversationUI/Folder.topology.json",
                "UI/WorkspaceUI/Folder.ent",
                "UI/WorkspaceUI/Folder.topology.json",
                "UI/WorkspaceUI/XcodeNavigator/Folder.ent",
                "UI/WorkspaceUI/XcodeNavigator/Folder.topology.json",
                "UI/Shell/Folder.ent",
                "UI/Shell/Folder.topology.json",
                "UI/Theme/Folder.ent",
                "UI/Theme/Folder.topology.json",
                "ViewModels/Folder.ent",
                "ViewModels/Folder.topology.json",
                "ViewModels/Conversations/Folder.ent",
                "ViewModels/Conversations/Folder.topology.json",
                "ViewModels/Conversations/Faculties/Folder.ent",
                "ViewModels/Conversations/Faculties/Folder.topology.json",
                "ViewModels/Conversations/Models/Folder.ent",
                "ViewModels/Conversations/Models/Folder.topology.json",
                "ViewModels/Conversations/Services/Folder.ent",
                "ViewModels/Conversations/Services/Folder.topology.json",
                "ViewModels/Projects/Folder.ent",
                "ViewModels/Projects/Folder.topology.json",
                "ViewModels/Projects/Models/Folder.ent",
                "ViewModels/Projects/Models/Folder.topology.json",
                "ViewModels/Projects/Services/Folder.ent",
                "ViewModels/Projects/Services/Folder.topology.json",
                "ViewModels/Workspace/Folder.ent",
                "ViewModels/Workspace/Folder.topology.json",
                "ViewModels/Workspace/Faculties/Folder.ent",
                "ViewModels/Workspace/Faculties/Folder.topology.json",
                "ViewModels/Workspace/Models/Folder.ent",
                "ViewModels/Workspace/Models/Folder.topology.json",
                "ViewModels/Workspace/Services/Folder.ent",
                "ViewModels/Workspace/Services/Folder.topology.json",
                "Tools/Folder.ent",
                "Tools/Folder.topology.json",
                "Tools/Operator/Folder.ent",
                "Tools/Operator/Folder.topology.json",
                "Tools/Operator/EntelechiaOperator/Folder.ent",
                "Tools/Operator/EntelechiaOperator/Folder.topology.json",
                "Tools/Operator/EntelechiaOperator/Sources/Folder.ent",
                "Tools/Operator/EntelechiaOperator/Sources/Folder.topology.json",
                "Tools/Operator/EntelechiaOperator/Sources/App/Folder.ent",
                "Tools/Operator/EntelechiaOperator/Sources/App/Folder.topology.json",
                "Tools/Operator/EntelechiaOperator/Sources/App/Toolbar/Folder.ent",
                "Tools/Operator/EntelechiaOperator/Sources/App/Toolbar/Folder.topology.json",
                "Tools/Operator/EntelechiaOperator/Sources/Editor/Folder.ent",
                "Tools/Operator/EntelechiaOperator/Sources/Editor/Folder.topology.json",
                "Tools/Operator/EntelechiaOperator/Sources/Inspector/Folder.ent",
                "Tools/Operator/EntelechiaOperator/Sources/Inspector/Folder.topology.json",
                "Tools/Operator/EntelechiaOperator/Sources/Navigation/Folder.ent",
                "Tools/Operator/EntelechiaOperator/Sources/Navigation/Folder.topology.json",
                "Tools/Operator/EntelechiaOperator/Sources/Systems/Folder.ent",
                "Tools/Operator/EntelechiaOperator/Sources/Systems/Folder.topology.json",
                "Tools/Operator/EntelechiaOperator/Sources/Systems/Codex/Folder.ent",
                "Tools/Operator/EntelechiaOperator/Sources/Systems/Codex/Folder.topology.json",
                "Tools/Operator/EntelechiaOperator/Sources/Systems/Daemon/Folder.ent",
                "Tools/Operator/EntelechiaOperator/Sources/Systems/Daemon/Folder.topology.json",
                "Tools/Operator/EntelechiaOperator/Sources/Systems/FileSystem/Folder.ent",
                "Tools/Operator/EntelechiaOperator/Sources/Systems/FileSystem/Folder.topology.json",
                "Tools/Operator/EntelechiaOperator/Sources/Systems/PatchEngine/Folder.ent",
                "Tools/Operator/EntelechiaOperator/Sources/Systems/PatchEngine/Folder.topology.json"
            ],
            resources: [
                .process("Assets/Assets.xcassets"),
                .process("Support/Configuration/CodexSecrets.example.plist")
            ],
            swiftSettings: [
                .enableUpcomingFeature("DisableOutwardActorInference"),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault")
            ]
        ),
        .testTarget(
            name: "ChatUITests",
            dependencies: ["ChatUI"]
        )
    ]
)
