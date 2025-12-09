.PHONY: ontology ontology-validate ontology-rename lint-guards

# Run ontology generator
ontology:
	swift run --package-path Tools/OntologyGenerator entelechia-ontology .

# Run validation only
ontology-validate:
	swift run --package-path Tools/OntologyGenerator entelechia-ontology --validate-only .

# Apply renames (placeholder - not implemented yet)
ontology-rename:
	swift run --package-path Tools/OntologyGenerator entelechia-ontology --apply-renames .

# Run guard checks for unchecked sendable and blocking primitives
lint-guards:
	bash Tools/lint-guards.sh

# Run all package test suites in deterministic order
workspace-test:
	bash scripts/workspace-test.sh
