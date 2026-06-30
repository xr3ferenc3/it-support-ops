# Playbook: High CPU / Memory Usage

## Purpose

This playbook provides a resolution guide for tickets where a device is running slowly,
unresponsive, fans running constantly, or otherwise showing symptoms of resource
exhaustion. High CPU and memory usage is both a standalone ticket category and a root
cause frequently underlying tickets reported as application crashes, slow network
performance, or general slowness.

---

## When to Use This Playbook

Use this playbook when the user reports:

- "My computer is really slow"
- "Everything is laggy"
- "The fan is really loud all the time"
- "The computer freezes or becomes unresponsive"
- "Applications take a long time to respond"
- High resource usage is suspected as the underlying cause of another reported symptom

---

## Ticket Intake - Required Information

| Field | What to Record |
|---|---|
| Symptom description | Slow overall, specific app slow, freezing, fan noise |
| When it started | Sudden onset or gradual decline over time |
| Pattern | Constant, or worse at specific times/after specific actions |
| Recent changes | New software installed, OS update, more browser tabs than usual |
| Device age/specs | Helpful context - older or lower-spec devices have lower headroom |

---

## Step 1 - Establish Baseline Resource Usage

Capture current resource state before making any changes - this is the evidence
for diagnosis and the comparison point after resolution.

```powershell
# Windows: Quick resource snapshot
Write-Host "=== CPU Usage ==="
Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 2 -MaxSamples 3 |
    Select-Object -ExpandProperty CounterSamples |
    Select-Object Timestamp, CookedValue

Write-Host "=== Memory Usage ==="
$os = Get-CimInstance Win32_OperatingSystem
$totalMem = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$freeMem  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$usedMem  = [math]::Round($totalMem - $freeMem, 2)
$pctUsed  = [math]::Round(($usedMem / $totalMem) * 100, 1)
Write-Host "Total: ${totalMem}GB | Used: ${usedMem}GB | Free: ${freeMem}GB | Usage: ${pctUsed}%"

Write-Host "=== Disk Usage ==="
Get-PSDrive -PSProvider FileSystem |
    Select-Object Name, @{N="UsedGB";E={[math]::Round($_.Used/1GB,2)}},
                  @{N="FreeGB";E={[math]::Round($_.Free/1GB,2)}}
```

```bash
# Linux: Quick resource snapshot
echo "=== CPU and Memory Overview ==="
top -bn1 | head -15

echo "=== Memory Detail ==="
free -h

echo "=== Load Average ==="
uptime

echo "=== Disk Usage ==="
df -h
```

**Baseline interpretation:**

| Metric | Normal | Concerning | Critical |
|---|---|---|---|
| CPU sustained usage | <60% | 60–85% | >85% sustained |
| Memory usage | <75% | 75–90% | >90% |
| Disk free space | >20% free | 10–20% free | <10% free |
| Load average (Linux, per core) | <0.7 | 0.7–1.0 | >1.0 |

---

## Step 2 - Identify Top Resource-Consuming Processes

```powershell
# Windows: Top CPU consumers
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 |
    Select-Object ProcessName, Id, CPU,
                  @{N="MemoryMB";E={[math]::Round($_.WorkingSet/1MB,1)}}

# Top memory consumers
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 |
    Select-Object ProcessName, Id,
                  @{N="MemoryMB";E={[math]::Round($_.WorkingSet/1MB,1)}}, CPU
```

```bash
# Linux: Top CPU consumers
ps aux --sort=-%cpu | head -11

# Top memory consumers
ps aux --sort=-%mem | head -11

# Interactive view for ongoing monitoring
top   # Press 'P' to sort by CPU, 'M' to sort by memory, 'q' to quit
```

**Evaluate findings:**

| Observation | Likely Cause | Action |
|---|---|---|
| One process consistently at 90%+ CPU | Runaway or hung process | Step 3 - investigate and terminate if appropriate |
| Many browser tab processes consuming memory | Excessive open tabs | Advise user; consider tab management extension |
| Antivirus/security scan at high CPU | Scheduled scan running | Confirm scheduled timing; usually self-resolving |
| Unfamiliar process name consuming resources | Possible unwanted/malicious software | Step 6 - investigate before terminating |
| Multiple legitimate apps each using moderate resources | Cumulative load exceeding device capacity | Step 5 - startup/background app review |

