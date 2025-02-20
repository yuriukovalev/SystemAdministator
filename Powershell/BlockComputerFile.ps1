# Импортируем модуль Active Directory
Import-Module ActiveDirectory

# Определяем путь для экспорта
$outputFile = "C:\Reports\enabled_computers.txt"

# Получаем включенные компьютеры
$enabledComputers = Get-ADComputer -Filter {Enabled -eq $true} | Select-Object -ExpandProperty Name

# Записываем список в TXT-файл
$enabledComputers | Out-File -Encoding UTF8 $outputFile

Write-Output "Экспорт завершен. Файл сохранен: $outputFile"