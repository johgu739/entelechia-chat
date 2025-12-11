import Foundation
import XCTest
import CryptoKit
@testable import UIConnections
import AppCoreEngine
import AppAdapters

enum TestHasher {
    static func hash(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

struct TestWorkspaceFile {
    let relativePath: String
    let content: String
}

private final class WorkspaceTreeNode {
    let name: String
    let id: FileID
    var children: [String: WorkspaceTreeNode] = [:]
    var content: String?
    var isDirectory: Bool
    
    init(name: String, isDirectory: Bool, content: String? = nil, id: FileID = FileID()) {
        self.name = name
        self.isDirectory = isDirectory
        self.content = content
        self.id = id
    }
}

final class DeterministicWorkspaceEngine: WorkspaceEngine, @unchecked Sendable {
    private var snapshot: WorkspaceSnapshot
    private var projection: WorkspaceTreeProjection?
    private let stream: AsyncStream<WorkspaceUpdate>
    private let continuation: AsyncStream<WorkspaceUpdate>.Continuation
    private let rootPath: String
    private let exclusionFolders: Set<String> = [".git", ".build", "node_modules", "DerivedData", "Pods", ".swiftpm"]
    private var descriptorIndex: [String: FileID]
    private var filesStore: [TestWorkspaceFile]
    
    var currentSnapshot: WorkspaceSnapshot { snapshot }
    
    init(root: URL, files: [TestWorkspaceFile], initialSelection: String? = nil) {
        self.rootPath = root.path
        let excluded = exclusionFolders
        let filteredFiles = files.filter { file in
            let components = file.relativePath.split(separator: "/").map(String.init)
            return !components.contains(where: { excluded.contains($0) })
        }
        self.filesStore = filteredFiles
        let (snapshot, projection, descriptorIndex) = Self.buildSnapshot(
            root: root.path,
            files: filteredFiles,
            selection: initialSelection.map { root.appendingPathComponent($0).path }
        )
        self.snapshot = snapshot
        self.projection = projection
        self.descriptorIndex = descriptorIndex
        
        var cont: AsyncStream<WorkspaceUpdate>.Continuation!
        stream = AsyncStream { cont = $0 }
        continuation = cont
        continuation.yield(WorkspaceUpdate(snapshot: snapshot, projection: projection, error: nil))
    }
    
    func openWorkspace(rootPath: String) async throws -> WorkspaceSnapshot { snapshot }
    
    func snapshot() async -> WorkspaceSnapshot { snapshot }
    
    func refresh() async throws -> WorkspaceSnapshot { snapshot }
    
    func select(path: String?) async throws -> WorkspaceSnapshot {
        let updated = Self.updatedSnapshot(snapshot, selectedPath: path, descriptorIndex: descriptorIndex)
        snapshot = updated
        continuation.yield(WorkspaceUpdate(snapshot: snapshot, projection: projection, error: nil))
        return snapshot
    }
    
    func contextPreferences() async throws -> WorkspaceSnapshot { snapshot }
    
    func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceSnapshot {
        var preferences = snapshot.contextPreferences
        var inclusions = snapshot.contextInclusions
        if let id = descriptorIndex[path] {
            inclusions[id] = included ? .included : .excluded
        }
        if included {
            preferences.includedPaths.insert(path)
            preferences.excludedPaths.remove(path)
        } else {
            preferences.excludedPaths.insert(path)
            preferences.includedPaths.remove(path)
        }
        snapshot = WorkspaceSnapshot(
            rootPath: snapshot.rootPath,
            selectedPath: snapshot.selectedPath,
            lastPersistedSelection: snapshot.lastPersistedSelection,
            selectedDescriptorID: snapshot.selectedDescriptorID,
            lastPersistedDescriptorID: snapshot.lastPersistedDescriptorID,
            contextPreferences: preferences,
            descriptorPaths: snapshot.descriptorPaths,
            contextInclusions: inclusions,
            descriptors: snapshot.descriptors,
            snapshotHash: snapshot.snapshotHash
        )
        continuation.yield(WorkspaceUpdate(snapshot: snapshot, projection: projection, error: nil))
        return snapshot
    }
    
    func treeProjection() async -> WorkspaceTreeProjection? { projection }
    
    func updates() -> AsyncStream<WorkspaceUpdate> { stream }
    
    func emitUpdate() {
        continuation.yield(WorkspaceUpdate(snapshot: snapshot, projection: projection, error: nil))
    }
    
    // MARK: - Mutation helpers for tests
    func addFile(relativePath: String, content: String) {
        mutateFiles { files in
            files.append(TestWorkspaceFile(relativePath: relativePath, content: content))
        }
    }
    
    func removeFile(relativePath: String) {
        mutateFiles { files in
            if let idx = files.firstIndex(where: { $0.relativePath == relativePath }) {
                files.remove(at: idx)
            }
        }
    }
    
    private func mutateFiles(_ block: (inout [TestWorkspaceFile]) -> Void) {
        var currentFiles = filesStore
        block(&currentFiles)
        filesStore = currentFiles
        let (newSnapshot, newProjection, newIndex) = Self.buildSnapshot(root: rootPath, files: currentFiles, selection: snapshot.selectedPath)
        snapshot = newSnapshot
        projection = newProjection
        descriptorIndex = newIndex
        emitUpdate()
    }
    
    func changeRoot(to newRoot: URL, files: [TestWorkspaceFile], selection: String? = nil) {
        let filtered = files.filter { file in
            let comps = file.relativePath.split(separator: "/").map(String.init)
            return !comps.contains(where: { exclusionFolders.contains($0) })
        }
        filesStore = filtered
        let (newSnapshot, newProjection, newIndex) = Self.buildSnapshot(
            root: newRoot.path,
            files: filtered,
            selection: selection.map { newRoot.appendingPathComponent($0).path }
        )
        snapshot = newSnapshot
        projection = newProjection
        descriptorIndex = newIndex
        continuation.yield(WorkspaceUpdate(snapshot: snapshot, projection: projection, error: nil))
    }
}

private extension DeterministicWorkspaceEngine {
    static func buildSnapshot(
        root: String,
        files: [TestWorkspaceFile],
        selection: String?
    ) -> (WorkspaceSnapshot, WorkspaceTreeProjection?, [String: FileID]) {
        let rootName = URL(fileURLWithPath: root).lastPathComponent
        let rootNode = WorkspaceTreeNode(name: rootName, isDirectory: true, id: deterministicID(for: root))
        for file in files {
            insert(file: file, under: rootNode, rootPath: root)
        }
        var descriptors: [FileDescriptor] = []
        var descriptorPaths: [FileID: String] = [:]
        let projection = makeProjection(
            node: rootNode,
            currentPath: (root as NSString).deletingLastPathComponent,
            descriptors: &descriptors,
            descriptorPaths: &descriptorPaths
        )
        let indexByPath = Dictionary(uniqueKeysWithValues: descriptorPaths.map { ($0.value, $0.key) })
        let selectedID = selection.flatMap { indexByPath[$0] }
        let signature = descriptorPaths
            .sorted { $0.value < $1.value }
            .map { "\($0.value):\($0.key.rawValue.uuidString)" }
            .joined(separator: "|")
        let snapshot = WorkspaceSnapshot(
            rootPath: root,
            selectedPath: selection,
            lastPersistedSelection: selection,
            selectedDescriptorID: selectedID,
            lastPersistedDescriptorID: selectedID,
            contextPreferences: .empty,
            descriptorPaths: descriptorPaths,
            contextInclusions: Dictionary(uniqueKeysWithValues: descriptorPaths.map { ($0.key, ContextInclusionState.neutral) }),
            descriptors: descriptors,
            snapshotHash: TestHasher.hash(signature)
        )
        return (snapshot, projection, indexByPath)
    }
    
    static func updatedSnapshot(_ snapshot: WorkspaceSnapshot, selectedPath: String?, descriptorIndex: [String: FileID]) -> WorkspaceSnapshot {
        let selectedID = selectedPath.flatMap { descriptorIndex[$0] }
        return WorkspaceSnapshot(
            rootPath: snapshot.rootPath,
            selectedPath: selectedPath,
            lastPersistedSelection: snapshot.lastPersistedSelection,
            selectedDescriptorID: selectedID,
            lastPersistedDescriptorID: snapshot.lastPersistedDescriptorID,
            contextPreferences: snapshot.contextPreferences,
            descriptorPaths: snapshot.descriptorPaths,
            contextInclusions: snapshot.contextInclusions,
            descriptors: snapshot.descriptors,
            snapshotHash: snapshot.snapshotHash
        )
    }
    
    static func insert(file: TestWorkspaceFile, under root: WorkspaceTreeNode, rootPath: String) {
        let components = file.relativePath.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return }
        var current = root
        var currentPath = rootPath
        for (index, component) in components.enumerated() {
            let isLast = index == components.count - 1
            currentPath = (currentPath as NSString).appendingPathComponent(component)
            if let existing = current.children[component] {
                current = existing
                continue
            }
            let node = WorkspaceTreeNode(
                name: component,
                isDirectory: !isLast,
                content: isLast ? file.content : nil,
                id: deterministicID(for: currentPath)
            )
            current.children[component] = node
            current = node
        }
    }
    
    static func makeProjection(
        node: WorkspaceTreeNode,
        currentPath: String,
        descriptors: inout [FileDescriptor],
        descriptorPaths: inout [FileID: String]
    ) -> WorkspaceTreeProjection {
        let path = (currentPath as NSString).appendingPathComponent(node.name)
        let sortedChildren = node.children.values.sorted { $0.name < $1.name }
        let childProjections = sortedChildren.map {
            makeProjection(node: $0, currentPath: path, descriptors: &descriptors, descriptorPaths: &descriptorPaths)
        }
        let descriptor = FileDescriptor(
            id: node.id,
            name: node.name,
            type: node.isDirectory ? .directory : .file,
            children: childProjections.map { $0.id },
            canonicalPath: path,
            language: node.isDirectory ? nil : "text",
            size: node.isDirectory ? 0 : (node.content?.utf8.count ?? 0),
            hash: node.isDirectory ? "" : FileDescriptor.hashFor(contents: Data((node.content ?? "").utf8))
        )
        descriptors.append(descriptor)
        descriptorPaths[node.id] = path
        return WorkspaceTreeProjection(
            id: node.id,
            name: node.name,
            path: path,
            isDirectory: node.isDirectory,
            children: childProjections
        )
    }
    
    static func deterministicID(for path: String) -> FileID {
        let digest = SHA256.hash(data: Data(path.utf8))
        let bytes = Array(digest.prefix(16))
        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return FileID(uuid)
    }
}

final class FakeConversationEngine: ConversationStreaming, @unchecked Sendable {
    private(set) var sendCalls: [(text: String, conversation: Conversation, request: ConversationContextRequest?)] = []
    private(set) var ensureCalls: [URL] = []
    private(set) var descriptorEnsureCalls: [[FileID]] = []
    var nextContextResult: ContextBuildResult
    var streamEvents: [ConversationDelta] = []
    var storedConversation: Conversation?
    
