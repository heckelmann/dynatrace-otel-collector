# Tool management logic from:
# https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/820510e537167f621c857caaa0109f0dad021d74/Makefile.Common

BUILD_DIR = build
DIST_DIR = dist
BIN_DIR = bin

# SRC_ROOT is the top of the source tree.
SRC_ROOT := $(shell git rev-parse --show-toplevel)

# ALL_MODULES includes ./* dirs (excludes . dir)
ALL_MODULES := $(shell find . -type f -name "go.mod" -not -path "./build/*" -not -path "./internal/tools/*" -exec dirname {} \; | sort | grep -E '^./' )
# Append root module to all modules
GOMODULES = $(ALL_MODULES) $(PWD)

SOURCES := $(shell find confmap -type f | sort )


BIN = $(BIN_DIR)/dynatrace-otel-collector
MAIN = $(BUILD_DIR)/main.go

# Files to be copied directly from the project root
CP_FILES = LICENSE README.md
CP_FILES_DEST = $(addprefix $(BUILD_DIR)/, $(CP_FILES))

TOOLS_MOD_DIR    := $(SRC_ROOT)/internal/tools
TOOLS_MOD_REGEX  := "\s+_\s+\".*\""
TOOLS_PKG_NAMES  := $(shell grep -E $(TOOLS_MOD_REGEX) < $(TOOLS_MOD_DIR)/tools.go | tr -d " _\"")
TOOLS_BIN_DIR    := $(SRC_ROOT)/.tools
TOOLS_BIN_NAMES  := $(addprefix $(TOOLS_BIN_DIR)/, $(notdir $(TOOLS_PKG_NAMES)))

GORELEASER := $(TOOLS_BIN_DIR)/goreleaser
BUILDER    := $(TOOLS_BIN_DIR)/builder

.PHONY: build generate test clean clean-all components install-tools snapshot release
build: $(BIN)
build-all: .goreleaser.yaml $(GORELEASER) $(MAIN)
	$(GORELEASER) build --snapshot --clean
generate: $(MAIN) $(CP_FILES_DEST)
test: $(BIN)
	for MOD in $(GOMODULES); do \
		cd $${MOD}; \
		go test ./...; \
		cd -; \
	done
clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR) $(BIN_DIR)
clean-tools:
	rm -rf $(TOOLS_BIN_DIR)
clean-all: clean clean-tools
components: $(BIN)
	$(BIN) components
install-tools: $(TOOLS_BIN_NAMES)
snapshot: .goreleaser.yaml $(GORELEASER)
	$(GORELEASER) release --snapshot --clean
release: .goreleaser.yaml $(GORELEASER)
	$(GORELEASER) release --clean

$(TOOLS_BIN_DIR):
	mkdir -p $@

$(TOOLS_BIN_NAMES): $(TOOLS_MOD_DIR)/go.mod | $(TOOLS_BIN_DIR)
	cd $(TOOLS_MOD_DIR) && go build -o $@ -trimpath $(filter %/$(notdir $@),$(TOOLS_PKG_NAMES))

$(BIN): .goreleaser.yaml $(GORELEASER) $(MAIN) $(SOURCES)
	$(GORELEASER) build --single-target --snapshot --clean -o $(BIN)

$(MAIN): $(BUILDER) manifest.yaml
	$(BUILDER) --config manifest.yaml --skip-compilation

$(CP_FILES_DEST): $(MAIN)
	cp $(notdir $@) $@
