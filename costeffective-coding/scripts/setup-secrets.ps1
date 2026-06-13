#!/usr/bin/env pwsh
#Requires -Version 5.1
<#
.SYNOPSIS
    CodeFreedom — Assisted Secret Setup (PowerShell)
    Recipe: costeffective-coding

.DESCRIPTION
    Sets CF_CLI_* environment variables so CodeFreedom's env chain can read
    and interpolate them at runtime.

    - Persists variables in your PowerShell profile (CurrentUser scope).
    - Exports them in the current session immediately.
    - If a placeholder is empty, prompts interactively (Enter to skip).

.EXAMPLE
    .\scripts\setup-secrets.ps1

.EXAMPLE
    # Pre-fill in script header, then run (no interactive prompts for filled values)
    .\scripts\setup-secrets.ps1

.NOTES
    If running from bash/zsh (e.g. WSL):  pwsh scripts/setup-secrets.ps1
    If execution policy blocks scripts:   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#>

# ═══════════════════════════════════════════════════════════════════════════════
#  Placeholder values — edit before running, OR leave empty to be prompted.
# ═══════════════════════════════════════════════════════════════════════════════

$Placeholders = @{
    LITELLM_MASTER_KEY              = ""   # Proxy master key (default: sk-codefreedom-local)
    MICROSOFT_FOUNDRY_API_BASE      = ""   # Azure AI Foundry endpoint URL
    MICROSOFT_FOUNDRY_API_KEY       = ""   # Azure AI Foundry API key
    OPENCODE_ZEN_API_KEY            = ""   # https://opencode.ai dashboard
    OPENROUTER_API_KEY              = ""   # https://openrouter.ai/keys
    GITHUB_PERSONAL_ACCESS_TOKEN    = ""   # https://github.com/settings/tokens
    GH_TOKEN                        = ""   # Alias — usually same as GITHUB_PERSONAL_ACCESS_TOKEN
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Secret definitions — display name, description, URL, default
# ═══════════════════════════════════════════════════════════════════════════════

$SecretDefs = [ordered]@{
    LITELLM_MASTER_KEY = @{
        Name        = "LiteLLM Master Key"
        Description = "Proxy authentication (clients use this to talk to the proxy)"
        URL         = ""
        Default     = "sk-codefreedom-local"
    }
    MICROSOFT_FOUNDRY_API_BASE = @{
        Name        = "Azure Foundry Base URL"
        Description = "Azure AI Foundry workspace endpoint"
        URL         = ""
        Default     = ""
    }
    MICROSOFT_FOUNDRY_API_KEY = @{
        Name        = "Azure Foundry API Key"
        Description = "Azure AI Foundry API key"
        URL         = ""
        Default     = ""
    }
    OPENCODE_ZEN_API_KEY = @{
        Name        = "OpenCode Zen API Key"
        Description = "Covers both Zen (free) and GO (subscription)"
        URL         = "https://opencode.ai"
        Default     = ""
    }
    OPENROUTER_API_KEY = @{
        Name        = "OpenRouter API Key"
        Description = "Multi-provider routing"
        URL         = "https://openrouter.ai/keys"
        Default     = ""
    }
    GITHUB_PERSONAL_ACCESS_TOKEN = @{
        Name        = "GitHub PAT"
        Description = "Git push/pull in sandbox mode"
        URL         = "https://github.com/settings/tokens"
        Default     = ""
    }
    GH_TOKEN = @{
        Name        = "GitHub Token (alias)"
        Description = "Alias for GITHUB_PERSONAL_ACCESS_TOKEN"
        URL         = ""
        Default     = ""
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Service → required secrets (for failure summary)
# ═══════════════════════════════════════════════════════════════════════════════

$ServiceDefs = [ordered]@{
    "LiteLLM Proxy"             = @("LITELLM_MASTER_KEY")
    "Azure Foundry Provider"    = @("MICROSOFT_FOUNDRY_API_BASE", "MICROSOFT_FOUNDRY_API_KEY")
    "OpenCode Zen Provider"     = @("OPENCODE_ZEN_API_KEY")
    "OpenRouter Provider"       = @("OPENROUTER_API_KEY")
    "Git in Sandbox"            = @("GITHUB_PERSONAL_ACCESS_TOKEN")
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Functions
# ═══════════════════════════════════════════════════════════════════════════════

$Script:SecretValues = @{}
$Script:SetCount = 0

function Write-Header {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
    Write-Host "  CodeFreedom — Assisted Secret Setup" -ForegroundColor White
    Write-Host "  Recipe: costeffective-coding" -ForegroundColor DarkGray
    Write-Host "  Setting CF_CLI_* env vars in PowerShell profile" -ForegroundColor DarkGray
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
    Write-Host ""
    Write-Host "  Enter a value to set, or press ENTER to skip." -ForegroundColor DarkGray
    Write-Host "  To pre-fill values, edit the placeholders at the top of this script." -ForegroundColor DarkGray
}

function Prompt-Secret {
    param(
        [string]$VarName,
        [string]$DisplayName,
        [string]$Description,
        [string]$URL,
        [string]$Default,
        [string]$PlaceholderValue
    )

    # If placeholder is pre-filled, use it
    if ($PlaceholderValue -ne "") {
        Write-Host "  " -NoNewline
        Write-Host [char]0x2714 -ForegroundColor Green -NoNewline
        Write-Host " $DisplayName " -NoNewline
        Write-Host "(from script placeholder)" -ForegroundColor DarkGray
        $Script:SecretValues[$VarName] = $PlaceholderValue
        $Script:SetCount++
        return
    }

    # Check if CF_CLI_* already set in environment
    $cfCliVar = "CF_CLI_$VarName"
    $existingValue = [Environment]::GetEnvironmentVariable($cfCliVar, "Process")
    if (-not $existingValue) { $existingValue = [Environment]::GetEnvironmentVariable($cfCliVar, "User") }
    if (-not $existingValue) { $existingValue = [Environment]::GetEnvironmentVariable($cfCliVar, "Machine") }

    if ($existingValue -and $existingValue -ne "") {
        # Mask value
        if ($existingValue.Length -le 12) { $masked = "****" }
        else { $masked = $existingValue.Substring(0, 8) + "..." + $existingValue.Substring($existingValue.Length - 4) }

        Write-Host ""
        Write-Host "  $DisplayName" -ForegroundColor Cyan
        Write-Host "  Found existing ${cfCliVar}=$masked" -ForegroundColor Yellow
        Write-Host "  $Description" -ForegroundColor DarkGray

        $overwriteChoice = Read-Host -Prompt "  > [K]eep existing  [O]verwrite  (Enter to keep)"
        if ($overwriteChoice -eq "o" -or $overwriteChoice -eq "O") {
            Write-Host "  Overwriting — enter new value (Enter to skip):" -ForegroundColor DarkGray
            $userInput = Read-Host -Prompt "  >"
            if ($userInput -ne "") {
                $Script:SecretValues[$VarName] = $userInput
                Write-Host "  " -NoNewline
                Write-Host [char]0x2714 -ForegroundColor Green -NoNewline
                Write-Host " Overwritten"
                $Script:SetCount++
            }
            else {
                Write-Host "  " -NoNewline
                Write-Host [char]0x2298 -ForegroundColor Yellow -NoNewline
                Write-Host " Skipped (previous value kept in environment)"
            }
        }
        else {
            Write-Host "  " -NoNewline
            Write-Host [char]0x2714 -ForegroundColor Green -NoNewline
            Write-Host " Keeping existing value"
            $Script:SetCount++
        }
        return
    }

    # Prompt interactively
    Write-Host ""
    Write-Host "  $DisplayName" -ForegroundColor Cyan
    Write-Host "  $Description" -ForegroundColor DarkGray
    if ($URL -ne "") {
        Write-Host "  Get one: $URL" -ForegroundColor DarkGray
    }

    $promptText = "  > Enter value"
    if ($Default -ne "") {
        $promptText += " [default: $Default]"
    }
    $promptText += " (Enter to skip): "

    $userInput = Read-Host -Prompt $promptText

    if ($userInput -ne "") {
        $Script:SecretValues[$VarName] = $userInput
        Write-Host "  " -NoNewline
        Write-Host [char]0x2714 -ForegroundColor Green -NoNewline
        Write-Host " Set"
        $Script:SetCount++
    }
    elseif ($Default -ne "") {
        $Script:SecretValues[$VarName] = $Default
        Write-Host "  " -NoNewline
        Write-Host [char]0x2714 -ForegroundColor Green -NoNewline
        Write-Host " Using default"
        $Script:SetCount++
    }
    else {
        Write-Host "  " -NoNewline
        Write-Host [char]0x2298 -ForegroundColor Yellow -NoNewline
        Write-Host " Skipped"
    }
}

function Write-ProfileBlock {
    $profilePath = $PROFILE.CurrentUserCurrentHost
    if (-not (Test-Path $profilePath)) {
        New-Item -Path $profilePath -ItemType File -Force | Out-Null
    }

    $markerBegin = "# >>> codefreedom:costeffective-coding secrets >>>"
    $markerEnd   = "# <<< codefreedom:costeffective-coding secrets <<<"

    # Read existing content and remove old block
    $content = if (Test-Path $profilePath) { Get-Content $profilePath -Raw } else { "" }
    if ($content -and $content.Contains($markerBegin)) {
        $startIdx = $content.IndexOf($markerBegin)
        $endIdx   = $content.IndexOf($markerEnd) + $markerEnd.Length
        $content  = $content.Remove($startIdx, $endIdx - $startIdx)
    }

    # Build new block
    $block = "`n$markerBegin`n# Added by: scripts/setup-secrets.ps1 ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))`n"
    foreach ($varName in $SecretDefs.Keys) {
        if ($Script:SecretValues.ContainsKey($varName) -and $Script:SecretValues[$varName] -ne "") {
            $block += "`$env:CF_CLI_$varName = `"$($Script:SecretValues[$varName])`"`n"
        }
    }
    $block += "$markerEnd`n"

    # Write
    Set-Content -Path $profilePath -Value ($content.TrimEnd() + "`n" + $block) -NoNewline
}

function Export-CurrentSession {
    foreach ($varName in $SecretDefs.Keys) {
        if ($Script:SecretValues.ContainsKey($varName) -and $Script:SecretValues[$varName] -ne "") {
            [Environment]::SetEnvironmentVariable("CF_CLI_$varName", $Script:SecretValues[$varName], "Process")
        }
    }
}

function Write-Summary {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
    Write-Host "  Secret Setup Summary" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
    Write-Host ""

    foreach ($varName in $SecretDefs.Keys) {
        if ($Script:SecretValues.ContainsKey($varName) -and $Script:SecretValues[$varName] -ne "") {
            $val = $Script:SecretValues[$varName]
            if ($val.Length -le 12) {
                $masked = "****"
            } else {
                $masked = $val.Substring(0, 8) + "..." + $val.Substring($val.Length - 4)
            }
            Write-Host "  " -NoNewline
            Write-Host [char]0x2714 -ForegroundColor Green -NoNewline
            Write-Host " $varName=" -NoNewline
            Write-Host $masked -ForegroundColor DarkGray
        }
        else {
            Write-Host "  " -NoNewline
            Write-Host [char]0x2298 -ForegroundColor Yellow -NoNewline
            Write-Host " $varName " -NoNewline
            Write-Host "(skipped)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "  Set: " -NoNewline
    Write-Host "$($Script:SetCount)" -ForegroundColor Green -NoNewline
    Write-Host " / $($SecretDefs.Count) secrets"

    # Service failure analysis
    Write-Host ""

    $failingServices = @()
    foreach ($serviceName in $ServiceDefs.Keys) {
        $requiredKeys = $ServiceDefs[$serviceName]
        $allSet = $true
        $missingList = @()

        foreach ($key in $requiredKeys) {
            if (-not $Script:SecretValues.ContainsKey($key) -or $Script:SecretValues[$key] -eq "") {
                $allSet = $false
                $missingList += $key
            }
        }

        if (-not $allSet) {
            $failingServices += $serviceName
            Write-Host "  " -NoNewline
            Write-Host [char]0x2717 -ForegroundColor Red -NoNewline
            Write-Host " $serviceName " -NoNewline
            Write-Host "— missing: $($missingList -join ', ')" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    if ($failingServices.Count -eq 0) {
        Write-Host "  " -NoNewline
        Write-Host "All services configured!" -ForegroundColor Green
    }
    else {
        Write-Host "  $($failingServices.Count) service(s) will fail:" -ForegroundColor Red
        foreach ($svc in $failingServices) {
            Write-Host "    " -NoNewline
            Write-Host [char]0x2022 -ForegroundColor Red -NoNewline
            Write-Host " $svc"
        }
        Write-Host ""
        Write-Host "  Re-run this script or export missing CF_CLI_* vars manually." -ForegroundColor DarkGray
    }

    Write-Host ""
    $profilePath = $PROFILE.CurrentUserCurrentHost
    Write-Host "  Persisted to: $profilePath" -ForegroundColor DarkGray
    Write-Host "  Restart PowerShell or run: . `$PROFILE" -ForegroundColor DarkGray
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════════════════════════════════

Write-Header

foreach ($varName in $SecretDefs.Keys) {
    $def = $SecretDefs[$varName]
    $placeholder = if ($Placeholders.ContainsKey($varName)) { $Placeholders[$varName] } else { "" }
    Prompt-Secret -VarName $varName `
                  -DisplayName $def.Name `
                  -Description $def.Description `
                  -URL $def.URL `
                  -Default $def.Default `
                  -PlaceholderValue $placeholder
}

Write-ProfileBlock
Export-CurrentSession
Write-Summary
