# Scripts

Helper scripts for the `costeffective-coding` recipe.

## setup-secrets.sh / setup-secrets.ps1

Assisted secret setup for all API keys and tokens used by this recipe.

### What it does

1. **Placeholder mode** — edit the placeholder values at the top of the script,
   then run it. No interactive prompts for pre-filled values.

2. **Interactive mode** — leave placeholders empty (default) and the script
   prompts you one by one. Press ENTER with no input to skip a secret.

3. **Existing value detection** — if a `CF_CLI_*` variable is already set in
   your environment, the script shows the masked value and asks:
   - `[K]eep` — use the existing value as-is
   - `[O]verwrite` — enter a new value (Enter to skip and keep the old one)

4. **Summary** — at the end, prints how many secrets were set and which
   services will fail due to missing keys.

5. **CF*CLI*\* prefix** — all secrets are persisted as `CF_CLI_<VAR>=value` in
   your shell profile. CodeFreedom's env chain strips the `CF_CLI_` prefix
   automatically at the highest priority tier.

### Usage

```bash
# Bash / Zsh
bash <CODEFREEDOM_HOME>/scripts/costeffective-coding/setup-secrets.sh

# If permission denied:
chmod +x <CODEFREEDOM_HOME>/scripts/costeffective-coding/setup-secrets.sh
<CODEFREEDOM_HOME>/scripts/costeffective-coding/setup-secrets.sh

# PowerShell
<CODEFREEDOM_HOME>\scripts\costeffective-coding\setup-secrets.ps1

# If execution policy blocks:
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### Secrets managed

| Variable                       | Provider               | Required                              |
| ------------------------------ | ---------------------- | ------------------------------------- |
| `LITELLM_MASTER_KEY`           | Proxy auth             | Yes (default: `sk-codefreedom-local`) |
| `DEEPSEEK_API_KEY`             | DeepSeek               | No (skip to disable)                  |
| `MICROSOFT_FOUNDRY_API_BASE`   | Azure Foundry          | No (skip to disable)                  |
| `MICROSOFT_FOUNDRY_API_KEY`    | Azure Foundry          | No (skip to disable)                  |
| `OPENCODE_ZEN_API_KEY`         | OpenCode Zen           | No (skip to disable)                  |
| `OPENROUTER_API_KEY`           | OpenRouter             | No (skip to disable)                  |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | Git in sandbox         | No (skip to disable)                  |
| `GH_TOKEN`                     | Git in sandbox (alias) | No (skip to disable)                  |

### Where secrets are persisted

| Shell      | Profile file                      |
| ---------- | --------------------------------- |
| Bash       | `~/.bashrc`                       |
| Zsh        | `~/.zshrc`                        |
| PowerShell | `$PROFILE.CurrentUserCurrentHost` |

The script writes inside a marker block so re-running replaces previous values
rather than appending.

### Re-running

Safe to re-run at any time. The script removes its previous marker block from
your profile before writing new values.

### See also

- `.env.proxy.secrets` — file-based secret fallback (lower priority than `CF_CLI_*`)
- `.env.claude.secrets`, `.env.mimo.secrets`, `.env.opencode.secrets` — agent-specific secrets
