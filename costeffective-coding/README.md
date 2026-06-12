# costeffective-coding

> A CodeFreedom recipe that routes Claude Code and MiMoCode through cloud
> providers — minimizing cost while maximizing flexibility.

## Overview

This recipe installs a complete CodeFreedom configuration for coding with
cloud providers:

- **LiteLLM proxy** on port 4000 routing model aliases to cloud provider backends
- **4 tool containers** (Chrome, Web, GitHub, Web-bridge) for browser automation,
  web search, and repository access
- **Embedded PostgreSQL** for LiteLLM spend tracking and Admin UI
- **MiMoCode support** — 0-click proxy auto-config with all models available

Model aliases (`fable`, `sonnet`, `opus`, `haiku`, `custom`) are mapped to the cheapest
capable provider.

### Who is this for?

- Developers who want **multiple provider options** (Azure Foundry, OpenCode,
  OpenRouter) without reconfiguring
- Teams optimizing for **cost-to-capability ratio** — cheap daily drivers,
  expensive models for hard tasks
- Users who want both **Claude Code** and **MiMoCode** with shared proxy config

---

## Prerequisites

Before starting, make sure you have:

- **Docker** with Compose V2 (`docker compose` command available)
- **CodeFreedom CLI** installed — `pip install codefreedom` or from source
- API key accounts for at least one cloud provider (see table below)
- Port 4000 free for the proxy
- ~2 GB free disk space for Docker images (one-time pull)

---

## Quick start

```bash
# 1. Preview what will be installed
cf init --plan costeffective-coding

# 2. Apply the plan (you will be prompted for API keys)
cf init --apply <plan_id>

# 3. Fix ownership (Linux/WSL only)
sudo chown -R $(id -u):$(id -g) ~/.codefreedom

# 4. Start the proxy — auto-starts Chrome, Web, GitHub, Web-bridge
cf px start

# 5. Launch Claude Code or MiMoCode
cf cc
# or
cf mimo
```

Step 1 shows every file the recipe will create, along with a diff preview.
Step 2 writes config files and creates `pg/data` + `pg/backup` mount directories
for embedded PostgreSQL. During this step you will be prompted for API keys.
Step 3 fixes file ownership when the container user UID differs from your host
UID (Docker on Linux). Step 4 starts the LiteLLM proxy on port 4000 and all
tool containers. Step 5 launches Claude Code or MiMoCode with the configured profile.

![Recipe plan and apply output](assets/image.png)

### Staging flag

If you are on the `recipe-branch` branch (unstable recipes), add `--staging`
to the plan command:

```bash
cf init --staging --plan costeffective-coding
```

---

## Secrets flow

When you run `--plan`, the recipe engine prompts for each required secret:

| Secret                      | Prompt                    | Default                 |
| --------------------------- | ------------------------- | ----------------------- |
| `LITELLM_MASTER_KEY`        | LiteLLM proxy master key  | `sk-codefreedom-local`  |
| `MICROSOFT_FOUNDRY_API_KEY` | Microsoft Foundry API key | (empty — must provide)  |
| `OPENCODE_ZEN_API_KEY`      | OpenCode Zen API key      | (empty — must provide)  |
| `OPENROUTER_API_KEY`        | OpenRouter API key        | (empty — must provide)  |

Keys are written to `~/.codefreedom/.env.proxy.secrets`. Leave a key empty to
skip that provider — LiteLLM will not load its config.

---

## Environment variables reference

All variables below can be set as machine env vars (with `CF_CLI_` prefix for
highest priority), in `.env.*.secrets` files (secrets), or in `.env.user`
(non-secrets). The `CF_CLI_` prefix is stripped automatically — e.g.
`export CF_CLI_LITELLM_MASTER_KEY=sk-...` sets `LITELLM_MASTER_KEY`.

### Secrets

Secrets are split across three files by scope. Set via `CF_CLI_*` machine env
vars (recommended) or fill in the `.env.*.secrets` files as fallbacks.

