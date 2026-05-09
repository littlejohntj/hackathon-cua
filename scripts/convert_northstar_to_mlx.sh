#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p models
HF_HUB_ENABLE_HF_TRANSFER=1 uv run --with mlx-vlm --with hf_transfer \
  mlx_vlm.convert \
  --hf-path Tzafon/Northstar-CUA-Fast \
  --mlx-path models/Northstar-CUA-Fast-4bit \
  --quantize \
  --q-bits 4 \
  --q-group-size 64
