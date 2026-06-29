# costeffective-coding

> Cloud providers recipe -- routes Claude Code, MiMoCode, and OpenCode through
> Azure Foundry, OpenCode, and OpenRouter. Minimizes cost, maximizes flexibility.

## Who is this for?

- Developers who want **multiple cloud provider options** without reconfiguring
- Teams optimizing for **cost-to-capability ratio**
- Users who want Claude Code, MiMoCode, and OpenCode with shared proxy config

## Prerequisites

- Docker with Compose V2 (`docker compose` available)
- CodeFreedom CLI -- `pip install codefreedom`
- At least one API key from the providers below
- Port 4000 free

## Quick Start

```bash
# 1. Plan + apply (preview, confirm, install)
cf s i -pa costeffective-coding

# 2. Fix ownership (Linux/WSL only)
sudo chown -R $(id -u):$(id -g) ~/.codefreedom

# 3. Start proxy + tools
cf r px start

# 4. Launch your agent
cf r ag cc          # Claude Code
cf r ag mc          # MiMoCode
cf r ag oc          # OpenCode
```

## API Keys

Set at least one. Unset providers are skipped automatically.

| Provider | Key | Where to get it |
|----------|-----|-----------------|
| Azure Foundry | `MICROSOFT_FOUNDRY_API_KEY` | [ai.azure.com](https://ai.azure.com) |
| OpenCode Zen | `OPENCODE_ZEN_API_KEY` | [opencode.ai](https://opencode.ai) (free tier available) |
| OpenRouter | `OPENROUTER_API_KEY` | [openrouter.ai](https://openrouter.ai) |

Keys are stored in `~/.codefreedom/.env.proxy.secrets`. You can also set them as `CF_CLI_*` environment variables (highest priority):

```bash
export CF_CLI_MICROSOFT_FOUNDRY_API_KEY=sk-...
```

### Assisted setup

Instead of editing files by hand:

```bash
bash ~/.codefreedom/scripts/costeffective-coding/setup-secrets.sh
```

## What it provides

- **LiteLLM proxy** on port 4000 (embedded PostgreSQL, spend tracking, Admin UI)
- **Browser tools**: Chrome, Camoufox web search, GitHub MCP, Web Bridge
- **Model aliases**: `fable`, `sonnet`, `opus`, `haiku`, `custom` -- mapped to cheapest capable provider
- **Reasoning-effort plugin**: automatic translation per model

## Model Aliases

Aliases map to real models. Override any in `~/.codefreedom/.env.user`:

| Alias | Default model | Purpose |
|-------|---------------|---------|
| `fable` | Qwen3.7-Max | Hard reasoning |
| `opus` | Qwen3.7-Plus | Complex reasoning |
| `sonnet` | DeepSeek-V4-Pro | Daily coding |
| `haiku` | DeepSeek-V4-Flash | Fast / cheap |
| `custom` | DeepSeek-V4-Flash | Custom slot |

Override example:

```bash
echo "LITELLM_MODEL_ALIAS_HAIKU=DeepSeek-V4-Pro" >> ~/.codefreedom/.env.user
```

## Tool Endpoints

After `cf r px start`:

| Tool | URL | Purpose |
|------|-----|---------|
| Proxy | http://localhost:4000 | LiteLLM API |
| Admin UI | http://localhost:4000/ui | Spend, models, keys |
| Chrome CDP | http://127.0.0.1:9222 | Browser automation |
| Chrome MCP | http://127.0.0.1:9223/mcp | Browser MCP |
| Web MCP | http://127.0.0.1:8420/mcp | Camoufox search |
| GitHub MCP | http://127.0.0.1:8129/mcp | GitHub API |
| Web Bridge | http://127.0.0.1:8500/search | SearXNG bridge |

## Common Commands

| Command | What it does |
|---------|-------------|
| `cf s i -pa costeffective-coding` | Install recipe |
| `cf r px start` | Start proxy + tools |
| `cf r px stop` | Stop proxy + tools |
| `cf r px status` | Proxy health check |
| `cf r px restart` | Restart proxy |
| `cf r ag cc` | Launch Claude Code |
| `cf r ag mc` | Launch MiMoCode |
| `cf r ag oc` | Launch OpenCode |
| `cf run tools status` | Tool container status |
| `cf manage doctor` | Diagnose issues |

## Verification

```bash
# Check proxy
cf r px status

# Test a model call
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-codefreedom-local" \
  -H "Content-Type: application/json" \
  -d '{"model": "haiku", "messages": [{"role": "user", "content": "Say hello"}], "max_tokens": 10}'
```

## Troubleshooting

**Docker permissions (Linux/WSL):**

```bash
sudo chown -R $(id -u):$(id -g) ~/.codefreedom
```

**Port 4000 in use:**

```bash
echo "PROXY_PORT=4001" >> ~/.codefreedom/.env.user
```

**Proxy won't start:**

```bash
docker ps -a --filter name=litellm     # check for stuck container
docker rm -f litellm-codefreedom        # remove it
cf r px start                           # try again
```

**Model returns empty / timeout:**

- Check your API key is set in `.env.proxy.secrets`
- Check provider status pages for outages

## Cleanup

```bash
cf r px stop                    # stop everything
cf setup deinit                 # remove all config (interactive)
cf setup deinit --force         # remove all config (no prompts)
```

## Cost Estimate

| Usage pattern | Estimated monthly cost |
|---------------|----------------------|
| Free tier only (`haiku` via OpenCode Zen) | $0 |
| Cloud daily driver (`sonnet`) | ~$1-5 |
| Heavy reasoning (`fable` + `opus`) | ~$5-20 |
| Mixed (typical) | ~$2-10 |

## Recipe Metadata

| Field | Value |
|-------|-------|
| Name | `costeffective-coding` |
| Extends | `_default` |
| Type | Cloud providers |
