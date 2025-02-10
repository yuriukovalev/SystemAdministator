# Определяем пути к файлам
$BlockListPath = "C:\Reports\block.txt"
$LogFilePath = "C:\Reports\BlockedUsers.log"

# Проверяем, существует ли файл block.txt
if (-Not (Test-Path $BlockListPath)) {
    Write-Host "❌ Файл $BlockListPath не найден. Добавьте список логинов и повторите попытку."
    exit
}

# Загружаем список логинов
$UserLogins = Get-Content $BlockListPath

# Проверяем, есть ли логины в файле
if ($UserLogins.Count -eq 0) {
    Write-Host "⚠️ Файл $BlockListPath пуст. Добавьте логины и повторите попытку."
    exit
}

# Открываем лог-файл для записи
"=== Блокировка учетных записей $(Get-Date) ===" | Out-File -Append $LogFilePath

# Обрабатываем каждого пользователя
foreach ($Login in $UserLogins) {
    # Очищаем пробелы в логине
    $Login = $Login.Trim()
    
    # Проверяем, существует ли учетная запись
    $User = Get-ADUser -Filter {SamAccountName -eq $Login} -Properties Enabled -ErrorAction SilentlyContinue

    if ($User) {
        # Проверяем, не отключен ли уже пользователь
        if ($User.Enabled -eq $true) {
            # Отключение пользователя
            Disable-ADAccount -Identity $User.SamAccountName
            Write-Host "✅ Учетная запись '$Login' заблокирована." -ForegroundColor Green
            "Блокирована учетная запись: $Login" | Out-File -Append $LogFilePath
        } else {
            Write-Host "⚠️ Учетная запись '$Login' уже заблокирована." -ForegroundColor Yellow
            "Учетная запись уже заблокирована: $Login" | Out-File -Append $LogFilePath
        }
    } else {
        Write-Host "❌ Учетная запись '$Login' не найдена в Active Directory." -ForegroundColor Red
        "Учетная запись не найдена: $Login" | Out-File -Append $LogFilePath
    }
}

Write-Host "✅ Процесс завершен. Лог записан в $LogFilePath"