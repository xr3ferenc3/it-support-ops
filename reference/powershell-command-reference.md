# PowerShell Command Reference

## Purpose

This reference organises PowerShell cmdlets for IT support tasks by operational
category, complementing [`windows-command-reference.md`](windows-command-reference.md)
which covers traditional cmd-style commands. PowerShell cmdlets are generally
preferred over their legacy cmd equivalents for scripting, structured output, and
remote management, and are used throughout this repository's automation scripts.

This reference covers cmdlets used in the playbooks, networking guides, and scripts
throughout this repository, plus commonly needed Active Directory cmdlets for
domain-joined environments.

---

## When to Use This Reference

Use this reference when building a diagnostic script, running an ad-hoc PowerShell
command during a ticket, or confirming correct cmdlet syntax and parameters. For
step-by-step diagnostic procedures using these cmdlets in context, use the relevant
playbook or networking guide.

---

## Network Cmdlets

| Task | Cmdlet | Notes |
|---|---|---|
| View network adapters | `Get-NetAdapter` | Add `\| Select Name, Status, LinkSpeed` for concise view |
| Enable a network adapter | `Enable-NetAdapter -Name "Ethernet"` | |
| Disable a network adapter | `Disable-NetAdapter -Name "Ethernet" -Confirm:$false` | |
| View IP configuration | `Get-NetIPConfiguration` | More structured than `ipconfig` for scripting |
| View IP addresses | `Get-NetIPAddress` | Filter with `-AddressFamily IPv4` |
| Set a static IP address | `New-NetIPAddress -InterfaceIndex 5 -IPAddress "192.168.1.50" -PrefixLength 24 -DefaultGateway "192.168.1.1"` | Requires elevation |
| Remove a static IP | `Remove-NetIPAddress -IPAddress "192.168.1.50"` | Requires elevation |
| View DNS client server settings | `Get-DnsClientServerAddress` | |
| Set DNS server addresses | `Set-DnsClientServerAddress -InterfaceIndex 5 -ServerAddresses ("8.8.8.8","1.1.1.1")` | Requires elevation |
| Reset DNS servers to DHCP-assigned | `Set-DnsClientServerAddress -InterfaceIndex 5 -ResetServerAddresses` | |
| Flush DNS client cache | `Clear-DnsClientCache` | PowerShell equivalent of `ipconfig /flushdns` |
| DNS name resolution | `Resolve-DnsName -Name google.com` | Structured alternative to `nslookup` |
| Test network connectivity | `Test-Connection -ComputerName host -Count 4` | PowerShell equivalent of `ping` |
| Test specific port | `Test-NetConnection -ComputerName host -Port 443` | Includes TCP handshake test |
| Test with traceroute | `Test-NetConnection -ComputerName host -TraceRoute` | Combines ping and tracert |
| View routing table | `Get-NetRoute` | Filter with `-DestinationPrefix "0.0.0.0/0"` for default route |
| View ARP/neighbour cache | `Get-NetNeighbor` | Modern equivalent of `arp -a` |

Used extensively in [`scripts/windows/Get-NetworkDiagnostics.ps1`](../scripts/windows/Get-NetworkDiagnostics.ps1)
and [`scripts/windows/Test-ConnectivitySuite.ps1`](../scripts/windows/Test-ConnectivitySuite.ps1).

---

## System Information Cmdlets

| Task | Cmdlet | Notes |
|---|---|---|
| OS information | `Get-CimInstance Win32_OperatingSystem` | Caption, version, last boot time |
| CPU information | `Get-CimInstance Win32_Processor` | Model, core count |
| Computer system info | `Get-CimInstance Win32_ComputerSystem` | Manufacturer, model, domain membership |
| BIOS information | `Get-CimInstance Win32_BIOS` | Serial number, version |
| Installed hotfixes | `Get-HotFix` | List of applied updates |
| System uptime | `(Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime` | Calculates a TimeSpan |

Used in [`scripts/windows/Get-SystemHealthReport.ps1`](../scripts/windows/Get-SystemHealthReport.ps1).

