# CodeFreedom Recipes

Pre-built configuration packages for [CodeFreedom](https://github.com/nilayparikh/codefreedom) -- one command to go from zero to a working AI coding environment.

## What Are Recipes?

Recipes are opinionated bundles of proxy config, Claude Code profiles, and tool settings that install into `~/.codefreedom/` with a single command. Each recipe targets a specific LLM provider or use case -- pick the one that matches your API keys and let it wire everything up.

## Quick Start

```bash
# See what's available
cf init --list

# Plan + apply in one step (recommended)
cf init -pa costeffective-coding

# Or two-step: preview first, then apply separately
cf init --plan costeffective-coding
cf init --apply <plan-id>
```

After installing, set your API keys in the `.secrets` files, then:

```bash
cf proxy start
cf cc
```

## Available Recipes

| Recipe | Description | API Keys Needed |
|--------|-------------|-----------------|
| [costeffective-coding](costeffective-coding/) | Cloud-only: Azure, OpenCode, OpenRouter via LiteLLM proxy | `DEEPSEEK_API_KEY`, `MICROSOFT_FOUNDRY_API_KEY`, `OPENCODE_ZEN_API_KEY`, `OPENROUTER_API_KEY` |
| [costeffective-coding-with-local](costeffective-coding-with-local/) | Universal: cloud providers + local inference, graduated recipe | `DEEPSEEK_API_KEY`, `MICROSOFT_FOUNDRY_API_KEY`, `OPENCODE_ZEN_API_KEY`, `OPENROUTER_API_KEY` |
| [free](free/) | Free models from NVIDIA, OpenRouter, and OpenCode Zen | None (optional for higher rate limits) |
| [deepseek](deepseek/) | Native DeepSeek API via LiteLLM proxy | `DEEPSEEK_API_KEY` |
| [nvidia](nvidia/) | NVIDIA AI Endpoints | `NVIDIA_API_KEY` (free at build.nvidia.com) |
| [azure-openai](azure-openai/) | Microsoft Azure AI Foundry / Azure OpenAI | `MICROSOFT_FOUNDRY_API_KEY` |
| [openrouter-free](openrouter-free/) | OpenRouter free-tier models | `OPENROUTER_API_KEY` (free key available) |
| [opencode-free](opencode-free/) | OpenCode Zen free-tier models | `OPENCODE_ZEN_API_KEY` (free) |
| [opencode-go](opencode-go/) | OpenCode GO subscription + free models | `OPENCODE_ZEN_API_KEY_NPG` |
| [local](local/) | Self-hosted local inference (vLLM, Ollama, etc.) | None (point to your inference server) |

## How Recipes Work

Each recipe is a folder containing a `recipe.yaml` manifest and the config files it installs. The manifest declares:

- **`files`** -- what gets installed and how it merges with existing config
- **`extends`** -- base recipe to inherit from (`_default` provides shared tool profiles and proxy scaffolding)
- **`required_secrets`** -- API keys the user must provide
- **`optional_config`** -- model aliases and settings with sensible defaults

Recipes merge intelligently: existing keys in `.env` files are preserved; YAML config is structurally merged via DeepDiff. Switching recipes cleans up orphans from the previous one.

### Recipe Inheritance

All recipes extend `[_default](_default/)`, which provides:

- Shared tool profiles (Chrome, Web/Camoufox, GitHub MCP, Web Bridge)
- Base proxy `docker-compose.yaml` and LiteLLM config
- Reasoning-efforts mapping plugin (full rule library)
- `.env` scaffolding for Claude Code and proxy

Extending recipes override only what's specific to their provider -- model aliases, provider YAML, and compose env vars.

## Custom Recipe Stores

Point to your own recipe store -- a GitHub repo or local folder with the same structure:

```bash
# GitHub repository
cf init --store https://github.com/your-org/my-recipes

# Local folder
cf init --store /path/to/my-recipes
```

## Recipe Format

A minimal `recipe.yaml`:

```yaml
name: my-recipe
extends: _default
description: "My custom LLM setup"
version: 1

files:
  - path: .env.proxy
    target: .env.proxy
    merge: env
  - path: profiles/claude-code.yaml
    target: profiles/claude-code.yaml
    merge: deepdiff
  - path: proxy/config/providers/my-provider.yaml
    target: proxy/config/providers/my-provider.yaml
    merge: deepdiff

required_secrets:
  - var: MY_API_KEY
    prompt: "My Provider API key"
    hint: "Get one at https://example.com/keys"

optional_config:
  - var: LITELLM_MODEL_ALIAS_BEST
    default: "MyProvider/Best-Model"
```

### Merge Modes

| Mode | When to Use | Behavior |
|------|-------------|----------|
| `env` | `.env` files | New keys appended; existing keys preserved |
| `deepdiff` | YAML, JSON | Structural merge; existing keys preserved |
| `overwrite` | Anything | Recipe version always wins |
| `auto` | Default | Inferred from file extension |

### File Layout

```
recipe-name/
  recipe.yaml                    # manifest
  .env.proxy                     # proxy environment variables
  .env.proxy.secrets             # proxy secrets template
  profiles/
    claude-code.yaml             # Claude Code profile (model aliases)
  proxy/
    docker-compose.yaml          # compose override (provider env vars)
    config/
      config.yaml                # LiteLLM config override (provider include)
      providers/
        my-provider.yaml         # provider definition
      plugins/
        reasoning-efforts/
          reasoning-efforts-mapping.yaml  # reasoning-effort rules
```

## Contributing

### Adding a Recipe

1. Create a folder at the root of this repo: `your-recipe/`
2. Write a `recipe.yaml` manifest extending `_default`
3. Include the config files referenced in the manifest
4. Make sure `required_secrets` lists every API key the user needs
5. Set sensible defaults in `optional_config` for model aliases
6. Write a `README.md` following the [costeffective-coding-with-local template](costeffective-coding-with-local/README.md):
   - Overview with who-this-is-for section
   - Prerequisites checklist
   - Quick start with numbered steps
   - Secrets flow table
   - Architecture diagram (ASCII)
   - Provider API keys table
   - Model alias routing with explanation
   - Verification commands
   - Troubleshooting section
   - Cleanup instructions

### Guidelines

- **Extend `_default`** -- don't duplicate shared config
- **Slim reasoning-efforts** -- include only rules for your provider's models
- **Clear hints** -- tell users where to get their API keys
- **Free-first defaults** -- if your provider has a free tier, default to it
- **Test the flow** -- run `cf init --plan <name>` and verify the diff looks right

### Model Aliases

Every recipe should set these aliases so Claude Code "best/sonnet/opus/haiku" language maps to real models:

| Alias | Purpose |
|-------|---------|
| `LITELLM_MODEL_ALIAS_BEST` | Top model for general use |
| `LITELLM_MODEL_ALIAS_FABLE` | Claude Fable equivalent |
| `LITELLM_MODEL_ALIAS_SONNET` | Claude Sonnet equivalent |
| `LITELLM_MODEL_ALIAS_OPUS` | Claude Opus equivalent |
| `LITELLM_MODEL_ALIAS_HAIKU` | Claude Haiku equivalent (fast/cheap) |
| `LITELLM_MODEL_ALIAS_SONNET_1M` | Sonnet with 1M context |
| `LITELLM_MODEL_ALIAS_OPUS_1M` | Opus with 1M context |
| `LITELLM_MODEL_ALIAS_OPUSPLAN` | Opus for planning tasks |

## Community Disclaimer

This is a community-maintained repository. Anyone can contribute recipes, and contributions are merged on the basis of quality -- correct format, working structure, and adherence to the recipe spec. Beyond that bar, **the repository creator assumes no responsibility for third-party content**.

By contributing, you represent that you are responsible for your own submissions: their correctness, their legal standing, and any downstream effects of the configurations they describe. Merging a PR is a quality signal, not an endorsement.

Users are encouraged to review recipe contents before applying them -- that's what `cf init --plan` is for.

## License

Same as [CodeFreedom](https://github.com/nilayparikh/codefreedom) -- MIT.
