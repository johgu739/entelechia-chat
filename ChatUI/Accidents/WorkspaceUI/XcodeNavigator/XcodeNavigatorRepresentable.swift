// @EntelechiaHeaderStart
// Signifier: XcodeNavigatorRepresentable
// Substance: AppKit outline bridge
// Genus: UI bridge
// Differentia: Wires NSOutlineView data source/delegate
// Form: Data source/delegate wiring
// Matter: FileNode tree; selection/expansion sets
// Powers: Populate rows; sync selection; apply diffs
// FinalCause: Render file tree via AppKit within SwiftUI
// Relations: Serves workspace UI; depends on WorkspaceViewModel and FileNode
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
struct XcodeNavigatorRepresentable: NSViewRepresentable {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    
    func makeNSView(context: Context) -> NSView {
        let scrollView = NSScrollView()
        let outlineView = NSOutlineView()
        
        // Configure scroll view - completely transparent
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Configure outline view (Xcode style) - completely transparent
        outlineView.headerView = nil
        outlineView.rowHeight = 20
        if #available(macOS 12.0, *) {
            outlineView.style = .sourceList
        } else {
            outlineView.selectionHighlightStyle = .sourceList
        }
        outlineView.backgroundColor = .clear
        outlineView.wantsLayer = true
        outlineView.layer?.backgroundColor = NSColor.clear.cgColor
        outlineView.floatsGroupRows = false
        outlineView.indentationPerLevel = 12
        outlineView.indentationMarkerFollowsCell = true
        outlineView.autoresizesOutlineColumn = true
        outlineView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        
        // Create single column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("MainColumn"))
        column.title = ""
        column.resizingMask = [.autoresizingMask, .userResizingMask]
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        
        // Set data source and delegate
        let dataSource = NavigatorDataSource()
        dataSource.workspaceViewModel = workspaceViewModel
        outlineView.dataSource = dataSource
        outlineView.delegate = dataSource
        
        // Store reference
        context.coordinator.dataSource = dataSource
        context.coordinator.outlineView = outlineView
        
        scrollView.documentView = outlineView
        