---

## Step 3 - Investigate and Handle a Specific High-Usage Process

```powershell
# Windows: Get more detail on a specific process
Get-Process -Name "processname" |
    Select-Object ProcessName, Id, CPU, WorkingSet, StartTime, Path, Company

# Check if the process is responding
Get-Process -Name "processname" | Select-Object ProcessName, Responding

# If hung (Responding = False) and confirmed safe to terminate:
Stop-Process -Name "processname" -Force

# Verify termination and resource recovery
Get-Process -Name "processname" -ErrorAction SilentlyContinue
Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 2 -MaxSamples 1
```

```bash
# Linux: Get more detail on a specific process
ps -p <PID> -o pid,ppid,cmd,%cpu,%mem,etime

# Check the process's open files and network connections if investigating further
sudo lsof -p <PID>

# If confirmed safe to terminate
kill <PID>           # Graceful termination - try first
kill -9 <PID>         # Forceful termination - if graceful fails

# Verify
ps -p <PID>
```

> **Before terminating any process:** Confirm it is not an unsaved user document
> or a process critical to system stability. Ask the user if they have unsaved work
> in the application before forcing termination. For unfamiliar process names,
> complete Step 6 before deciding to terminate.

---

## Step 4 - Memory Leak Detection

A memory leak is identified by memory usage climbing steadily over time for a specific
process without releasing, eventually consuming all available memory.

```powershell
# Windows: Monitor a specific process's memory over time
$processName = "processname"
$logFile = "$env:TEMP\memory-leak-check.csv"
"Timestamp,MemoryMB" | Out-File $logFile

for ($i = 0; $i -lt 12; $i++) {
    $proc = Get-Process -Name $processName -ErrorAction SilentlyContinue
    if ($proc) {
        $mem = [math]::Round(($proc | Measure-Object WorkingSet -Sum).Sum / 1MB, 1)
        $timestamp = Get-Date -Format "HH:mm:ss"
        "$timestamp,$mem" | Out-File $logFile -Append
        Write-Host "$timestamp - ${processName}: ${mem} MB"
    }
    Start-Sleep -Seconds 30
}
# Runs for 6 minutes, sampling every 30 seconds
# Review $logFile - steadily climbing values with no drops confirm a leak
```

```bash
# Linux: Monitor a specific process's memory over time
PROCESS_NAME="processname"
LOGFILE="/tmp/memory-leak-check.csv"
echo "Timestamp,MemoryMB" > "$LOGFILE"

for i in $(seq 1 12); do
    PID=$(pgrep -f "$PROCESS_NAME" | head -1)
    if [ -n "$PID" ]; then
        MEM=$(ps -p "$PID" -o rss= | awk '{print $1/1024}')
        TIMESTAMP=$(date +%H:%M:%S)
        echo "$TIMESTAMP,$MEM" >> "$LOGFILE"
        echo "$TIMESTAMP - ${PROCESS_NAME}: ${MEM} MB"
    fi
    sleep 30
done
# Review $LOGFILE for steady upward trend
```

**If a memory leak is confirmed:**
1. Document the application name, version, and growth rate
2. Recommend the user restart the application periodically as an immediate workaround
3. Check for an available application update that may fix the leak
4. Escalate to Tier 2 if the application is business-critical and no update resolves it

---

## Step 5 - Review and Manage Startup Programs and Background Services

Excessive startup applications consume resources from boot and accumulate over time
as software is installed.

```powershell
# Windows: List startup programs
Get-CimInstance Win32_StartupCommand |
    Select-Object Name, Command, Location, User |
    Sort-Object Name

# Disable a specific startup item (requires Task Manager or registry approach)
# Safer method - disable via Task Manager Startup tab, or:
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Get-ItemProperty -Path $regPath | Format-List

# To remove a specific startup entry (confirm the entry first):
# Remove-ItemProperty -Path $regPath -Name "EntryName"
```

```bash
# Linux: List enabled systemd services that start at boot
systemctl list-unit-files --type=service --state=enabled

# List autostart applications (desktop environment dependent)
ls -la ~/.config/autostart/

# Disable a specific unnecessary service (confirm it is safe to disable first)
sudo systemctl disable servicename
```

**Common resource-heavy startup culprits:**

