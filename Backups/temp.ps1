# Count including the deleted objects container
$totalWithDeleted = (Get-ADObject -Filter * -IncludeDeletedObjects -SearchBase "DC=GREAT,DC=CRETACEOUS").Count

# Count objects in the Configuration partition (where some of those 381 might live)
$configCount = (Get-ADObject -Filter * -SearchBase "CN=Configuration,DC=GREAT,DC=CRETACEOUS").Count

Write-Host "Visible Objects: 287"
Write-Host "Objects + Deleted: $totalWithDeleted"
Write-Host "Configuration Records: $configCount"
