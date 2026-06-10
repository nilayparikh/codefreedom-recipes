# costeffective-coding-with-local

Graduated CodeFreedom recipe — a universal configuration for coding with a mix of cloud and local inference providers.

## Quick start

```
# 1. Preview what will be installed
cf init recipe --plan costeffective-coding-with-local

# 2. Apply the plan
cf init recipe --apply <plan_id>

# 3. Fix ownership (Linux/WSL only)
sudo chown -R $(id -u):$(id -g) ~/.codefreedom

# 4. Start the proxy — auto-starts Chrome, Web, GitHub, Web-bridge
cf px start
```

Steps 1–2 write config files (`~/.codefreedom/.env.*`, profiles, compose, providers)
and create `pg/data` + `pg/backup` mount directories for embedded PostgreSQL.
Step 3 fixes file ownership when the container user UID differs from your host UID.
Step 4 starts the LiteLLM proxy on port 4000 with all tools.

![Recipe plan and apply output](assets/image.png)

## What it provides

| Layer                  | Files                                                                           |
| ---------------------- | ------------------------------------------------------------------------------- |
| **Claude Code config** | `.env.claude`, `.env.claude.secrets`                                            |
| **Proxy config**       | `.env.proxy`, `.env.proxy.secrets`                                              |
| **Profiles**           | `claude-code.yaml`, `chrome.yaml`, `web.yaml`, `github.yaml`, `web-bridge.yaml` |
| **Proxy compose**      | `docker-compose.yaml` with embedded PostgreSQL                                  |
| **Proxy config**       | `config.yaml` with LiteLLM routing                                              |
| **Plugins**            | Reasoning-efforts mapping (full rule library)                                   |
| **Providers**          | DeepSeek, Azure Foundry, OpenCode, Command Code, Local                          |
| **Mount dirs**         | `pg/data`, `pg/backup` (embedded PostgreSQL host volumes)                       |

## Extends

`_default` — inherits shared profiles, compose, base proxy config, and tool profiles.

## Provider API keys

Each provider config reads its key from an env var. Set the ones you want to use.
Unset providers are skipped automatically by LiteLLM.

| Provider config         | Key env var                 | Default in `.env.proxy`                                           |
| ----------------------- | --------------------------- | ----------------------------------------------------------------- |
| **DeepSeek**            | `DEEPSEEK_API_KEY`          | `api_base`: `https://api.deepseek.com`                            |
| **Azure Foundry**       | `MICROSOFT_FOUNDRY_API_KEY` | `api_base`: `https://ergox-ca-resource.services.ai.azure.com/...` |
| **OpenCode Zen**        | `OPENCODE_ZEN_API_KEY`      | `api_base`: `https://opencode.ai/zen/v1`                          |
| **Command Code**        | `COMMAND_CODE_API_KEY`      | `api_base`: `https://api.commandcode.ai/provider/v1/`             |
| **Local M** (port 8000) | `LOCAL_M_API_KEY`           | `sk-dummy` (any value works)                                      |
| **Local S** (port 8001) | `LOCAL_S_API_KEY`           | `sk-dummy` (any value works)                                      |

The proxy auth key `LITELLM_MASTER_KEY` defaults to `sk-codefreedom-local` and
is used as `ANTHROPIC_AUTH_TOKEN` by Claude Code. Set in `.env.secrets` or
`.env.user` only if you want a different value.

Set any key in `~/.codefreedom/.env.secrets` or export as an env var.

> **Note:** This recipe does **not** ship an NVIDIA provider config (`providers/nvidia.yaml` is not included in `config.yaml`). The `NVIDIA_API_KEY` variable in `.env.proxy.secrets` is a template placeholder — it has no effect unless you add your own provider file.

## Installed model aliases

These are the actual values written to `~/.codefreedom/.env.proxy` by the recipe. Override any in `~/.codefreedom/.env.user`.

