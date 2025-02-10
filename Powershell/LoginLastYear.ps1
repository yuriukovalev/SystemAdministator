# Определяем диапазоны дат
$CurrentYear = (Get-Date).Year
$LastYear = $CurrentYear - 1

# Даты для прошлого года
$StartDateLastYear = Get-Date -Day 1 -Month 1 -Year $LastYear
$EndDateLastYear = Get-Date -Day 31 -Month 12 -Year $LastYear

# Даты для текущего года
$StartDateCurrentYear = Get-Date -Day 1 -Month 1 -Year $CurrentYear
$EndDateCurrentYear = Get-Date

# Запрос пользователей за прошлый год
$UsersLastYear = Get-ADUser -Filter {lastLogonDate -ge $StartDateLastYear -and lastLogonDate -le $EndDateLastYear -and Enabled -eq $true} -Properties lastLogonDate, SamAccountName, Name, Enabled

# Запрос пользователей за текущий год
$UsersCurrentYear = Get-ADUser -Filter {lastLogonDate -ge $StartDateCurrentYear -and lastLogonDate -le $EndDateCurrentYear -and Enabled -eq $true} -Properties lastLogonDate, SamAccountName, Name, Enabled

# Проверяем и сохраняем данные для прошлого года
if ($UsersLastYear.Count -gt 0) {
    $UsersLastYear | Select-Object Name, SamAccountName, LastLogonDate | Export-Csv -Path "C:\Reports\ActiveUsers_LastYear.csv" -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Список активных пользователей с активностью в прошлом году сохранен в C:\Reports\ActiveUsers_LastYear.csv"
} else {
    Write-Host "⚠️ Не найдено активных учетных записей с активностью в прошлом году."
}

# Проверяем и сохраняем данные для текущего года
if ($UsersCurrentYear.Count -gt 0) {
    $UsersCurrentYear | Select-Object Name, SamAccountName, LastLogonDate | Export-Csv -Path "C:\Reports\ActiveUsers_CurrentYear.csv" -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Список активных пользователей с активностью в текущем году сохранен в C:\Reports\ActiveUsers_CurrentYear.csv"
} else {
    Write-Host "⚠️ Не найдено активных учетных записей с активностью в текущем году."
}