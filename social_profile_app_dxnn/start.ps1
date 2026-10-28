# Demarre Docker Desktop, attend qu'il soit pret, puis lance la pile Supabase.
# Usage : .\start.ps1

$ErrorActionPreference = 'Continue'

function Wait-Docker {
    param([int]$Minutes = 5)
    $deadline = (Get-Date).AddMinutes($Minutes)
    while ((Get-Date) -lt $deadline) {
        docker info *> $null
        if ($LASTEXITCODE -eq 0) { return $true }
        Start-Sleep -Seconds 10
    }
    return $false
}

Write-Host '== Verification de Docker ==' -ForegroundColor Cyan
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Docker Desktop est arrete. Lancement...' -ForegroundColor Yellow
    $dockerExe = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
    if (Test-Path $dockerExe) {
        Start-Process $dockerExe
    } else {
        Write-Host 'Docker Desktop introuvable a l''emplacement par defaut. Lance-le manuellement.' -ForegroundColor Red
        exit 1
    }
    if (Wait-Docker -Minutes 5) {
        Write-Host 'Docker pret.' -ForegroundColor Green
    } else {
        Write-Host 'Docker pas pret apres 5 minutes. Relance le script.' -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host 'Docker deja pret.' -ForegroundColor Green
}

Write-Host '== Demarrage de Supabase ==' -ForegroundColor Cyan
supabase start
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Echec du demarrage Supabase. Verifie le message ci-dessus.' -ForegroundColor Red
    exit 1
}
Write-Host 'Supabase demarre.' -ForegroundColor Green

Write-Host '== Verification de la base ==' -ForegroundColor Cyan
try {
    $anonKey = (Get-Content .env | Select-String 'SUPABASE_ANON_KEY').ToString().Split('=')[1]
    Invoke-RestMethod -Uri 'http://127.0.0.1:54321/rest/v1/brand_profile?select=username' -Headers @{ apikey = $anonKey } | Out-Null
    Write-Host 'Base accessible (brand_profile OK).' -ForegroundColor Green
} catch {
    Write-Host 'Base pas encore accessible. Attends 1 minute puis fais F5 dans Chrome.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Reste a faire manuellement :' -ForegroundColor White
Write-Host '  1. supabase functions serve refresh-stats --env-file .env.admin'
Write-Host '  2. flutter run -d chrome --dart-define-from-file=.env'
