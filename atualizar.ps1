param(
  [switch]$Auto
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $Root '.env'
$VersionFile = Join-Path $Root 'VERSION'

function Get-EnvValue([string]$Name) {
  if (-not (Test-Path $EnvFile)) { return $null }
  $line = Get-Content $EnvFile | Where-Object { $_ -match "^$([regex]::Escape($Name))=(.*)$" } | Select-Object -Last 1
  if (-not $line) { return $null }
  $value = ($line -split '=', 2)[1].Trim().Trim('"').Trim("'")
  return [Environment]::ExpandEnvironmentVariables($value)
}

function Write-Info([string]$Message) { Write-Host "[MIRA] $Message" }
function Write-Warn([string]$Message) { Write-Host "[AVISO] $Message" -ForegroundColor Yellow }

function Invoke-RobocopyMirror([string]$Source, [string]$Destination) {
  if (-not (Test-Path $Destination)) { New-Item -ItemType Directory -Path $Destination -Force | Out-Null }
  & robocopy $Source $Destination /MIR /XD node_modules .next .yarn /XF .env .env.local tsconfig.tsbuildinfo /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -gt 7) {
    throw "Robocopy falhou com codigo $LASTEXITCODE"
  }
}

if (-not (Test-Path $EnvFile)) {
  Write-Warn '.env nao encontrado. Execute instalar.bat primeiro.'
  exit 0
}

$UpdatePath = Get-EnvValue 'MIRA_UPDATE_PATH'
if ([string]::IsNullOrWhiteSpace($UpdatePath) -or $UpdatePath -match 'SERVIDOR\\PASTA_ETL|COLE_AQUI|TROQUE_AQUI') {
  Write-Warn 'MIRA_UPDATE_PATH ainda nao foi configurado no .env. Nenhuma atualizacao foi aplicada.'
  exit 0
}

if (-not (Test-Path $UpdatePath)) {
  Write-Warn "Pasta de atualizacao inacessivel: $UpdatePath"
  exit 0
}

$ManifestPath = Join-Path $UpdatePath 'update-manifest.json'
if (-not (Test-Path $ManifestPath)) {
  Write-Warn "Manifesto nao encontrado: $ManifestPath"
  exit 0
}

$Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
if (-not $Manifest.version -or -not $Manifest.package -or -not $Manifest.sha256) {
  throw 'update-manifest.json invalido. Campos obrigatorios: version, package, sha256.'
}

$LocalVersion = '0.0.0.0'
if (Test-Path $VersionFile) {
  $LocalVersion = (Get-Content $VersionFile -Raw).Trim()
}

try {
  $RemoteVersionObj = [version]$Manifest.version
  $LocalVersionObj = [version]$LocalVersion
  if ($RemoteVersionObj -le $LocalVersionObj) {
    Write-Info "Versao local $LocalVersion ja esta atualizada."
    exit 0
  }
} catch {
  if ($Manifest.version -eq $LocalVersion) {
    Write-Info "Versao local $LocalVersion ja esta atualizada."
    exit 0
  }
  Write-Warn 'Versao fora do formato numerico padrao; sera aplicada por diferenca de versao.'
}

$PackagePath = Join-Path $UpdatePath $Manifest.package
if (-not (Test-Path $PackagePath)) {
  throw "Pacote de atualizacao nao encontrado: $PackagePath"
}

Write-Info "Nova versao encontrada: $LocalVersion -> $($Manifest.version)"

$TempRoot = Join-Path $env:TEMP ("MIRA-EVO-update-" + [guid]::NewGuid().ToString('N'))
$TempZip = Join-Path $TempRoot 'update.zip'
$ExtractDir = Join-Path $TempRoot 'extract'
New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
Copy-Item $PackagePath $TempZip -Force

$Hash = (Get-FileHash $TempZip -Algorithm SHA256).Hash.ToLowerInvariant()
$ExpectedHash = ([string]$Manifest.sha256).ToLowerInvariant()
if ($Hash -ne $ExpectedHash) {
  Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
  throw "Checksum SHA-256 invalido. Esperado $ExpectedHash, recebido $Hash. Atualizacao cancelada."
}
Write-Info 'Checksum SHA-256 validado.'

Expand-Archive -Path $TempZip -DestinationPath $ExtractDir -Force
$SourceApp = Join-Path $ExtractDir 'nextjs_space'
if (-not (Test-Path $SourceApp)) {
  Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
  throw 'Pacote invalido: pasta nextjs_space nao encontrada.'
}

$TargetApp = Join-Path $Root 'nextjs_space'
$BackupsDir = Join-Path $Root 'backups'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupApp = Join-Path $BackupsDir ("nextjs_space-$Stamp")
New-Item -ItemType Directory -Path $BackupsDir -Force | Out-Null

Write-Info "Criando backup do codigo em $BackupApp"
Invoke-RobocopyMirror $TargetApp $BackupApp

try {
  Write-Info 'Aplicando arquivos da atualizacao...'
  Invoke-RobocopyMirror $SourceApp $TargetApp

  Copy-Item $EnvFile (Join-Path $TargetApp '.env') -Force

  Push-Location $TargetApp
  try {
    if (Test-Path 'yarn.lock') {
      & yarn install --frozen-lockfile
      if ($LASTEXITCODE -ne 0) { throw 'yarn install --frozen-lockfile falhou.' }
    } else {
      & yarn install
      if ($LASTEXITCODE -ne 0) { throw 'yarn install falhou.' }
    }

    & yarn prisma generate
    if ($LASTEXITCODE -ne 0) { throw 'prisma generate falhou.' }

    & yarn build
    if ($LASTEXITCODE -ne 0) { throw 'yarn build falhou.' }
  } finally {
    Pop-Location
  }

  Set-Content -Path $VersionFile -Value ([string]$Manifest.version) -Encoding ASCII
  Write-Info "Atualizacao concluida. Versao atual: $($Manifest.version)"
} catch {
  Write-Warn "Falha durante a atualizacao: $($_.Exception.Message)"
  Write-Warn 'Restaurando backup do codigo...'
  Invoke-RobocopyMirror $BackupApp $TargetApp
  Copy-Item $EnvFile (Join-Path $TargetApp '.env') -Force
  throw
} finally {
  Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

if (-not $Auto) {
  Write-Host ''
  Write-Host 'Atualizacao finalizada. Pressione Enter para sair.'
  [void](Read-Host)
}
