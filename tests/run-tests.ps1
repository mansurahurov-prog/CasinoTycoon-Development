# Runs the CasinoTycoonData concurrency tests against a standalone Luau CLI.
# Prerequisite: luau.exe on PATH (or pass -LuauPath).
# The spec needs the project globals (game, task, workspace), so the module
# source is injected into the spec chunk before it is executed.
param(
    [string]$LuauPath = "luau"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $root "src/ServerScriptService/CasinoTycoonData.luau"
$specPath = Join-Path $PSScriptRoot "data_concurrency.spec.luau"

if (-not (Test-Path $modulePath)) { throw "module not found: $modulePath" }

$module = [IO.File]::ReadAllText($modulePath)
$spec = [IO.File]::ReadAllText($specPath)

# Long-bracket delimiter that cannot appear in the module source.
$delimiter = "[====["
$nl = [Environment]::NewLine
$combined = "_MODULE_SOURCE = " + $delimiter + $nl + $module + $nl + "]====]" + $nl + $spec

$temp = Join-Path ([IO.Path]::GetTempPath()) ("casino_data_spec_" + [Guid]::NewGuid().ToString("N") + ".luau")
try {
    [IO.File]::WriteAllText($temp, $combined, (New-Object System.Text.UTF8Encoding($false)))
    & $LuauPath $temp
    exit $LASTEXITCODE
}
finally {
    if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Force }
}
