# Provider `order` Routing Priority Scheme

LiteLLM uses the `order` field on each deployment to control failover routing:
**lower number = tried first**. When a deployment hits a rate-limit, auth error,
or timeout, LiteLLM walks the order ascending until it finds a healthy one.

This file documents the reserved numbering scheme used across all provider YAMLs
in this directory. **Do not reuse a slot that is already reserved.**

## Slots

### Tier 1 — Free models (slots 1–9)

Lower numbers = preferred free provider.

| Slot | Provider | Anchor in YAML | Notes |
|------|----------|----------------|-------|
| `1`  | OpenCode Zen (free tier) | `opencode.yaml` → `free_model_routing_params` | Free OpenCode models. 12 h cooldown after rate-limit. |
| `1`  | **Local** *(shared with OpenCode free)* | `local.yaml` → `&local_params` *(only in `-with-local` recipe)* | Host-machine local backend. **60 s cooldown** (intentionally shorter than cloud free tier — local failures are usually transient and we want a tight retry loop). |
| `2`  | OpenRouter (free tier)  | `openrouter.yaml` → `free_model_routing_params` | Free OpenRouter models. 12 h cooldown after rate-limit. |
| `3`–`9` | *reserved* | — | Available for future free providers. |

### Tier 2 — Subscription (slots 10–25)

Flat-rate / metered subscriptions. Used after free tier is exhausted.

| Slot | Provider | Anchor in YAML | Notes |
|------|----------|----------------|-------|
| `10` | OpenCode Zen (subscription / GO) | `opencode.yaml` → `sub_model_routing_params` | OpenCode subscription. 60 s cooldown. |
| `11` | Cline Pass | `cline-pass.yaml` → `sub_model_routing_params` | Flat-rate subscription. 60 s cooldown. |
| `12`–`25` | *reserved* | — | Available for future subscription providers. |

### Tier 3 — Pay-per-token (slots 26–98)

| Slot | Provider | Anchor in YAML | Notes |
|------|----------|----------------|-------|
| `26` | Microsoft Foundry (Azure) | `azure-foundry.yaml` → `azure_routing_params` | First pay-per-token tier. 60 s cooldown, 300 s timeout (Azure has higher per-request latency). |
| `27`–`98` | *reserved* | — | Available for future pay-per-token providers. |

### Tier 4 — Last-resort (slot 99)

| Slot | Provider | Anchor in YAML | Notes |
|------|----------|----------------|-------|
| `99` | OpenRouter (pay-per-token) | `openrouter.yaml` → `open_routing_params` | Last-resort fallback when all free + subscription tiers are exhausted. 60 s cooldown. |

## Rules for adding a new provider

1. **Pick the next free slot in the correct tier.** Never reuse a reserved slot.
2. **Mirror the cooldown pattern** of other providers in the same tier
   (cloud free = 12 h cooldown; local free / subscription / pay = 60 s cooldown).
3. **Set `timeout: 120`** for normal providers; use `300` only when the provider
   has inherently higher per-request latency (e.g. Azure Foundry).
4. **Update this file** with the new slot assignment.

## Reserved gap policy

Slots `3`–`9`, `12`–`25`, and `27`–`98` are intentionally left empty so a new
provider can be added without renumbering existing deployments. Do not collapse
the gaps — the visible numbers are a contract, not a sequence.
