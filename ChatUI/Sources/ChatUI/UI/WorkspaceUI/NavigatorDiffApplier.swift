import Foundation
import AppKit
import UIContracts

struct NavigatorDiffApplier {
    func applyDiff(from oldRoot: UIContracts.FileNode, to newRoot: UIContracts.FileNode, in outlineView: NSOutlineView) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            outlineView.beginUpdates()
            reconcile(node: oldRoot, with: newRoot, parentItem: nil, in: outlineView)
            outlineView.endUpdates()
        }
    }
    
    private func identityKey(for node: UIContracts.FileNode) -> AnyHashable {
        node.descriptorID.map { AnyHashable($0) } ?? AnyHashable(node.path)
    }
    
    private func reconcile(
        node oldNode: UIContracts.FileNode,
        with newNode: UIContracts.FileNode,
        parentItem: Any?,
        in outlineView: NSOutlineView
    ) {
        let sameIdentity: Bool = {
            if let lhs = oldNode.descriptorID, let rhs = newNode.descriptorID {
                return lhs == rhs
            }
            return oldNode.path == newNode.path
        }()
        guard sameIdentity else { return }
        
        let oldChildren = oldNode.children ?? []
        let newChildren = newNode.children ?? []
        
        var updatedChildren: [UIContracts.FileNode] = []
        var removals: [Int] = []
        var insertions: [(Int, UIContracts.FileNode)] = []
        
        let oldByIdentity = identityMap(from: oldChildren)
        
        let newKeys: Set<AnyHashable> = Set(newChildren.map { identityKey(for: $0) })
        for (idx, child) in oldChildren.enumerated()
        where !newKeys.contains(identityKey(for: child)) {
            removals.append(idx)
        }
        
        for (newIndex, newChild) in newChildren.enumerated() {
            let key = identityKey(for: newChild)
            if let existing = oldByIdentity[key]?.1 {
                updatedChildren.append(existing)
            } else {
                updatedChildren.append(newChild)
                insertions.append((newIndex, newChild))
            }
        }
        
        if !removals.isEmpty {
            let indexSet = IndexSet(removals)
            outlineView.removeItems(at: indexSet, inParent: parentItem, withAnimation: [])
        }
        
        oldNode.children = updatedChildren
        
        if !insertions.isEmpty {
            let indexSet = IndexSet(insertions.map { $0.0 })
            outlineView.insertItems(at: indexSet, inParent: parentItem, withAnimation: [])
        }
        
        for newChild in newChildren {
            let key = identityKey(for: newChild)
            if let existing = oldByIdentity[key]?.1 {
                reconcile(node: existing, with: newChild, parentItem: existing, in: outlineView)
            }
        }
    }
    
    private func identityMap(from children: [UIContracts.FileNode]) -> [AnyHashable: (Int, UIContracts.FileNode)] {
        Dictionary(
            uniqueKeysWithValues: children.enumerated().map { index, child in
                (identityKey(for: child), (index, child))
            }
        )
    }
}

