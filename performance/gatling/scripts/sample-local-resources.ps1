param(
  [int]$DurationSeconds = 150,
  [string]$ContainerName = 'eowyn-library-postgres-db-1',
  [int]$ApiPort = 3000,
  [string]$OutputFile = (Join-Path $PSScriptRoot '..\target\resource-samples.csv'),
  [string]$StopFile
)

$ErrorActionPreference = 'Stop'
[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
$outputDirectory = Split-Path -Parent $OutputFile
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$listener = Get-NetTCPConnection -LocalPort $ApiPort -State Listen | Select-Object -First 1
if (-not $listener) { throw "No se encontró proceso escuchando en el puerto $ApiPort." }
$apiProcess = Get-Process -Id $listener.OwningProcess
$totalPhysicalMemoryBytes = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
if (-not $totalPhysicalMemoryBytes) { throw 'No se pudo obtener la memoria física total del equipo.' }
$processorCount = [Environment]::ProcessorCount
$invariant = [Globalization.CultureInfo]::InvariantCulture
$samples = [Collections.Generic.List[object]]::new()
$previousTime = Get-Date
$previousCpu = $apiProcess.CPU
$stopAt = $previousTime.AddSeconds($DurationSeconds)

while ((Get-Date) -lt $stopAt -and (-not $StopFile -or -not (Test-Path -LiteralPath $StopFile))) {
  Start-Sleep -Seconds 1
  $now = Get-Date
  $apiProcess = Get-Process -Id $listener.OwningProcess -ErrorAction Stop
  $elapsed = ($now - $previousTime).TotalSeconds
  $apiCpu = (($apiProcess.CPU - $previousCpu) / $elapsed / $processorCount) * 100

  $stats = docker stats --no-stream --format '{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}' $ContainerName
  if ($LASTEXITCODE -ne 0) { throw "docker stats falló para $ContainerName." }
  $parts = $stats.Trim().Split('|')
  $dbCpu = [double]::Parse(($parts[0] -replace '%',''), $invariant)
  $dbMemory = ($parts[1] -split '/')[0].Trim()
  $match = [regex]::Match($dbMemory, '^([\d.]+)\s*(B|kB|KB|KiB|MB|MiB|GB|GiB)$')
  if (-not $match.Success) { throw "No se pudo interpretar la memoria de Docker: $dbMemory" }
  $value = [double]::Parse($match.Groups[1].Value, $invariant)
  $unit = $match.Groups[2].Value
  $dbMemoryMiB = switch ($unit) {
    'B'   { $value / 1MB }
    { $_ -in 'kB', 'KB' } { $value / 1024 }
    'KiB' { $value / 1024 }
    { $_ -in 'MB', 'MiB' } { $value }
    'GB'  { $value * 1000 }
    'GiB' { $value * 1024 }
  }

  $samples.Add([pscustomobject]@{
    timestamp = $now.ToString('o')
    api_process = $apiProcess.ProcessName
    api_cpu_percent = [math]::Round($apiCpu, 3)
    api_memory_mib = [math]::Round($apiProcess.WorkingSet64 / 1MB, 2)
    api_memory_percent_host = [math]::Round(($apiProcess.WorkingSet64 / $totalPhysicalMemoryBytes) * 100, 3)
    postgres_cpu_percent = $dbCpu
    postgres_memory_mib = [math]::Round($dbMemoryMiB, 2)
    postgres_memory_percent = [double]::Parse(($parts[2] -replace '%',''), $invariant)
  })

  $previousTime = $now
  $previousCpu = $apiProcess.CPU
}

$samples | Export-Csv -LiteralPath $OutputFile -NoTypeInformation -Encoding utf8
$samples | Measure-Object -Property api_cpu_percent,api_memory_mib,api_memory_percent_host,postgres_cpu_percent,postgres_memory_mib,postgres_memory_percent -Average -Maximum |
  Select-Object Property,Count,Average,Maximum | Format-Table -AutoSize
Write-Output "CSV: $((Resolve-Path $OutputFile).Path)"
