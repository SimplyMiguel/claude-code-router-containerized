clear

cat > .ccr_config.json <<'EOF'
{
  "LOG": true,
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
        "use": [
          "openrouter"
        ],
        "moonshotai/kimi-k2-0905": {
          "use": [
            [
              "openrouter",
              {
                "provider": {
                  "sort": "price",
                  "ignore": [
                    "baseten/fp4",
                    "moonshotai/turbo",
                    "moonshotai"
                  ]
                }
              }
            ]
          ]
        },
        "z-ai/glm-4.5": {
          "use": [
            [
              "openrouter",
              {
                "provider": {
                  "sort": "throughput"
                }
              }
            ]
          ]
        },
        "z-ai/glm-4.5-air": {
          "use": [
            [
              "openrouter",
              {
                "provider": {
                  "sort": "throughput"
                }
              }
            ]
          ]
        },
        "qwen/qwen3-coder": {
          "use": [
            [
              "openrouter",
              {
                "provider": {
                  "sort": "throughput",
                  "ignore": [
                    "deepinfra/fp4",
                    "google-vertex"
                  ]
                }
              }
            ]
          ]
        },
        "openai/gpt-5": {
          "use": [
            [
              "openrouter",
              {
                "reasoning": {
                  "effort": "medium",
                  "enabled": true
                }
              }
            ]
          ]
        },
        "google/gemini-2.5-flash-lite": {
          "use": [
            [
              "openrouter",
              {
                "reasoning": {
                  "effort": "high",
                  "enabled": true
                }
              }
            ]
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
CONFIG_VOL="ccr-config-$PROJ"
DATA_VOL="ccr-data-$PROJ"
CACHE_VOL="ccr-cache-$PROJ"
IMAGE="nezhar/claude-container:latest"

# If container exists
if docker ps -a --format '{{.Names}}' | grep -q "^$NAME$"; then
  # If running, open CCR in it; else start and attach
  if docker ps --format '{{.Names}}' | grep -q "^$NAME$"; then
    docker exec -it "$NAME" /bin/sh -lc "ccr code"
  else
    docker start -ai "$NAME"
  fi
else
  # First run: create named container with persistent volumes and seed config
  docker run -it --name "$NAME" \
    -v "$(pwd):/workspace" \
    -v "$CONFIG_VOL:/root/.claude-code-router" \
    -v "$DATA_VOL:/root/.local/share/claude-code-router" \
    -v "$CACHE_VOL:/root/.cache/claude-code-router" \
    "$IMAGE" /bin/sh -lc "npm install -g @musistudio/claude-code-router && mkdir -p /root/.claude-code-router && cp /workspace/.ccr_config.json /root/.claude-code-router/config.json && ccr restart && ccr code"
fi
