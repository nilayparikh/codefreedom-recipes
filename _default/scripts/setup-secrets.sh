#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# CodeFreedom — Assisted Secret Setup (Bash / Zsh)
# Recipe: _default
# ═══════════════════════════════════════════════════════════════════════════════
#
# USAGE:
#   1. Edit the placeholder values below (or leave empty to be prompted).
#   2. Run:  bash scripts/setup-secrets.sh
#          (if permission denied: chmod +x scripts/setup-secrets.sh && ./scripts/setup-secrets.sh)
#
# WHAT IT DOES:
#   - Sets CF_CLI_* environment variables so CodeFreedom's env chain can
#     read and interpolate them at runtime.
#   - Persists them in your shell profile (~/.bashrc or ~/.zshrc) inside a
#     marker block so re-running the script replaces the previous values.
#   - Exports them in the current session immediately.
#
# Press ENTER at any prompt with no input to SKIP that secret (not set).
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Placeholder values ───────────────────────────────────────────────────────
# Edit these before running, OR leave empty to be prompted interactively.
# Press ENTER at the prompt to skip (the service will not be available).

LITELLM_MASTER_KEY=""               # Proxy master key (default: sk-codefreedom-local)
GITHUB_PERSONAL_ACCESS_TOKEN=""     # https://github.com/settings/tokens
GH_TOKEN=""                         # Alias — usually same as GITHUB_PERSONAL_ACCESS_TOKEN

# ── Marker for shell profile block (do not edit) ─────────────────────────────
MARKER_BEGIN="# >>> codefreedom:_default secrets >>>"
MARKER_END="# <<< codefreedom:_default secrets <<<"

# ── Colors ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    BOLD="\033[1m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    RED="\033[31m"
    CYAN="\033[36m"
    DIM="\033[2m"
    RESET="\033[0m"
else
    BOLD="" GREEN="" YELLOW="" RED="" CYAN="" DIM="" RESET=""
fi

# ── Secret definitions ────────────────────────────────────────────────────────
# Format: VARIABLE_NAME|DISPLAY_NAME|DESCRIPTION|URL|DEFAULT_VALUE
# DEFAULT_VALUE: "-" means no default (will be skipped if empty)

SECRETS=(
    "LITELLM_MASTER_KEY|LiteLLM Master Key|Proxy authentication (clients use this to talk to the proxy)|-|sk-codefreedom-local"
    "GITHUB_PERSONAL_ACCESS_TOKEN|GitHub PAT|Git push/pull in sandbox mode|https://github.com/settings/tokens|-"
    "GH_TOKEN|GitHub Token (alias)|Alias for GITHUB_PERSONAL_ACCESS_TOKEN|-|-"
)

# ── Service → secret mapping (for failure summary) ───────────────────────────
# Format: SERVICE_NAME|REQUIRED_SECRETS (comma-separated, ALL required)
SERVICES=(
    "LiteLLM Proxy|LITELLM_MASTER_KEY"
    "Git in Sandbox|GITHUB_PERSONAL_ACCESS_TOKEN"
)

# ── Functions ─────────────────────────────────────────────────────────────────

prompt_secret() {
    local var_name="$1"
    local display_name="$2"
    local description="$3"
    local url="$4"
    local default="$5"
    local current_value="${!var_name:-}"
    local cf_cli_var="CF_CLI_${var_name}"
    local env_existing="${!cf_cli_var:-}"

    # If already set in script header, use that value
    if [[ -n "$current_value" ]]; then
        echo -e "  ${GREEN}✔${RESET} ${BOLD}${display_name}${RESET} ${DIM}(from script placeholder)${RESET}"
        SECRET_VALUES["$var_name"]="$current_value"
        return
    fi

    # If CF_CLI_* already set in environment, ask user what to do
    if [[ -n "$env_existing" ]]; then
        local masked
        if [[ ${#env_existing} -le 2 ]]; then
            masked="****"
        else
            masked="${env_existing:0:1}...${env_existing: -1}"
        fi
        echo -e ""
        echo -e "  ${CYAN}${BOLD}${display_name}${RESET}"
        echo -e "  ${YELLOW}Found existing ${cf_cli_var}=${masked}${RESET}"
        echo -e "  ${DIM}${description}${RESET}"
        local overwrite_choice=""
        read -r -p "$(echo -e "  > [K]eep existing  [O]verwrite  (Enter to keep): ")" overwrite_choice
        case "${overwrite_choice,,}" in
            o)
                echo -e "  ${DIM}Overwriting — enter new value (Enter to skip):${RESET}"
                read -r -p "  > " user_input
                if [[ -n "$user_input" ]]; then
                    SECRET_VALUES["$var_name"]="$user_input"
                    echo -e "  ${GREEN}✔${RESET} Overwritten"
                else
                    echo -e "  ${YELLOW}⊘${RESET} Skipped (previous value kept in environment)"
                fi
                ;;
            *)
                echo -e "  ${GREEN}✔${RESET} Keeping existing value"
                SECRET_VALUES["$var_name"]="$env_existing"
                ;;
        esac
        return
    fi

    # Prompt interactively
    echo -e ""
    echo -e "  ${CYAN}${BOLD}${display_name}${RESET}"
    echo -e "  ${DIM}${description}${RESET}"
    if [[ "$url" != "-" ]]; then
        echo -e "  ${DIM}Get one: ${url}${RESET}"
    fi

    local prompt_text="  > Enter value"
    if [[ "$default" != "-" ]]; then
        prompt_text="${prompt_text} [default: ${default}]"
    fi
    prompt_text="${prompt_text} (Enter to skip): "

    read -r -p "$(echo -e "$prompt_text")" user_input

    if [[ -n "$user_input" ]]; then
        SECRET_VALUES["$var_name"]="$user_input"
        echo -e "  ${GREEN}✔${RESET} Set"
    elif [[ "$default" != "-" ]]; then
        SECRET_VALUES["$var_name"]="$default"
        echo -e "  ${GREEN}✔${RESET} Using default"
    else
        echo -e "  ${YELLOW}⊘${RESET} Skipped"
    fi
}

detect_shell_profile() {
    local shell_name
    shell_name="$(basename "${SHELL:-/bin/bash}")"
    case "$shell_name" in
        zsh)  echo "${ZDOTDIR:-$HOME}/.zshrc" ;;
        bash) echo "$HOME/.bashrc" ;;
        *)    echo "$HOME/.profile" ;;
    esac
}

