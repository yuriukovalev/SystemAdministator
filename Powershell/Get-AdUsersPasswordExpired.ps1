<# 
.SYNOPSIS
  Найти пользователей с протухшим паролем и посчитать, сколько дней он просрочен.

.PARAMETERS
  -Identity <sAM/UPN/DN>     Проверить одного конкретного пользователя
  -SearchBase <DN>           Ограничить область поиска (OU DN)
  -IncludeDisabled           Включать отключённые учётки (по умолчанию: нет)
  -ThresholdDays <int>       Порог просрочки (в днях), по умолчанию 0 = все просроченные
  -ExportCsv <path>          Путь для выгрузки CSV

.OUTPUT
  SamAccountName, DisplayName, Enabled, DaysExpired, ExpireAtUTC, PasswordLastSetUTC, LastLogonDateUTC, DaysSinceLastLogon, OU, DN
#>

param(
  [string]$Identity,
  [string]$SearchBase,
  [switch]$IncludeDisabled,
  [int]$ThresholdDays = 0,
  [string]$ExportCsv
)

# --- подготовка ---
try { Import-Module ActiveDirectory -ErrorAction Stop } catch { Write-Error "RSAT/ActiveDirectory не найден."; return }

$nowUtc = (Get-Date).ToUniversalTime()

# --- выборка пользователей ---
$props = "SamAccountName","DisplayName","Enabled","pwdLastSet","msDS-UserPasswordExpiryTimeComputed","LastLogonDate","DistinguishedName","userAccountControl"

if ($Identity) {
  $users = @( Get-ADUser -Identity $Identity -Properties $props -ErrorAction Stop )
} else {
  $parts = @(
    "(objectCategory=person)"
    "(objectClass=user)"
    "(!(userAccountControl:1.2.840.113556.1.4.803:=65536))"  # НЕ 'пароль не истекает'
  )
  if (-not $IncludeDisabled) {
    $parts += "(!(userAccountControl:1.2.840.113556.1.4.803:=2))" # НЕ disabled
  }
  $ldap = "(&" + ($parts -join '') + ")"

  if ($SearchBase) {
    $users = Get-ADUser -LDAPFilter $ldap -SearchBase $SearchBase -SearchScope Subtree -Properties $props -ResultPageSize 2000 -ResultSetSize $null
  } else {
    $domainDN = (Get-ADDomain).DistinguishedName
    $users = Get-ADUser -LDAPFilter $ldap -SearchBase $domainDN -SearchScope Subtree -Properties $props -ResultPageSize 2000 -ResultSetSize $null
  }
}

# --- вычисление статусов ---
$result = foreach ($u in $users) {
  # 1) Дата/время истечения пароля по политике (учитывает Fine-Grained)
  $expFT = [int64]($u.'msDS-UserPasswordExpiryTimeComputed')
  if (-not $expFT -or $expFT -eq 0 -or $expFT -eq 9223372036854775807) { continue } # "никогда"
  $expUTC = [DateTime]::FromFileTimeUtc($expFT)

  # 2) Не просрочен — пропускаем
  if ($expUTC -gt $nowUtc) { continue }

  # 3) Порог просрочки
  $daysExpired = [math]::Floor(($nowUtc - $expUTC).TotalDays)
  if ($daysExpired -lt $ThresholdDays) { continue }

  # 4) Когда пароль последний раз менялся
  $pwdLastSetUTC = $null
  if ($u.pwdLastSet -and $u.pwdLastSet -ne 0) {
    $pwdLastSetUTC = [DateTime]::FromFileTimeUtc([int64]$u.pwdLastSet)
  }

  # 5) Последний логон (если есть)
  $lld = $null
  if ($u.LastLogonDate) {
    # AD-модуль отдаёт без таймзоны — помечаем как UTC для консистентности
    $lld = [DateTime]::SpecifyKind($u.LastLogonDate, 'Utc')
  }
  $daysSinceLogon = if ($lld) { [math]::Floor(($nowUtc - $lld).TotalDays) } else { $null }

  # 6) Верхний OU
  $dn = $u.DistinguishedName
  $parentDN = ($dn -replace '^CN=[^,]+,', '')
  $topOU = (($parentDN -split ',') | Where-Object { $_ -like 'OU=*' } | Select-Object -First 1) -replace '^OU=',''
  if (-not $topOU) { $topOU = '—' }

  [pscustomobject]@{
    SamAccountName       = $u.SamAccountName
    DisplayName          = $u.DisplayName
    Enabled              = $u.Enabled
    PasswordLastSetUTC   = $pwdLastSetUTC
    ExpireAtUTC          = $expUTC
    DaysExpired          = $daysExpired
    LastLogonDateUTC     = $lld
    DaysSinceLastLogon   = $daysSinceLogon
    OU                   = $topOU
    DN                   = $u.DistinguishedName
  }
}

if (-not $result) {
  Write-Host "Нет пользователей с просроченным паролем по заданным условиям." -ForegroundColor Yellow
  return
}

# --- сортировка и вывод ---
$resultSorted = $result | Sort-Object @{Expression='DaysExpired';Descending=$true},
                                     @{Expression='SamAccountName';Descending=$false}

$resultSorted |
  Format-Table SamAccountName, DisplayName, Enabled, DaysExpired, ExpireAtUTC, PasswordLastSetUTC, LastLogonDateUTC, DaysSinceLastLogon, OU -AutoSize

# --- экспорт ---
if ($ExportCsv) {
  $resultSorted | Export-Csv -NoTypeInformation -Encoding UTF8 $ExportCsv
  Write-Host "Экспортировано в $ExportCsv" -ForegroundColor Green
}