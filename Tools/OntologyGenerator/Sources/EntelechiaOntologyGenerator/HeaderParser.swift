// @EntelechiaHeaderStart
// Signifier: HeaderParser
// Substance: Header parsing and generation
// Genus: Ontology parser
// Differentia: Parses and ensures correct header structure with Signifier
// Form: Parsing rules and header generation
// Matter: File contents; header strings
// Powers: Parse headers; insert missing Signifier; preserve existing content
// FinalCause: Ensure all files have proper headers with Signifier first
// Relations: Used by FileScanner, EntWriter, TopologyBuilder
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation

struct HeaderParser {
    // MARK: - Header Field Order (Signifier MUST be first)
    
    static let orderedKeys: [String] = [
        "Signifier",
        "Substance",
        "Genus",
        "Differentia",
        "Form",
        "Matter",
        "Powers",
        "FinalCause",
        "Relations",
        "CausalityType"
    ]
    
    // MARK: - Header Markers
    
    static let headerStartMarker = "// @EntelechiaHeaderStart"
    static let headerEndMarker = "// @EntelechiaHeaderEnd"
    static let folderHeaderStartMarker = "// @EntelechiaFolderStart"
    static let folderHeaderEndMarker = "// @EntelechiaFolderEnd"
    
    // MARK: - Parse Header
    
