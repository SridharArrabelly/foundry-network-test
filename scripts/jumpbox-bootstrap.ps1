# jumpbox-bootstrap.ps1
# Runs ON THE JUMPBOX VM via `az vm run-command invoke`. Installs Python,
# downloads the repo zip, and runs scripts/setup_aisearch_index.py using the
# VM's system-assigned managed identity to auth to AI Search + Foundry.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $RepoUrl,
    [Parameter(Mandatory = $true)] [string] $RepoBranch,
    [Parameter(Mandatory = $true)] [string] $AiSearchEndpoint,
    [Parameter(Mandatory = $true)] [string] $AiFoundryEndpoint,
    [string] $AiSearchIndexName = 'documents-index',
    [string] $EmbeddingModel = 'text-embedding-3-large',
    [string] $EmbeddingDimensions = '3072'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Step($msg) { Write-Host "==> $msg" }

# 1) Install Python silently if missing.
$pyCmd = Get-Command python -ErrorAction SilentlyContinue
$pythonExe = if ($pyCmd) { $pyCmd.Source } else { $null }
if (-not $pythonExe) {
    Write-Step "Installing Python 3.12 (silent)..."
    $installer = "$env:TEMP\python-installer.exe"
    Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe' -OutFile $installer -UseBasicParsing
    Start-Process -FilePath $installer -ArgumentList '/quiet','InstallAllUsers=1','PrependPath=1','Include_pip=1' -Wait
    $pythonExe = 'C:\Program Files\Python312\python.exe'
    if (-not (Test-Path $pythonExe)) { throw "Python install failed." }
}
Write-Step "Python: $pythonExe"

# 2) Download repo archive.
$workDir = "$env:TEMP\foundry-network-test"
if (Test-Path $workDir) { Remove-Item -Recurse -Force $workDir }
New-Item -ItemType Directory -Path $workDir | Out-Null

$archiveUrl = "$($RepoUrl.TrimEnd('.git'))/archive/refs/heads/$RepoBranch.zip"
$zipPath = "$env:TEMP\repo.zip"
Write-Step "Downloading $archiveUrl"
Invoke-WebRequest -Uri $archiveUrl -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath $workDir -Force
$repoRoot = (Get-ChildItem $workDir -Directory | Select-Object -First 1).FullName
Write-Step "Repo extracted to $repoRoot"

# 3) Install python deps.
Push-Location $repoRoot
try {
    Write-Step "Installing python dependencies..."
    & $pythonExe -m pip install --quiet --upgrade pip
    & $pythonExe -m pip install --quiet -r scripts/requirements.txt

    # 4) Set env vars for the script (DefaultAzureCredential will use the VM MI).
    $env:AI_SEARCH_ENDPOINT      = $AiSearchEndpoint
    $env:AI_FOUNDRY_ENDPOINT     = $AiFoundryEndpoint
    $env:AI_SEARCH_INDEX_NAME    = $AiSearchIndexName
    $env:EMBEDDING_MODEL         = $EmbeddingModel
    $env:EMBEDDING_DIMENSIONS    = $EmbeddingDimensions

    Write-Step "Running setup_aisearch_index.py"
    & $pythonExe scripts/setup_aisearch_index.py
    if ($LASTEXITCODE -ne 0) { throw "setup_aisearch_index.py exited with $LASTEXITCODE" }
    Write-Step "Indexing complete."
}
finally {
    Pop-Location
}