---

## Process and Performance Cmdlets

| Task | Cmdlet | Notes |
|---|---|---|
| List processes | `Get-Process` | Add `\| Sort CPU -Descending` for top consumers |
| Get a specific process | `Get-Process -Name notepad` | |
| Stop a process | `Stop-Process -Name notepad -Force` | `-Force` skips confirmation |
| Stop a process by ID | `Stop-Process -Id 1234 -Force` | More precise with multiple instances |
| Check if a process is responding | `Get-Process -Name notepad \| Select Responding` | `False` indicates hung process |
| Get performance counter sample | `Get-Counter '\Processor(_Total)\% Processor Time'` | Add `-SampleInterval` and `-MaxSamples` |
| List available counters | `Get-Counter -ListSet *` | Useful for discovering counter paths |

Used in [`scripts/windows/Get-SystemHealthReport.ps1`](../scripts/windows/Get-SystemHealthReport.ps1)
for CPU, memory, and disk queue monitoring.

---

## Disk and Storage Cmdlets

| Task | Cmdlet | Notes |
|---|---|---|
| View logical drives | `Get-PSDrive -PSProvider FileSystem` | Used + Free space per drive |
| View physical disks | `Get-PhysicalDisk` | HealthStatus, MediaType, OperationalStatus |
| View disk partitions | `Get-Partition` | |
| View volumes | `Get-Volume` | Includes file system type and health |
| Optimise/defrag a volume | `Optimize-Volume -DriveLetter C -Defrag` | Use `-ReTrim` instead for SSDs |
| Run a SMART-style health check | `Get-PhysicalDisk \| Select FriendlyName, HealthStatus` | Basic health without third-party tools |

Used in [`scripts/windows/Get-DiskHealthReport.ps1`](../scripts/windows/Get-DiskHealthReport.ps1).

---

## Event Log Cmdlets

| Task | Cmdlet | Notes |
|---|---|---|
| Query an event log | `Get-WinEvent -LogName Application` | Modern replacement for `Get-EventLog` |
| Filter by level and time | `Get-WinEvent -FilterHashtable @{LogName="System"; Level=2,3; StartTime=(Get-Date).AddHours(-24)}` | Level 2=Error, 3=Warning |
| Filter by specific Event ID | `Get-WinEvent -FilterHashtable @{LogName="System"; Id=41,6008}` | Useful for known significant events |
| Filter by XPath query | `Get-WinEvent -FilterXPath "*[System[(EventID=1000)]]"` | Alternative filtering syntax |
| Get most recent N events | `Get-WinEvent -LogName Application -MaxEvents 50` | |
| List available log names | `Get-WinEvent -ListLog *` | Shows all logs the current user can access |

Used extensively in
[`scripts/windows/Get-EventLogSummary.ps1`](../scripts/windows/Get-EventLogSummary.ps1).

---

## Printer Management Cmdlets

| Task | Cmdlet | Notes |
|---|---|---|
| List printers | `Get-Printer` | Name, PrinterStatus, DriverName |
| List print jobs for a printer | `Get-PrintJob -PrinterName "Name"` | JobStatus, SubmittedTime |
| Remove a print job | `Remove-PrintJob -PrinterName "Name" -ID 5` | |
| Clear all jobs for a printer | `Get-PrintJob -PrinterName "Name" \| Remove-PrintJob` | |
| Add a printer | `Add-Printer -Name "Name" -DriverName "Driver" -PortName "Port"` | Requires port and driver to exist first |
| Remove a printer | `Remove-Printer -Name "Name"` | |
| List printer drivers | `Get-PrinterDriver` | |
| Add a printer port | `Add-PrinterPort -Name "IP_192.168.1.50" -PrinterHostAddress "192.168.1.50"` | |
| Add a printer driver | `Add-PrinterDriver -Name "DriverName"` | Driver must be available to the OS first |

Full procedures in [`playbooks/printer-not-working.md`](../playbooks/printer-not-working.md).

---

## Service Management Cmdlets

