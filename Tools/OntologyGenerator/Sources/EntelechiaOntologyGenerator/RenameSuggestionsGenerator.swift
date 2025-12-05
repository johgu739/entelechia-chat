// @EntelechiaHeaderStart
// Signifier: RenameSuggestionsGenerator
// Substance: Rename suggestion generation
// Genus: Ontology analyzer
// Differentia: Generates canonical filename suggestions based on ontology
// Form: Analysis and suggestion rules
// Matter: File headers; current filenames
// Powers: Analyze headers; suggest canonical names; compute confidence
// FinalCause: Propose metaphysically-correct file names
// Relations: Used by main.swift; uses HeaderParser
// CausalityType: Efficient
// @EntelechiaHeaderEnd

import Foundation

struct RenameSuggestionsGenerator {
    struct RenameSuggestion {
        let currentPath: String
        let currentName: String
        let signifier: String
        let genus: String?
        let differentia: String?
        let proposedName: String
        let confidence: String // "HIGH", "MEDIUM", "LOW"
        let reason: String
    }
    
    /// Generate rename suggestions for all files
    static func generateSuggestions(swiftFiles: [URL]) -> [RenameSuggestion] {
        var suggestions: [RenameSuggestion] = []
        
        for fileURL in swiftFiles {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8),
                  let header = HeaderParser.parseHeader(from: content) else {
                continue
            }
            
            let signifier = header["Signifier"] ?? fileURL.deletingPathExtension().lastPathComponent
            let genus = header["Genus"]
            let differentia = header["Differentia"]
            let currentName = fileURL.deletingPathExtension().lastPathComponent
            
            // Generate canonical name: Signifier__Genus__Differentia.swift
            let canonicalName = generateCanonicalName(signifier: signifier, genus: genus, differentia: differentia)
            
            var confidence = "LOW"
            var reason = "Missing semantic fields"
            
            if genus != nil && !genus!.isEmpty && differentia != nil && !differentia!.isEmpty {
                if !genus!.contains("TODO") && !differentia!.contains("TODO") {
                    confidence = "HIGH"
                    reason = "All required fields present"
                } else {
                    confidence = "MEDIUM"
                    reason = "Some fields contain TODO markers"
                }
            }
            
            if canonicalName != currentName {
                suggestions.append(RenameSuggestion(
                    currentPath: fileURL.path,
                    currentName: currentName,
                    signifier: signifier,
                    genus: genus,
                    differentia: differentia,
                    proposedName: canonicalName,
                    confidence: confidence,
                    reason: reason
                ))
            }
        }
        
        return suggestions
    }
    
    /// Generate canonical filename from ontology fields
    private static func generateCanonicalName(signifier: String, genus: String?, differentia: String?) -> String {
        var parts: [String] = [signifier]
        
        if let genus = genus, !genus.isEmpty, !genus.contains("TODO") {
            let sanitizedGenus = sanitizeForFilename(genus)
            parts.append(sanitizedGenus)
        }
        
        if let differentia = differentia, !differentia.isEmpty, !differentia.contains("TODO") {
            let sanitizedDifferentia = sanitizeForFilename(differentia)
            parts.append(sanitizedDifferentia)
        }
        
        return parts.joined(separator: "__") + ".swift"
    }
    
    /// Sanitize string for use in filename
    private static func sanitizeForFilename(_ str: String) -> String {
        return str
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "\\", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ";", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
    }
}

