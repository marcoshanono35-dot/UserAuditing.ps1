$allowedAdmins = @("Administrator")| ForEach-Object { $_.Trim().ToLower() }

$allAdmins = Get-ADGroupMember -Identity "Domain Admins" | Select-Object SamAccountName | ForEach-Object { $_.Trim().ToLower() }

foreach ($acc in $allAdmins) {
    if ($acc -notin $allowedAdmins) {
        Disable-ADAccount -Identity $acc
    }
}
