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
import UIConnections

@MainActor
struct XcodeNavigatorRepresentable: NSViewRepresentable {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    
    func makeNSView(context: Context) -> NSView {
        let dataSource = NavigatorDataSource(diffApplier: NavigatorDiffApplier())
        dataSource.workspaceViewModel = workspaceViewModel

        let outlineView = configuredOutlineView(dataSource: dataSource)
        let scrollView = configuredScrollView(containing: outlineView)
        let containerView = containerWrapping(scrollView)

        context.coordinator.dataSource = dataSource
        context.coordinator.outlineView = outlineView
        context.coordinator.lastRootURL = workspaceViewModel.rootDirectory
        context.coordinator.lastFilterText = workspaceViewModel.filterText

        // Perform an initial data load now that everything is wired up.
        dataSource.reloadData()
        outlineView.reloadData()
        
        return containerView
    }
    
    private func configuredOutlineView(dataSource: NavigatorDataSource) -> NSOutlineView {
        let outlineView = NSOutlineView()
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

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("MainColumn"))
        column.title = ""
        column.resizingMask = [.autoresizingMask, .userResizingMask]
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        outlineView.dataSource = dataSource
        outlineView.delegate = dataSource
        return outlineView
    }

    private func configuredScrollView(containing outlineView: NSOutlineView) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = NSColor.clear.cgColor
        scrollView.documentView = outlineView
        return scrollView
    }

    private func containerWrapping(_ scrollView: NSScrollView) -> NSView {
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
        let currentSelectionID = workspaceViewModel.selectedDescriptorID
        if context.coordinator.lastSelectedDescriptorID != currentSelectionID {
            context.coordinator.lastSelectedDescriptorID = currentSelectionID
            dataSource.applySelection(descriptorID: currentSelectionID, in: outlineView)
        }

        // Keep expansion in sync with view model
        let currentExpanded = workspaceViewModel.expandedDescriptorIDs
        if context.coordinator.lastExpandedDescriptorIDs != currentExpanded {
            context.coordinator.lastExpandedDescriptorIDs = currentExpanded
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
        var lastSelectedDescriptorID: FileID?
        var lastExpandedDescriptorIDs: Set<FileID> = []
    }
}

// MARK: - Navigator Data Source

@MainActor
class NavigatorDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    weak var workspaceViewModel: WorkspaceViewModel?
    
    /// Rotnod för trädstrukturen (motsvarar vald `rootDirectory`).
    var rootNode: FileNode?
    /// Cache to avoid recomputing paths repeatedly.
    private var descriptorPathCache: [FileID: [FileNode]] = [:]
    private let diffApplier: NavigatorDiffApplier

    init(diffApplier: NavigatorDiffApplier) {
        self.diffApplier = diffApplier
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
        descriptorPathCache.removeAll()
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
        
        let cellView = outlineView.makeView(
            withIdentifier: NSUserInterfaceItemIdentifier("NavigatorCell"),
            owner: nil
        ) as? NavigatorCellView
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
                if let descriptorID = node.descriptorID {
                    self.workspaceViewModel?.setSelectedDescriptorID(descriptorID)
                } else {
                    // Nodes without descriptor IDs are not part of the canonical engine projection.
                    self.workspaceViewModel?.setSelectedDescriptorID(nil)
                }
            } else {
                self.workspaceViewModel?.setSelectedDescriptorID(nil)
            }
        }
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? FileNode else { return }
        Task { @MainActor [weak self] in
            if let descriptorID = node.descriptorID {
                self?.workspaceViewModel?.expandedDescriptorIDs.insert(descriptorID)
            }
        }
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? FileNode else { return }
        Task { @MainActor [weak self] in
            if let descriptorID = node.descriptorID {
                self?.workspaceViewModel?.expandedDescriptorIDs.remove(descriptorID)
            }
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
        diffApplier.applyDiff(from: oldRoot, to: newRoot, in: outlineView)
    }

    /// Expand tree to the provided descriptor ID (preferred) or URL (fallback) and select it.
    func applySelection(descriptorID: FileID?, in outlineView: NSOutlineView) {
        guard let rootNode else { return }
        if let did = descriptorID, let path = findPath(descriptorID: did, in: rootNode) {
            expandAndSelect(path: path, in: outlineView)
        }
    }

    /// Expand nodes that correspond to provided descriptor IDs.
    func applyExpansionState(_ expanded: Set<FileID>, in outlineView: NSOutlineView) {
        guard let rootNode else { return }
        for did in expanded {
            guard let path = findPath(descriptorID: did, in: rootNode) else { continue }
            for node in path {
                outlineView.expandItem(node)
            }
        }
    }

    private func expandAndSelect(path: [FileNode], in outlineView: NSOutlineView) {
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

    /// Find path from root to node by descriptor ID (cached).
    private func findPath(descriptorID: FileID, in node: FileNode) -> [FileNode]? {
        if let cached = descriptorPathCache[descriptorID] { return cached }
        if let current = node.descriptorID, current == descriptorID {
            let path = [node]
            descriptorPathCache[descriptorID] = path
            return path
        }
        guard let children = node.children else { return nil }
        for child in children {
            if let path = findPath(descriptorID: descriptorID, in: child) {
                let fullPath = [node] + path
                descriptorPathCache[descriptorID] = fullPath
                return fullPath
            }
        }
        return nil
    }

}

private extension NavigatorDataSource {
    @MainActor
    func loadChildren(for node: FileNode) -> [FileNode]? {
        return node.children
    }
}
