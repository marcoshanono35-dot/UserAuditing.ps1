$BackupPath = "C:\DNS_Backup"
New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null

$SnapshotPath = "$BackupPath\DNS_Snapshot.csv"
if (Test-Path $SnapshotPath) { Remove-Item $SnapshotPath -Force }

Get-DnsServerZone | ForEach-Object {
    $name = $_.ZoneName
    Get-DnsServerResourceRecord -ZoneName $name | 
    Select-Object @{n='Zone';e={$name}}, HostName, RecordType, @{n='Data';e={$_.RecordData.IPv4Address.IPAddressToString}} | 
    Export-Csv -Append -Path $SnapshotPath -NoTypeInformation
}

reg export "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DNS\Parameters" "$BackupPath\DNS_Settings.reg" /y

Get-DnsServerZone | ForEach-Object {
    $ZoneName = $_.ZoneName
    Get-DnsServerResourceRecord -ZoneName $ZoneName | Export-Clixml -Path "$BackupPath\$ZoneName.xml"
}

Get-DnsServerZone | Select-Object ZoneName, ZoneType, IsAutoCreated, ReplicationScope | Export-Csv "$BackupPath\ZoneList.csv"

Write-Host "Backup Complete at $BackupPath" -ForegroundColor Green
