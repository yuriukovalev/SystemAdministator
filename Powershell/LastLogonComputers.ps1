<#
Get-ADPC_WithDescription.ps1
---------------------------------------------
EnabledComputers.csv   – включённые ПК
DisabledComputers.csv  – отключённые ПК
Summary.txt            – сводка
Колонки CSV: Name, DNSHostName, Enabled,
             OperatingSystem, Description,
             LastLogonDate, DaysIdle, InUse
#>

param(
    [string]$LogRoot    = 'C:\ps',     # куда писать файлы
    [string]$SearchBase = '',          # DN OU; '' = весь домен
    [int]   $IdleDays   = 90           # сколько дней считать «активным»
)

# --- 1. Подключаем модуль AD ------------------------------------
Import-Module ActiveDirectory -ErrorAction Stop

# --- 2. Готовим папку -------------------------------------------
if (-not (Test-Path $LogRoot)) {
    New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
}

# --- 3. Берём компьютеры ----------------------------------------
$adParams = @{
    Filter     = '*'
    Properties = 'Enabled','DNSHostName','OperatingSystem',
                 'LastLogonDate','Description'      # ← добавили Description
}
if ($SearchBase) { $adParams.SearchBase = $SearchBase }

$now = Get-Date

$computers = Get-ADComputer @adParams | ForEach-Object {

    # --- вычисляем, сколько дней ПК «молчал» ---
    $daysIdle = if ($_.LastLogonDate) {
                    [int]($now - $_.LastLogonDate).TotalDays
                } else {
                    [int]::MaxValue    # никогда не логинился
                }

    # --- формируем расширенный объект -----------
    [pscustomobject]@{
        Name            = $_.Name
        DNSHostName     = $_.DNSHostName
        Enabled         = $_.Enabled
        OperatingSystem = $_.OperatingSystem
        Description     = $_.Description       # ← новая колонка
        LastLogonDate   = $_.LastLogonDate
        DaysIdle        = if ($daysIdle -eq [int]::MaxValue) { 'Never' } else { $daysIdle }
        InUse           = if ($daysIdle -lt $IdleDays) { 'Yes' } else { 'No' }
    }
}

$enabled   = $computers | Where-Object Enabled
$disabled  = $computers | Where-Object { -not $_.Enabled }

# --- 4. Сохраняем CSV -------------------------------------------
$enabledPath  = Join-Path $LogRoot 'EnabledComputers.csv'
$disabledPath = Join-Path $LogRoot 'DisabledComputers.csv'

$enabled  | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $enabledPath
$disabled | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $disabledPath

# --- 5. Сводка ---------------------------------------------------
$summaryPath = Join-Path $LogRoot 'Summary.txt'
@(
    (Get-Date -Format u)
    "Всего учётных записей : $($computers.Count)"
    "Включённых            : $($enabled.Count)"
    "Отключённых           : $($disabled.Count)"
    ""
    "Порог активности (InUse=Yes) : $IdleDays дн."
    "Файлы:"
    $enabledPath
    $disabledPath
    '------------------------------------------------------------'
) | Out-File -FilePath $summaryPath -Encoding UTF8

Write-Host "Готово!  Отчёты сохранены в $LogRoot"
Write-Host "Обе таблицы содержат колонку Description."