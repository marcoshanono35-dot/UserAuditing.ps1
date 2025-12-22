$BackupPath = "C:\DNS_Backup" 

$ZoneList = Import-Csv "$BackupPath\ZoneList.csv"
foreach ($Z in $ZoneList) {
    if ($Z.IsAutoCreated -eq $false) {
        try {
            Add-DnsServerPrimaryZone -Name $Z.ZoneName -ReplicationScope "Domain" -ErrorAction SilentlyContinue
            Write-Host "Zone Check: $($Z.ZoneName)" -ForegroundColor Cyan
        } catch {}
    }
}

$XMLFiles = Get-ChildItem "$BackupPath\*.xml"
foreach ($File in $XMLFiles) {
    $ZoneName = $File.BaseName
    $Records = Import-Clixml $File.FullName
    
    foreach ($Record in $Records) {
        try {
            Add-DnsServerResourceRecord -ZoneName $ZoneName -InputObject $Record -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Failed to add $($Record.HostName) to $ZoneName"
        }
    }
    Write-Host "Restored records for $ZoneName" -ForegroundColor Green
}