| Task | Cmdlet | Notes |
|---|---|---|
| List services | `Get-Service` | |
| Get a specific service | `Get-Service -Name Spooler` | |
| Start a service | `Start-Service -Name Spooler` | |
| Stop a service | `Stop-Service -Name Spooler -Force` | |
| Restart a service | `Restart-Service -Name Spooler -Force` | |
| Set service startup type | `Set-Service -Name Spooler -StartupType Automatic` | Options: Automatic, Manual, Disabled |

---

## Active Directory Cmdlets

> **Note:** Requires the Active Directory PowerShell module
> (`Import-Module ActiveDirectory`), available via RSAT tools. These commands
> typically require appropriate AD permissions - some may be delegated to Tier 1,
> others reserved for Tier 2 per your organisation's access model.

| Task | Cmdlet | Notes |
|---|---|---|
| Get a user account | `Get-ADUser -Identity "username" -Properties *` | `-Properties *` returns all attributes |
| Check lockout status | `Get-ADUser -Identity "username" -Properties LockedOut` | |
| Check password expiry | `Get-ADUser -Identity "username" -Properties PasswordExpired,PasswordLastSet` | |
| Unlock an account | `Unlock-ADAccount -Identity "username"` | |
| Enable an account | `Enable-ADAccount -Identity "username"` | Verify authorisation before use |
| Disable an account | `Disable-ADAccount -Identity "username"` | Verify authorisation before use |
| Reset a password | `Set-ADAccountPassword -Identity "username" -Reset -NewPassword (Read-Host -AsSecureString)` | Verify identity first |
| Force password change at logon | `Set-ADUser -Identity "username" -ChangePasswordAtLogon $true` | |
| Get group membership | `Get-ADPrincipalGroupMembership -Identity "username"` | |
| Search for users | `Get-ADUser -Filter "Name -like '*smith*'"` | |
| Get computer account info | `Get-ADComputer -Identity "COMPUTERNAME" -Properties *` | |

Full login fault procedures using these cmdlets are in
[`playbooks/user-cannot-login.md`](../playbooks/user-cannot-login.md).

---

## Local Account Cmdlets

| Task | Cmdlet | Notes |
|---|---|---|
| List local users | `Get-LocalUser` | |
| Get a specific local user | `Get-LocalUser -Name "username"` | |
| Enable a local account | `Enable-LocalUser -Name "username"` | |
| Disable a local account | `Disable-LocalUser -Name "username"` | |
| List local groups | `Get-LocalGroup` | |
| Add user to local group | `Add-LocalGroupMember -Group "Administrators" -Member "username"` | Use cautiously |

---

## Security and Defender Cmdlets

| Task | Cmdlet | Notes |
|---|---|---|
| Check Defender status | `Get-MpComputerStatus` | Real-time protection, last scan, definitions version |
| Check Defender preferences/exclusions | `Get-MpPreference` | Shows configured exclusion paths |
| View recent threat detections | `Get-MpThreatDetection` | |
| Start a quick scan | `Start-MpScan -ScanType QuickScan` | |
| Start a full scan | `Start-MpScan -ScanType FullScan` | Can take significant time |
| Update Defender definitions | `Update-MpSignature` | |
| Get file digital signature status | `Get-AuthenticodeSignature -FilePath "C:\path\to\file.exe"` | Useful when investigating unfamiliar processes |

Used in suspicious process investigation per
[`playbooks/high-cpu-memory-usage.md`](../playbooks/high-cpu-memory-usage.md) Step 6.

---

## File System and Permissions Cmdlets

| Task | Cmdlet | Notes |
|---|---|---|
| Get file/folder ACL | `Get-Acl "C:\path"` | |
| Set file/folder ACL | `Set-Acl "C:\path" $aclObject` | Typically combined with Get-Acl to modify and reapply |
| Get file hash | `Get-FileHash "C:\path\to\file.exe"` | Useful for verifying file integrity |
| Copy items recursively | `Copy-Item -Path "C:\source" -Destination "C:\dest" -Recurse -Force` | |
| Test if a path exists | `Test-Path "C:\path"` | Returns boolean |
| Measure folder size | `Get-ChildItem -Recurse \| Measure-Object -Property Length -Sum` | Sum is in bytes - divide for GB/MB |

