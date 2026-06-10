# costeffective-coding-with-local

![Recipe plan and apply output](assets/image.png)

Graduated CodeFreedom recipe — a universal configuration for coding with a mix of cloud and local inference providers.

## What it provides

| Layer | Files |
|---|---|
| **Claude Code config** | `.env.claude`, `.env.claude.secrets` |
| **Proxy config** | `.env.proxy`, `.env.proxy.secrets` |
| **Profiles** | `claude-code.yaml`, `chrome.yaml`, `web.yaml`, `github.yaml`, `web-bridge.yaml` |
| **Proxy compose** | `docker-compose.yaml` with embedded PostgreSQL |
| **Proxy config** | `config.yaml` with LiteLLM routing |
| **Plugins** | Reasoning-efforts mapping (full rule library) |
| **Providers** | DeepSeek, Azure Foundry, OpenCode, Command Code, Local |
| **Mount dirs** | `pg/data`, `pg/backup` (embedded PostgreSQL host volumes) |

## Extends

`_default` — inherits shared profiles, compose, and base proxy config.

## Required secrets

- `LITELLM_MASTER_KEY` — LiteLLM proxy admin key
- `DEEPSEEK_API_KEY` — DeepSeek API
- `MICROSOFT_FOUNDRY_API_KEY` — Azure AI Foundry
- `NVIDIA_API_KEY` — NVIDIA AI Endpoints
- `OPENCODE_ZEN_API_KEY` — OpenCode Zen

## Usage

```bash
cf init recipe costeffective-coding-with-local
```
