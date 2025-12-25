Write-Host "--- WARNING: STARTING AD DESTRUCTIVE TEST ---" -ForegroundColor Red
$Confirm = Read-Host "Are you sure you want to 'Nuke' this AD environment? (Type 'YES')"
if ($Confirm -ne "YES") { exit }

# 1. DELETE USERS & GROUPS (The Identity Nuke)
# We exclude built-in accounts like 'Administrator' and 'Guest' to avoid total lockouts
Write-Host "[1/3] Deleting non-essential Domain Users and Groups..." -ForegroundColor Yellow
Get-ADUser -Filter 'Name -ne "Administrator" -and Name -ne "Guest"' | Remove-ADUser -Confirm:$false
Get-ADGroup -Filter 'Category -eq "Security"' | Where-Object { $_.Name -notlike "Domain *" -and $_.Name -notlike "Schema *" } | Remove-ADGroup -Confirm:$false

# 2. WIPE GROUP POLICY (The Policy Nuke)
# This removes all GPOs except the default ones (which it will attempt to reset)
Write-Host "[2/3] Deleting custom GPOs and resetting defaults..." -ForegroundColor Yellow
Get-GPO -All | Where-Object { $_.DisplayName -notlike "Default Domain*" } | Remove-GPO
# Optional: Resetting Default Domain Policy to "Blank" settings
# dcgpofix /target:Both /force 

# 3. CORRUPT THE SERVICE (The Database Nuke)
# This stops the AD service and renames the database file so it 'disappears'
Write-Host "[3/3] Simulating Database Corruption..." -ForegroundColor Yellow
Stop-Service NTDS -Force -ErrorAction SilentlyContinue
# Note: Renaming requires being in DSRM or having the service stopped
$Path = "C:\Windows\NTDS\ntds.dit"
if (Test-Path $Path) { Rename-Item $Path "ntds.bak" -ErrorAction SilentlyContinue }

Write-Host "--- NUKE COMPLETE. AD IS NOW BROKEN. ---" -ForegroundColor Red
Write-Host "Test 1: Check Active Directory Users and Computers (Should be empty/broken)."
Write-Host "Test 2: Try running 'gpresult /h report.html' (Should show missing GPOs)."