---

## Remoting and Cross-Computer Cmdlets

| Task | Cmdlet | Notes |
|---|---|---|
| Test if WinRM is enabled | `Test-WSMan -ComputerName hostname` | Required for PowerShell remoting |
| Run a command on a remote computer | `Invoke-Command -ComputerName hostname -ScriptBlock { Get-Process }` | Requires WinRM enabled and appropriate permissions |
| Start an interactive remote session | `Enter-PSSession -ComputerName hostname` | |
| Check a remote service status | `Get-Service -ComputerName hostname -Name Spooler` | Useful for shared printer host diagnosis |
| Test remote connectivity | `Test-Connection -ComputerName hostname -Count 4` | |

Used for shared printer host diagnosis per
[`playbooks/printer-not-working.md`](../playbooks/printer-not-working.md) Step 6.

---

## Output Formatting and Scripting Patterns

| Task | Pattern | Notes |
|---|---|---|
| Select specific properties | `Get-Process \| Select-Object Name, CPU` | Reduces output to relevant fields |
| Sort results | `Get-Process \| Sort-Object CPU -Descending` | |
| Filter results | `Get-Process \| Where-Object {$_.CPU -gt 100}` | |
| Format as a table | `Get-Process \| Format-Table -AutoSize` | |
| Format as a list | `Get-Process \| Format-List` | Useful for objects with many properties |
| Export to CSV | `Get-Process \| Export-Csv -Path "output.csv" -NoTypeInformation` | |
| Export to a text file | `Get-Process \| Out-File -FilePath "output.txt"` | Used throughout this repository's scripts |
| Measure execution time | `Measure-Command { Get-Process }` | Useful for performance baseline testing |
| Calculate an average from samples | `($samples \| Measure-Object -Property CookedValue -Average).Average` | Used in counter sampling |

---

## Error Handling Patterns

These patterns are used consistently throughout this repository's scripts and are
included here as a quick reference for anyone extending them.

```powershell
# Standard try/catch with specific error message
try {
    $result = Get-Something -ErrorAction Stop
}
catch {
    Write-Warning "Could not retrieve data: $($_.Exception.Message)"
}

# Continue on error rather than stopping the whole script
$ErrorActionPreference = "Continue"

# Suppress expected/non-critical errors for a single command
Get-Something -ErrorAction SilentlyContinue

# Check if a command/cmdlet exists before using it
if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
    Get-PhysicalDisk
} else {
    Write-Host "Get-PhysicalDisk not available on this system."
}
```

---

## Security Considerations

- Cmdlets that modify Active Directory accounts (`Unlock-ADAccount`, `Enable-ADAccount`,
  `Set-ADAccountPassword`) should only be run after identity verification per
  [`playbooks/user-cannot-login.md`](../playbooks/user-cannot-login.md)
- `Invoke-Command` and remoting cmdlets execute code on remote systems - verify the
  target and the script block content carefully before running
- `Get-AuthenticodeSignature` and similar investigative cmdlets should be used before,
  not after, terminating an unfamiliar process - see
  [`playbooks/high-cpu-memory-usage.md`](../playbooks/high-cpu-memory-usage.md) Step 6
- Avoid storing plaintext passwords in scripts - use `Read-Host -AsSecureString` or
  credential objects (`Get-Credential`) instead
- `-Force` and `-Confirm:$false` parameters skip safety prompts - use deliberately,
  not as a default habit

---

## Related Documents

| Document | Relationship |
|---|---|
| [`windows-command-reference.md`](windows-command-reference.md) | Legacy cmd-style command equivalents |
| [`network-ports-protocols.md`](network-ports-protocols.md) | Port and protocol reference |
| [`../scripts/windows/`](../scripts/windows/) | Full diagnostic scripts built using these cmdlets |
| [`../playbooks/`](../playbooks/) | Scenario-specific application of these cmdlets |