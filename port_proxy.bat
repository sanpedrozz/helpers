# Requires Admin. Run in elevated PowerShell
# Меню управления PortProxy (v4->v4)

function Ensure-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Host "[ОШИБКА] Запустите PowerShell от имени администратора." -ForegroundColor Red
        exit 1
    }
}

function Add-OrUpdate-Rule {
    param(
        [string]$ListenIP = "0.0.0.0",
        [int]$ListenPort = 4840,
        [string]$DestIP = "192.168.10.50",
        [int]$DestPort = 4840
    )
    Write-Host "Создаю правило: $ListenIP`:$ListenPort -> $DestIP`:$DestPort"
    & netsh interface portproxy delete v4tov4 listenaddress=$ListenIP listenport=$ListenPort | Out-Null
    & netsh interface portproxy add v4tov4 listenaddress=$ListenIP listenport=$ListenPort connectaddress=$DestIP connectport=$DestPort
}

function Remove-One {
    param([string]$ListenIP, [int]$ListenPort)
    & netsh interface portproxy delete v4tov4 listenaddress=$ListenIP listenport=$ListenPort
}

function Remove-All {
    & netsh interface portproxy reset
}

function Show-Rules {
    & netsh interface portproxy show all
}

Ensure-Admin

$ListenIP  = "0.0.0.0"
$ListenPort= 4840
$DestIP    = "192.168.10.50"
$DestPort  = 4840

while ($true) {
    Clear-Host
    Write-Host "==============================================="
    Write-Host "    Меню PortProxy (проброс портов v4->v4)"
    Write-Host "==============================================="
    Write-Host "[1] Добавить / Обновить правило"
    Write-Host "[2] Удалить одно правило"
    Write-Host "[3] Удалить ВСЕ правила"
    Write-Host "[4] Показать правила"
    Write-Host "[5] Выход"
    Write-Host "==============================================="
    $choice = Read-Host "Выберите пункт (1-5)"

    switch ($choice) {
        "1" {
            $li = Read-Host "IP для прослушивания [$ListenIP]"
            if ($li) { $ListenIP = $li }
            $lp = Read-Host "Порт для прослушивания [$ListenPort]"
            if ($lp) { $ListenPort = [int]$lp }
            $di = Read-Host "IP назначения [$DestIP]"
            if ($di) { $DestIP = $di }
            $dp = Read-Host "Порт назначения [$DestPort]"
            if ($dp) { $DestPort = [int]$dp }

            Add-OrUpdate-Rule -ListenIP $ListenIP -ListenPort $ListenPort -DestIP $DestIP -DestPort $DestPort
            Pause
        }
        "2" {
            $li = Read-Host "IP правила (пусто = $ListenIP)"
            if (-not $li) { $li = $ListenIP }
            $lp = Read-Host "Порт правила (пусто = $ListenPort)"
            if (-not $lp) { $lp = $ListenPort }
            Remove-One -ListenIP $li -ListenPort ([int]$lp)
            Pause
        }
        "3" {
            $c = Read-Host "ВНИМАНИЕ! Удалить все правила? Напишите ДА"
            if ($c -eq "ДА") {
                Remove-All
                Write-Host "Все правила удалены."
            } else {
                Write-Host "Отменено."
            }
            Pause
        }
        "4" {
            Show-Rules
            Pause
        }
        "5" { break }
        default { }
    }
}
