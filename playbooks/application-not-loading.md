# Playbook: Application Not Launching

## Purpose

This playbook provides a resolution guide for tickets where an application fails to
open, crashes immediately on launch, hangs during startup, or displays an error before
becoming usable. This covers desktop applications on both Windows and Linux.

Application launch failures have a wide range of causes - corrupted installation,
missing dependencies, conflicting processes, insufficient permissions, or underlying
system resource exhaustion. This playbook works through causes in order of likelihood
and diagnostic cost.

---

## When to Use This Playbook

Use this playbook when the user reports:

- "The application won't open"
- "It opens then immediately closes"
- "I click it and nothing happens"
- "It shows an error message and won't start"
- "It opens but freezes immediately"
- "It worked yesterday, now it won't open"

Do not use this playbook if:
- The application opens but performs slowly - use
  [`high-cpu-memory-usage.md`](high-cpu-memory-usage.md) to check resource contention first
- The application requires network access and the network itself is at fault - use
  [`no-network-connectivity.md`](no-network-connectivity.md)
- The failure is OS-wide (multiple applications failing) - this points to an OS-level
  fault rather than a single application issue; broaden diagnosis accordingly

---

## Ticket Intake - Required Information

| Field | What to Record |
|---|---|
| Application name and version | Exact name; version if known |
| Exact symptom | Won't open / crashes / freezes / error message |
| Exact error message | Screenshot or exact text - critical for diagnosis |
| When it started | First failure time, and what was happening before |
| Recent changes | Updates (OS or application), new install, configuration change |
| Other applications affected | Isolated to this app, or wider pattern |
| Reproducibility | Does it fail every time, or intermittently |

---

## Step 1 - Confirm Scope: Single Application or System-Wide

```
Ask: "Are any other applications also failing to open or behaving strangely?"

If other applications are also affected:
  → This is likely an OS-level or resource-level fault, not application-specific
  → Check system resources: high-cpu-memory-usage.md
  → Check for recent OS updates or pending restarts
  → Check disk space (applications can fail silently when disk is full)

If only this one application is affected:
  → Continue with this playbook - application-specific fault
```

**Quick disk space check (common overlooked cause):**

```powershell
# Windows
Get-PSDrive -PSProvider FileSystem |
    Select-Object Name, @{N="UsedGB";E={[math]::Round($_.Used/1GB,2)}},
                  @{N="FreeGB";E={[math]::Round($_.Free/1GB,2)}}

# Less than 10% free space or under 5GB free on the system drive
# can cause application launch failures, especially for applications
# that write temp files or check available space on startup
```

```bash
# Linux
df -h /

# Check inode usage too - a full inode table also causes launch failures
# even when disk space appears available
df -i /
```

---

## Step 2 - Check Whether the Process Is Already Running

A common cause of "nothing happens when I click it" is a hung instance of the
application already running in the background, often invisible in the taskbar.

```powershell
# Windows: Check for existing processes
Get-Process | Where-Object {$_.ProcessName -like "*appname*"} |
    Select-Object ProcessName, Id, CPU, WorkingSet, Responding

# If found and "Responding" is False - the process is hung
# Terminate the hung process before relaunching
Stop-Process -Name "appname" -Force

# Verify it has been terminated
Get-Process -Name "appname" -ErrorAction SilentlyContinue
```

```bash
# Linux: Check for existing processes
ps aux | grep -i appname | grep -v grep

# If a hung or zombie process is found
kill -9 <PID>

# Verify termination
ps aux | grep -i appname | grep -v grep
```

**After confirming no hung process exists, attempt to relaunch the application.**
If it now opens correctly, the fault is resolved - document and verify with user.

---

## Step 3 - Review Event Logs / Application Logs for Crash Details

Identifying the specific error behind a crash narrows the cause significantly and
avoids guessing.

