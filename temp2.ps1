Write-Warning "DESTRUCTIVE TEST: DISABLING SERVICES AND WIPING DNS IN 5 SECONDS."
Start-Sleep -Seconds 5

# 1. Kill the "Auto-Repair" Mechanism
# Netlogon re-registers SRV records; stopping it prevents the DC from fixing itself.
Write-Host "Stopping Services..." -ForegroundColor Yellow
Stop-Service Netlogon, DNS -Force

# 2. Delete the Record Blueprints
# Netlogon uses this file to know which records to register. Deleting it makes recovery harder.
$NetlogonPath = "$env:SystemRoot\System32\Config\netlogon.dns"
if (Test-Path $NetlogonPath) { 
    Remove-Item $NetlogonPath -Force 
    Write-Host "Netlogon blueprint deleted." -ForegroundColor Red
}

# 3. Wipe AD-Integrated and Standard Zones
# We use -notin to bypass system-protected zones that cause the script to hang.
$Protected = @("TrustAnchors", "0.in-addr.arpa", "127.in-addr.arpa", "255.in-addr.arpa")

# Start DNS briefly to run the wipe commands
Start-Service DNS
Get-DnsServerZone | Where-Object { $_.ZoneName -notin $Protected } | ForEach-Object {
    Write-Host "Wiping Zone: $($_.ZoneName)" -ForegroundColor Red
    Remove-DnsServerZone -Name $_.ZoneName -Force -ErrorAction SilentlyContinue
}

# 4. Corrupt the Registry (The "Error 87" Trigger)
# Removing these keys causes the service to lose its "parameters," leading to Error 87.
Write-Host "Corrupting Registry Parameters..." -ForegroundColor Red
$RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\DNS\Parameters"
Remove-ItemProperty -Path $RegPath -Name "Forwarders", "ListenAddresses" -ErrorAction SilentlyContinue

# 5. Flush everything and Kill the process
Clear-DnsServerCache -Force
Stop-Service DNS -Force

Write-Host "TEST COMPLETE: DNS CRIPPLED. TEST YOUR BACKUP RESTORE NOW." -ForegroundColor White -BackgroundColor Red