| Variable | File | Used by | Description |
| --- | --- | --- | --- |
| `LITELLM_MASTER_KEY` | `.env.proxy.secrets` | Proxy, Claude, MiMo, OpenCode | Proxy auth token — all agents use this to talk to LiteLLM |
| `DEEPSEEK_API_KEY` | `.env.proxy.secrets` | Proxy | DeepSeek direct API key |
| `MICROSOFT_FOUNDRY_API_KEY` | `.env.proxy.secrets` | Proxy (Azure provider) | Azure AI Foundry API key |
| `MICROSOFT_FOUNDRY_API_BASE` | `.env.proxy.secrets` | Proxy (Azure provider) | Azure endpoint URL (region-specific) |
| `OPENCODE_ZEN_API_KEY` | `.env.proxy.secrets` | Proxy (OpenCode Zen + GO) | OpenCode API key — free tier + subscription |
| `OPENROUTER_API_KEY` | `.env.proxy.secrets` | Proxy (OpenRouter) | OpenRouter API key |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | `.env.claude/.mimo/.opencode.secrets` | Sandbox mode | GitHub PAT for git push/pull in `--sandbox` |
| `GH_TOKEN` | `.env.claude/.mimo/.opencode.secrets` | Sandbox mode | GitHub token alias (usually same as PAT above) |

### Non-secrets (proxy container)

Set in `.env.proxy` or `.env.user`. These control the proxy container and
model routing — they are not sensitive.

| Variable | Default | Description |
| --- | --- | --- |
| `LITELLM_IMAGE` | `docker.io/nilayparikh/codefreedom:litellm-latest` | Proxy container image |
| `LITELLM_CONTAINER_NAME` | `litellm-codefreedom` | Docker container name |
| `LITELLM_PORT` | `4000` | Proxy listen port |
| `LITELLM_BIND_HOST` | `0.0.0.0` | Proxy bind address |
| `LITELLM_LOG` | `INFO` | Log level (DEBUG/INFO/WARNING) |
| `LITELLM_DROP_PARAMS` | `true` | Strip unsupported params before forwarding |
| `JSON_LOGS` | `true` | JSON-formatted log output |
| `SEARXNG_API_BASE` | `http://host.docker.internal:8500` | Web bridge SearXNG endpoint |
| `OPENCODE_ZEN_BASE_URL` | `https://opencode.ai/zen/v1` | OpenCode Zen API endpoint |
| `OPENCODE_GO_BASE_URL` | `https://opencode.ai/zen/go/v1` | OpenCode GO API endpoint |
| `OPENCODE_GO_ANTHROPIC_BASE_URL` | `https://opencode.ai/zen/go` | OpenCode GO Anthropic-format endpoint |
| `OPENROUTER_BASE_URL` | `https://openrouter.ai/api/v1` | OpenRouter API endpoint |
| `POSTGRES_HOST_DATA_DIR` | `~/.codefreedom/pg/data` | PostgreSQL data directory host path |
| `POSTGRES_HOST_BACKUP_DIR` | `~/.codefreedom/pg/backup` | PostgreSQL backup directory host path |

### Non-secrets (model alias overrides)

