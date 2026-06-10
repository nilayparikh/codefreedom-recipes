# costeffective-coding-with-local

> A CodeFreedom recipe that routes Claude Code through a mix of cloud providers
> and local inference -- minimizing cost while maximizing flexibility.

## Overview

This recipe installs a complete CodeFreedom configuration for coding with cloud
providers alongside self-hosted local models:

- **LiteLLM proxy** on port 4000 routing model aliases to 5 provider backends
- **4 tool containers** (Chrome, Web, GitHub, Web-bridge) for browser automation,
  web search, and repository access
- **Embedded PostgreSQL** for LiteLLM spend tracking and Admin UI
- **Local model fallback** -- self-hosted inference on ports 8000/8001 for
  offline or zero-cost coding

Model aliases (`fable`, `sonnet`, `opus`, `haiku`) are mapped to the cheapest
capable provider. Context windows that exceed local model limits fall back to
cloud automatically.

### Who is this for?

- Developers who want **multiple provider options** (DeepSeek, Azure, OpenCode,
  Command Code, local) without reconfiguring
- Teams optimizing for **cost-to-capability ratio** -- cheap daily drivers,
  expensive models for hard tasks
- Users who self-host local models (vLLM, Ollama, SGLang) and want them as
  a drop-in backend

---

## Prerequisites

Before starting, make sure you have:

- **Docker** with Compose V2 (`docker compose` command available)
- **CodeFreedom CLI** installed -- `pip install codefreedom` or from source
- API key accounts for at least one cloud provider (see table below)
- Port 4000 free for the proxy; ports 8000/8001 if using local backends
- ~2 GB free disk space for Docker images (one-time pull)

---

## Quick start

```bash
# 1. Preview what will be installed
cf init recipe --plan costeffective-coding-with-local

# 2. Apply the plan (you will be prompted for API keys)
cf init recipe --apply <plan_id>

# 3. Fix ownership (Linux/WSL only)
sudo chown -R $(id -u):$(id -g) ~/.codefreedom

# 4. Start the proxy -- auto-starts Chrome, Web, GitHub, Web-bridge
cf px start

# 5. Launch Claude Code
cf cc
```

Step 1 shows every file the recipe will create, along with a diff preview.
Step 2 writes config files and creates `pg/data` + `pg/backup` mount directories
for embedded PostgreSQL. During this step you will be prompted for API keys.
Step 3 fixes file ownership when the container user UID differs from your host
UID (Docker on Linux). Step 4 starts the LiteLLM proxy on port 4000 and all
tool containers. Step 5 launches Claude Code with the configured profile.

![Recipe plan and apply output](assets/image.png)

### Staging flag

If you are on the `recipe-branch` branch (unstable recipes), add `--staging`
to the plan command:

```bash
cf init recipe --staging --plan costeffective-coding-with-local
```

---

## Secrets flow

When you run `--plan`, the recipe engine prompts for each required secret:

| Secret                       | Prompt                                    | Default                   |
| ---------------------------- | ----------------------------------------- | ------------------------- |
| `LITELLM_MASTER_KEY`         | LiteLLM proxy master key                  | `sk-codefreedom-local`    |
| `DEEPSEEK_API_KEY`           | DeepSeek API key                          | (empty -- must provide)   |
| `MICROSOFT_FOUNDRY_API_KEY`  | Microsoft Foundry API key                 | (empty -- must provide)   |
| `NVIDIA_API_KEY`             | NVIDIA API key (template only, see note)  | (empty -- unused)         |
| `OPENCODE_ZEN_API_KEY`       | OpenCode Zen API key                      | (empty -- must provide)   |

Keys are written to `~/.codefreedom/.env.proxy.secrets`. Leave a key empty to
skip that provider -- LiteLLM will not load its config.

> **NVIDIA note:** The `NVIDIA_API_KEY` prompt exists in the recipe `required_secrets`
> list, but this recipe does **not** ship an NVIDIA provider config. Setting the key
> has no effect unless you add your own `providers/nvidia.yaml` to `config.yaml`.
> This is a template artifact from the parent recipe.

---

## Architecture

```
                           Claude Code (cf cc)
                                  |
                    ANTHROPIC_BASE_URL = http://localhost:4000
                                  |
                     LiteLLM Proxy (:4000)
                     /    |    |    |    \
                    /     |    |    |     \
             DeepSeek  Azure  OpenCode  Cmd  Local
             (cloud)  (cloud) (cloud)  (cloud) (:8000/8001)

    Tools (auto-started with proxy):
      Chrome (:9222)   Web (:8420)   GitHub (:8129)   Web-bridge (:8500)

    PostgreSQL (embedded in proxy container):
      Spend tracking + Admin UI at http://localhost:4000/ui
```

