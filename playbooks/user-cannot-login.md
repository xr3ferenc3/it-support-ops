# Playbook: User Cannot Login

## Purpose

This playbook provides a resolution guide for login and authentication failures across
Windows domain accounts, local accounts, and Linux user accounts. Login failures are
high-urgency by nature - a user who cannot log in cannot work - and require a calm,
structured approach that avoids unnecessary account lockouts or security policy violations.

---

## When to Use This Playbook

Use this playbook when the user reports:

- "My password isn't working"
- "I'm locked out of my account"
- "It says my password has expired"
- "I can't log into my computer"
- "I logged in but I'm seeing a temporary profile / different desktop"
- Login screen rejects credentials that the user believes are correct

Do not use this playbook if:
- The issue is access to a specific application after successful OS login - this is
  an application-layer authentication issue, escalate per the application's owning team
- The user suspects unauthorised account access - treat as a security event immediately
  per [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md)

---

## Ticket Intake - Required Information

| Field | What to Record |
|---|---|
| Username / account | Exact username as known to the system |
| Login type | Windows domain, Windows local, Linux local, Linux domain (LDAP/AD-joined) |
| Exact error message | Screenshot or exact text - critical for correct diagnosis |
| When it started | First failed attempt time if known |
| Recent changes | Recent password change, account modification, device change |
| Number of failed attempts | Helps assess lockout risk |
| Working previously | Did this account work on this device before |

**Security check before proceeding:** Confirm the identity of the person requesting
help through an approved verification method (employee ID, manager confirmation, or
organisational identity verification process) before resetting any credentials.
Never reset a password based solely on a phone call claiming to be the user without
verification - this is a common social engineering vector.

---

## Step 1 - Classify the Login Failure Type

The exact error message determines the diagnostic path. Do not guess - read the
message carefully or have the user read it exactly.

| Error Message / Symptom | Classification | Go To |
|---|---|---|
| "The user name or password is incorrect" | Credential mismatch | Step 2 |
| "Your account has been locked" / "too many attempts" | Account lockout | Step 3 |
| "Your password has expired" | Expired password | Step 4 |
| "The trust relationship between this workstation and the domain failed" | Domain trust fault | Step 5 |
| Logs in but shows "Temporary Profile" notice | Profile corruption | Step 6 |
| Login screen freezes or takes a very long time | Profile loading or network fault | Step 7 |
| "This account has been disabled" | Account disabled | Step 8 |
| Login succeeds on other devices, fails on this one | Device-specific fault | Step 9 |

---

## Step 2 - Credential Mismatch

**Confirm basic factors first - these resolve the majority of "wrong password" tickets:**

- [ ] Confirm Caps Lock is not enabled
- [ ] Confirm the correct keyboard layout is active (especially for special characters)
- [ ] Confirm the user is typing the password and not relying on autofill that may be stale
- [ ] Confirm the username is correct (domain\username format if applicable)
- [ ] Confirm the user is selecting the correct account if multiple are listed

**If basics are confirmed correct and password still fails:**

Windows (Active Directory) - check account status:
```powershell
# Requires AD module and appropriate permissions - typically Tier 2,
# but Tier 1 may have read access in many SMB environments

Import-Module ActiveDirectory
Get-ADUser -Identity "username" -Properties LockedOut, PasswordExpired, Enabled, LastLogonDate

# Key fields to review:
# LockedOut        : True/False
# PasswordExpired  : True/False
# Enabled          : True/False
# LastLogonDate    : confirms if recent login attempts are reaching the domain controller
```

Windows (local account):
```powershell
# Check local account status
Get-LocalUser -Name "username" | Select-Object Name, Enabled, PasswordExpired, LastLogon
```

Linux:
```bash
# Check local account status
sudo chage -l username

# Key fields:
# Last password change
# Password expires
# Account expires
# Password inactive

# Check if account is locked
sudo passwd -S username
# Output codes: P = usable password, L = locked, NP = no password set
```

**If credentials are confirmed correct via Tier 2 verification but still rejected:**
This may indicate replication delay (AD) or a password sync issue. Escalate to Tier 2.

