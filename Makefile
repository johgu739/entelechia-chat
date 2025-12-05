.PHONY: ontology

APP_ROOT := $(CURDIR)/entelechia-chat

# Run ontology scan safely with local HOME/cache to avoid permission issues
ontology:
	@cd "$(APP_ROOT)" && HOME=$$(PWD)/.tmp_home SWIFT_MODULE_CACHE_PATH=$$(PWD)/.swift_module_cache ./Scripts/generateOntology.swift