| Application Type | Typical Impact |
|---|---|
| Cloud sync clients (OneDrive, Dropbox, Google Drive) | Moderate CPU/network during sync |
| Multiple chat/communication apps auto-starting | Cumulative memory usage |
| Update checkers for multiple applications | Periodic CPU spikes |
| Old/unused software still running in background | Unnecessary baseline resource usage |

---

## Step 6 - Identify Unfamiliar or Suspicious Processes

Before terminating any unrecognised process consuming high resources, verify what
it is. Terminating a legitimate system process can cause instability; ignoring a
malicious one allows continued harm.

```powershell
# Windows: Get the file path and digital signature of an unfamiliar process
$proc = Get-Process -Name "unfamiliarprocess" -ErrorAction SilentlyContinue
if ($proc) {
    $path = $proc.Path
    Write-Host "Path: $path"
    Get-AuthenticodeSignature -FilePath $path |
        Select-Object Status, SignerCertificate
}

# Check if the process is in the standard Windows directory (more likely legitimate)
# or in an unusual location (Temp, Downloads, AppData root - warrants suspicion)
```

```bash
# Linux: Get the executable path and check its origin
PID=<process-id>
readlink -f /proc/$PID/exe

# Check the package that owns this binary (legitimate software is usually
# installed via the package manager)
dpkg -S $(readlink -f /proc/$PID/exe) 2>/dev/null || \
    echo "Not installed via package manager - investigate further"

# Check network connections from this process - unexpected outbound
# connections are a red flag
sudo lsof -p $PID -i
```

**Indicators that warrant security escalation instead of routine termination:**

- Process name closely mimics a legitimate system process but with a slight
  misspelling or unusual capitalisation
- Executable is located in a temp folder, downloads folder, or user-writable
  location rather than Program Files / standard system directories
- No digital signature, or signature does not match the claimed publisher
- Unexpected outbound network connections to unfamiliar addresses
- Process consuming high CPU with no corresponding visible application window
  (potential cryptomining or background malicious activity)