```powershell
# Windows: Check Application event log for recent crash entries
Get-WinEvent -LogName Application -MaxEvents 50 |
    Where-Object {$_.LevelDisplayName -eq "Error" -and
                  $_.Message -like "*appname*"} |
    Select-Object TimeCreated, Id, Message |
    Format-List

# Common Event IDs to look for:
# 1000 - Application Error (the application itself crashed)
# 1001 - Windows Error Reporting
# 1002 - Application Hang

# Get specific fault details for the most recent crash
Get-WinEvent -LogName Application -MaxEvents 1 -FilterXPath `
    "*[System[(EventID=1000)]]" -ErrorAction SilentlyContinue |
    Format-List TimeCreated, Message
```

```bash
# Linux: Check system journal for application errors
journalctl --since "1 hour ago" | grep -i appname

# Check for core dumps (indicates a crash)
coredumpctl list | grep -i appname

# View details of the most recent core dump
coredumpctl info appname 2>/dev/null | head -30

# Check application-specific logs if they exist
# Common locations:
ls -la ~/.config/appname/ 2>/dev/null
ls -la ~/.local/share/appname/ 2>/dev/null
find /var/log -iname "*appname*" 2>/dev/null
```

**What to look for in crash details:**

| Error Pattern | Likely Cause |
|---|---|
| Faulting module: a specific .dll | Corrupted or missing dependency - reinstall or repair |
| Access violation (0xc0000005) | Memory corruption - reinstall application |
| Out of memory | System resource exhaustion - check available RAM |
| Missing .dll / shared library error | Missing dependency - install required runtime |
| Permission denied / Access denied | Insufficient user permissions on app files or folders |
| License/activation error | Licensing server unreachable or license expired |

---

## Step 4 - Verify Application Dependencies

Many applications depend on runtime frameworks that can become corrupted or missing,
especially after OS updates.

```powershell
# Windows: Check for common required runtimes
Get-CimInstance -ClassName Win32_Product |
    Where-Object {$_.Name -like "*Visual C++*" -or
                  $_.Name -like "*.NET*"} |
    Select-Object Name, Version

# Check installed .NET versions specifically
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP" -Recurse |
    Get-ItemProperty -Name Version -ErrorAction SilentlyContinue |
    Select-Object PSChildName, Version

# If a required runtime is missing or outdated, download and install
# the latest redistributable from the official Microsoft source
```

```bash
# Linux: Check for missing shared library dependencies
# Replace /usr/bin/appname with the actual binary path
ldd /usr/bin/appname | grep "not found"

# If dependencies are missing, identify and install the required package
# Example for a Debian/Ubuntu system:
sudo apt-get install -f   # Fixes broken dependencies automatically where possible

# Check the package manager for the application's recorded dependencies
dpkg -s appname 2>/dev/null | grep Depends
```

**If a missing dependency is identified:**

```powershell
# Windows: Download and silently install common redistributables
# (URLs should point to official Microsoft download pages)
# Example pattern - confirm current official URL before use:
$url = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
$installer = "$env:TEMP\vc_redist.x64.exe"
Invoke-WebRequest -Uri $url -OutFile $installer
Start-Process -FilePath $installer -ArgumentList "/install /quiet /norestart" -Wait
```

```bash
# Linux: Install missing package identified from ldd output
sudo apt-get update
sudo apt-get install -y <missing-package-name>
```

---

## Step 5 - Check File and Folder Permissions

Applications that fail silently or with access errors often have a permissions
problem on their installation directory, configuration folder, or data files.

```powershell
# Windows: Check permissions on the application's install directory
$appPath = "C:\Program Files\AppName"
Get-Acl $appPath | Format-List

# Check permissions on the user's application data folder
$appDataPath = "$env:APPDATA\AppName"
if (Test-Path $appDataPath) {
    Get-Acl $appDataPath | Format-List
}

# Verify the current user has at least Read & Execute on the install path
# and Full Control on their own AppData folder for the application
```

```bash
# Linux: Check permissions on the application binary and config directory
ls -la /usr/bin/appname
ls -la ~/.config/appname/

# Verify the binary has execute permission
# -rwxr-xr-x indicates correct execute permission for all users

# If execute permission is missing:
chmod +x /usr/bin/appname