---

## Step 3 - Account Lockout

Account lockouts occur after a policy-defined number of failed login attempts, as a
security measure against brute-force attacks.

> **Book reference:** CompTIA A+ Guide to IT Technical Support (11th Ed.) covers account
> lockout policies as part of Windows security configuration. Lockout thresholds are
> typically configured via Group Policy in domain environments.

**Step 3.1 - Identify the cause of the lockout before unlocking**

Unlocking an account without understanding why it locked can result in an immediate
re-lock if the underlying cause (e.g. a saved incorrect password in a mobile device or
mapped drive) is not addressed.

Windows (Active Directory):
```powershell
# Check lockout status and source (requires appropriate permissions)
Get-ADUser -Identity "username" -Properties LockedOut, BadPwdCount, BadLogonCount

# Identify which device caused the lockout (useful for finding a saved bad password)
# Check Event Viewer on the Domain Controller for Event ID 4740 (account lockout)
# This is typically a Tier 2 task requiring DC access
```

**Common lockout causes to ask the user about:**

- A mobile device or tablet with a saved old password attempting to sync email
- A mapped network drive with cached old credentials
- An old RDP session left open with outdated credentials
- A scheduled task or service running under the user's account with an old password

**Step 3.2 - Unlock the account**

Windows (Active Directory) - if Tier 1 has delegated permission:
```powershell
Unlock-ADAccount -Identity "username"

# Verify unlock was successful
Get-ADUser -Identity "username" -Properties LockedOut
```

Windows local account:
```powershell
# Local accounts do not lock in the same way by default, but if using
# local security policy lockout:
net user username /active:yes
```

Linux:
```bash
# Unlock a locked local account
sudo passwd -u username

# Verify
sudo passwd -S username
```

**After unlocking - instruct the user to:**
1. Update any saved passwords on mobile devices before attempting to log in again
2. Close any open sessions using the old password (RDP, mapped drives)
3. Attempt login fresh and confirm success

---

## Step 4 - Expired Password

```powershell
# Windows (Active Directory) - confirm expiry and force reset on next login if needed
Get-ADUser -Identity "username" -Properties PasswordLastSet, PasswordExpired

# If a manual reset is required (verify identity first, per security note above)
Set-ADAccountPassword -Identity "username" -Reset -NewPassword (
    Read-Host -AsSecureString "Enter temporary password"
)
Set-ADUser -Identity "username" -ChangePasswordAtLogon $true
```

Linux:
```bash
# Check password expiry status
sudo chage -l username

# Force password change at next login
sudo chage -d 0 username

# Reset password if needed (verify identity first)
sudo passwd username
```

**Communicate to the user:**
- Confirm their organisation's password complexity requirements before they set a new one
- Advise that they will be prompted to change their password at next login
- If a temporary password was set, ensure secure delivery (not via unencrypted email or chat)

---

## Step 5 - Domain Trust Relationship Failure

**Error:** "The trust relationship between this workstation and the primary domain failed"

This indicates the computer account's password (separate from the user's password) is
out of sync with Active Directory. Common causes: the device was restored from an old
backup/snapshot, or was offline longer than the machine account password rotation period.

This typically requires Tier 2 access to rejoin the domain.

```powershell
# Tier 1 diagnostic confirmation (read-only check)
# Confirm this is the actual error by checking Event Viewer
Get-WinEvent -LogName System -MaxEvents 50 |
    Where-Object {$_.Id -eq 5719 -or $_.Message -like "*trust relationship*"}
```

**Tier 2 resolution (for reference - confirm scope before performing):**
```powershell
# Requires local administrator credentials and domain admin credentials
# Remove from domain, rejoin
Remove-Computer -UnjoinDomainCredential (Get-Credential) -PassThru -Verbose -Restart
# After restart, rejoin:
Add-Computer -DomainName "company.local" -Credential (Get-Credential) -Restart
```

**Escalate to Tier 2 immediately** - do not attempt domain rejoin without confirming
scope and authorisation, as this requires domain administrator credentials and causes
a restart that will disrupt the user's work.

---