    /// Parse header from file content
    /// Returns dictionary of field -> value, or nil if no header found
    static func parseHeader(from content: String) -> [String: String]? {
        guard let startRange = content.range(of: headerStartMarker),
              let endRange = content.range(of: headerEndMarker, range: startRange.upperBound..<content.endIndex) else {
            return nil
        }
        
        let headerBlock = String(content[startRange.upperBound..<endRange.lowerBound])
        var fields: [String: String] = [:]
        
        for line in headerBlock.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") {
                let content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if let colonIndex = content.firstIndex(of: ":") {
                    let key = String(content[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let value = String(content[content.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty {
                        fields[key] = value
                    }
                }
            }
        }
        
        return fields.isEmpty ? nil : fields
    }
    
    // MARK: - Parse Folder Header
    
    /// Parse folder header from Folder.ent content
    /// Handles both new format (@EntelechiaFolderStart) and old format (@EntelechiaFolderHeaderStart)
    static func parseFolderHeader(from content: String) -> [String: String]? {
        // Try new format first
        if let startRange = content.range(of: folderHeaderStartMarker),
           let endRange = content.range(of: folderHeaderEndMarker, range: startRange.upperBound..<content.endIndex) {
            let headerBlock = String(content[startRange.upperBound..<endRange.lowerBound])
            var fields: [String: String] = [:]
            
            for line in headerBlock.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") {
                    let content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    if let colonIndex = content.firstIndex(of: ":") {
                        let key = String(content[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                        let value = String(content[content.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                        if !key.isEmpty {
                            fields[key] = value
                        }
                    }
                }
            }
            
            return fields.isEmpty ? nil : fields
        }
        
        // Try old format
        let oldStartMarker = "// @EntelechiaFolderHeaderStart"
        let oldEndMarker = "// @EntelechiaFolderHeaderEnd"
        if let startRange = content.range(of: oldStartMarker),
           let endRange = content.range(of: oldEndMarker, range: startRange.upperBound..<content.endIndex) {
            let headerBlock = String(content[startRange.upperBound..<endRange.lowerBound])
            var fields: [String: String] = [:]
            
            for line in headerBlock.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Old format may not have // prefix
                let lineContent = trimmed.hasPrefix("//") ? String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces) : trimmed
                if let colonIndex = lineContent.firstIndex(of: ":") {
                    let key = String(lineContent[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let value = String(lineContent[lineContent.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty {
                        fields[key] = value
                    }
                }
            }
            
            return fields.isEmpty ? nil : fields
        }
        
        return nil
    }
    
    // MARK: - Ensure Header (with Signifier)
    
    /// Ensure file has proper header with Signifier first
    /// NEVER overwrites existing semantic content - only inserts missing fields
    /// Returns: (updated content, signifier value, todos for missing fields)
    static func ensureHeader(in content: String, fileName: String) -> (content: String, signifier: String, todos: [String]) {
        let baseFileName = (fileName as NSString).deletingPathExtension
        var todos: [String] = []
        
        // Parse existing header if present
        var existingFields = parseHeader(from: content) ?? [:]
        
        // Ensure Signifier exists and is correct
        if existingFields["Signifier"] == nil || existingFields["Signifier"]?.isEmpty == true {
            existingFields["Signifier"] = baseFileName
        }
        
        // Check for missing fields and add TODOs
        for key in orderedKeys {
            if existingFields[key] == nil || existingFields[key]?.isEmpty == true {
                if key == "Signifier" {
                    // Signifier is auto-filled, no TODO needed
                    continue
                }
                todos.append("\(fileName): Missing \(key)")
            }
        }
        
        // If header exists, update it
        if content.contains(headerStartMarker) && content.contains(headerEndMarker) {
            return (updateExistingHeader(in: content, with: existingFields), existingFields["Signifier"] ?? baseFileName, todos)
        }
        
        // Otherwise, insert new header at the beginning
        let newHeader = renderHeaderBlock(fields: existingFields)
        let newContent = newHeader + "\n\n" + content
        return (newContent, existingFields["Signifier"] ?? baseFileName, todos)
    }
    
    // MARK: - Update Existing Header
    
    /// Update existing header, preserving order and only adding missing fields
    /// NEVER overwrites existing non-empty values
    private static func updateExistingHeader(in content: String, with fields: [String: String]) -> String {
        guard let startRange = content.range(of: headerStartMarker),
              let endRange = content.range(of: headerEndMarker, range: startRange.upperBound..<content.endIndex) else {
            return content
        }
        
        // Build new header block with correct ordering
        var headerLines: [String] = [headerStartMarker]
        
        for key in orderedKeys {
            if let value = fields[key], !value.isEmpty {
                headerLines.append("// \(key): \(value)")
            } else if key == "Signifier" {
                // Signifier must always be present
                let signifier = fields["Signifier"] ?? "TODO"
                headerLines.append("// \(key): \(signifier)")
            }
        }
        
        headerLines.append(headerEndMarker)
        
        let newHeader = headerLines.joined(separator: "\n")
        let beforeHeader = String(content[..<startRange.lowerBound])
        let afterHeader = String(content[endRange.upperBound...])
        
        return beforeHeader + newHeader + afterHeader
    }
    
    // MARK: - Render Header Block
    
    /// Render complete header block from fields dictionary
    static func renderHeaderBlock(fields: [String: String]) -> String {
        var lines: [String] = [headerStartMarker]
        
        for key in orderedKeys {
            if let value = fields[key], !value.isEmpty {
                lines.append("// \(key): \(value)")
            } else if key == "Signifier" {
                // Signifier must always be present
                let signifier = fields["Signifier"] ?? "TODO"
                lines.append("// \(key): \(signifier)")
            } else {
                // Missing field - add TODO
                lines.append("// \(key): TODO_AGENT_FILL")
            }
        }
        
        lines.append(headerEndMarker)
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Ensure Folder Header
    
    /// Ensure folder has proper header with Signifier
    /// CRITICAL: ONLY adds Signifier if missing - NEVER modifies existing fields
    /// Returns: (updated content, signifier value, todos)
    static func ensureFolderHeader(in content: String, folderName: String) -> (content: String, signifier: String, todos: [String]) {
        var todos: [String] = []
        
        // Parse existing header if present
        let existingFields = parseFolderHeader(from: content) ?? [:]
        
        // Check if Signifier is missing
        let hasSignifier = existingFields["Signifier"] != nil && !(existingFields["Signifier"]?.isEmpty ?? true)
        
        // If Signifier exists, return content unchanged
        if hasSignifier {
            // Just collect TODOs for missing fields (but don't modify)
            for key in orderedKeys {
                if existingFields[key] == nil || existingFields[key]?.isEmpty == true {
                    if key != "Signifier" {
                        todos.append("\(folderName)/Folder.ent: Missing \(key)")
                    }
                }
            }
            return (content, existingFields["Signifier"] ?? folderName, todos)
        }
        
        // Signifier is missing - add it ONLY, preserving all other content
        // Try new format first
        if content.contains(folderHeaderStartMarker) && content.contains(folderHeaderEndMarker) {
            if let startRange = content.range(of: folderHeaderStartMarker),
               let endRange = content.range(of: folderHeaderEndMarker, range: startRange.upperBound..<content.endIndex) {
                let headerBlock = String(content[startRange.upperBound..<endRange.lowerBound])
                let beforeHeader = String(content[..<startRange.upperBound])
                let afterHeader = String(content[endRange.upperBound...])
                
                // Insert Signifier as first line after start marker
                let newHeaderBlock = "// Signifier: \(folderName)\n" + headerBlock
                let newContent = beforeHeader + folderHeaderStartMarker + "\n" + newHeaderBlock + folderHeaderEndMarker + afterHeader
                return (newContent, folderName, todos)
            }
        }
        
        // Try old format
        let oldStartMarker = "// @EntelechiaFolderHeaderStart"
        let oldEndMarker = "// @EntelechiaFolderHeaderEnd"
        if content.contains(oldStartMarker) && content.contains(oldEndMarker) {
            if let startRange = content.range(of: oldStartMarker),
               let endRange = content.range(of: oldEndMarker, range: startRange.upperBound..<content.endIndex) {
                let headerBlock = String(content[startRange.upperBound..<endRange.lowerBound])
                let beforeHeader = String(content[..<startRange.upperBound])
                let afterHeader = String(content[endRange.upperBound...])
                
                // Insert Signifier as first line after start marker
                let newHeaderBlock = "Signifier: \(folderName)\n" + headerBlock
                let newContent = beforeHeader + oldStartMarker + "\n" + newHeaderBlock + oldEndMarker + afterHeader
                return (newContent, folderName, todos)
            }
        }
        
        // No header found - return unchanged (shouldn't happen, but be safe)
        return (content, folderName, todos)
    }
    
    // MARK: - Update Existing Folder Header
    
    private static func updateExistingFolderHeader(in content: String, with fields: [String: String]) -> String {
        guard let startRange = content.range(of: folderHeaderStartMarker),
              let endRange = content.range(of: folderHeaderEndMarker, range: startRange.upperBound..<content.endIndex) else {
            return content
        }
        
        var headerLines: [String] = [folderHeaderStartMarker]
        
        for key in orderedKeys {
            if let value = fields[key], !value.isEmpty {
                headerLines.append("// \(key): \(value)")
            } else if key == "Signifier" {
                let signifier = fields["Signifier"] ?? "TODO"
                headerLines.append("// \(key): \(signifier)")
            }
        }
        
        headerLines.append(folderHeaderEndMarker)
        
        let newHeader = headerLines.joined(separator: "\n")
        let beforeHeader = String(content[..<startRange.lowerBound])
        let afterHeader = String(content[endRange.upperBound...])
        
        return beforeHeader + newHeader + afterHeader
    }
    
    // MARK: - Render Folder Header Block
    
    static func renderFolderHeaderBlock(fields: [String: String]) -> String {
        var lines: [String] = [folderHeaderStartMarker]
        
        for key in orderedKeys {
            if let value = fields[key], !value.isEmpty {
                lines.append("// \(key): \(value)")
            } else if key == "Signifier" {
                let signifier = fields["Signifier"] ?? "TODO"
                lines.append("// \(key): \(signifier)")
            } else {
                lines.append("// \(key): TODO_AGENT_FILL")
            }
        }
        
        lines.append(folderHeaderEndMarker)
        return lines.joined(separator: "\n")
    }
}

