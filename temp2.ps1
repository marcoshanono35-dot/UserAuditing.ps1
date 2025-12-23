# Check for Administrative Privileges first
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "You MUST run this as Administrator."
    break
}

# 1. Test DNS Module
if (!(Get-Module -ListAvailable DNSServer)) {
    Write-Error "DNS Server Module not found. The script cannot proceed."
}

# 2. Wipe Zones with Error Reporting (Removed SilentlyContinue)
try {
    $zones = Get-DnsServerZone | Where-Object {$_.ZoneName -ne "TrustAnchors"}
    foreach ($zone in $zones) {
        Write-Host "Attempting to delete: $($zone.ZoneName)"
        Remove-DnsServerZone -Name $zone.ZoneName -Force
    }
} catch {
    Write-Host "Failed to delete zones: $_" -ForegroundColor Yellow
}
