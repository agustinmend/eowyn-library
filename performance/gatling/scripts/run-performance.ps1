param(
  [string]$BaseUrl,
  [string]$TestEmail = 'admin@example.com',
  [string]$TestPassword = '123456'
)

# Compose writes some non-fatal notices to stderr; each native command is checked
# by its exit code below.
$ErrorActionPreference = 'Continue'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$moduleRoot = Join-Path $repoRoot 'performance\gatling'
$targetRoot = Join-Path $moduleRoot 'target'
$environmentPath = Join-Path $moduleRoot 'config\eowyn-local.postman_environment.json'
$originalLocation = Get-Location
$databaseReady = $false
$exitCode = 1
$samplerProcess = $null
$samplerStopFile = Join-Path $targetRoot 'resource-sampler.stop'
$samplerOutput = $null
$samplerStdout = $null
$samplerStderr = $null
$simulations = @(
  'performance.EowynCatalogSimulation',
  'performance.EowynLoadSimulation',
  'performance.EowynStressSimulation'
)

try {
  if (-not (Test-Path (Join-Path $repoRoot '.env'))) {
    throw 'No existe .env en la raíz. Configúralo una vez a partir de .env.template antes de ejecutar.'
  }

  $postmanEnvironment = Get-Content $environmentPath -Raw | ConvertFrom-Json
  if (-not $BaseUrl) {
    $BaseUrl = ($postmanEnvironment.values | Where-Object key -eq 'host' | Select-Object -First 1).value
  }
  if (-not $BaseUrl) { throw "La variable 'host' está vacía en $environmentPath." }

  $env:BASE_URL = $BaseUrl.TrimEnd('/')
  $env:TEST_EMAIL = $TestEmail
  $env:TEST_PASSWORD = $TestPassword
  New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
  Set-Location $repoRoot

  Write-Host 'Iniciando PostgreSQL local...'
  & docker compose up -d postgres-db
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar postgres-db con Docker Compose.' }

  for ($attempt = 0; $attempt -lt 30; $attempt++) {
    & docker compose exec -T postgres-db pg_isready -U gandalf -d eowyn-library *> $null
    if ($LASTEXITCODE -eq 0) { $databaseReady = $true; break }
    Start-Sleep -Seconds 2
  }
  if (-not $databaseReady) { throw 'PostgreSQL no quedó listo después de 60 segundos.' }

  if (-not (Test-Path (Join-Path $repoRoot 'node_modules'))) {
    Write-Host 'Instalando dependencias Node...'
    & npm install
    if ($LASTEXITCODE -ne 0) { throw 'npm install terminó con error.' }
  }

  Write-Host 'Aplicando migraciones pendientes...'
  & npm run migrate:latest
  if ($LASTEXITCODE -ne 0) { throw 'Las migraciones terminaron con error.' }

  $healthUrl = "$($env:BASE_URL)/api/auth/validate-email/runner-health"
  $apiReady = $false
  try {
    $healthResponse = Invoke-WebRequest -Uri $healthUrl -TimeoutSec 3 -UseBasicParsing
    $apiReady = $healthResponse.StatusCode -eq 200
  } catch { $apiReady = $false }

  if (-not $apiReady) {
    Write-Host 'Iniciando la API en segundo plano...'
    Start-Process -FilePath $env:ComSpec `
      -ArgumentList '/c', 'npm run dev' `
      -WorkingDirectory $repoRoot `
      -WindowStyle Hidden `
      -RedirectStandardOutput (Join-Path $targetRoot 'api-dev.stdout.log') `
      -RedirectStandardError (Join-Path $targetRoot 'api-dev.stderr.log') | Out-Null

    for ($attempt = 0; $attempt -lt 60; $attempt++) {
      Start-Sleep -Seconds 1
      try {
        $healthResponse = Invoke-WebRequest -Uri $healthUrl -TimeoutSec 3 -UseBasicParsing
        if ($healthResponse.StatusCode -eq 200) { $apiReady = $true; break }
      } catch { $apiReady = $false }
    }
    if (-not $apiReady) { throw "La API no respondió en $healthUrl. Revisa los logs bajo $targetRoot." }
  }

  Set-Location $moduleRoot
  foreach ($simulation in $simulations) {
    Write-Host "Ejecutando $simulation..."
    $resourceProfile = if ($simulation -eq 'performance.EowynLoadSimulation') { 'load' } elseif ($simulation -eq 'performance.EowynStressSimulation') { 'stress' } else { $null }
    if ($resourceProfile) {
      $samplerOutput = Join-Path $targetRoot "$resourceProfile-resources-final.csv"
      $samplerStdout = Join-Path $targetRoot "$resourceProfile-resource-sampler.stdout.log"
      $samplerStderr = Join-Path $targetRoot "$resourceProfile-resource-sampler.stderr.log"
      Remove-Item $samplerStopFile, $samplerOutput, $samplerStdout, $samplerStderr -Force -ErrorAction SilentlyContinue
      $samplerPath = Join-Path $PSScriptRoot 'sample-local-resources.ps1'
      $samplerProcess = Start-Process -FilePath 'powershell.exe' `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$samplerPath`"", '-DurationSeconds', '240', '-OutputFile', "`"$samplerOutput`"", '-StopFile', "`"$samplerStopFile`"") `
        -WorkingDirectory $repoRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $samplerStdout `
        -RedirectStandardError $samplerStderr `
        -PassThru
      Start-Sleep -Seconds 2
    }
    & mvn test-compile gatling:test "-Dgatling.simulationClass=$simulation"
    if ($LASTEXITCODE -ne 0) { throw "$simulation terminó con código $LASTEXITCODE." }
    if ($resourceProfile -and $samplerProcess) {
      New-Item -ItemType File -Path $samplerStopFile -Force | Out-Null
      Wait-Process -Id $samplerProcess.Id
      $sampleRows = if (Test-Path -LiteralPath $samplerOutput) { @(Import-Csv -LiteralPath $samplerOutput) } else { @() }
      $samplerLog = if (Test-Path -LiteralPath $samplerStdout) { Get-Content -LiteralPath $samplerStdout -Raw } else { '' }
      if ($sampleRows.Count -eq 0 -or $samplerLog -notmatch 'CSV:') {
        throw "El muestreador no confirmó muestras válidas. Revisa $samplerStdout y $samplerStderr."
      }
      $samplerProcess = $null
    }
  }
  $exitCode = 0
}
catch {
  Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
  $exitCode = 1
}
finally {
  if ($samplerProcess) {
    New-Item -ItemType File -Path $samplerStopFile -Force | Out-Null
    Wait-Process -Id $samplerProcess.Id -ErrorAction SilentlyContinue
  }
  Remove-Item $samplerStopFile -Force -ErrorAction SilentlyContinue
  Set-Location $originalLocation
  Remove-Item Env:BASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:TEST_EMAIL -ErrorAction SilentlyContinue
  Remove-Item Env:TEST_PASSWORD -ErrorAction SilentlyContinue
}

if ($exitCode -ne 0) { throw 'La ejecución de los perfiles Gatling no terminó correctamente.' }

Write-Host 'Reportes de esta ejecución:'
foreach ($name in @('eowyncatalogsimulation', 'eowynloadsimulation', 'eowynstresssimulation')) {
  $latest = Get-ChildItem (Join-Path $targetRoot 'gatling') -Directory -Filter "$name-*" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($latest) { Write-Host (Join-Path $latest.FullName 'index.html') }
}