**If any of these indicators are present:** Stop routine troubleshooting. Do not
terminate the process yet if data preservation for investigation may matter. Escalate
immediately per the security event procedures in
[`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md).

---

## Step 7 - Check for Pending Updates or Restarts

A device that has not been restarted in an extended period accumulates memory
fragmentation and pending update processes that consume background resources.

```powershell
# Windows: Check last boot time
(Get-CimInstance Win32_OperatingSystem).LastBootUpTime

# Check for pending Windows Updates requiring a restart
Get-CimInstance -Namespace "root\ccm\clientsdk" -ClassName CCM_SoftwareUpdate `
    -ErrorAction SilentlyContinue

# Simple check - pending reboot flag
Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
```

```bash
# Linux: Check system uptime
uptime -p

# Check if a reboot is required (Debian/Ubuntu)
[ -f /var/run/reboot-required ] && echo "Reboot required" || echo "No reboot pending"
```

**If uptime exceeds 14–30 days (organisational policy dependent) or a pending update
restart is flagged:** Recommend a scheduled restart. This alone frequently resolves
gradual performance degradation without further diagnosis.

---

## Step 8 - Disk Space and Disk Health Check

Low disk space and a failing or fragmented disk both cause symptoms that present
as general slowness and high resource usage (especially high disk I/O wait, which
manifests as the system feeling unresponsive even with available CPU).

```powershell
# Windows: Check disk health status
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus

# Check free space
Get-PSDrive -PSProvider FileSystem |
    Select-Object Name, @{N="FreeGB";E={[math]::Round($_.Free/1GB,2)}}

# Check disk queue length (high sustained values indicate disk I/O bottleneck)
Get-Counter '\PhysicalDisk(_Total)\Current Disk Queue Length' -SampleInterval 2 -MaxSamples 3
```

```bash
# Linux: Check disk health via SMART (if smartmontools installed)
sudo smartctl -H /dev/sda 2>/dev/null || \
    echo "smartmontools not installed - install with: sudo apt install smartmontools"

# Check free space
df -h

# Check disk I/O wait - high values indicate disk bottleneck
iostat -x 2 3 2>/dev/null || echo "sysstat not installed - install with: sudo apt install sysstat"

# Check current I/O wait via top (the %wa value in the CPU line)
top -bn1 | grep "Cpu(s)"
```

For full disk diagnostic procedures refer to
[`../scripts/windows/Get-DiskHealthReport.ps1`](../scripts/windows/Get-DiskHealthReport.ps1)
and [`../scripts/linux/disk-health-report.sh`](../scripts/linux/disk-health-report.sh).

---

## Escalation Criteria

Escalate to Tier 2 when:

- [ ] A suspicious or unverifiable process is identified per Step 6 indicators
- [ ] A confirmed memory leak affects a business-critical application with no
  available update or fix
- [ ] Disk health check shows a failing or degraded physical disk
- [ ] Resource exhaustion persists after process termination, startup review, and
  restart - possible hardware limitation requiring upgrade evaluation
- [ ] The pattern affects multiple devices simultaneously (possible deployed
  software issue or organisation-wide malware concern)

**Escalation package must include:**

- Baseline resource measurements from Step 1
- Top resource-consuming processes identified
- Any suspicious process findings from Step 6
- Disk health status if checked
- Actions already taken and their effect on resource usage

---

## Expected Results After Successful Resolution

```
BEFORE:
  CPU sustained usage: 92%
  Memory usage: 94% (15.8GB / 16GB)
  Top process: chrome.exe consuming 8.2GB across 47 tab processes

AFTER (excess tabs closed, browser restarted, startup items reviewed):
  CPU sustained usage: 35%
  Memory usage: 58% (9.3GB / 16GB)

User confirms applications now respond normally and fan noise has reduced.
```

---

## Common Fault Patterns and Quick Resolutions

| Symptom Pattern | Most Likely Cause | First Action |
|---|---|---|
| Fan constantly loud, one process at high CPU | Runaway or hung process | Identify and terminate (Step 2–3) |
| Gradually worse over the day, restart fixes it | Memory leak in a specific application | Monitor and confirm (Step 4); restart workaround |
| Slow since a specific software install | New software's background processes | Review startup items (Step 5) |
| Slow despite low CPU/memory usage | Disk I/O bottleneck or failing disk | Check disk health (Step 8) |
| High CPU with no visible application window | Possible unwanted/malicious background process | Investigate per Step 6 before terminating |
| Slow only during antivirus scan window | Scheduled scan - expected behaviour | Confirm scan schedule; no action needed if expected |
| Uptime measured in months | Resource fragmentation, pending updates | Recommend scheduled restart |

---

## Verification Checklist

- [ ] Baseline measurements recorded before changes
- [ ] Root cause identified (specific process, leak, disk, or startup load)
- [ ] Resolution applied
- [ ] Post-fix measurements taken and compared against baseline
- [ ] User confirms system feels responsive for their normal workload
- [ ] No suspicious processes remain unexplained
- [ ] Disk health confirmed acceptable if checked

---

## Security Considerations

- Never terminate an unidentified process without first checking its file path,
  digital signature, and behaviour - premature termination can both destabilise
  legitimate software and tip off active malware before it can be properly investigated
- High CPU usage with no visible cause and no recognisable process name is a common
  cryptomining malware symptom - treat with appropriate caution per Step 6
- Document any suspicious findings thoroughly even if the immediate resource issue
  is resolved by other means - security teams may need this information later
- Memory dumps or process investigation data gathered during troubleshooting may
  contain sensitive information - handle according to organisational data policy

---

## Related Documents

| Document | Relationship |
|---|---|
| [`application-not-launching.md`](application-not-launching.md) | Related when resource exhaustion prevents application launch |
| [`slow-network-performance.md`](slow-network-performance.md) | Related when local resource issues masquerade as network slowness |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Security event escalation criteria |
| [`../scripts/windows/Get-SystemHealthReport.ps1`](../scripts/windows/Get-SystemHealthReport.ps1) | Automated Windows resource diagnostic collection |
| [`../scripts/linux/system-health-report.sh`](../scripts/linux/system-health-report.sh) | Automated Linux resource diagnostic collection |
| [`../scripts/windows/Get-DiskHealthReport.ps1`](../scripts/windows/Get-DiskHealthReport.ps1) | Detailed disk health diagnostics |
| [`../scripts/linux/disk-health-report.sh`](../scripts/linux/disk-health-report.sh) | Detailed disk health diagnostics |