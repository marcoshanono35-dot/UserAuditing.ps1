$acc = Get-ADUser -Filter * | Select-Object -ExpandProperty SamAccountName

foreach ($user in $acc) {
    Write-Host "`nSet password for: $user"
    $Password = Read-Host "Enter the new password for $user" -AsSecureString
    
    Set-ADAccountPassword -Identity $user -NewPassword $Password -Reset
}