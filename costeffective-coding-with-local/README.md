# costeffective-coding-with-local

![Recipe plan and apply output](assets/image.png)

Graduated CodeFreedom recipe — a universal configuration for coding with a mix of cloud and local inference providers.

## Quick start

```bash
# 1. Plan — preview what will be installed (recommended before first run)
cf init recipe --plan costeffective-coding-with-local

# 2. Apply — writes config files + creates mountable directories
cf init recipe --apply <plan-id>

# 3. Fix permissions (Linux/WSL only)
sudo chown -R $(id -u):$(id -g) ~/.codefreedom

# 4. Start the proxy — auto-starts tools (Chrome, Web, GitHub, Web-bridge)
cf px start

# 5. Verify the proxy is running
curl http://localhost:4000/health/readiness

# 6. Launch Claude Code
cf cc
```

**Outcome:** After step 6, Claude Code connects through the local LiteLLM proxy, which routes requests to whichever providers have API keys set. Tools (Chrome browser automation, Camoufox web search, GitHub MCP, SearXNG web bridge) start automatically alongside the proxy.

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

`_default` — inherits shared profiles, compose, and base proxy config.

## Required secrets

| Variable | Prompt |
|---|---|
| `LITELLM_MASTER_KEY` | LiteLLM proxy admin key (default: `sk-codefreedom-local`) |
| `DEEPSEEK_API_KEY` | DeepSeek API — [platform.deepseek.com](https://platform.deepseek.com/api_keys) |
| `MICROSOFT_FOUNDRY_API_KEY` | Azure AI Foundry — set in Foundry portal |
| `NVIDIA_API_KEY` | NVIDIA AI Endpoints — [build.nvidia.com](https://build.nvidia.com) |
| `OPENCODE_ZEN_API_KEY` | OpenCode Zen — OpenCode dashboard |

Secrets are prompted interactively during `cf init recipe`. To skip prompts, set them in `~/.codefreedom/.env.user` or export as environment variables.

## Optional config

| Variable | Default | Description |
|---|---|---|
| `LITELLM_MODEL_ALIAS_BEST` | `DeepSeek/DeepSeek-V4-Pro` | Primary coding model |
| `LITELLM_MODEL_ALIAS_FABLE` | `DeepSeek/DeepSeek-V4-Pro` | Reasoning model |
| `LITELLM_MODEL_ALIAS_SONNET` | `DGX/Qwen3.6-27B` | Local Sonnet-equivalent |
| `LITELLM_MODEL_ALIAS_OPUS` | `DeepSeek/DeepSeek-V4-Pro` | Opus-equivalent |
| `LITELLM_MODEL_ALIAS_HAIKU` | `DGX/Qwen3.6-35B-A3B` | Fast/lightweight |
| `LITELLM_MODEL_ALIAS_SONNET_1M` | `DGX/Qwen3.6-27B` | 1M context Sonnet |
| `LITELLM_MODEL_ALIAS_OPUS_1M` | `DeepSeek/DeepSeek-V4-Pro` | 1M context Opus |
| `LITELLM_MODEL_ALIAS_OPUSPLAN` | `DeepSeek/DeepSeek-V4-Pro` | Planning model |

Override any alias in `~/.codefreedom/.env.user`:
```
LITELLM_MODEL_ALIAS_BEST=my-custom-model
```

## Commands

| Command | Outcome |
|---|---|
| `cf init recipe --plan costeffective-coding-with-local` | Generates a plan: shows what files would be created/replaced, previews diffs, lists dirs to create |
| `cf init recipe --apply <plan-id>` | Writes config files to `~/.codefreedom/`, creates `pg/data` and `pg/backup` mount dirs, prints permission advice |
| `cf init recipe costeffective-coding-with-local` | Same as plan+apply in one step — fetches and applies immediately |
| `cf px start` | Starts LiteLLM proxy + embedded PostgreSQL + all tools (Chrome, Web, GitHub, Web-bridge) |
| `cf px status` | Shows proxy health |
| `cf px stop` | Stops proxy + tools |
| `sudo chown -R $(id -u):$(id -g) ~/.codefreedom` | Fixes file ownership (Linux/WSL only — needed when container user UID differs from host UID) |
| `cf cc` | Launches Claude Code with the configured profile |

## Staging

To test unreleased changes from the `staging` branch:

```bash
cf init recipe --plan costeffective-coding-with-local --staging
cf init recipe --apply <plan-id> --staging
```
