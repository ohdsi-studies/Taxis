# ==============================================================================
# TAXIS: Dockerized Synthea OMOP PostgreSQL Setup & Runner (PowerShell)
# ==============================================================================
# Starts local PostgreSQL container, initializes OMOP CDM v5.4 schemas,
# loads synthetic dataset, and executes TAXIS integration verification.
# ==============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " TAXIS Dockerized Synthea-OMOP PostgreSQL Setup & Execution" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# 1. Verify Docker is available
Write-Host "--> Step 1: Checking Docker engine..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version
    Write-Host "    Found: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Error "Docker is not installed or not in PATH. Please install Docker Desktop."
}

# 2. Start container via docker compose
Write-Host "--> Step 2: Starting PostgreSQL container via docker compose..." -ForegroundColor Yellow
Push-Location $ScriptDir
try {
    docker compose up -d
} finally {
    Pop-Location
}

# 3. Wait for PostgreSQL container healthcheck
Write-Host "--> Step 3: Waiting for PostgreSQL healthcheck..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0
$isHealthy = $false

while ($attempt -lt $maxAttempts) {
    Start-Sleep -Seconds 2
    $status = docker inspect --format="{{.State.Health.Status}}" taxis-synthea-postgres 2>$null
    if ($status -eq "healthy") {
        $isHealthy = $true
        break
    }
    $attempt++
    Write-Host "    Waiting for postgres to become healthy ($attempt/$maxAttempts)..." -ForegroundColor Gray
}

if (-not $isHealthy) {
    Write-Error "PostgreSQL container failed to become healthy. Check logs with 'docker logs taxis-synthea-postgres'."
}
Write-Host "    PostgreSQL is ready and healthy on localhost:5433." -ForegroundColor Green

# 4. Load Synthetic OMOP CDM Data
Write-Host "--> Step 4: Loading Synthetic OMOP CDM data..." -ForegroundColor Yellow
python "$ScriptDir\load_synthea.py" --host localhost --port 5433 --db synthea --user ohdsi_app --password ohdsi_app_pass_2026

# 5. Run TAXIS PostgreSQL Integration Test
Write-Host "--> Step 5: Executing TAXIS integration test on PostgreSQL..." -ForegroundColor Yellow
$rootDir = Resolve-Path "$ScriptDir\..\.."
python "$rootDir\extras\test_postgres_synthea_integration.py" --port 5433
if ($LASTEXITCODE -ne 0) {
    Write-Error "TAXIS PostgreSQL integration test failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " PostgreSQL Synthea-OMOP Setup & Integration Test Complete!" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan
