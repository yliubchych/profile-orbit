$ErrorActionPreference = 'Stop'
$script:Passed = 0
$script:Failed = 0
function Test-Case([string]$Name, [scriptblock]$Body) {
    try { & $Body; $script:Passed++; Write-Output "PASS $Name" }
    catch { $script:Failed++; Write-Output "FAIL $Name : $($_.Exception.Message)"; Write-Output $_.ScriptStackTrace }
}
function Assert-True($Value, [string]$Message = 'Expected true') { if (!$Value) { throw $Message } }
function Assert-Equal($Expected, $Actual) {
    if (($Expected | ConvertTo-Json -Depth 20 -Compress) -cne ($Actual | ConvertTo-Json -Depth 20 -Compress)) {
        throw "Expected [$Expected], got [$Actual]"
    }
}
function Assert-Throws([scriptblock]$Body, [string]$Pattern = '*') {
    $caught = $false
    try { & $Body | Out-Null } catch { $caught = $true; if ($_.Exception.Message -notlike $Pattern) { throw } }
    if (!$caught) { throw 'Expected an exception' }
}
function New-TestRoot {
    $path = Join-Path $PSScriptRoot ('.tmp/' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $path -Force
    return $path
}
function Complete-Tests {
    Write-Output "RESULT: $script:Passed passed, $script:Failed failed"
    if ($script:Failed -gt 0) { exit 1 }
}
