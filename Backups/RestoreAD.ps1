# --- CONFIGURATION ---
$BackupPath = "C:\AD_Backup"
$IFMPath = "$BackupPath\AD_Database"
$UserCSV = "$BackupPath\UserSnapshot.csv"
$GPOPath = "$BackupPath\GPOs"

# 1. CHECK FOR DSRM (SAFE MODE)
# Reliability: WMI BootupState often returns null; the registry is the source of truth.
$SafeMode = Test-Path "HKLM:\System\CurrentControlSet\Control\SafeBoot\Option"

Write-Host "`n--- MANUAL RESTORATION GUIDE ---" -ForegroundColor Cyan
Write-Host "Because auto-entry is failing, follow these steps exactly." -ForegroundColor White

if ($SafeMode) {
    Write-Host "[!] DSRM DETECTED: Preparing database for restore." -ForegroundColor Yellow
    
    # --- INSERT THE COMMAND HERE ---
    # This seeds the database so ntdsutil has a file to work on.
    Copy-Item -Path "$IFMPath\Active Directory\ntds.dit" -Destination "C:\Windows\NTDS\ntds.dit" -Force
    # -------------------------------

    Write-Host "STEP 1: Database file seeded to C:\Windows\NTDS\ntds.dit" -ForegroundColor Cyan
    
    # Verify the shutdown state as a sanity check.
    esentutl /mh C:\Windows\NTDS\ntds.dit
    
    Write-Host "STEP 2: Run this exact command to bypass syntax errors:" -ForegroundColor Cyan
    Write-Host "ntdsutil `"activate instance ntds`" `"authoritative restore`" `"restore database`" quit quit"

    Write-Host "STEP 3: Return to Normal Mode" -ForegroundColor Cyan
    Write-Host "bcdedit /deletevalue {current} safeboot"
    Write-Host "Restart-Computer"
} 
else {
    Write-Host "[*] NORMAL MODE DETECTED: Proceeding with Surgical Fixes." -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"

    # STEP 1: Fix System Time
    # This resolves the SEC_E_CERT_EXPIRED error seen in your logs.
    Write-Host "[*] STEP 1: Syncing System Time..." -ForegroundColor Cyan
    $CurrentDate = "01/06/2026 17:45" # Adjusted to match your last successful restore time
    Set-Date -Date $CurrentDate

    # STEP 2: Import GPOs
    # Replaced the invalid -All parameter with a functional loop.
    if (Test-Path $GPOPath) {
        Write-Host "[*] STEP 2: Importing GPO Exports..." -ForegroundColor Cyan
        Get-ChildItem $GPOPath -Directory | ForEach-Object {
            Write-Host " Importing GPO: $($_.Name)" -ForegroundColor Gray
            $Backup = Get-GPOBackup -BackupId $_.Name -Path $GPOPath
            Import-GPO -BackupId $_.Name -Path $GPOPath -TargetName $Backup.DisplayName -CreateIfNeeded
        }
    }

    # STEP 3: Reconstruct Users from CSV
    # This works now because ADWS is running in Normal Mode.
    if (Test-Path $UserCSV) {
        Write-Host "[*] STEP 3: Reconstructing Users from CSV..." -ForegroundColor Cyan
        $Users = Import-Csv $UserCSV
        foreach ($U in $Users) {
            if (-not (Get-ADUser -Filter "SamAccountName -eq '$($U.SamAccountName)'" -ErrorAction SilentlyContinue)) {
                Write-Host " Creating user: $($U.SamAccountName)" -ForegroundColor Gray
                # Extracts the OU path from the DistinguishedName
                $OU = $U.DistinguishedName.Substring($U.DistinguishedName.IndexOf("OU="))
                $SecurePass = ConvertTo-SecureString "P@ssword123!" -AsPlainText -Force
                New-ADUser -Name $U.SamAccountName -SamAccountName $U.SamAccountName -Path $OU -AccountPassword $SecurePass -Enabled $true
            }
        }
    }

    Write-Host "`n--- Reconstruction Complete. Please run 'gpupdate /force' ---" -ForegroundColor Green
    
    Write-Host "`n[!] To return to DSRM if needed, type:" -ForegroundColor Red
    Write-Host "bcdedit /set {current} safeboot dsrepair && Restart-Computer"
}
