$ft = [DateTime]::UtcNow.ToFileTime()

$ldap = "(&(objectCategory=person)(objectClass=user)" +
        "(!(userAccountControl:1.2.840.113556.1.4.803:=2))" +             
        "(!(accountExpires=0))(!(accountExpires=9223372036854775807))" +
        "(accountExpires<=$ft))"

Get-ADUser -LDAPFilter $ldap -Properties SamAccountName,AccountExpirationDate,Enabled |
  Select SamAccountName, Enabled, AccountExpirationDate