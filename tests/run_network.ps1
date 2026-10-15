param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [ValidateSet('clean', 'fault', 'timeout', 'dedicated', 'disconnect', 'server_loss')][string]$Scenario = 'clean',
    [int]$Cycles = 20
)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$outputDirectory = Join-Path $workspace ".godot/network-$Scenario"
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$participants = @()
$proxy = $null
try {
    if ($Scenario -eq 'fault') {
        $proxyArguments = @('--headless', '--path', $workspace, '--log-file', "$outputDirectory/proxy-engine.log", '--script', 'res://tests/udp_proxy.gd')
        $proxy = Start-Process -FilePath $Godot -ArgumentList $proxyArguments -WorkingDirectory $workspace -WindowStyle Hidden -PassThru -RedirectStandardOutput "$outputDirectory/proxy.out" -RedirectStandardError "$outputDirectory/proxy.err"
        Start-Sleep -Milliseconds 500
    }
    foreach ($role in @('host', 'client1', 'client2')) {
        $port = if ($Scenario -eq 'fault' -and $role -ne 'host') { if ($role -eq 'client1') { 25434 } else { 25435 } } else { 25433 }
        $arguments = @('--headless', '--path', $workspace, '--log-file', "$outputDirectory/$role-engine.log", 'res://tests/network_peer.tscn', '--', "--role=$role", "--scenario=$Scenario", "--cycles=$Cycles", "--port=$port")
        $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WorkingDirectory $workspace -WindowStyle Hidden -PassThru -RedirectStandardOutput "$outputDirectory/$role.out" -RedirectStandardError "$outputDirectory/$role.err"
        $participants += $process
        if ($role -eq 'host') { Start-Sleep -Milliseconds 500 }
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(100)
    while (@($participants | Where-Object { -not $_.HasExited }).Count -gt 0) {
        if ($proxy -and $proxy.HasExited) { throw 'UDP proxy exited before the participants.' }
        foreach ($role in @('host', 'client1', 'client2')) {
            $errorPath = "$outputDirectory/$role.err"
            if ((Test-Path $errorPath) -and (Get-Content $errorPath -Raw) -match 'SCRIPT ERROR|NETWORK_FAIL|(?m)^ERROR: (?!Failed to read the root certificate store)') {
                Get-Content $errorPath -Tail 25 | Write-Output
                throw "$role reported a script error."
            }
        }
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Network integration test exceeded 100 seconds.' }
        Start-Sleep -Milliseconds 250
    }
    if ($Scenario -eq 'fault') {
        $stats = Get-Content "$outputDirectory/proxy-stats.json" -Raw | ConvertFrom-Json
        if ($stats.dropped -le 0 -or $stats.forwarded -le 0) { throw 'Loss injection was not exercised.' }
        Write-Output "UDP_PROXY received=$($stats.received) dropped=$($stats.dropped) forwarded=$($stats.forwarded)"
    }
    $reference = @(Get-Content "$outputDirectory/host.out" | Where-Object { $_ -match '^RESULT ' })
    $referenceStates = @{}
    foreach ($line in Get-Content "$outputDirectory/host.out") {
        if ($line -match '^STATE round=(\d+) tick=(\d+) hash=(.+)') {
            $referenceStates["$($Matches[1])/$($Matches[2])"] = $Matches[3]
        }
    }
    $repairedGaps = 0
    foreach ($role in @('host', 'client1', 'client2')) {
        $stdout = Get-Content "$outputDirectory/$role.out" -Raw
        $stderr = Get-Content "$outputDirectory/$role.err" -Raw
        if ($Scenario -eq 'server_loss') {
            $expected = if ($role -eq 'host') { 'SERVER_CLOSED_OK' } else { 'SERVER_LOSS_OK' }
            if ($stdout -notmatch $expected) { throw "$role did not handle server loss." }
            Write-Output $expected
            continue
        }
        if ($Scenario -eq 'disconnect' -and $stdout -match 'NETWORK_DISCONNECTED_OK') {
            Write-Output "NETWORK_DISCONNECTED_OK role=$role"
            continue
        }
        if ($stdout -notmatch 'NETWORK_OK' -or $stderr -match 'SCRIPT ERROR|NETWORK_FAIL|(?m)^ERROR: (?!Failed to read the root certificate store)') {
            Write-Output $stdout
            Write-Output $stderr
            throw "$role failed"
        }
        $results = @(Get-Content "$outputDirectory/$role.out" | Where-Object { $_ -match '^RESULT ' })
        $lastTicks = @{}
        foreach ($line in Get-Content "$outputDirectory/$role.out") {
            if ($line -match '^STATE round=(\d+) tick=(\d+) hash=(.+)') {
                $round = $Matches[1]
                $tick = [int]$Matches[2]
                $hash = $Matches[3]
                if ($hash -ne $referenceStates["$round/$tick"]) { throw "$role intermediate snapshot differs from host." }
                if ($role -ne 'host' -and $lastTicks.ContainsKey($round) -and $tick -gt $lastTicks[$round] + 1) { $repairedGaps++ }
                $lastTicks[$round] = $tick
            }
        }
        if ($results.Count -ne $Cycles -or ($results -join [Environment]::NewLine) -ne ($reference -join [Environment]::NewLine)) {
            throw "$role final states differ from the host."
        }
        Write-Output ($stdout -split [Environment]::NewLine | Where-Object { $_ -match 'NETWORK_OK|TIMEOUT_RECOVERED' })
    }
    if ($Scenario -eq 'fault') {
        if ($repairedGaps -eq 0) { throw 'No missed snapshots followed by a valid running snapshot were observed.' }
        Write-Output "SNAPSHOT_GAPS_REPAIRED count=$repairedGaps"
    }
    if ($Scenario -eq 'server_loss') {
        Write-Output "NETWORK_SUITE_OK scenario=$Scenario; both clients cleared the session."
    } elseif ($Scenario -eq 'disconnect') {
        Write-Output "NETWORK_SUITE_OK scenario=$Scenario; disconnected client cleaned up, remaining peers agree."
    } else {
        Write-Output "NETWORK_SUITE_OK scenario=$Scenario cycles=$Cycles; intermediate and final state hashes agree."
    }
}
finally {
    foreach ($process in $participants) { if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force } }
    if ($proxy -and -not $proxy.HasExited) { Stop-Process -Id $proxy.Id -Force }
}
