<#
Block-Computers.ps1
Отключает (Disable-ADAccount) учётки компьютеров из списка.
#>

# ----------------------------------------------------------------
# 0.  Пути к файлам
# ----------------------------------------------------------------
$BasePath       = 'C:\ps\BlockComputers'
$BlockListPath  = Join-Path $BasePath 'block.txt'          # список имён ПК
$LogFilePath    = Join-Path $BasePath 'BlockedComputers.log'

# ----------------------------------------------------------------
# 1.  Подготовка
# ----------------------------------------------------------------
Import-Module ActiveDirectory -ErrorAction Stop

if (-not (Test-Path $BlockListPath)) {
    Write-Host "❌ Файл $BlockListPath не найден."
    exit 1
}

$ComputerNames = Get-Content $BlockListPath | Where-Object { $_.Trim() }  # убираем пустые строки

if ($ComputerNames.Count -eq 0) {
    Write-Host "⚠️  Файл $BlockListPath пуст."
    exit 1
}

"=== Блокировка компьютеров  $(Get-Date -Format u) ===" | Out-File -Append $LogFilePath

# ----------------------------------------------------------------
# 2.  Обработка каждой строки
# ----------------------------------------------------------------
foreach ($rawName in $ComputerNames) {

    $name = $rawName.Trim()

    # --- нормализуем SAMAccountName ---
    $samName = if ($name -like '*$') { $name } else { "$name`$" }

    # --- ищем объект-компьютер ---
    $comp = Get-ADComputer -Filter { SamAccountName -eq $samName } -Properties Enabled -ErrorAction SilentlyContinue

    if ($comp) {

        if ($comp.Enabled) {
            try {
                Disable-ADAccount -Identity $comp.DistinguishedName -ErrorAction Stop
                Write-Host "✅ Компьютер '$name' заблокирован." -ForegroundColor Green
                "Blocked : $name" | Out-File -Append $LogFilePath
            }
            catch {
                Write-Host "❌ Ошибка блокировки '$name' : $_" -ForegroundColor Red
                "Error   : $name   $_" | Out-File -Append $LogFilePath
            }
        }
        else {
            Write-Host "⚠️  '$name' уже заблокирован." -ForegroundColor Yellow
            "Already : $name" | Out-File -Append $LogFilePath
        }

    }
    else {
        Write-Host "❌ Компьютер '$name' не найден в AD." -ForegroundColor Red
        "NotFound: $name" | Out-File -Append $LogFilePath
    }
}

Write-Host "`n✅ Готово!  Подробности в логе $LogFilePath"