param(
    [int]$Port = 17000,
    [int]$Seed = 424242,
    [ValidateRange(2, 4)]
    [int]$Players = 2,
    [int]$Days = 3,
    [double]$RoundSeconds = 0.1,
    [int]$TimeoutSeconds = 30,
    [string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    $godotCommand = Get-Command godot,godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $godotCommand) {
        $GodotBin = $godotCommand.Source
    }
}
if ([string]::IsNullOrWhiteSpace($GodotBin) -or -not (Test-Path $GodotBin)) {
    throw "Set GODOT_BIN to the Godot executable path, for example: `$env:GODOT_BIN = 'C:\Path\Godot.exe'"
}

$runDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("stocktroder-network-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
$hostReport = Join-Path $runDirectory "host.json"
$hostOutput = Join-Path $runDirectory "host.log"
$processes = @()

$clientReports = @()
$clientOutputs = @()
for ($playerId = 2; $playerId -le $Players; $playerId++) {
    $clientReports += Join-Path $runDirectory ("client-{0}.json" -f $playerId)
    $clientOutputs += Join-Path $runDirectory ("client-{0}.log" -f $playerId)
}

function Read-Report([string]$Path) {
    if (-not (Test-Path $Path)) {
        return $null
    }
    return Get-Content -Raw -Path $Path | ConvertFrom-Json
}

try {
    $commonArguments = @(
        "--headless",
        "--path", $repo,
        "res://scenes/network_test_peer.tscn",
        "--",
        "--port=$Port",
        "--seed=$Seed",
        "--days=$Days",
        "--round-seconds=$RoundSeconds",
        "--players=$Players"
    )
    $hostArguments = $commonArguments + @("--role=host", "--name=Host", "--report=$hostReport")
    $hostProcess = Start-Process -FilePath $GodotBin -ArgumentList $hostArguments -WorkingDirectory $repo -RedirectStandardOutput $hostOutput -RedirectStandardError ($hostOutput + ".err") -PassThru
    $processes += $hostProcess
    [void]$hostProcess.WaitForInputIdle(1000)

    for ($clientIndex = 0; $clientIndex -lt $clientReports.Count; $clientIndex++) {
        $clientName = "Client$($clientIndex + 2)"
        $clientArguments = $commonArguments + @("--role=client", "--name=$clientName", "--report=$($clientReports[$clientIndex])")
        $clientProcess = Start-Process -FilePath $GodotBin -ArgumentList $clientArguments -WorkingDirectory $repo -RedirectStandardOutput $clientOutputs[$clientIndex] -RedirectStandardError ($clientOutputs[$clientIndex] + ".err") -PassThru
        $processes += $clientProcess
    }

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $hostReportData = Read-Report $hostReport
        $clientReportData = @($clientReports | ForEach-Object { Read-Report $_ })
        if ($null -ne $hostReportData -and @($clientReportData | Where-Object { $null -eq $_ }).Count -eq 0) {
            break
        }
        $hostProcess.Refresh()
        $all_clients_exited = $true
        foreach ($process in $processes | Select-Object -Skip 1) {
            $process.Refresh()
            $all_clients_exited = $all_clients_exited -and $process.HasExited
        }
        if ($hostProcess.HasExited -and $all_clients_exited) {
            break
        }
        [System.Threading.Thread]::Sleep(100)
    }

    $hostReportData = Read-Report $hostReport
    $clientReportData = @($clientReports | ForEach-Object { Read-Report $_ })
    if ($null -eq $hostReportData -or @($clientReportData | Where-Object { $null -eq $_ }).Count -ne 0) {
        throw "Network harness timed out. Logs: $runDirectory"
    }
    if (-not $hostReportData.success -or @($clientReportData | Where-Object { -not $_.success }).Count -ne 0) {
        $clientMessages = ($clientReportData | ForEach-Object { $_.message }) -join "; "
        throw "Network harness failed. Host: $($hostReportData.message). Clients: $clientMessages. Logs: $runDirectory"
    }
    if ($hostReportData.phase -ne "COMPLETE" -or @($clientReportData | Where-Object { $_.phase -ne "COMPLETE" }).Count -ne 0) {
        throw "Network harness did not reach COMPLETE. Logs: $runDirectory"
    }
    $expectedPlayerNames = @("Host")
    for ($playerId = 2; $playerId -le $Players; $playerId++) {
        $expectedPlayerNames += "Client$playerId"
    }
    $expectedPlayerNamesText = @($expectedPlayerNames | Sort-Object) -join "|"
    $actualHostNames = @($hostReportData.player_names | Sort-Object) -join "|"
    if ($actualHostNames -ne $expectedPlayerNamesText) {
        throw "Host received unexpected player names. Expected: $expectedPlayerNamesText. Actual: $actualHostNames. Logs: $runDirectory"
    }
    foreach ($clientReport in $clientReportData) {
        $actualClientNames = @($clientReport.player_names | Sort-Object) -join "|"
        if ($actualClientNames -ne $expectedPlayerNamesText) {
            throw "Client received unexpected player names. Expected: $expectedPlayerNamesText. Actual: $actualClientNames. Logs: $runDirectory"
        }
    }
    if ($hostReportData.completed_rounds -ne $Days -or @($clientReportData | Where-Object { $_.completed_rounds -ne $Days }).Count -ne 0) {
        throw "Network harness completed the wrong number of rounds. Logs: $runDirectory"
    }

    Write-Output ("PASS: {0} real ENet peers completed {1} synchronized rounds. Reports: {2}" -f $Players, $Days, $runDirectory)
}
finally {
    foreach ($process in $processes) {
        $process.Refresh()
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
        }
    }
}