    init(contextResult: ContextBuildResult = .emptyStub()) {
        self.nextContextResult = contextResult
    }
    
    func conversation(for url: URL) async -> Conversation? { storedConversation }
    
    func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? { storedConversation }
    
    func ensureConversation(for url: URL) async throws -> Conversation {
        ensureCalls.append(url)
        let convo = storedConversation ?? Conversation(contextFilePaths: [url.path])
        storedConversation = convo
        return convo
    }
    
    func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> Conversation {
        descriptorEnsureCalls.append(ids)
        let paths = ids.compactMap { pathResolver($0) }
        let convo = storedConversation ?? Conversation(contextFilePaths: paths)
        storedConversation = convo
        return convo
    }
    
    func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws {}
    
    func sendMessage(
        _ text: String,
        in conversation: Conversation,
        context: ConversationContextRequest?,
        onStream: ((ConversationDelta) -> Void)?
    ) async throws -> (Conversation, ContextBuildResult) {
        sendCalls.append((text, conversation, context))
        streamEvents.forEach { onStream?($0) }
        return (conversation, nextContextResult)
    }
}

final class FakeCodexService: CodexQuerying, @unchecked Sendable {
    struct Call: Equatable {
        let scope: WorkspaceScope
        let question: String
    }
    
    private(set) var calls: [Call] = []
    var mutationAttempts = 0
    var streamEcho: [String] = []
    var contextResult: ContextBuildResult
    var contextProvider: ((WorkspaceScope) -> ContextBuildResult)?
    var errorToThrow: Error?
    var cancelAfterFirstChunk: Bool = false
    private(set) var lastStreamedText: String?
    private(set) var streamedChunkCount: Int = 0
    