### Routing logic

1. Claude Code sends a request with a model alias (`sonnet`, `opus`, etc.)
2. LiteLLM resolves the alias to a model group (e.g. `sonnet` -> `OpenCode/DeepSeek-V4-Flash`)
3. LiteLLM load-balances across provider models in that group
4. If context exceeds the selected model's limit, the configured fallback kicks in
   (`DGX/Qwen3.6-27B` falls back to `opus` for cloud overflow)

---

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

---

## Provider API keys

Each provider config reads its key from an environment variable. Set the ones
you want to use. Unset providers are skipped automatically by LiteLLM.

| Provider config         | Key env var                 | Default endpoint                                                     |
| ----------------------- | --------------------------- | -------------------------------------------------------------------- |
| **DeepSeek**            | `DEEPSEEK_API_KEY`          | `https://api.deepseek.com`                                           |
| **Azure Foundry**       | `MICROSOFT_FOUNDRY_API_KEY` | `https://ergox-ca-resource.services.ai.azure.com/openai/v1`         |
| **OpenCode Zen**        | `OPENCODE_ZEN_API_KEY`      | `https://opencode.ai/zen/v1`                                        |
| **OpenCode GO**         | `OPENCODE_ZEN_API_KEY`      | `https://opencode.ai/zen/go/v1`                                     |
| **Command Code**        | `COMMAND_CODE_API_KEY`      | `https://api.commandcode.ai/provider/v1/`                           |
| **Local M** (port 8000) | `LOCAL_M_API_KEY`           | `http://host.docker.internal:8000/v1` (any key value works)          |
| **Local S** (port 8001) | `LOCAL_S_API_KEY`           | `http://host.docker.internal:8001/v1` (any key value works)          |

Set keys in `~/.codefreedom/.env.secrets` or `~/.codefreedom/.env.user`:

```bash
echo "DEEPSEEK_API_KEY=sk-..." >> ~/.codefreedom/.env.secrets
chmod 600 ~/.codefreedom/.env.secrets
```

Or export them as environment variables (highest priority).

---

## Model alias routing

These are the actual values written to `~/.codefreedom/.env.proxy` by the recipe.
Override any in `~/.codefreedom/.env.user`.

| Variable                        | Installed value              | Provider     | Format     | Cost tier  | Purpose                  |
| ------------------------------- | ---------------------------- | ------------ | ---------- | ---------- | ------------------------ |
| `LITELLM_MODEL_ALIAS_BEST`      | `OpenCode/Qwen3.7-Max`       | OpenCode GO  | Anthropic  | $$$        | Primary coding           |
| `LITELLM_MODEL_ALIAS_FABLE`     | `OpenCode/Qwen3.7-Max`       | OpenCode GO  | Anthropic  | $$$        | Hard reasoning           |
| `LITELLM_MODEL_ALIAS_SONNET`    | `OpenCode/DeepSeek-V4-Flash` | OpenCode GO  | OpenAI     | $          | Daily coding             |
| `LITELLM_MODEL_ALIAS_OPUS`      | `DeepSeek/DeepSeek-V4-Pro`   | DeepSeek     | OpenAI     | $$         | Complex reasoning        |
| `LITELLM_MODEL_ALIAS_HAIKU`     | `DGX/Qwen3.6-35B-A3B`        | Local S      | OpenAI     | Free       | Fast / lightweight       |
| `LITELLM_MODEL_ALIAS_SONNET_1M` | `OpenCode/DeepSeek-V4-Flash` | OpenCode GO  | OpenAI     | $          | 1M context daily coding  |
| `LITELLM_MODEL_ALIAS_OPUS_1M`   | `DeepSeek/DeepSeek-V4-Pro`   | DeepSeek     | OpenAI     | $$         | 1M context complex       |
| `LITELLM_MODEL_ALIAS_OPUSPLAN`  | `DeepSeek/DeepSeek-V4-Pro`   | DeepSeek     | OpenAI     | $$         | Plan mode (opus/exec)    |
| `LITELLM_MODEL_ALIAS_CUSTOM`    | `DGX/Qwen3.6-27B`            | Local M      | OpenAI     | Free       | Custom model slot        |

**How aliases resolve at request time:**

1. Claude Code sends the alias as the `model` field (e.g. `model: sonnet`)
2. LiteLLM looks up `model_group_alias.sonnet` -> `OpenCode/DeepSeek-V4-Flash`
3. `OpenCode/DeepSeek-V4-Flash` matches a `model_name` in the OpenCode provider config
4. LiteLLM routes the request to one of the models with that `model_name`
5. Reasoning-effort translation runs automatically via the plugin