# If the user's config directory has incorrect ownership
# (can happen after running the app once with sudo by mistake):
sudo chown -R $(whoami):$(whoami) ~/.config/appname/
```

---

## Step 6 - Reset Application Configuration (Corrupted User Settings)

A corrupted configuration or preferences file is a common cause of an application
that previously worked suddenly failing to launch, particularly after an unclean
shutdown.

> **Caution:** This resets the user's personal application settings. Confirm with
> the user before proceeding, and back up the configuration folder first in case
> reversal is needed.

```powershell
# Windows: Back up and reset application configuration
$configPath = "$env:APPDATA\AppName"
$backupPath = "$env:TEMP\AppName_Config_Backup_$(Get-Date -Format yyyyMMdd_HHmmss)"

if (Test-Path $configPath) {
    Copy-Item -Path $configPath -Destination $backupPath -Recurse -Force
    Write-Host "Configuration backed up to: $backupPath"

    # Remove the configuration to force the application to recreate defaults
    Remove-Item -Path $configPath -Recurse -Force

    Write-Host "Configuration reset. Attempt to relaunch the application."
} else {
    Write-Host "Configuration path not found - check application documentation for correct path"
}
```

```bash
# Linux: Back up and reset application configuration
CONFIG_DIR="$HOME/.config/appname"
BACKUP_DIR="$HOME/appname_config_backup_$(date +%Y%m%d_%H%M%S)"

if [ -d "$CONFIG_DIR" ]; then
    cp -r "$CONFIG_DIR" "$BACKUP_DIR"
    echo "Configuration backed up to: $BACKUP_DIR"

    rm -rf "$CONFIG_DIR"
    echo "Configuration reset. Attempt to relaunch the application."
else
    echo "Configuration directory not found - check application documentation"
fi
```

**If the application now launches correctly:** The original configuration was corrupted.
Document this and advise the user that personal settings (layout, preferences) have
been reset to default - restore specific settings manually if the user needs them and
they can be identified in the backup.

---

## Step 7 - Repair or Reinstall the Application

If the above steps do not resolve the fault, the application installation itself is
likely corrupted.

```powershell
# Windows: Attempt repair via installed programs (if the installer supports repair)
Get-CimInstance -ClassName Win32_Product |
    Where-Object {$_.Name -like "*AppName*"} |
    Select-Object Name, IdentifyingNumber, Version

# Trigger repair via msiexec if it is an MSI-based installer
# Replace {PRODUCT-CODE} with the IdentifyingNumber from above
msiexec /f "{PRODUCT-CODE}" /quiet

# If repair is not available or does not resolve the issue, uninstall cleanly:
$app = Get-CimInstance -ClassName Win32_Product | Where-Object {$_.Name -like "*AppName*"}
$app | Invoke-CimMethod -MethodName Uninstall

# Reinstall using the organisation's approved installation source
# (deployment tool, software centre, or verified installer location)
```

```bash
# Linux: Reinstall via package manager (Debian/Ubuntu example)
sudo apt-get remove --purge appname
sudo apt-get autoremove
sudo apt-get update
sudo apt-get install appname

# For applications installed via Snap
sudo snap remove appname
sudo snap install appname

# For applications installed via Flatpak
flatpak uninstall appname
flatpak install appname
```

> **Note:** Always use the organisation's approved deployment method (software centre,
> management platform, or verified installer source) for reinstallation rather than
> downloading installers directly from the internet, unless this is the organisation's
> standard practice and the source is verified as official.

---

## Step 8 - Check for Conflicting Software

Some applications fail to launch due to conflicts with security software, other
applications holding exclusive file locks, or incompatible versions of shared
components.

```powershell
# Windows: Check if antivirus/security software is blocking the application
# Review Windows Defender exclusions and recent quarantine actions
Get-MpThreatDetection | Where-Object {$_.ProcessName -like "*appname*"}

Get-MpPreference | Select-Object ExclusionPath

# Check Windows Event Log for Defender or third-party AV blocking the executable
Get-WinEvent -LogName "Microsoft-Windows-Windows Defender/Operational" -MaxEvents 20 |
    Where-Object {$_.Message -like "*appname*"}
```

```bash
# Linux: Check if AppArmor or SELinux is blocking the application
# AppArmor
sudo aa-status | grep -i appname

# SELinux (if in use)
sudo ausearch -m avc -ts recent | grep -i appname