Set in `.env.user` to override the default model for each alias. See
[Model alias routing](#model-alias-routing) for details.

| Variable | Default | Overrides alias |
| --- | --- | --- |
| `LITELLM_MODEL_ALIAS_BEST` | `DeepSeek/DeepSeek-V4-Pro` | `best` |
| `LITELLM_MODEL_ALIAS_FABLE` | `DeepSeek/DeepSeek-V4-Pro` | `fable` |
| `LITELLM_MODEL_ALIAS_SONNET` | `DGX/Qwen3.6-27B` | `sonnet` |
| `LITELLM_MODEL_ALIAS_OPUS` | `DeepSeek/DeepSeek-V4-Pro` | `opus` |
| `LITELLM_MODEL_ALIAS_HAIKU` | `DGX/Qwen3.6-35B-A3B` | `haiku` |
| `LITELLM_MODEL_ALIAS_OPUS_1M` | `DeepSeek/DeepSeek-V4-Pro` | `opus` (1M context) |
| `LITELLM_MODEL_ALIAS_OPUSPLAN` | `DeepSeek/DeepSeek-V4-Pro` | `opusplan` |

### Non-secrets (agent profiles)

These are set in profile YAML `env:` blocks and resolved automatically. Override
in `.env.user` only if you need to change agent behavior.

| Variable | Agent | Description |
| --- | --- | --- |
| `ANTHROPIC_BASE_URL` | Claude Code | Proxy URL (`http://localhost:4000`) |
| `ANTHROPIC_AUTH_TOKEN` | Claude Code | Proxy auth (= `LITELLM_MASTER_KEY`) |
| `CLAUDE_MODEL` | Claude Code | Default model alias (`haiku`) |
| `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY` | Claude Code | Enable model discovery via proxy |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | Claude Code | Disable telemetry/analytics |
| `ANTHROPIC_DEFAULT_FABLE_MODEL` | Claude Code | Model for `fable` alias |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Claude Code | Model for `opus` alias |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Claude Code | Model for `sonnet` alias |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Claude Code | Model for `haiku` alias |
| `ANTHROPIC_CUSTOM_MODEL_OPTION` | Claude Code | Model for `custom` alias |
| `LITELLM_BASE_URL` | MiMoCode / OpenCode | Proxy URL for 0-click config |
| `PROXY_API_KEY` | MiMoCode / OpenCode | Proxy auth (= `LITELLM_MASTER_KEY`) |
| `MIMOCODE_MIMO_ONLY` | MiMoCode | Pure MiMo mode (no Claude Code) |
| `MIMOCODE_DISABLE_AUTOUPDATE` | MiMoCode | Disable auto-update checks |
| `MIMOCODE_ENABLE_ANALYSIS` | MiMoCode | Disable remote telemetry |
| `MIMOCODE_CONFIG` | MiMoCode | Path to generated `mimocode.json` |
| `OPENCODE_CONFIG` | OpenCode | Path to generated `opencode.json` |
| `OPENCODE_DISABLE_AUTOUPDATE` | OpenCode | Disable auto-update checks |

### Secrets file summary

| File | Scope | Variables |
| --- | --- | --- |
| `.env.proxy.secrets` | Proxy + all providers | `LITELLM_MASTER_KEY`, `DEEPSEEK_API_KEY`, `MICROSOFT_FOUNDRY_API_KEY`, `MICROSOFT_FOUNDRY_API_BASE`, `OPENCODE_ZEN_API_KEY`, `OPENROUTER_API_KEY` |
| `.env.claude.secrets` | Claude Code sandbox | `GITHUB_PERSONAL_ACCESS_TOKEN`, `GH_TOKEN` |
| `.env.mimo.secrets` | MiMoCode sandbox | `GITHUB_PERSONAL_ACCESS_TOKEN`, `GH_TOKEN` |
| `.env.opencode.secrets` | OpenCode sandbox | `GITHUB_PERSONAL_ACCESS_TOKEN`, `GH_TOKEN` |

---

## Architecture

```
                            Claude Code (cf cc) / MiMoCode (cf mimo)
                                   |
                     ANTHROPIC_BASE_URL = http://localhost:4000
                                   |
                      LiteLLM Proxy (:4000)
                      /    |    |    |    \
                      /     |    |    \
               Azure  OpenCode  OpenRouter
               (cloud)  (cloud)   (cloud)

    Tools (auto-started with proxy):
      Chrome (:9222)   Web (:8420)   GitHub (:8129)   Web-bridge (:8500)

    PostgreSQL (embedded in proxy container):
      Spend tracking + Admin UI at http://localhost:4000/ui
```

### Routing logic

1. Claude Code or MiMoCode sends a request with a model alias (`sonnet`, `opus`, etc.)
2. LiteLLM resolves the alias to a model name (e.g. `sonnet` -> `DeepSeek-V4-Pro`)
3. LiteLLM load-balances across provider models with that name
4. Reasoning-effort translation runs automatically via the plugin

---

## What it provides

| Layer                  | Files                                                                           |
| ---------------------- | ------------------------------------------------------------------------------- |
| **Claude Code config** | `.env.claude`, `.env.claude.secrets`                                            |
| **MiMoCode config**    | `.env.mimo`, `.env.mimo.secrets`                                                |
| **Proxy config**       | `.env.proxy`, `.env.proxy.secrets`                                              |
| **Profiles**           | `claude-code.yaml`, `mimo-code.yaml`, `chrome.yaml`, `web.yaml`, `github.yaml`, `web-bridge.yaml` |
| **Proxy compose**      | `docker-compose.yaml` with embedded PostgreSQL                                  |
| **Proxy config**       | `config.yaml` with LiteLLM routing                                              |
| **Plugins**            | Reasoning-efforts mapping, image-router, system-message-merger                 |
| **Providers**          | Azure Foundry, OpenCode, OpenRouter                                              |
| **Mount dirs**         | `pg/data`, `pg/backup` (embedded PostgreSQL host volumes)                       |

---

## Provider API keys

Each provider config reads its key from an environment variable. Set the ones
you want to use. Unset providers are skipped automatically by LiteLLM.

| Provider config         | Key env var                 | Default endpoint                                                                |
| ----------------------- | --------------------------- | ------------------------------------------------------------------------------- |
| **Azure Foundry**       | `MICROSOFT_FOUNDRY_API_KEY` | Region-specific — set in `.env.user`; see commented placeholder in `.env.proxy` |
| **OpenCode Zen**        | `OPENCODE_ZEN_API_KEY`      | `https://opencode.ai/zen/v1`                                                    |
| **OpenCode GO**         | `OPENCODE_ZEN_API_KEY`      | `https://opencode.ai/zen/go/v1`                                                 |
| **OpenRouter**          | `OPENROUTER_API_KEY`        | `https://openrouter.ai/api/v1`                                                  |

Set keys in `~/.codefreedom/.env.secrets` or `~/.codefreedom/.env.user`:

```bash
echo "MICROSOFT_FOUNDRY_API_KEY=sk-..." >> ~/.codefreedom/.env.secrets
echo "OPENCODE_ZEN_API_KEY=sk-..." >> ~/.codefreedom/.env.secrets
echo "OPENROUTER_API_KEY=sk-..." >> ~/.codefreedom/.env.secrets
chmod 600 ~/.codefreedom/.env.secrets
```

Or export them as environment variables (highest priority).

---

## Model alias routing

Aliases are defined in `proxy/config/config.yaml` and map directly to model names.
Override any by setting the corresponding `LITELLM_MODEL_ALIAS_*` env var
(included in `recipe.yaml` `optional_config` with defaults).

| Alias in config.yaml | Routes to model name   | Available providers                          | Purpose                 |
| -------------------- | ---------------------- | -------------------------------------------- | ----------------------- |
| `fable`              | `Qwen3.7-Max`          | OpenCode GO, OpenRouter                      | Hard reasoning, primary |
| `opus`               | `Qwen3.7-Plus`         | OpenCode GO, OpenRouter                      | Complex reasoning       |
| `sonnet`             | `DeepSeek-V4-Pro`      | OpenRouter                                   | Daily coding            |
| `haiku`              | `DeepSeek-V4-Flash`    | OpenCode Zen (free), OpenCode GO, OpenRouter | Fast / lightweight      |
| `custom`             | `Qwen3.6-27B`          | OpenRouter                                   | Custom model slot       |

**Override an alias** — set `LITELLM_MODEL_ALIAS_*` in `~/.codefreedom/.env.user`:

```bash
LITELLM_MODEL_ALIAS_OPUS=Qwen3.7-Max
LITELLM_MODEL_ALIAS_HAIKU=DeepSeek-V4-Pro
```

The `recipe.yaml` `optional_config` block provides default override values for
all standard Claude Code aliases (`best`, `fable`, `sonnet`, `opus`, `haiku`,
`sonnet_1m`, `opus_1m`, `opusplan`, `custom`). These env vars are available for
reference even though `config.yaml` currently uses hardcoded aliases.

**How aliases resolve at request time:**

1. Claude Code sends the alias as the `model` field (e.g. `model: sonnet`)
2. LiteLLM looks up `model_group_alias.sonnet` -> `DeepSeek-V4-Pro`
3. `DeepSeek-V4-Pro` matches a `model_name` in the OpenRouter provider config
4. LiteLLM routes the request to the matching model
5. Reasoning-effort translation runs automatically via the plugin

---

## Proxy environment

Key settings written to `~/.codefreedom/.env.proxy`:

| Variable                      | Value                                    | Purpose                                    |
| ----------------------------- | ---------------------------------------- | ------------------------------------------ |
| `LITELLM_IMAGE`               | `docker.io/nilayparikh/codefreedom:litellm-latest` | Proxy container image          |
| `LITELLM_PORT`                | `4000`                                   | Proxy listen port                          |
| `LITELLM_DROP_PARAMS`         | `true`                                   | Strip unsupported params before forwarding |
| `OPENCODE_ZEN_BASE_URL`       | `https://opencode.ai/zen/v1`             | OpenCode Zen API                           |
| `OPENCODE_GO_BASE_URL`        | `https://opencode.ai/zen/go/v1`          | OpenCode GO API                            |
| `OPENCODE_GO_ANTHROPIC_BASE_URL` | `https://opencode.ai/zen/go`          | OpenCode GO Anthropic API                  |
| `OPENROUTER_BASE_URL`         | `https://openrouter.ai/api/v1`           | OpenRouter API endpoint                    |

> **Microsoft Foundry:** The `MICROSOFT_FOUNDRY_API_BASE` variable is set in the
> docker-compose environment but **not** defined in `.env.proxy` — it's expected
> to be set per-workspace in `~/.codefreedom/.env.user` with your region-specific
> Azure AI Foundry endpoint.

---

## Tool endpoints

After `cf px start`, the following services are available:

| Tool        | Endpoint                        | Purpose                                  |
| ----------- | ------------------------------- | ---------------------------------------- |
| Proxy       | `http://localhost:4000`         | LiteLLM API proxy                        |
| Proxy Admin | `http://localhost:4000/ui`      | LiteLLM Admin UI (spend, models, keys)   |
| Chrome CDP  | `http://127.0.0.1:9222`         | Headless Chromium browser automation     |
| Chrome MCP  | `http://127.0.0.1:9223/mcp`     | Browser automation MCP interface         |
| Web MCP     | `http://127.0.0.1:8420/mcp`     | Camoufox stealth web search / scraping   |
| GitHub MCP  | `http://127.0.0.1:8129/mcp`     | GitHub API via MCP                       |
| Web-bridge  | `http://127.0.0.1:8500/search`  | SearXNG-shaped search -> Camoufox bridge |
| Web-bridge  | `http://127.0.0.1:8500/healthz` | Web bridge health check                  |

---

## Claude Code profile

The recipe's `claude-code.yaml` configures Claude Code to:

- Route through the local proxy (`ANTHROPIC_BASE_URL=http://localhost:4000`)
- Authenticate with `ANTHROPIC_AUTH_TOKEN` = the `LITELLM_MASTER_KEY` value
- Register all model aliases (`fable`, `sonnet`, `opus`, `haiku`, `custom`)
  so Claude Code knows which models are available
- Auto-start tools: Chrome, Web, GitHub
- Disable non-essential traffic, telemetry, and auto-installs
- Include `ui-ux` profile with vision-capable models for frontend work

### Profiles

| Profile   | Description                                                              |
| --------- | ------------------------------------------------------------------------ |
| `default` | Base profile — routes through proxy with all model aliases               |
| `bare`    | Minimal — no model aliases, no sandbox settings, no preferences          |
| `ui-ux`   | UI/UX design — vision-capable models for frontend development            |

---

## MiMoCode profile

The recipe's `mimo-code.yaml` configures MiMoCode to:

- Use 0-click proxy auto-config — probes `LITELLM_BASE_URL`, fetches `/v1/models`,
  and generates a complete `mimocode.json` with all models
- Auto-start tools: Web
- Disable auto-updates, models fetch, and Claude Code integration

### Profiles

| Profile   | Description                                                              |
| --------- | ------------------------------------------------------------------------ |
| `default` | Base profile — 0-click proxy auto-config with all models                 |
| `bare`    | Minimal — no model config, no proxy auto-config, no sandbox settings     |
| `ultra`   | Maximum capability — best models, all experimental features              |
| `pro`     | Production — high-quality models, balanced feature set                   |
| `flash`   | Speed-optimized — lightweight models, minimal plugins                    |
| `air`     | Minimal-resource — for low-power devices and constrained environments    |
| `ui-ux`   | UI/UX design — interactive design feedback, image attachment support     |

---

## Plugins

Three plugins are included in the proxy configuration:

| Plugin                  | Purpose                                                                  |
| ----------------------- | ------------------------------------------------------------------------ |
| **Reasoning-efforts**   | Translates reasoning effort settings per model (full rule library)       |
| **Image-router**        | Routes image requests to vision-capable models for text-only models      |
| **System-message-merger** | Merges system messages for models that don't support them natively |

---

## PostgreSQL (embedded)

The proxy container ships an embedded PostgreSQL 18.4 instance (Unix-socket only,
no TCP listener). The entrypoint auto-initializes the cluster, runs Prisma schema
push, and connects LiteLLM automatically — no user configuration needed.

**Purpose:**

- **Spend tracking** — LiteLLM logs token usage per model and provider
- **Admin UI** — browse models, view spend, manage keys at `http://localhost:4000/ui`

**Data persistence:**

| Directory                  | Purpose                   |
| -------------------------- | ------------------------- |
| `~/.codefreedom/pg/data`   | PostgreSQL data directory |
| `~/.codefreedom/pg/backup` | Backup directory          |

**External PostgreSQL:** To use an external database instead of embedded, set
`DATABASE_URL` in `.env.proxy` and remove the three PG volume mounts from
`docker-compose.yaml`.

---

## Cost estimate

This recipe is designed to minimize cost through three strategies:

1. **Cheap cloud daily driver** — `haiku` routes to `DeepSeek-V4-Flash` at
   $0.14/M input tokens (free tier available via OpenCode Zen)
3. **Expensive models on demand** — `fable` / `opus` use top-tier
   models only when you explicitly select them

Rough monthly estimate for a solo developer (1M input tokens / month):

| Usage pattern                          | Estimated cost |
| -------------------------------------- | -------------- |
| Free tier only (`haiku` via OpenCode Zen) | $0          |
| Cloud daily driver (`sonnet`)          | ~$1-5          |
| Heavy reasoning (`fable` + `opus`)     | ~$5-20         |
| Mixed (typical)                        | ~$2-10         |

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

# Or launch MiMoCode
cf mimo
```

---

## Commands reference

| Command                                                 | Outcome                                                                      |
| ------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `cf init --plan costeffective-coding` | Preview: shows files to create/replace with diffs and dirs to create         |
| `cf init --apply <plan-id>`                      | Apply: writes config files, creates `pg/data` and `pg/backup` mount dirs     |
| `cf px start`                                           | Starts proxy + embedded PostgreSQL + tools (Chrome, Web, GitHub, Web-bridge) |
| `cf px status`                                          | Proxy health check                                                           |
| `cf px stop`                                            | Stop proxy and tools                                                         |
| `cf px restart`                                         | Restart proxy (preserves state, no image pull)                               |
| `cf cc`                                                 | Launch Claude Code with configured profile                                   |
| `cf mimo`                                               | Launch MiMoCode with configured profile                                      |
| `sudo chown -R $(id -u):$(id -g) ~/.codefreedom`        | Fix ownership (Linux/WSL — container user UID vs host UID)                  |
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
docker rm -f litellm-codefreedom

# Try again
cf px start
```

### Model returns empty / timeout

- Check your API key is set correctly in `.env.secrets`
- Test the provider directly: `curl $OPENCODE_ZEN_BASE_URL/v1/chat/completions ...`
- Increase timeout: `echo "LITELLM_TIMEOUT_ERROR_RETRIES=10" >> ~/.codefreedom/.env.user`
- Check provider status pages for outages

---

## Override defaults

Use `~/.codefreedom/.env.user` to override any setting without modifying recipe
files. This file is never touched by recipe apply or updates.

```bash
# Change default model for "best" alias
echo "LITELLM_MODEL_ALIAS_BEST=Qwen3.7-Max" >> ~/.codefreedom/.env.user

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

`_default` — inherits shared tool profiles (Chrome, Web, GitHub, Web-bridge),
base proxy compose, LiteLLM config, and plugins from the
[default recipe](../_default/).

---

## Recipe metadata

| Field       | Value                             |
| ----------- | --------------------------------- |
| **Name**    | `costeffective-coding` |
| **Extends** | `_default`                        |
| **Version** | 1                                 |
| **Type**    | Cloud providers                   |
