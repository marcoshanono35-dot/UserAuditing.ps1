Write-Host "--- WARNING: STARTING AD DESTRUCTIVE TEST ---" -ForegroundColor Red
$Confirm = Read-Host "Are you sure you want to 'Nuke' this AD environment? (Type 'YES')"
if ($Confirm -ne "YES") { exit }

# 1. THE IDENTITY NUKE (Users & Groups)
Write-Host "[1/3] Deleting non-essential Domain Users and Groups..." -ForegroundColor Yellow
# Deletes users that aren't built-in admins to simulate object loss
Get-ADUser -Filter 'Name -ne "Administrator" -and Name -ne "Guest"' | Remove-ADUser -Confirm:$false
# Strips memberships from sensitive groups
Get-ADGroup -Filter 'Name -like "*Admins*"' | ForEach-Object { Remove-ADGroupMember -Identity $_ -Members (Get-ADGroupMember $_) -Confirm:$false }

# 2. THE POLICY NUKE (GPOs)
Write-Host "[2/3] Deleting custom GPOs..." -ForegroundColor Yellow
# Removes GPOs that aren't the Default Domain policies
Get-GPO -All | Where-Object { $_.DisplayName -notlike "Default Domain*" } | Remove-GPO

# 3. THE DATABASE NUKE (Service Corruption)
Write-Host "[3/3] Simulating Database Corruption..." -ForegroundColor Yellow
# Renaming the database file makes the AD service fail to start
Stop-Service NTDS -Force -ErrorAction SilentlyContinue
$Path = "C:\Windows\NTDS\ntds.dit"
if (Test-Path $Path) { Rename-Item $Path "ntds.bak" -ErrorAction SilentlyContinue }

Write-Host "--- NUKE COMPLETE. AD IS NOW BROKEN. ---" -ForegroundColor Red