# Check audit log for denials related to the application
sudo journalctl -u auditd --since "1 hour ago" | grep -i denied
```

**If security software is confirmed to be blocking the application:**
Do not disable security software to work around the block. Document the specific
block event and escalate to Tier 2 or the security team to add an appropriate,
scoped exclusion if the application is verified legitimate.

---

## Escalation Criteria

Escalate to Tier 2 when:

- [ ] Application crash logs point to a licensing server or backend service fault
- [ ] Security software is confirmed to be blocking the application and an exclusion
  requires security team review
- [ ] Reinstallation does not resolve the fault
- [ ] The application is part of a managed deployment and requires changes at the
  deployment/policy level
- [ ] The fault affects multiple users simultaneously (points to a deployment or
  licensing server issue rather than a single device fault)
- [ ] Crash details indicate a deeper OS-level fault (disk corruption, driver conflict)

**Escalation package must include:**

- Exact error message and any crash log details captured
- Steps already attempted (process check, log review, dependency check, config reset)
- Whether the issue is isolated to one user/device or affects multiple
- Application name, version, and deployment method

---

## Expected Results After Successful Resolution

```
Application launches within expected time (typically under 10 seconds for
standard desktop applications, longer for specialised software - compare
against documented baseline if available).

No error dialogs appear.

User confirms core functionality is accessible (can create/open a document,
connect to required services, etc. as relevant to the application).

No new crash events logged in Event Viewer / journalctl after relaunch.
```

---

## Common Fault Patterns and Quick Resolutions

| Symptom Pattern | Most Likely Cause | First Action |
|---|---|---|
| Opens then closes immediately | Corrupted config or missing dependency | Check logs (Step 3), reset config (Step 6) |
| Nothing happens when clicked | Hung background process | Check and kill existing process (Step 2) |
| "Missing DLL" / "library not found" error | Missing runtime dependency | Install required redistributable (Step 4) |
| Worked yesterday, fails today, no changes | Corrupted config from unclean shutdown | Reset config (Step 6) |
| Fails only for one user on a shared computer | User-specific config or permissions fault | Check permissions (Step 5), reset that user's config |
| Fails after recent Windows/OS update | Compatibility or dependency regression | Check for application update; verify dependencies |
| Disk full error or silent failure | Insufficient disk space | Check disk space (Step 1); free up space |
| Antivirus quarantined the executable | False positive security block | Check security logs (Step 8); escalate for exclusion |

---

## Verification Checklist

- [ ] Application launches successfully and consistently (tested at least twice)
- [ ] User confirms core functionality works as expected
- [ ] Root cause identified and documented
- [ ] If configuration was reset, user is aware personal settings were affected
- [ ] If application was reinstalled, confirm licensing/activation still works
- [ ] No new errors appear in logs after the fix

---

## Security Considerations

- Do not disable antivirus or endpoint protection to "test" whether it is the cause -
  identify the specific block via logs instead, and request a scoped exclusion if needed
- Only reinstall applications from approved, verified sources - never from unsolicited
  links or unofficial download sites, even if they appear to be the correct application
- If a crash log reveals unexpected process names or unusual file paths, treat this with
  caution - it may indicate malware interfering with the legitimate application rather
  than a routine software fault
- Configuration backups created during troubleshooting (Step 6) may contain sensitive
  data (saved credentials, tokens) - store and dispose of them according to organisational
  data handling policy

---

## Related Documents

| Document | Relationship |
|---|---|
| [`high-cpu-memory-usage.md`](high-cpu-memory-usage.md) | Use when system-wide resource exhaustion is the suspected cause |
| [`no-network-connectivity.md`](no-network-connectivity.md) | Use when the application requires network access that is unavailable |
| [`../methodology/troubleshooting-methodology.md`](../methodology/troubleshooting-methodology.md) | General diagnostic methodology this playbook applies |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Escalation criteria and package requirements |
| [`../scripts/windows/Get-EventLogSummary.ps1`](../scripts/windows/Get-EventLogSummary.ps1) | Automated Windows event log collection |
| [`../scripts/linux/log-summary.sh`](../scripts/linux/log-summary.sh) | Automated Linux log collection |