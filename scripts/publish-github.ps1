# Creates the GitHub repo and pushes rain battle (run after: gh auth login)
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $repoRoot

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Error "GitHub CLI (gh) is not installed. Install with: winget install GitHub.cli"
}

gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not logged into GitHub. Run: gh auth login"
}

$remote = git remote get-url origin 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Remote already set: $remote"
    git push -u origin main
    exit 0
}

gh repo create rain-battle --public --source=. --remote=origin --push --description "Rain Battle Roblox game (Rojo) with ClassicSword fire effects"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create or push repository."
}

Write-Host "Done. Repository published to GitHub."
