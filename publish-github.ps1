param(
  [string]$RepoName = "af20-upgrade-page-gallery",
  [switch]$Public
)

$ErrorActionPreference = "Stop"
if (Get-Variable PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
  $PSNativeCommandUseErrorActionPreference = $false
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw "GitHub CLI (gh) is not installed."
}

cmd /c "gh auth status >nul 2>nul"
if ($LASTEXITCODE -ne 0) {
  Write-Output "GitHub CLI is not logged in. Run: gh auth login"
  exit 1
}

$visibility = if ($Public) { "--public" } else { "--private" }
$owner = gh api user --jq ".login"

git branch -M main

$remote = git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0) {
  gh repo create $RepoName $visibility --source . --remote origin --push
} else {
  git push -u origin main
}

$repoFullName = "$owner/$RepoName"

try {
  $pagesConfig = New-TemporaryFile
  Set-Content -LiteralPath $pagesConfig -Value '{"source":{"branch":"main","path":"/docs"}}' -Encoding ASCII

  gh api -X POST "repos/$repoFullName/pages" `
    -H "Accept: application/vnd.github+json" `
    --input $pagesConfig 2>$null

  if ($LASTEXITCODE -ne 0) {
    gh api -X PUT "repos/$repoFullName/pages" `
      -H "Accept: application/vnd.github+json" `
      --input $pagesConfig
  }
} finally {
  if ($pagesConfig -and (Test-Path $pagesConfig)) {
    Remove-Item -LiteralPath $pagesConfig -Force
  }
}

$pagesUrl = gh api "repos/$repoFullName/pages" --jq ".html_url"
$repoUrl = "https://github.com/$repoFullName"

Write-Output "Repository: $repoUrl"
Write-Output "Pages: $pagesUrl"
Write-Output "Weekly report: $repoUrl/blob/main/docs/AF20升级款_周报_2026-07-21_2026-07-27.md"