| Variable                        | Installed value              | Routes to                                      |
| ------------------------------- | ---------------------------- | ---------------------------------------------- |
| `LITELLM_MODEL_ALIAS_BEST`      | `OpenCode/Qwen3.7-Max`       | Primary coding                                 |
| `LITELLM_MODEL_ALIAS_FABLE`     | `OpenCode/Qwen3.7-Max`       | Hard reasoning                                 |
| `LITELLM_MODEL_ALIAS_SONNET`    | `OpenCode/DeepSeek-V4-Flash` | Daily coding                                   |
| `LITELLM_MODEL_ALIAS_OPUS`      | `DeepSeek/DeepSeek-V4-Pro`   | Complex reasoning                              |
| `LITELLM_MODEL_ALIAS_HAIKU`     | `DGX/Qwen3.6-35B-A3B`        | Fast / lightweight                             |
| `LITELLM_MODEL_ALIAS_SONNET_1M` | `OpenCode/DeepSeek-V4-Flash` | 1M context, daily coding                       |
| `LITELLM_MODEL_ALIAS_OPUS_1M`   | `DeepSeek/DeepSeek-V4-Pro`   | 1M context, complex reasoning                  |
| `LITELLM_MODEL_ALIAS_OPUSPLAN`  | `DeepSeek/DeepSeek-V4-Pro`   | Plan mode (opus), execution switches to sonnet |
| `LITELLM_MODEL_ALIAS_CUSTOM`    | `DGX/Qwen3.6-27B`            | Custom model slot                              |

Override example — `~/.codefreedom/.env.user`:

```
LITELLM_MODEL_ALIAS_BEST=my-custom-model
```

## Proxy environment

Key settings written to `~/.codefreedom/.env.proxy`:

| Variable                      | Value                                     | Purpose                                    |
| ----------------------------- | ----------------------------------------- | ------------------------------------------ |
| `LITELLM_IMAGE`               | `nilayparikh/codefreedom:litellm-latest`  | Proxy container image                      |
| `LITELLM_PORT`                | `4000`                                    | Proxy listen port                          |
| `LITELLM_DROP_PARAMS`         | `true`                                    | Strip unsupported params before forwarding |
| `LITELLM_STREAM_USAGE`        | `true`                                    | Emit token usage in streaming responses    |
| `DEEPSEEK_BASE_URL`           | `https://api.deepseek.com`                | DeepSeek API endpoint                      |
| `MICROSOFT_FOUNDRY_API_BASE`  | `https://ergox-ca-resource.../openai/v1`  | Azure AI Foundry endpoint                  |
| `OPENCODE_ZEN_BASE_URL`       | `https://opencode.ai/zen/v1`              | OpenCode Zen API                           |
| `OPENCODE_GO_BASE_URL`        | `https://opencode.ai/zen/go/v1`           | OpenCode GO API                            |
| `COMMAND_CODE_BASE_URL`       | `https://api.commandcode.ai/provider/v1/` | Command Code API                           |
| `LOCAL_M_BASE_URL`            | `http://host.docker.internal:8000/v1`     | Local primary backend                      |
| `LOCAL_S_BASE_URL`            | `http://host.docker.internal:8001/v1`     | Local secondary backend                    |
| `WEB_BRIDGE_COOLDOWN_SECONDS` | `2.0`                                     | Web search rate-limit cooldown             |
| `MCP_TIMEOUT_SECONDS`         | `60`                                      | Web search MCP timeout                     |

## Claude Code profile

The recipe's `claude-code.yaml` configures Claude Code to:

- Route through the local proxy (`ANTHROPIC_BASE_URL=http://localhost:4000`)
- Authenticate with `ANTHROPIC_AUTH_TOKEN` = the `LITELLM_MASTER_KEY` value
- Register all model aliases (`fable`, `sonnet`, `opus`, `haiku`, `custom`) so Claude Code knows which models are available
- Auto-start tools: Chrome, Web, GitHub
- Disable non-essential traffic, telemetry, and auto-installs

## Commands

| Command                                                 | Outcome                                                                      |
| ------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `cf init recipe --plan costeffective-coding-with-local` | Preview: shows files to create/replace with diffs and dirs to create         |
| `cf init recipe --apply <plan-id>`                      | Apply: writes config files, creates `pg/data` and `pg/backup` mount dirs     |
| `cf px start`                                           | Starts proxy + embedded PostgreSQL + tools (Chrome, Web, GitHub, Web-bridge) |
| `cf px status`                                          | Proxy health check                                                           |
| `cf px stop`                                            | Stop proxy and tools                                                         |
| `sudo chown -R $(id -u):$(id -g) ~/.codefreedom`        | Fix ownership (Linux/WSL — needed when container user UID != host UID)       |
| `cf cc`                                                 | Launch Claude Code with configured profile                                   |