        // The visual effect background is handled by the parent ZStack in XcodeNavigatorView
        // So we just return the scrollView wrapped in a container
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.addSubview(scrollView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Initial coordinator state
        context.coordinator.lastRootURL = workspaceViewModel.rootDirectory
        context.coordinator.lastFilterText = workspaceViewModel.filterText

        // Perform an initial data load now that everything is wired up.
        dataSource.reloadData()
        outlineView.reloadData()
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard
            let outlineView = context.coordinator.outlineView,
            let dataSource = context.coordinator.dataSource
        else { return }

        // Håll referensen i sync
        dataSource.workspaceViewModel = workspaceViewModel

        let currentRoot = workspaceViewModel.rootDirectory
        let hasProjectRootChanged = context.coordinator.lastRootURL != currentRoot
        if hasProjectRootChanged {
            context.coordinator.lastRootURL = currentRoot
            dataSource.rootNode = workspaceViewModel.rootFileNode
            outlineView.reloadData()
        } else if let newRoot = workspaceViewModel.rootFileNode,
                  let existingRoot = dataSource.rootNode,
                  existingRoot.path == newRoot.path {
            // Same project: apply incremental diff to avoid flicker/collapse
            dataSource.applyDiff(from: existingRoot, to: newRoot, in: outlineView)
        } else {
            // Fallback: set and reload
            dataSource.rootNode = workspaceViewModel.rootFileNode
            outlineView.reloadData()
        }

        // Keep selection in sync with view model
        let currentSelection = workspaceViewModel.selectedURL
        if context.coordinator.lastSelectedURL != currentSelection {
            context.coordinator.lastSelectedURL = currentSelection
            dataSource.applySelection(currentSelection, in: outlineView)
        }

        // Keep expansion in sync with view model
        let currentExpanded = workspaceViewModel.expandedURLs
        if context.coordinator.lastExpandedURLs != currentExpanded {
            context.coordinator.lastExpandedURLs = currentExpanded
            dataSource.applyExpansionState(currentExpanded, in: outlineView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    @MainActor
    class Coordinator {
        var dataSource: NavigatorDataSource?
        var outlineView: NSOutlineView?
        var lastFilterText: String = ""
        var lastRootURL: URL?
        var lastSelectedURL: URL?
        var lastExpandedURLs: Set<URL> = []
    }
}

// MARK: - Navigator Data Source

@MainActor
class NavigatorDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    weak var workspaceViewModel: WorkspaceViewModel?
    
    /// Rotnod för trädstrukturen (motsvarar vald `rootDirectory`).
    var rootNode: FileNode?
    /// Cache to avoid recomputing paths repeatedly.
    private var pathCache: [URL: [FileNode]] = [:]

    override init() {
        super.init()
    }
    
    /// Ladda om hela trädet från aktuell `rootDirectory`.
    @MainActor
    func reloadData() {
        guard let root = workspaceViewModel?.rootFileNode else {
            rootNode = nil
            return
        }
        // Återanvänd det förinlästa trädet från WorkspaceViewModel.
        rootNode = root
        pathCache.removeAll()
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            guard let rootNode = rootNode else { return 0 }
            return loadChildren(for: rootNode)?.count ?? 0
        }

        if let node = item as? FileNode {
            return loadChildren(for: node)?.count ?? 0
        }

        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            guard let rootNode = rootNode else {
                return NSObject()
            }
            return loadChildren(for: rootNode)?[index] ?? rootNode
        }

        if let node = item as? FileNode {
            return loadChildren(for: node)?[index] ?? node
        }

        return NSObject()
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? FileNode)?.isDirectory == true
    }
    
    // MARK: - NSOutlineViewDelegate
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let fileNode = item as? FileNode else { return nil }
        
        let cellView = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("NavigatorCell"), owner: nil) as? NavigatorCellView
            ?? NavigatorCellView()
        
        // Ensure cell view is completely transparent
        cellView.wantsLayer = true
        cellView.layer?.backgroundColor = NSColor.clear.cgColor
        
        cellView.configure(with: fileNode)
        return cellView
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return true
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else { return }
        let selectedRow = outlineView.selectedRow
        
        // NSOutlineView callbacks may not be on main thread, ensure we're on main actor
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if selectedRow >= 0,
               let node = outlineView.item(atRow: selectedRow) as? FileNode {
                // Check if this is a parent directory item (should not be selectable)
               if node.isParentDirectory {
                   // This is a parent directory - don't set as selected
                   // Just expand/collapse to navigate
                   return
               }
                self.workspaceViewModel?.setSelectedURL(node.path)
            } else {
                self.workspaceViewModel?.setSelectedURL(nil)
            }
        }
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? FileNode else { return }
        Task { @MainActor [weak self] in
            self?.workspaceViewModel?.expandedURLs.insert(node.path)
        }
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? FileNode else { return }
        Task { @MainActor [weak self] in
            self?.workspaceViewModel?.expandedURLs.remove(node.path)
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, menuForEvent event: NSEvent) -> NSMenu? {
        let point = outlineView.convert(event.locationInWindow, from: nil)
        let row = outlineView.row(at: point)
        
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? FileNode else {
            return nil
        }
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Open", action: #selector(openFile(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reveal in Finder", action: #selector(revealInFinder(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Copy Path", action: #selector(copyPath(_:)), keyEquivalent: ""))
        
        // Store the URL in the menu item's representedObject
        menu.items.forEach { $0.representedObject = node.path }
        menu.items.forEach { $0.target = self }
        
        return menu
    }
    
    @objc private func openFile(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }
    
    @objc private func revealInFinder(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    @objc private func copyPath(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
    }
    
    func rowForURL(_ url: URL) -> Int? {
        // Minimal implementation: rely on NSOutlineView APIs instead of
        // en egen, komplex trädtraversering. Kan byggas ut senare vid behov.
        return nil
    }

    /// Apply a lightweight diff between current tree and new tree to avoid full reloads.
    func applyDiff(from oldRoot: FileNode, to newRoot: FileNode, in outlineView: NSOutlineView) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            outlineView.beginUpdates()
            reconcile(node: oldRoot, with: newRoot, parentItem: nil, in: outlineView)
            outlineView.endUpdates()
        }
        // Root node was mutated in-place to match new tree
        pathCache.removeAll()
    }

    /// Reconcile a subtree by removing/adding children in place.
    private func reconcile(node oldNode: FileNode, with newNode: FileNode, parentItem: Any?, in outlineView: NSOutlineView) {
        // Only reconcile nodes that represent the same path
        guard oldNode.path == newNode.path else {
            return
        }

        let oldChildren = oldNode.children ?? []
        let newChildren = newNode.children ?? []

        var updatedChildren: [FileNode] = []
        var removals: [Int] = []
        var insertions: [(Int, FileNode)] = []

        var oldByPath: [URL: (Int, FileNode)] = [:]
        for (idx, child) in oldChildren.enumerated() {
            oldByPath[child.path] = (idx, child)
        }

        // Determine removals
        let newPaths = Set(newChildren.map { $0.path })
        for (idx, child) in oldChildren.enumerated() where !newPaths.contains(child.path) {
            removals.append(idx)
        }

        // Determine updated ordering and insertions
        for (newIndex, newChild) in newChildren.enumerated() {
            if let (_, existing) = oldByPath[newChild.path] {
                updatedChildren.append(existing)
            } else {
                updatedChildren.append(newChild)
                insertions.append((newIndex, newChild))
            }
        }

        // Apply removals first (from highest index to lowest)
        if !removals.isEmpty {
            let indexSet = IndexSet(removals)
            outlineView.removeItems(at: indexSet, inParent: parentItem, withAnimation: [])
        }

        // Update children array to reflect new state
        oldNode.children = updatedChildren

        // Apply insertions
        if !insertions.isEmpty {
            let indexSet = IndexSet(insertions.map { $0.0 })
            outlineView.insertItems(at: indexSet, inParent: parentItem, withAnimation: [])
        }

        // Recurse into matched children
        for newChild in newChildren {
            if let existing = oldByPath[newChild.path]?.1 {
                reconcile(node: existing, with: newChild, parentItem: existing, in: outlineView)
            }
        }
    }

    /// Expand tree to the provided URL and select it.
    func applySelection(_ url: URL?, in outlineView: NSOutlineView) {
        guard let url else { return }
        guard let rootNode else { return }
        guard let path = findPath(to: url, in: rootNode) else { return }

        for ancestor in path.dropLast() {
            outlineView.expandItem(ancestor)
        }

        if let node = path.last {
            let row = outlineView.row(forItem: node)
            if row >= 0 {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                outlineView.scrollRowToVisible(row)
            }
        }
    }

    /// Expand nodes that correspond to provided URLs.
    func applyExpansionState(_ expanded: Set<URL>, in outlineView: NSOutlineView) {
        guard let rootNode else { return }
        for url in expanded {
            guard let path = findPath(to: url, in: rootNode) else { continue }
            for node in path {
                outlineView.expandItem(node)
            }
        }
    }

    /// Find path from root to node with URL (with simple caching).
    private func findPath(to url: URL, in node: FileNode) -> [FileNode]? {
        if let cached = pathCache[url] { return cached }
        if node.path == url {
            let path = [node]
            pathCache[url] = path
            return path
        }
        guard let children = node.children else { return nil }
        for child in children {
            if let path = findPath(to: url, in: child) {
                let fullPath = [node] + path
                pathCache[url] = fullPath
                return fullPath
            }
        }
        return nil
    }
}