## Step 6 - Temporary Profile / Profile Corruption

**Symptom:** User logs in successfully but sees a notification: "You have been logged
on with a temporary profile" - desktop settings, files on the desktop, and saved
preferences are missing or reset.

> **Book reference:** CompTIA A+ Guide to IT Technical Support (11th Ed.) covers user
> profile structure and corruption as a common Windows fault requiring profile repair
> or recreation.

**Step 6.1 - Confirm profile corruption:**

```powershell
# Check the registry for the profile's state
# Look in: HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList

Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" |
    ForEach-Object {
        $sid = $_.PSChildName
        $path = (Get-ItemProperty $_.PSPath).ProfileImagePath
        $state = (Get-ItemProperty $_.PSPath).State
        [PSCustomObject]@{SID=$sid; Path=$path; State=$state}
    }

# A profile folder appended with ".bak" alongside the original
# (e.g. C:\Users\jsmith and C:\Users\jsmith.bak) confirms profile
# corruption - Windows created a new profile because the original failed to load
```

**Step 6.2 - Back up data from the corrupted profile before any repair:**

```powershell
# Copy user data from the corrupted profile to a safe location
# IMPORTANT: Do this before attempting any repair - data loss risk otherwise

$username = "jsmith"
$sourcePath = "C:\Users\$username"
$backupPath = "C:\Temp\ProfileBackup_$username"

New-Item -ItemType Directory -Path $backupPath -Force

$foldersToBackup = @("Desktop", "Documents", "Downloads", "Pictures", "Favorites")
foreach ($folder in $foldersToBackup) {
    $src = Join-Path $sourcePath $folder
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $backupPath -Recurse -Force
        Write-Host "Backed up: $folder"
    }
}
```

**Step 6.3 - Repair the profile:**

```powershell
# Method: Remove the corrupted profile registry entry, allow Windows
# to recreate the profile cleanly, then restore user data

# 1. Log the user out completely
# 2. Open Registry Editor (regedit) as administrator
# 3. Navigate to:
#    HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList
# 4. Find the SID matching the user (identified in Step 6.1)
# 5. If there is a corresponding SID.bak key, the original SID key is the
#    broken reference - back up the registry key (export) then delete it
# 6. Rename or remove the old profile folder (e.g. C:\Users\jsmith.bak)
# 7. Have the user log in again - Windows will create a fresh profile
# 8. Restore the backed-up data from Step 6.2 into the new profile folders

Write-Host "After user logs in with fresh profile, restore data with:"
Write-Host "Copy-Item -Path '$backupPath\*' -Destination 'C:\Users\$username' -Recurse -Force"
```

> **Caution:** Registry editing carries risk. If the technician is not confident
> performing this manually, escalate to Tier 2 rather than risk further profile damage.

---

## Step 7 - Slow Login / Profile Loading Delay

**Symptom:** Login screen accepts credentials but takes an extended time (multiple
minutes) before the desktop loads.

**Common causes and checks:**

```powershell
# Check if slow login correlates with network/domain connectivity
# (roaming profiles or domain-based login scripts depend on network availability)
Test-NetConnection -ComputerName dc01.company.local -Port 389

# Check startup program load - excessive startup items slow login
Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location

# Check for a large profile size (roaming profiles especially)
Get-ChildItem "C:\Users\username" -Recurse -ErrorAction SilentlyContinue |
    Measure-Object -Property Length -Sum |
    Select-Object @{N="SizeGB";E={[math]::Round($_.Sum / 1GB, 2)}}
```

```bash
# Linux: Check login script execution time and home directory size
du -sh /home/username

# Check for network-mounted home directories (NFS) causing delay
mount | grep home
df -h /home/username
```

**If caused by network dependency (roaming profile / domain login script):**
Refer to [`no-network-connectivity.md`](no-network-connectivity.md) to confirm network
health first - slow login is frequently a symptom of an underlying network fault.

**If caused by excessive startup items:**
Work with the user to identify and disable unnecessary startup applications, or
escalate to Tier 2 for Group Policy-managed startup item review.

---

## Step 8 - Account Disabled

