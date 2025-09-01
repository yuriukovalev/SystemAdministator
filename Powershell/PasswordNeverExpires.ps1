#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
  Найти пользователей в AD: sAMAccountName заканчивается на "-out",
  PasswordNeverExpires=TRUE и AccountExpires=Never.
.PARAMETERS
  -SearchBase "OU=Users,OU=HQ,DC=contoso,DC=local"  # граница поиска
  -Server "dc01.contoso.local"                      # конкретный КД
  -IncludeDisabled                                  # включить отключённые учётки
  -MatchAttribute sAMAccountName|userPrincipalName  # где матчить "-out"
  -CsvPath "D:\reports\out-users.csv"               # путь для CSV
  -Grid                                             # показать Out-GridView
#>

param(
  [string]$SearchBase,
  [string]$Server,
  [switch]$IncludeDisabled,
  [ValidateSet('sAMAccountName','userPrincipalName')]
  [string]$MatchAttribute = 'sAMAccountName',
  [string]$CsvPath = ".\AD_Out_NoExpiry_{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmm'),
  [switch]$Grid
)

Import-Module ActiveDirectory -ErrorAction Stop

# Конструируем LDAP-фильтр
$clauses = @(
  '(objectCategory=person)'
  '(objectClass=user)'
  "($MatchAttribute=*-out)"
  '(userAccountControl:1.2.840.113556.1.4.803:=65536)'               # PASSWORD_NEVER_EXPIRES
  '(|(accountExpires=0)(accountExpires=9223372036854775807))'        # Never
)
if (-not $IncludeDisabled) {
  $clauses += '(!(userAccountControl:1.2.840.113556.1.4.803:=2))'    # NOT DISABLED
}
$ldapFilter = '(&' + ($clauses -join '') + ')'

$props = @(
  'sAMAccountName','name','userPrincipalName','enabled','mail',
  'userAccountControl','accountExpires','pwdLastSet','lastLogonTimestamp',
  'whenCreated','distinguishedName'
)

$params = @{ LDAPFilter = $ldapFilter; Properties = $props }
if ($SearchBase) { $params.SearchBase = $SearchBase }
if ($Server)     { $params.Server     = $Server     }

$neverVals = 0, 9223372036854775807

$results = (Get-ADUser @params) |
  Select-Object `
    @{n='sAMAccountName';e={$_.sAMAccountName}},
    @{n='DisplayName';   e={$_.Name}},
    @{n='UPN';           e={$_.UserPrincipalName}},
    @{n='Enabled';       e={$_.Enabled}},
    @{n='PasswordNeverExpires'; e={ ($_.userAccountControl -band 0x10000) -ne 0 }},
    @{n='AccountExpiry'; e={
        if ($_.accountExpires -in $neverVals) { 'Never' }
        elseif ($_.accountExpires) { [DateTime]::FromFileTimeUtc([int64]$_.accountExpires) }
    }},
    @{n='PwdLastSet';     e={ if ($_.pwdLastSet) { [DateTime]::FromFileTimeUtc([int64]$_.pwdLastSet) } }},
    @{n='LastLogonApprox';e={ if ($_.lastLogonTimestamp) { [DateTime]::FromFileTimeUtc([int64]$_.lastLogonTimestamp) } }},
    @{n='Mail';           e={$_.mail}},
    @{n='DN';             e={$_.DistinguishedName}} |
  Sort-Object sAMAccountName

$results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
if ($Grid) { $results | Out-GridView -Title 'Users *-out | PwdNeverExpires | Account Never Expires' }

Write-Host ("Найдено: {0}. CSV: {1}" -f ($results.Count), (Resolve-Path $CsvPath))