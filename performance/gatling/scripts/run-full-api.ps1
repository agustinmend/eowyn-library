param(
  [ValidateRange(1, 20)]
  [int]$WriteUsers = 1,
  [string]$BaseUrl,
  [string]$TestEmail = 'admin@example.com',
  [string]$TestPassword = '123456'
)

# Docker Compose may write non-fatal deprecation notices to stderr. Keep those
# informational; every native command below is checked via $LASTEXITCODE.
$ErrorActionPreference = 'Continue'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$moduleRoot = Join-Path $repoRoot 'performance\gatling'
$targetRoot = Join-Path $moduleRoot 'target'
$environmentPath = Join-Path $moduleRoot 'config\eowyn-local.postman_environment.json'
$cleanupPath = Join-Path $moduleRoot 'scripts\cleanup-gatling-fixtures.sql'
$apiStartedHere = $false
$databaseReady = $false
$runStarted = $false
$runExitCode = 1
$originalLocation = Get-Location

try {
  if (-not (Test-Path (Join-Path $repoRoot '.env'))) {
    throw 'No existe .env en la raíz. Configúralo una vez a partir de .env.template antes de ejecutar.'
  }

  $postmanEnvironment = Get-Content $environmentPath -Raw | ConvertFrom-Json
  if (-not $BaseUrl) {
    $BaseUrl = ($postmanEnvironment.values | Where-Object key -eq 'host' | Select-Object -First 1).value
  }
  if (-not $BaseUrl) {
    throw "La variable 'host' está vacía en $environmentPath."
  }

  $env:BASE_URL = $BaseUrl.TrimEnd('/')
  $env:TEST_EMAIL = $TestEmail
  $env:TEST_PASSWORD = $TestPassword
  $env:ENABLE_WRITE_TESTS = 'true'
  $env:WRITE_TEST_USERS = [string]$WriteUsers

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
  } catch {
    $apiReady = $false
  }

  if (-not $apiReady) {
    Write-Host 'Iniciando la API en segundo plano...'
    $stdoutPath = Join-Path $targetRoot 'api-dev.stdout.log'
    $stderrPath = Join-Path $targetRoot 'api-dev.stderr.log'
    Start-Process -FilePath $env:ComSpec `
      -ArgumentList '/c', 'npm run dev' `
      -WorkingDirectory $repoRoot `
      -WindowStyle Hidden `
      -RedirectStandardOutput $stdoutPath `
      -RedirectStandardError $stderrPath | Out-Null
    $apiStartedHere = $true

    for ($attempt = 0; $attempt -lt 60; $attempt++) {
      Start-Sleep -Seconds 1
      try {
        $healthResponse = Invoke-WebRequest -Uri $healthUrl -TimeoutSec 3 -UseBasicParsing
        if ($healthResponse.StatusCode -eq 200) { $apiReady = $true; break }
      } catch {
        $apiReady = $false
      }
    }
    if (-not $apiReady) {
      throw "La API no respondió en $healthUrl. Revisa $stderrPath y $stdoutPath."
    }
  }

  Write-Host "Ejecutando ciclo API completo con $WriteUsers usuario(s) virtual(es)..."
  Set-Location $moduleRoot
  $runStarted = $true
  & mvn test-compile gatling:test '-Dgatling.simulationClass=performance.EowynFullApiSimulation'
  $runExitCode = $LASTEXITCODE
}
catch {
  Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
  $runExitCode = 1
}
finally {
  if ($runStarted -and $databaseReady) {
    Write-Host 'Limpiando los datos Gatling creados...'
    Set-Location $repoRoot
    Get-Content $cleanupPath -Raw | & docker compose exec -T postgres-db psql -X -v ON_ERROR_STOP=1 -U gandalf -d eowyn-library
    if ($LASTEXITCODE -ne 0) {
      Write-Warning 'La limpieza automática falló. Ejecuta el SQL de limpieza indicado en la guía.'
      if ($runExitCode -eq 0) { $runExitCode = 2 }
    }
  }

  Set-Location $originalLocation
  Remove-Item Env:ENABLE_WRITE_TESTS -ErrorAction SilentlyContinue
  Remove-Item Env:WRITE_TEST_USERS -ErrorAction SilentlyContinue
  Remove-Item Env:BASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:TEST_EMAIL -ErrorAction SilentlyContinue
  Remove-Item Env:TEST_PASSWORD -ErrorAction SilentlyContinue
}

if ($apiStartedHere) {
  Write-Host 'La API iniciada por el script queda ejecutándose en segundo plano.'
  Write-Host "Logs: $(Join-Path $targetRoot 'api-dev.stdout.log')"
}

if ($runExitCode -ne 0) {
  throw "La ejecución de Gatling finalizó con código $runExitCode. Revisa el reporte y los logs anteriores."
}

$latestReport = Get-ChildItem (Join-Path $targetRoot 'gatling') -Directory -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
if ($latestReport) {
  Write-Host "Reporte HTML: $(Join-Path $latestReport.FullName 'index.html')"
  Write-Host 'Este reporte es cobertura del ciclo completo con la cantidad de usuarios indicada; no es el perfil de carga sostenida ni el de estrés.'
}
