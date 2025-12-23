Get-WinEvent -LogName "DNS Server" -MaxEvents 20 | 
    Where-Object { $_.Id -eq 4000 -or $_.Id -eq 4015 } | 
    Select-Object TimeCreated, Id, Message | Format-List
