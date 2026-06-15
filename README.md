# CodeFreedom Recipes

A **recipe** is a pre-built configuration bundle that wires up your proxy, profiles, and provider settings in one command. Pick the recipe that matches your API keys and go.

## Quick Start

```bash
# See what's available
cf s i -l

# Plan + apply (shows preview, prompts to confirm, then installs)
cf s i -pa costeffective-coding
```

After installing, set your API keys when prompted, then:

```bash
cf r px start      # start proxy + tools
cf r ag cc          # launch your agent
```

## Available Recipes

| Recipe | Description | API Keys Needed |
|--------|-------------|-----------------|
| [costeffective-coding](costeffective-coding/) | Cloud providers only -- Azure, OpenCode, OpenRouter | `MICROSOFT_FOUNDRY_API_KEY`, `OPENCODE_ZEN_API_KEY`, `OPENROUTER_API_KEY` |
| [costeffective-coding-with-local](costeffective-coding-with-local/) | Cloud providers + local inference (vLLM, Ollama, etc.) | Same as above + local backend keys (optional, any value) |

Both recipes extend `_default`, which provides shared tool profiles, base proxy config, and plugins.

## What a Recipe Does

When you run `cf s i -pa <recipe>`, it:

1. **Shows a preview** of every file it will create, with diffs
2. **Prompts for API keys** (secrets)
3. **Installs config** into `~/.codefreedom/` (proxy config, profiles, env files)
4. **Checks secrets** to confirm everything is wired up

Your existing config is preserved -- recipe files merge on top, they don't overwrite.

## Switching Recipes

```bash
cf s i -pa <new-recipe>
```

Orphaned files from the previous recipe are cleaned up automatically.

## Custom Recipe Store

Point to your own recipe repo:

```bash
# GitHub repository
cf s i --store https://github.com/your-org/my-recipes

# Local folder
cf s i --store /path/to/my-recipes
```

## Creating a Recipe

See the existing recipes for examples. Each recipe is a folder containing:

- `recipe.yaml` -- manifest (files, secrets, config)
- Config files referenced by the manifest

```yaml
name: my-recipe
extends: _default
description: "My custom LLM setup"
version: 1

files:
  - path: .env.proxy
    target: .env.proxy
    merge: env
  - path: .env.proxy.secrets
    target: .env.proxy.secrets
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

config_vars:
  - var: MY_PROVIDER_BASE_URL
    prompt: "Provider base URL"
    hint: "Region-specific endpoint"
```

## License

Same as [CodeFreedom](https://github.com/nilayparikh/codefreedom) -- Apache 2.0.
