$ErrorActionPreference = 'Stop'
$backend = Split-Path $PSScriptRoot -Parent
$python = Join-Path $backend '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw 'backend/.venv Python is missing. Install the backend first.' }
$logs = Join-Path $backend 'data/logs'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$log = Join-Path $logs ('seoul-static-' + (Get-Date -Format 'yyyy-MM') + '.log')
Push-Location $backend
try {
    # Native stderr is a log stream, not a PowerShell terminating error.
    $ErrorActionPreference = 'Continue'
    & $python -m pubpark.collectors.seoul_static *>> $log
    $result = $LASTEXITCODE
} finally { Pop-Location }
exit $result
