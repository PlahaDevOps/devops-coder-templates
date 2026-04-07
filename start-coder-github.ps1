# Start Coder (Docker). GitHub OAuth is optional via coder-github.env — see coder-github.env.example
#
# GitHub OAuth App callback URL (must match CODER_ACCESS_URL):
#   http://localhost:3000/api/v2/users/oauth2/github/callback
#
# Usage:
#   Copy coder-github.env.example to coder-github.env, set Client ID and Secret, then:
#   .\start-coder-github.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$EnvFile = Join-Path $ScriptDir "coder-github.env"

if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) { return }
        $eq = $line.IndexOf("=")
        if ($eq -lt 1) { return }
        $key = $line.Substring(0, $eq).Trim()
        $val = $line.Substring($eq + 1).Trim().Trim([char]0x22)
        if ($key) { Set-Item -Path "Env:$key" -Value $val }
    }
}

$clientId = $env:CODER_OAUTH2_GITHUB_CLIENT_ID
$clientSecret = $env:CODER_OAUTH2_GITHUB_CLIENT_SECRET
$placeholderId = @("YOUR_CLIENT_ID", "your_client_id", "<from GitHub>", "")
$placeholderSecret = @("YOUR_CLIENT_SECRET", "your_client_secret", "<from GitHub>", "")
$hasOAuth =
    $clientId -and $clientSecret -and
    ($clientId -notin $placeholderId) -and ($clientSecret -notin $placeholderSecret) -and
    ($clientId -notmatch "^\s*<") -and ($clientSecret -notmatch "^\s*<")

# Remove old container if present (ignore missing)
$ErrorActionPreference = "SilentlyContinue"
docker rm -f coder 2>$null | Out-Null
$ErrorActionPreference = "Stop"

$runArgs = @(
    "run", "-d", "--name", "coder", "--restart", "unless-stopped",
    "-e", "CODER_ACCESS_URL=http://localhost:3000",
    "-e", "CODER_HTTP_ADDRESS=0.0.0.0:3000",
    "-v", "/var/run/docker.sock:/var/run/docker.sock",
    "-v", "C:/Users/admin/Desktop/DevOps_work/Coder/coder-data:/home/coder/.config",
    "--privileged",
    "-p", "3000:3000"
)

if ($hasOAuth) {
    $runArgs += @(
        "-e", "CODER_OAUTH2_GITHUB_CLIENT_ID=$clientId",
        "-e", "CODER_OAUTH2_GITHUB_CLIENT_SECRET=$clientSecret",
        "-e", "CODER_OAUTH2_GITHUB_ALLOW_SIGNUPS=true"
    )
    Write-Host "Starting Coder with GitHub OAuth."
} else {
    if ($clientId -and ($clientId -notin $placeholderId) -and ((-not $clientSecret) -or ($clientSecret -in $placeholderSecret))) {
        Write-Warning @"
GitHub Client ID is set but Client Secret is missing or still a placeholder.
  1. GitHub: Settings / Developer settings / OAuth Apps / Coder Local
  2. Click 'Generate a new client secret', copy the value once
  3. Set CODER_OAUTH2_GITHUB_CLIENT_SECRET in coder-github.env (no quotes)
  4. Callback URL on the app must be: http://localhost:3000/api/v2/users/oauth2/github/callback
  5. Run this script again
"@
    } else {
        Write-Warning @"
GitHub OAuth is not configured (missing or placeholder values in coder-github.env).
Coder will start with built-in authentication. To enable GitHub login:
  1. Copy coder-github.env.example to coder-github.env
  2. Set CODER_OAUTH2_GITHUB_CLIENT_ID and CODER_OAUTH2_GITHUB_CLIENT_SECRET
  3. Run this script again (container will be recreated)
"@
    }
}

$runArgs += "ghcr.io/coder/coder:latest"
& docker @runArgs

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Coder container: http://localhost:3000"
$status = docker inspect coder -f "{{.State.Status}}" 2>$null
if ($status) { Write-Host "State: $status" }