private extension NavigatorDataSource {
    @MainActor
    func loadChildren(for node: FileNode) -> [FileNode]? {
        do {
            try node.loadChildrenIfNeeded(projectRoot: workspaceViewModel?.rootDirectory)
        } catch {
            Task { @MainActor [weak workspaceViewModel] in
                workspaceViewModel?.publishFileBrowserError(error)
            }
        }
        return node.children
    }
}

// MARK: - Navigator Cell View

class NavigatorCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let nameTextField = NSTextField()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // Make cell view completely transparent
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Configure icon view
        iconView.imageScaling = .scaleProportionallyDown
        iconView.imageAlignment = .alignCenter
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure text field
        nameTextField.isEditable = false
        nameTextField.isSelectable = false
        nameTextField.isBordered = false
        nameTextField.drawsBackground = false
        nameTextField.backgroundColor = .clear
        nameTextField.font = NSFont.systemFont(ofSize: 12)
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(iconView)
        addSubview(nameTextField)
        
        imageView = iconView
        textField = nameTextField
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            // Allow width to shrink if cell becomes very narrow to avoid constraint conflicts
            iconView.widthAnchor.constraint(lessThanOrEqualToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            nameTextField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            nameTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            nameTextField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func configure(with node: FileNode) {
        nameTextField.stringValue = node.name
        
        // Use native macOS icons (Xcode style) - they already have proper colors and are system-native
        let icon = NSWorkspace.shared.icon(forFile: node.path.path)
        icon.size = NSSize(width: 16, height: 16)
        iconView.image = icon
        
        // Style for parent directory
        if node.isParentDirectory {
            nameTextField.textColor = .secondaryLabelColor
        } else {
            nameTextField.textColor = .labelColor
        }
    }
}
