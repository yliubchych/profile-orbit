param([int]$Through=7)
$ErrorActionPreference='Stop'
$failed=@()
foreach($suite in Get-ChildItem $PSScriptRoot -Filter 'Feature*.Tests.ps1' | Sort-Object Name) {
    if($suite.Name -match '^Feature(\d+)' -and [int]$Matches[1] -le $Through) {
        Write-Output "SUITE $($suite.Name)"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File $suite.FullName
        if($LASTEXITCODE -ne 0){$failed+=@($suite.Name)}
    }
}
if($failed.Count){throw ('Failed suites: '+($failed -join ', '))}
Write-Output 'All selected suites passed.'