**Override an alias** -- `~/.codefreedom/.env.user`:

```bash
LITELLM_MODEL_ALIAS_BEST=DeepSeek/DeepSeek-V4-Pro
LITELLM_MODEL_ALIAS_HAIKU=OpenCode/DeepSeek-V4-Flash-FREE
```

---

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

---

## Tool endpoints

After `cf px start`, the following services are available:

| Tool        | Endpoint                              | Purpose                                    |
| ----------- | ------------------------------------- | ------------------------------------------ |
| Proxy       | `http://localhost:4000`               | LiteLLM API proxy                          |
| Proxy Admin | `http://localhost:4000/ui`            | LiteLLM Admin UI (spend, models, keys)     |
| Chrome CDP  | `http://127.0.0.1:9222`              | Headless Chromium browser automation       |
| Chrome MCP  | `http://127.0.0.1:9223/mcp`          | Browser automation MCP interface           |
| Web MCP     | `http://127.0.0.1:8420/mcp`          | Camoufox stealth web search / scraping     |
| GitHub MCP  | `http://127.0.0.1:8129/mcp`          | GitHub API via MCP                         |
| Web-bridge  | `http://127.0.0.1:8500/search`       | SearXNG-shaped search -> Camoufox bridge   |
| Web-bridge  | `http://127.0.0.1:8500/healthz`      | Web bridge health check                    |

---

## Claude Code profile

The recipe's `claude-code.yaml` configures Claude Code to:

- Route through the local proxy (`ANTHROPIC_BASE_URL=http://localhost:4000`)
- Authenticate with `ANTHROPIC_AUTH_TOKEN` = the `LITELLM_MASTER_KEY` value
- Register all model aliases (`fable`, `sonnet`, `opus`, `haiku`, `custom`)
  so Claude Code knows which models are available
- Auto-start tools: Chrome, Web, GitHub
- Disable non-essential traffic, telemetry, and auto-installs

---

## PostgreSQL (embedded)

The proxy container ships an embedded PostgreSQL 18.4 instance (Unix-socket only,
no TCP listener). The entrypoint auto-initializes the cluster, runs Prisma schema
push, and connects LiteLLM automatically -- no user configuration needed.

**Purpose:**

- **Spend tracking** -- LiteLLM logs token usage per model and provider
- **Admin UI** -- browse models, view spend, manage keys at `http://localhost:4000/ui`

**Data persistence:**

| Directory                  | Purpose                    |
| -------------------------- | -------------------------- |
| `~/.codefreedom/pg/data`   | PostgreSQL data directory  |
| `~/.codefreedom/pg/backup` | Backup directory           |

**External PostgreSQL:** To use an external database instead of embedded, set
`DATABASE_URL` in `.env.proxy` and remove the three PG volume mounts from
`docker-compose.yaml`.

---

## Local backend setup

The recipe reserves two ports for self-hosted inference:

| Port  | Alias             | Used by model alias |
| ----- | ----------------- | ------------------- |
| 8000  | `LOCAL_M_BASE_URL` | `custom` (Qwen3.6-27B) |
| 8001  | `LOCAL_S_BASE_URL` | `haiku` (Qwen3.6-35B-A3B) |

Run any OpenAI-compatible inference server on these ports:

```bash
# Example: vLLM
vllm serve Qwen/Qwen3.6-27B --port 8000

# Example: Ollama (runs on port 11434 by default -- use LOCAL_M_BASE_URL to match)
export LOCAL_M_BASE_URL=http://host.docker.internal:11434/v1

# Example: SGLang
python -m sglang.launch_server --model Qwen/Qwen3.6-27B --port 8000
```

When running inside Docker (the proxy container), use `host.docker.internal`
to reach services on the host. When running in a WSL2 VM, ensure the inference
server binds to `0.0.0.0` rather than `127.0.0.1`.

---

## Cost estimate

This recipe is designed to minimize cost through three strategies:

1. **Free local models** -- `haiku` and `custom` aliases hit the local server
   (zero cost per token)
2. **Cheap cloud daily driver** -- `sonnet` routes to `DeepSeek-V4-Flash` at
   $0.14/M input tokens
3. **Expensive models on demand** -- `opus` / `best` / `fable` use top-tier
   models only when you explicitly select them

Rough monthly estimate for a solo developer (1M input tokens / month):

| Usage pattern                          | Estimated cost |
| -------------------------------------- | -------------- |
| All local (default `haiku` + `custom`) | $0             |
| Cloud daily driver (`sonnet`)          | ~$5-15         |
| Heavy reasoning (`opus` + `best`)      | ~$30-80        |
| Mixed (typical)                        | ~$10-30        |

