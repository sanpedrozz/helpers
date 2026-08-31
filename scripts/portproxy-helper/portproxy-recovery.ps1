param(
    [ValidateRange(0, 300)]
    [int]$DelaySeconds = 10
)

# Restarts IP Helper after Windows has finished bringing up the network.
# This drops stale PortProxy TCP sessions left after a network interruption.
Start-Sleep -Seconds $DelaySeconds

$logPath = Join-Path $PSScriptRoot 'portproxy-recovery.log'
function Write-RecoveryLog([string]$Message) {
    Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Message"
}

# A boot trigger and a network trigger can arrive together. Do not restart the
# service twice, as each restart deliberately disconnects PortProxy clients.
$mutex = [Threading.Mutex]::new($false, 'Global\PortProxyHelperRecovery')
if (-not $mutex.WaitOne(0)) {
    Write-RecoveryLog 'Skipped: another recovery instance is already running.'
    exit 0
}

try {
    Write-RecoveryLog 'Recovery started.'
    $keyPath = 'HKLM:\SOFTWARE\PortProxyHelper'
    $now = [DateTime]::UtcNow
    $lastRecovery = $null
    try {
        $lastRecovery = (Get-ItemProperty -Path $keyPath -Name LastRecoveryUtc -ErrorAction Stop).LastRecoveryUtc
    } catch {
        New-Item -Path $keyPath -Force | Out-Null
    }

    if ($lastRecovery) {
        $lastRecoveryTime = [DateTime]::Parse($lastRecovery).ToUniversalTime()
        if (($now - $lastRecoveryTime).TotalSeconds -lt 60) {
            Write-RecoveryLog 'Skipped: a recovery ran less than 60 seconds ago.'
            exit 0
        }
    }

    Set-ItemProperty -Path $keyPath -Name LastRecoveryUtc -Value $now.ToString('o')

    $service = Get-Service -Name iphlpsvc -ErrorAction Stop
    if ($service.Status -ne 'Stopped') {
        Stop-Service -Name iphlpsvc -Force -ErrorAction Stop
        $service.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
    }

    Start-Service -Name iphlpsvc -ErrorAction Stop
    Write-RecoveryLog 'IP Helper restarted successfully.'
} catch {
    Write-RecoveryLog ("ERROR: " + $_.Exception.Message)
    exit 1
} finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
