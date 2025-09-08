#!/usr/bin/env bash
set -euo pipefail
clear

# 1) Generate CCR config from project (custom models/endpoints supported here)
cat > .ccr_config.json <<'EOF'
{
  "API_TIMEOUT_MS": 600000,
  "Providers": [
    {
      "name": "Openrouter",
      "api_base_url": "https://openrouter.ai/api/v1/chat/completions",
      "api_key": ${OPENROUTER_API_KEY},
      "models": [
        "moonshotai/kimi-k2-0905",
        "z-ai/glm-4.5",
        "z-ai/glm-4.5-air",
        "qwen/qwen3-coder",
        "openai/gpt-5",
        "google/gemini-2.5-flash-lite"
      ],
      "transformer": {
        "use": ["openrouter"],
        "moonshotai/kimi-k2-0905": {
          "use": [
            ["openrouter", { "provider": { "sort": "price", "ignore": ["baseten/fp4","moonshotai/turbo","moonshotai"] } }]
          ]
        },
        "z-ai/glm-4.5": {
          "use": [
            ["openrouter", { "provider": { "sort": "throughput" } }]
          ]
        },
        "z-ai/glm-4.5-air": {
          "use": [
            ["openrouter", { "provider": { "sort": "throughput" } }]
          ]
        },
        "qwen/qwen3-coder": {
          "use": [
            ["openrouter", { "provider": { "sort": "throughput", "ignore": ["deepinfra/fp4","google-vertex"] } }]
          ]
        },
        "openai/gpt-5": {
          "use": [
            ["openrouter", { "reasoning": { "effort": "medium", "enabled": true } }]
          ]
        },
        "google/gemini-2.5-flash-lite": {
          "use": [
            ["openrouter", { "reasoning": { "effort": "high", "enabled": true } }]
          ]
        }
      }
    }
  ],
  "Router": {
    "default": "Openrouter,moonshotai/kimi-k2-0905",
    "thinking": "Openrouter,openai/gpt-5",
    "background": "Openrouter,qwen/qwen3-coder",
    "webSearch": "Openrouter,google/gemini-2.5-flash-lite:online"
  }
}
EOF

PROJ=$(basename "$(pwd)")
NAME="ccr-$PROJ"

# Named volumes (kept for potential future use; not mounted to avoid duplicate targets)
CONFIG_VOL="ccr-config-$PROJ"
DATA_VOL="ccr-data-$PROJ"
CACHE_VOL="ccr-cache-$PROJ"

# Project-local persistence directories (source of truth for chats/config/cache)
LOCAL_STATE_DIR="$PWD/.ccr_state"
LOCAL_CFG_DIR="$LOCAL_STATE_DIR/config"
LOCAL_DATA_DIR="$LOCAL_STATE_DIR/data"
LOCAL_CACHE_DIR="$LOCAL_STATE_DIR/cache"

mkdir -p "$LOCAL_CFG_DIR" "$LOCAL_DATA_DIR" "$LOCAL_CACHE_DIR"

IMAGE="nezhar/claude-container:latest"
# Uncomment to match Apple Silicon platform and silence warning:
# PLATFORM_FLAG="--platform=linux/arm64/v8"
PLATFORM_FLAG="${PLATFORM_FLAG:-}"

# Common docker run args: bind mounts only (no duplicate mount points)
DOCKER_MOUNTS=(
  -v "$(pwd):/workspace"
  -v "$LOCAL_CFG_DIR:/root/.claude-code-router"
  -v "$LOCAL_DATA_DIR:/root/.local/share/claude-code-router"
  -v "$LOCAL_CACHE_DIR:/root/.cache/claude-code-router"
)

start_container() {
  docker run -it --name "$NAME" $PLATFORM_FLAG \
    "${DOCKER_MOUNTS[@]}" \
    --entrypoint /bin/sh \
    "$IMAGE" -lc "set -e; \
      mkdir -p \
        /root/.claude-code-router \
        /root/.local/share/claude-code-router \
        /root/.cache/claude-code-router \
        /root/.config && \
      cp -f /workspace/.ccr_config.json /root/.claude-code-router/config.json && \
      npm install -g @musistudio/claude-code-router && \
      ccr code"
}

# If container exists
if docker ps -a --format '{{.Names}}' | grep -q "^$NAME$"; then
  if docker ps --format '{{.Names}}' | grep -q "^$NAME$"; then
    # Container is running, just attach to it
    docker exec -it "$NAME" /bin/sh -lc "set -e; ccr code"
  else
    # Container exists but stopped, restart it
    docker start -ai "$NAME"
  fi
else
  # Container doesn't exist, create it
  start_container
fi