Actual costs vary by provider pricing, cache hit rate, and output token volume.

---

## Verification

After setup, confirm everything is working:

```bash
# Check proxy health
cf px status

# Check tool status
cf tools status

# Test a model call via the proxy
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-codefreedom-local" \
  -H "Content-Type: application/json" \
  -d '{"model": "haiku", "messages": [{"role": "user", "content": "Say hello in one word"}], "max_tokens": 10}'

# Expected response: {"id":"...","choices":[{"message":{"content":"Hello"}}],...}

# Launch Claude Code
cf cc
```

---

## Commands reference

| Command                                                 | Outcome                                                                      |
| ------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `cf init recipe --plan costeffective-coding-with-local` | Preview: shows files to create/replace with diffs and dirs to create         |
| `cf init recipe --apply <plan-id>`                      | Apply: writes config files, creates `pg/data` and `pg/backup` mount dirs     |
| `cf px start`                                           | Starts proxy + embedded PostgreSQL + tools (Chrome, Web, GitHub, Web-bridge) |
| `cf px status`                                          | Proxy health check                                                           |
| `cf px stop`                                            | Stop proxy and tools                                                         |
| `cf px restart`                                         | Restart proxy (preserves state, no image pull)                               |
| `cf cc`                                                 | Launch Claude Code with configured profile                                   |
| `sudo chown -R $(id -u):$(id -g) ~/.codefreedom`        | Fix ownership (Linux/WSL -- container user UID vs host UID)                  |
| `cf tools status`                                       | Status of all tool containers                                                |

---

## Troubleshooting

### Docker permissions (Linux/WSL)

Files created by the container (PostgreSQL data, cache) are owned by the
container user (UID 1000). If host commands can't access them:

```bash
sudo chown -R $(id -u):$(id -g) ~/.codefreedom
```

Run this once after `cf px start` if you see permission errors on the host.

### Port conflicts

If port 4000 is already in use:

```bash
# Override the proxy port for this run
cf px start --port 4001

# Or set it permanently
echo "LITELLM_PORT=4001" >> ~/.codefreedom/.env.user
```

### Proxy won't start

```bash
# Check Docker is running
docker info

# Check for existing containers with the same name
docker ps -a --filter name=litellm

# Remove stuck container
docker rm -f litellm-codefreedom-coding

# Try again
cf px start
```

### Model returns empty / timeout

- Check your API key is set correctly in `.env.secrets`
- Test the provider directly: `curl $DEEPSEEK_BASE_URL/v1/chat/completions ...`
- Increase timeout: `echo "LITELLM_TIMEOUT_ERROR_RETRIES=10" >> ~/.codefreedom/.env.user`
- Check provider status pages for outages

### Local model not reachable (Docker)

The proxy container uses `host.docker.internal` to reach host services:

- **Linux:** Requires `extra_hosts` config (included by default in this recipe's
  `docker-compose.yaml`). Ensure your local server binds to `0.0.0.0`, not `127.0.0.1`.
- **macOS / Windows:** `host.docker.internal` works out of the box with Docker Desktop.

---

## Override defaults

Use `~/.codefreedom/.env.user` to override any setting without modifying recipe
files. This file is never touched by recipe apply or updates.

```bash
# Change default model for "best" alias
echo "LITELLM_MODEL_ALIAS_BEST=OpenCode/DeepSeek-V4-Pro" >> ~/.codefreedom/.env.user

# Change proxy port
echo "LITELLM_PORT=4001" >> ~/.codefreedom/.env.user

# Disable telemetry
echo "CLAUDE_CODE_TELEMETRY_DISABLED=true" >> ~/.codefreedom/.env.user
```

---

## Cleanup

### Stop everything

```bash
cf px stop
```

### Remove all CodeFreedom config

```bash
# Interactive (asks for confirmation)
cf deinit

# Force (no prompts)
cf deinit --force
```

This stops containers and removes `~/.codefreedom` (except `.env.user` which
is preserved).

### Restore from backup

The `--apply` command creates an automatic backup before making changes:

```bash
# List available backups
cf admin list-backups

# Restore a backup
cf admin restore ~/.codefreedom/backup/codefreedom-backup-...tar.gz
```

---

## Extends

`_default` -- inherits shared tool profiles (Chrome, Web, GitHub, Web-bridge),
base proxy compose, LiteLLM config, and reasoning-efforts plugin from the
[default recipe](../_default/).

---

## Recipe metadata

| Field        | Value                              |
| ------------ | ---------------------------------- |
| **Name**     | `costeffective-coding-with-local`  |
| **Extends**  | `_default`                         |
| **Version**  | 1                                  |
| **Type**     | Universal (cloud + local)          |
