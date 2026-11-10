param(
    [ValidateSet('Live', 'Demo')][string]$Mode = 'Live',
    [string]$Device = 'emulator-5554',
    [string]$ApiBaseUrl = 'http://10.0.2.2:8000'
)
$ErrorActionPreference = 'Stop'
$app = Split-Path $PSScriptRoot -Parent
$repo = Split-Path (Split-Path $app -Parent) -Parent
$python = Join-Path $repo 'backend/.venv/Scripts/python.exe'
$envFile = Join-Path $repo 'backend/.env'
if (!(Test-Path -LiteralPath $python) -or !(Test-Path -LiteralPath $envFile)) {
    throw 'backend/.venv and backend/.env are required.'
}
# Read only the public map Client ID. Never pass the Client Secret to Flutter.
$mapClientId = & $python -c "from dotenv import dotenv_values; import sys; print(dotenv_values(sys.argv[1]).get('NAVER_MAPS_CLIENT_ID', ''))" $envFile
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($mapClientId)) {
    throw 'NAVER_MAPS_CLIENT_ID is missing in backend/.env.'
}
$mock = if ($Mode -eq 'Demo') { 'true' } else { 'false' }
$runArguments = @('run', '-d', $Device, "--dart-define=NAVER_MAPS_CLIENT_ID=$($mapClientId.Trim())",
    "--dart-define=USE_MOCK_DATA=$mock", "--dart-define=API_BASE_URL=$ApiBaseUrl")
Push-Location $app
try { & flutter @runArguments; $code = $LASTEXITCODE }
finally { Pop-Location }
exit $code