```powershell
# Windows (Active Directory)
Get-ADUser -Identity "username" -Properties Enabled

# If disabled and re-enabling is authorised (verify with manager/HR per policy):
Enable-ADAccount -Identity "username"
```

```bash
# Linux
sudo passwd -S username
# Output showing "L" indicates locked/disabled

sudo passwd -u username  # Unlock
```

**Important:** Account disablement is frequently intentional (offboarding, security
hold, HR action, leave of absence). Do not re-enable an account without confirming
authorisation through your organisation's account management process. If the reason
for disablement is unclear, escalate to Tier 2 or HR/security rather than re-enabling.

---

## Step 9 - Device-Specific Login Failure

**Symptom:** The user can log into the same account successfully on other devices,
but this specific device rejects login.

```powershell
# Check if the device itself is domain-joined correctly
Get-CimInstance Win32_ComputerSystem | Select-Object Domain, PartOfDomain

# Check time synchronisation - Kerberos authentication fails if device
# time differs from domain controller by more than the configured tolerance
# (default 5 minutes)
w32tm /query /status

# Resync time if drifted
w32tm /resync
```

```bash
# Linux: Check time synchronisation (critical for Kerberos/LDAP auth)
timedatectl status

# Resync if needed
sudo systemctl restart systemd-timesyncd
# or
sudo ntpdate pool.ntp.org
```

**Time drift is a frequently overlooked cause** of authentication failures in domain
and LDAP environments. Always check this when login fails on one device but works
on others for the same account.

---

## Escalation Criteria

Escalate to Tier 2 when:

- [ ] Domain trust relationship failure is confirmed (requires domain rejoin)
- [ ] Account lockout source cannot be identified and recurs immediately after unlock
- [ ] Profile corruption repair requires registry editing beyond Tier 1 confidence
- [ ] Account is disabled and the reason is unclear or requires HR/security confirmation
- [ ] Credentials are confirmed correct by the user but consistently rejected
  (possible AD replication issue)
- [ ] Multiple users report simultaneous login failures (possible domain controller fault)
- [ ] Any suspicion of unauthorised access attempts on the account

**Escalation package must include:**

- Exact error message
- Account status findings (locked/expired/disabled) from diagnostic commands
- Steps already attempted and their results
- Whether the user can log in on other devices (isolates device vs. account fault)
- Time synchronisation status if checked

---

## Verification Checklist

- [ ] User identity verified before any credential reset
- [ ] Root cause of login failure identified and documented
- [ ] User successfully logs in and confirms desktop/profile loads correctly
- [ ] If profile was recreated, confirm user's data was successfully restored
- [ ] If account was unlocked, confirm the source of lockout was addressed to prevent re-lock
- [ ] User is reminded of password policy if a reset was performed
- [ ] No unauthorised account changes were made

---

## Security Considerations

- Always verify the identity of the person requesting a password reset through an
  approved method before performing the reset - phone-based password reset requests
  are a common social engineering target
- Never communicate a new or temporary password via unencrypted email or chat -
  use a secure delivery method per organisational policy
- Do not re-enable a disabled account without confirming authorisation - disablement
  is often a deliberate security or HR action
- Repeated lockouts with no identifiable cause from the user's own devices may indicate
  a credential-stuffing or brute-force attempt against the account - escalate as a
  potential security event rather than continuing to simply unlock
- Profile corruption that occurs alongside other unusual system behaviour (unexpected
  processes, modified files) should be treated with caution - confirm it is a genuine
  technical fault before assuming it is routine corruption

---

## Related Documents

| Document | Relationship |
|---|---|
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Security event and Tier 2 escalation criteria |
| [`no-network-connectivity.md`](no-network-connectivity.md) | Use when slow/failed login correlates with network fault |
| [`../incidents/incident-classification-guide.md`](../incidents/incident-classification-guide.md) | For suspected unauthorised access scenarios |
| [`../templates/ticket-template.md`](../templates/ticket-template.md) | Ticket format for this scenario |
| [`../reference/powershell-command-reference.md`](../reference/powershell-command-reference.md) | Full AD and account management cmdlet reference |