.PHONY: ontology ontology-validate ontology-rename

# Run ontology generator
ontology:
	swift run --package-path Tools/OntologyGenerator entelechia-ontology .

# Run validation only
ontology-validate:
	swift run --package-path Tools/OntologyGenerator entelechia-ontology --validate-only .

# Apply renames (placeholder - not implemented yet)
ontology-rename:
	swift run --package-path Tools/OntologyGenerator entelechia-ontology --apply-renames .