remove_existing_block() {
    local profile="$1"
    if [[ -f "$profile" ]] && grep -qF "$MARKER_BEGIN" "$profile"; then
        # Remove existing block between markers (inclusive)
        sed -i.bak "/$MARKER_BEGIN/,/$MARKER_END/d" "$profile"
        rm -f "${profile}.bak"
    fi
}

write_to_profile() {
    local profile="$1"
    remove_existing_block "$profile"

    {
        echo ""
        echo "$MARKER_BEGIN"
        echo "# Added by: scripts/setup-secrets.sh ($(date '+%Y-%m-%d %H:%M'))"
        for secret_def in "${SECRETS[@]}"; do
            IFS='|' read -r var_name _ _ _ _ <<< "$secret_def"
            local val="${SECRET_VALUES[$var_name]:-}"
            if [[ -n "$val" ]]; then
                echo "export CF_CLI_${var_name}=\"${val}\""
            fi
        done
        echo "$MARKER_END"
        echo ""
    } >> "$profile"
}

export_current_session() {
    for secret_def in "${SECRETS[@]}"; do
        IFS='|' read -r var_name _ _ _ _ <<< "$secret_def"
        local val="${SECRET_VALUES[$var_name]:-}"
        if [[ -n "$val" ]]; then
            export "CF_CLI_${var_name}=${val}"
        fi
    done
}

print_summary() {
    local set_count=0
    local skipped_secrets=()
    local set_secrets=()

    echo -e ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}  Secret Setup Summary${RESET}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e ""

    for secret_def in "${SECRETS[@]}"; do
        IFS='|' read -r var_name display_name _ _ _ <<< "$secret_def"
        local val="${SECRET_VALUES[$var_name]:-}"
        if [[ -n "$val" ]]; then
            # Mask value — show first and last char only
            local masked
            if [[ ${#val} -le 2 ]]; then
                masked="****"
            else
                masked="${val:0:1}...${val: -1}"
            fi
            echo -e "  ${GREEN}✔${RESET} ${var_name}=${DIM}${masked}${RESET}"
            ((set_count++))
            set_secrets+=("$var_name")
        else
            echo -e "  ${YELLOW}⊘${RESET} ${var_name} ${DIM}(skipped)${RESET}"
            skipped_secrets+=("$var_name")
        fi
    done

    echo -e ""
    echo -e "  ${BOLD}Set:${RESET} ${GREEN}${set_count}${RESET} / ${#SECRETS[@]} secrets"
    echo -e ""

    # ── Service failure analysis ──────────────────────────────────────────────
    local failing_services=()
    for service_def in "${SERVICES[@]}"; do
        IFS='|' read -r service_name required_keys <<< "$service_def"
        IFS=',' read -ra required_arr <<< "$required_keys"

        local all_set=true
        for key in "${required_arr[@]}"; do
            if [[ -z "${SECRET_VALUES[$key]:-}" ]]; then
                all_set=false
                break
            fi
        done

        if [[ "$all_set" == false ]]; then
            failing_services+=("$service_name")
            local missing_list=""
            for key in "${required_arr[@]}"; do
                if [[ -z "${SECRET_VALUES[$key]:-}" ]]; then
                    [[ -n "$missing_list" ]] && missing_list+=", "
                    missing_list+="$key"
                fi
            done
            echo -e "  ${RED}✗${RESET} ${BOLD}${service_name}${RESET} ${DIM}— missing: ${missing_list}${RESET}"
        fi
    done

    echo -e ""
    if [[ ${#failing_services[@]} -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}All services configured!${RESET}"
    else
        echo -e "  ${RED}${BOLD}${#failing_services[@]} service(s) will fail:${RESET}"
        for svc in "${failing_services[@]}"; do
            echo -e "    ${RED}•${RESET} $svc"
        done
        echo -e ""
        echo -e "  ${DIM}Re-run this script or export missing CF_CLI_* vars manually.${RESET}"
    fi

    echo -e ""
    echo -e "  ${DIM}Persisted to: ${SHELL_PROFILE}${RESET}"
    echo -e "  ${DIM}Restart your shell or run: source ${SHELL_PROFILE}${RESET}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

declare -A SECRET_VALUES
SHELL_PROFILE="$(detect_shell_profile)"

echo -e ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  CodeFreedom — Assisted Secret Setup${RESET}"
echo -e "${DIM}  Recipe: _default${RESET}"
echo -e "${DIM}  Setting CF_CLI_* env vars in: ${SHELL_PROFILE}${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e ""
echo -e "${DIM}Enter a value to set, or press ENTER to skip.${RESET}"
echo -e "${DIM}To pre-fill values, edit the placeholders at the top of this script.${RESET}"

for secret_def in "${SECRETS[@]}"; do
    IFS='|' read -r var_name display_name description url default <<< "$secret_def"
    prompt_secret "$var_name" "$display_name" "$description" "$url" "$default"
done

# Persist to shell profile
write_to_profile "$SHELL_PROFILE"

# Export in current session
export_current_session

# Print summary
print_summary