    init(contextResult: ContextBuildResult = .emptyStub()) {
        self.contextResult = contextResult
    }
    
    func askAboutWorkspaceNode(
        scope: WorkspaceScope,
        question: String,
        onStream: ((String) -> Void)?
    ) async throws -> CodexAnswer {
        if let err = errorToThrow { throw err }
        calls.append(Call(scope: scope, question: question))
        lastStreamedText = nil
        streamedChunkCount = 0
        for (idx, chunk) in streamEcho.enumerated() {
            onStream?(chunk)
            lastStreamedText = chunk
            streamedChunkCount += 1
            if cancelAfterFirstChunk && idx == 0 { break }
        }
        let context = contextProvider?(scope) ?? contextResult
        return CodexAnswer(text: "answer:\(question)", context: context)
    }
    
    func attemptMutation() {
        mutationAttempts += 1
    }
}

final class FakeMutationAuthority: FileMutationAuthorizing, @unchecked Sendable {
    private(set) var applyCalls: Int = 0
    
    func apply(diffs: [FileDiff], rootPath: String) throws -> [AppliedPatchResult] {
        applyCalls += 1
        return diffs.map { AppliedPatchResult(path: $0.path, applied: false, message: "noop") }
    }
}

final class SharedStubTodosLoader: ProjectTodosLoading {
    func loadTodos(for root: URL) throws -> ProjectTodos { .empty }
}

extension LoadedFile {
    static func make(path: String, content: String, included: Bool = true) -> LoadedFile {
        LoadedFile(
            name: URL(fileURLWithPath: path).lastPathComponent,
            url: URL(fileURLWithPath: path),
            content: content,
            fileTypeIdentifier: "text",
            isIncludedInContext: included
        )
    }
}

extension ContextBuildResult {
    static func emptyStub() -> ContextBuildResult {
        ContextBuildResult(
            attachments: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 0,
            totalTokens: 0,
            budget: .default,
            encodedSegments: []
        )
    }
    
    static func from(files: [LoadedFile], segments: [ContextSegment] = []) -> ContextBuildResult {
        ContextBuildResult(
            attachments: files,
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: files.reduce(0) { $0 + $1.byteCount },
            totalTokens: files.reduce(0) { $0 + $1.tokenEstimate },
            budget: .default,
            encodedSegments: segments
        )
    }
}
