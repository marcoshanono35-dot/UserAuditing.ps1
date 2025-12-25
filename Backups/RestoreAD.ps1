$BackupPath = "C:\AD_Backup"
$IFMPath = "$BackupPath\AD_Database"
$UserCSV = "$BackupPath\UserSnapshot.csv"
$GPOPath = "$BackupPath\GPOs"

Write-Host "--- Active Directory Restoration Tool ---" -ForegroundColor Cyan


if (-not (Test-Path $BackupPath)) {
    Write-Host "[!] ERROR: Backup folder not found at $BackupPath. Restore aborted." -ForegroundColor Red
    return
}


$SafeMode = (Get-WmiObject Win32_ComputerSystem).BootupState
if ($SafeMode -match "Fail-safe") {
    Write-Host "[!] DSRM DETECTED: Proceeding with Actual Database Restore." -ForegroundColor Yellow
    
    
    $CommandFile = "$env:TEMP\ntds_restore.txt"
    $NtdsCommands = @(
        "activate instance ntds",
        "ifm",
        "restore database from path `"$IFMPath\Active Directory`"",
        "quit",
        "authoritative restore",
        "restore database",
        "quit",
        "quit"
    )
    $NtdsCommands | Out-File $CommandFile -Encoding ASCII

    Write-Host "Restoring from IFM Backup at $IFMPath... Watch for a popup dialog!" -ForegroundColor Yellow
    ntdsutil /s $CommandFile
    
    # Cleanup
    Remove-Item $CommandFile
    Write-Host "--- Database Restored. REBOOT into Normal Mode now. ---" -ForegroundColor Green
} 
else {
    Write-Host "[*] NORMAL MODE DETECTED: Proceeding with Surgical Fixes." -ForegroundColor Yellow

    if (Test-Path $UserCSV) {
        Write-Host "Scanning CSV for missing users/groups..." -ForegroundColor Cyan
        $Users = Import-Csv $UserCSV
        foreach ($U in $Users) {
            $SAM = $U.SamAccountName
            if (-not (Get-ADUser -Filter "SamAccountName -eq '$SAM'" -ErrorAction SilentlyContinue)) {
                Write-Host "  [!] Recreating missing user: $SAM" -ForegroundColor Red
                $OU = $U.DistinguishedName.Substring($U.DistinguishedName.IndexOf("OU="))
                $Pass = ConvertTo-SecureString "P@ssword123!" -AsPlainText -Force
                New-ADUser -Name $SAM -SamAccountName $SAM -Path $OU -AccountPassword $Pass -Enabled $true
            }
            if ($U.MemberOf) {
                $Groups = $U.MemberOf -split ';' | ForEach-Object { if ($_ -match "CN=([^,]+)") { $matches[1] } }
                foreach ($G in $Groups) {
                    Add-ADGroupMember -Identity $G -Members $SAM -ErrorAction SilentlyContinue
                }
            }
        }
    }

    if (Test-Path $GPOPath) {
        Write-Host "Restoring Group Policy Objects..." -ForegroundColor Cyan
        Import-Gpo -All -Path $GPOPath -CreateIfNeeded | Out-Null
        Write-Host "  [+] GPOs Restored." -ForegroundColor Yellow
    }
    
    Write-Host "--- Reconstruction Complete. Run 'gpupdate /force' ---" -ForegroundColor Green
}
