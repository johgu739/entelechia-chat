import AppKit
import UIConnections

final class NavigatorCellView: NSTableCellView {
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
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        iconView.imageScaling = .scaleProportionallyDown
        iconView.imageAlignment = .alignCenter
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
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
            iconView.widthAnchor.constraint(lessThanOrEqualToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            nameTextField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            nameTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            nameTextField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func configure(with node: FileNode) {
        nameTextField.stringValue = node.name
        let icon = NSWorkspace.shared.icon(forFile: node.path.path)
        icon.size = NSSize(width: 16, height: 16)
        iconView.image = icon
    }
}

