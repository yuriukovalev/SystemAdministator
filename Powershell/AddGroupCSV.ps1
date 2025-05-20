# Имя группы в Active Directory
$groupName = "br_vpn-ssl"

# Путь к CSV файлу
$csvPath = "C:\ps\users.csv"

# Путь для логирования
$logPath = "C:\ps\log.txt"

# Импортируем модуль Active Directory
Import-Module ActiveDirectory

# Чтение пользователей из CSV
$userList = Import-Csv -Path $csvPath

# Начинаем логирование
Add-Content -Path $logPath -Value "Начало добавления пользователей в группу $groupName - $(Get-Date)"

# Проверка существования группы
$group = Get-ADGroup -Identity $groupName -ErrorAction SilentlyContinue

if (-not $group) {
    Write-Host "Группа $groupName не найдена."
    Add-Content -Path $logPath -Value "Ошибка: Группа $groupName не найдена."
    exit
}

# Добавление пользователей в группу
foreach ($user in $userList) {
    $username = $user.username
    try {
        # Проверяем, состоит ли пользователь уже в группе
        $memberExists = Get-ADGroupMember -Identity $groupName | Where-Object { $_.SamAccountName -eq $username }

        if ($memberExists) {
            $message = "Пользователь $username уже в группе $groupName."
            Write-Host $message
            Add-Content -Path $logPath -Value $message
        } else {
            Add-ADGroupMember -Identity $groupName -Members $username -ErrorAction Stop
            $message = "Пользователь $username добавлен в группу $groupName."
            Write-Host $message
            Add-Content -Path $logPath -Value $message
        }
    } catch {
        $errorMessage = $_.Exception.Message
        $message = "Ошибка при добавлении пользователя $username : $errorMessage"
        Write-Host $message
        Add-Content -Path $logPath -Value $message
    }
}

Add-Content -Path $logPath -Value "Завершение добавления пользователей - $(Get-Date)"