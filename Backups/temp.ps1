$s = Get-ADObject -Filter * -SearchBase "DC=GREAT,DC=CRETACEOUS" | Group-Object ObjectClass | Select-Object Count

# Initialize the total variable at 0
$total = 0

foreach($c in $s){
    # Add each group's count to the total
    $total += $c.Count
}

# Output the final result
Write-Host "Total Sum of All Records: $total" -ForegroundColor Green
