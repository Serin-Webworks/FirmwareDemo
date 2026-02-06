NAME := serin-firmware-demo
VERSION := $(strip $(shell cat VERSION))
DIST := dist
BUILD := .build
BIN := $(DIST)/$(NAME)-v$(VERSION).bin
GEN := $(BUILD)/firmware_gen
PAYLOAD_LEN := 4096

CC ?= cc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Werror

SHA256_CMD := $(shell if command -v sha256sum >/dev/null 2>&1; then echo "sha256sum"; else echo "shasum -a 256"; fi)

.PHONY: build clean manifest checksum release

$(GEN): src/main.c | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $<

$(BUILD):
	mkdir -p $(BUILD)

$(DIST):
	mkdir -p $(DIST)

build: $(GEN) | $(DIST)
	@set -e; \
	BUILD_TS=$$(date -u +\"%Y-%m-%dT%H:%M:%SZ\"); \
	GIT_HASH=$$(git rev-parse --short HEAD 2>/dev/null || echo \"unknown\"); \
	VERSION=$(VERSION); \
	PAYLOAD_LEN=$(PAYLOAD_LEN); \
	OUTPUT=$(BIN); \
	VERSION=$$VERSION BUILD_TS=$$BUILD_TS GIT_HASH=$$GIT_HASH PAYLOAD_LEN=$$PAYLOAD_LEN OUTPUT=$$OUTPUT ./$(GEN); \
	echo $$VERSION > $(DIST)/version.txt; \
	echo $$BUILD_TS > $(DIST)/build_timestamp.txt; \
	echo $$GIT_HASH > $(DIST)/git_hash.txt; \
	echo $$PAYLOAD_LEN > $(DIST)/payload_len.txt

manifest: build
	@SIZE=$$(wc -c < $(BIN) | tr -d ' '); \
	SHA=$$($(SHA256_CMD) $(BIN) | awk '{print $$1}'); \
	BUILD_TS=$$(cat $(DIST)/build_timestamp.txt); \
	GIT_HASH=$$(cat $(DIST)/git_hash.txt); \
	PAYLOAD_LEN=$$(cat $(DIST)/payload_len.txt); \
	printf '{\n' > $(DIST)/manifest.json; \
	printf '  "name": "%s",\n' "$(NAME)" >> $(DIST)/manifest.json; \
	printf '  "version": "%s",\n' "$(VERSION)" >> $(DIST)/manifest.json; \
	printf '  "build_timestamp_utc": "%s",\n' "$$BUILD_TS" >> $(DIST)/manifest.json; \
	printf '  "git_commit": "%s",\n' "$$GIT_HASH" >> $(DIST)/manifest.json; \
	printf '  "payload_length": %s,\n' "$$PAYLOAD_LEN" >> $(DIST)/manifest.json; \
	printf '  "firmware_file": "%s",\n' "$(notdir $(BIN))" >> $(DIST)/manifest.json; \
	printf '  "firmware_size_bytes": %s,\n' "$$SIZE" >> $(DIST)/manifest.json; \
	printf '  "sha256": "%s"\n' "$$SHA" >> $(DIST)/manifest.json; \
	printf '}\n' >> $(DIST)/manifest.json

checksum: build
	@$(SHA256_CMD) $(BIN) > $(DIST)/checksums.txt

release: build manifest checksum
	@echo "Release artifacts ready in $(DIST)"

clean:
	rm -rf $(BUILD) $(DIST)
