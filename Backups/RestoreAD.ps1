# --- CONFIGURATION ---
$BackupPath = "C:\AD_Backup"
$IFMPath = "$BackupPath\AD_Database"
$UserCSV = "$BackupPath\UserSnapshot.csv"
$GPOPath = "$BackupPath\GPOs"

# 1. CHECK FOR DSRM (SAFE MODE)
# Reliability: Registry check is the source of truth when WMI is null.
$SafeMode = Test-Path "HKLM:\System\CurrentControlSet\Control\SafeBoot\Option"

if ($SafeMode) {
    Write-Host "[!] DSRM DETECTED: Seeding database and providing manual guide." -ForegroundColor Yellow
    
    # Seed the database so the Jet engine can start.
    Copy-Item -Path "$IFMPath\Active Directory\ntds.dit" -Destination "C:\Windows\NTDS\ntds.dit" -Force
    
    Write-Host "STEP 1: Database file seeded to C:\Windows\NTDS\ntds.dit" -ForegroundColor Cyan
    esentutl /mh C:\Windows\NTDS\ntds.dit

    Write-Host "STEP 2: Run this exact command to restore the GREAT.CRETACEOUS domain:" -ForegroundColor Cyan
    Write-Host "ntdsutil `"activate instance ntds`" `"authoritative restore`" `"restore subtree \`"DC=GREAT,DC=CRETACEOUS\`"`" quit quit"

    Write-Host "STEP 3: Return to Normal Mode" -ForegroundColor Cyan
    Write-Host "bcdedit /deletevalue {current} safeboot"
    Write-Host "Restart-Computer"
} 
else {
    Write-Host "[*] NORMAL MODE DETECTED: Proceeding with Surgical Fixes." -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"

    # STEP 1: Fix System Time
    # Resolves SEC_E_CERT_EXPIRED errors (GitHub/SSL).
    Write-Host "[*] STEP 1: Syncing System Time..." -ForegroundColor Cyan
    Set-Date -Date "01/06/2026 17:50" 

    # STEP 2: Import GPOs
    # Explicitly import module to fix 'Get-GPOBackup not recognized' error.
    if (Test-Path $GPOPath) {
        Write-Host "[*] STEP 2: Importing GPO Exports..." -ForegroundColor Cyan
        Import-Module GroupPolicy -ErrorAction SilentlyContinue
        Get-ChildItem $GPOPath -Directory | ForEach-Object {
            try {
                $Backup = Get-GPOBackup -BackupId $_.Name -Path $GPOPath
                Write-Host " Importing GPO: $($Backup.DisplayName)" -ForegroundColor Gray
                Import-GPO -BackupId $_.Name -Path $GPOPath -TargetName $Backup.DisplayName -CreateIfNeeded | Out-Null
            } catch {
                Write-Host " [!] Failed to import GPO folder: $($_.Name)" -ForegroundColor Red
            }
        }
    }

    # STEP 3: Reconstruct Users from CSV
    # Fixed the missing closing quote on the CSV path.
    if (Test-Path $UserCSV) {
        Write-Host "[*] STEP 3: Reconstructing Users from CSV..." -ForegroundColor Cyan
        $Users = Import-Csv -Path $UserCSV
        foreach ($U in $Users) {
            if (-not (Get-ADUser -Filter "SamAccountName -eq '$($U.SamAccountName)'" -ErrorAction SilentlyContinue)) {
                Write-Host " Creating user: $($U.SamAccountName)" -ForegroundColor Gray
                $OU = $U.DistinguishedName.Substring($U.DistinguishedName.IndexOf("OU="))
                $SecurePass = ConvertTo-SecureString "P@ssword123!" -AsPlainText -Force
                New-ADUser -Name $U.SamAccountName -SamAccountName $U.SamAccountName -Path $OU -AccountPassword $SecurePass -Enabled $true
            }
        }
    }

    Write-Host "`n--- Reconstruction Complete. Please run 'gpupdate /force' ---" -ForegroundColor Green
}
