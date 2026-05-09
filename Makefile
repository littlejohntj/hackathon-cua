PROJECT := NorthstarTalk.xcodeproj
SCHEME := NorthstarTalk
CONFIG := Debug
DERIVED := DerivedData
APP := $(DERIVED)/Build/Products/$(CONFIG)-iphoneos/NorthstarTalk.app
MODEL_DIR := models/Northstar-CUA-Fast-4bit
MODEL_NAME := $(notdir $(MODEL_DIR))
GUIDE_SERVER_PORT ?= 17772

DEVICE ?= $(shell tmp=$$(mktemp); xcrun devicectl list devices --json-output $$tmp >/dev/null 2>&1; jq -r '.result.devices[] | select(.hardwareProperties.platform == "iOS" and .hardwareProperties.reality == "physical" and .connectionProperties.pairingState == "paired") | .hardwareProperties.udid' $$tmp 2>/dev/null | awk 'NF { print; exit }'; rm -f $$tmp)
XCODE_TEAM := $(shell defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null | sed -n 's/.*teamID = \([A-Z0-9]*\);.*/\1/p' | awk 'NF { print; exit }')
KEYCHAIN_TEAM := $(shell security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"Apple Development: .* (\([A-Z0-9]*\))".*/\1/p' | awk 'NF { print; exit }')
TEAM ?= $(or $(XCODE_TEAM),$(KEYCHAIN_TEAM))
BUNDLE_STEM ?= $(shell if [ -n "$(TEAM)" ]; then printf '%s' "$(TEAM)" | tr A-Z a-z; else whoami; fi)
BUNDLE_ID ?= com.$(BUNDLE_STEM).NorthstarTalk
SIGNING := $(if $(TEAM),DEVELOPMENT_TEAM=$(TEAM) CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates -allowProvisioningDeviceRegistration,)
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -destination id=$(DEVICE) -derivedDataPath $(DERIVED) BASE_BUNDLE_ID=$(BUNDLE_ID) $(SIGNING)

.PHONY: help devices generate build install launch run console syslog pull-debug-log pull-crashes collect-debug install-model run-with-model model guide-server open clean check-device check-model

help:
	@echo "make run                 build, install, launch on plugged-in iPhone"
	@echo "make guide-server        run laptop VLM server on port $(GUIDE_SERVER_PORT)"
	@echo "make install-model       copy $(MODEL_DIR) into app Documents (legacy on-device mode)"
	@echo "make run-with-model      install app/extensions, copy model, launch"
	@echo "make console             launch attached to device console"
	@echo "make syslog              stream device syslog for NorthstarTalk over USB"
	@echo "make collect-debug       pull app debug log and crash/jetsam reports into logs/"
	@echo "make devices             list devices"
	@echo "make model               convert/download Northstar to 4-bit MLX"
	@echo "Detected DEVICE=$(DEVICE)"
	@echo "Detected TEAM=$(TEAM)"
	@echo "Using BUNDLE_ID=$(BUNDLE_ID)"

devices:
	xcrun devicectl list devices

check-device:
	@test -n "$(DEVICE)" || (xcrun devicectl list devices; echo "No paired physical iPhone found. Set DEVICE=<udid>." >&2; exit 1)

check-model:
	@test -d "$(MODEL_DIR)" || (echo "Missing $(MODEL_DIR). Run: make model" >&2; exit 1)

generate:
	xcodegen generate

build: generate check-device
	$(XCODEBUILD) build

install: build
	xcrun devicectl device install app --device "$(DEVICE)" "$(APP)"

launch: check-device
	@set -e; \
	if ! xcrun devicectl device process launch --device "$(DEVICE)" --terminate-existing "$(BUNDLE_ID)"; then \
		echo "Launch failed; retrying once in 2s…"; \
		sleep 2; \
		xcrun devicectl device process launch --device "$(DEVICE)" --terminate-existing "$(BUNDLE_ID)" || \
		(echo "If iOS still says the profile is not trusted: Settings → General → VPN & Device Management → Apple Development → Trust." >&2; exit 1); \
	fi

run: install launch

console: install
	xcrun devicectl device process launch --device "$(DEVICE)" --terminate-existing --console "$(BUNDLE_ID)"

syslog: check-device
	idevicesyslog -u "$(DEVICE)" --no-colors | awk '/NorthstarTalk|NorthstarFrameUpload|Northstar/ { print; fflush(); }'

pull-debug-log: check-device
	@mkdir -p logs/device
	-xcrun devicectl --timeout 60 device copy from --device "$(DEVICE)" --domain-type appDataContainer --domain-identifier "$(BUNDLE_ID)" --source Documents/northstar-debug.log --destination logs/device/northstar-debug.log
	@echo "App debug log: logs/device/northstar-debug.log"

pull-crashes: check-device
	@mkdir -p logs/crashes
	@tmp=$$(mktemp); xcrun devicectl --timeout 60 device info files --device "$(DEVICE)" --domain-type systemCrashLogs --json-output "$$tmp" >/dev/null; jq -r '.. | objects | (.name? // empty) | select(test("(^|/)(NorthstarTalk-|JetsamEvent-)"))' "$$tmp" | while IFS= read -r f; do mkdir -p "logs/crashes/$$(dirname "$$f")"; xcrun devicectl --timeout 60 device copy from --device "$(DEVICE)" --domain-type systemCrashLogs --source "$$f" --destination "logs/crashes/$$f" >/dev/null 2>&1 || true; done; rm -f "$$tmp"
	@echo "Crash/jetsam reports: logs/crashes/"

collect-debug: pull-debug-log pull-crashes

install-model: install check-model
	@echo "Copying $(MODEL_DIR) to the app as Documents/$(MODEL_NAME) (about 3.1 GB)…"
	@tmp=$$(mktemp -d); mkdir -p "$$tmp/$(MODEL_NAME)"; xcrun devicectl --timeout 120 device copy to --device "$(DEVICE)" --domain-type appDataContainer --domain-identifier "$(BUNDLE_ID)" --source "$$tmp/$(MODEL_NAME)" --destination "Documents/$(MODEL_NAME)" --remove-existing-content true >/dev/null 2>&1 || true; rm -rf "$$tmp"
	xcrun devicectl --timeout 3600 device copy to --device "$(DEVICE)" --domain-type appDataContainer --domain-identifier "$(BUNDLE_ID)" --source "$(MODEL_DIR)" --destination "Documents/$(MODEL_NAME)" --remove-existing-content true

run-with-model: install-model launch

model:
	./scripts/convert_northstar_to_mlx.sh

guide-server: check-model
	@mkdir -p logs
	@echo "Mac LAN IPs:"; ifconfig | awk '/inet / && $$2 !~ /^127\./ { print "  " $$2 }'
	uv run --with mlx-vlm --with pillow NorthstarGuideServer/server.py --model "$(MODEL_DIR)" --port $(GUIDE_SERVER_PORT)

open: generate
	open "$(PROJECT)"

clean:
	rm -rf "$(DERIVED)"
