#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

bundle_id="ai.tzafonhack.NorthstarTalk"
model_dir="${1:-models/Northstar-CUA-Fast-4bit}"

if [ ! -d "$model_dir" ]; then
  echo "missing model directory: $model_dir" >&2
  exit 1
fi

container="$(xcrun simctl get_app_container booted "$bundle_id" data)"
mkdir -p "$container/Documents"
rm -rf "$container/Documents/Northstar-CUA-Fast-4bit"
ditto "$model_dir" "$container/Documents/Northstar-CUA-Fast-4bit"
echo "installed to $container/Documents/Northstar-CUA-Fast-4bit"
