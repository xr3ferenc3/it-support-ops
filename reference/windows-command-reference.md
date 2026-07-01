# Windows Command Reference

## Purpose

This reference organises Windows diagnostic and administrative commands by operational
task rather than alphabetically - the goal is to support a technician mid-ticket who
knows what they need to accomplish but wants the correct command and syntax quickly,
not to serve as an exhaustive command index.

Commands are grouped to match the workflows used throughout this repository's
methodology, networking guides, and playbooks. Where a command is covered in depth
elsewhere in this repository, this reference links to that document rather than
duplicating full explanations.

---

## When to Use This Reference

Use this reference when you know the task you need to perform but want to confirm
exact syntax, parameters, or output interpretation without reopening the full playbook.
For step-by-step diagnostic procedures, use the relevant playbook or networking guide -
this document is a lookup tool, not a procedure guide.

---

## Network Configuration and Diagnostics

| Task | Command | Notes |
|---|---|---|
| View full IP configuration | `ipconfig /all` | Shows IP, gateway, DNS, DHCP, MAC for all adapters |
| View basic IP configuration | `ipconfig` | Quick view without full detail |
| Release DHCP lease | `ipconfig /release` | See [`networking/dns-dhcp-playbook.md`](../networking/dns-dhcp-playbook.md) |
| Renew DHCP lease | `ipconfig /renew` | Run after release |
| Flush DNS resolver cache | `ipconfig /flushdns` | Clears stale DNS entries |
| Display DNS cache | `ipconfig /displaydns` | Shows currently cached resolutions |
| Register DNS records | `ipconfig /registerdns` | Re-registers with DHCP/DNS - domain environments |
| Test connectivity | `ping <host>` | Add `-n <count>` to change packet count (default 4) |
| Continuous ping | `ping -t <host>` | Runs until manually stopped (Ctrl+C) |
| Trace route to host | `tracert <host>` | Add `-h <max hops>` to extend hop limit |
| DNS lookup | `nslookup <host>` | Add server: `nslookup <host> <dns-server>` |
| Test port connectivity | `Test-NetConnection -ComputerName <host> -Port <port>` | PowerShell - replaces telnet for port testing |
| View ARP table | `arp -a` | Shows IP-to-MAC mappings |
| View routing table | `route print` | Shows active routes |
| Display network statistics | `netstat -ano` | Shows active connections with process IDs |
| Reset Winsock | `netsh winsock reset` | Requires elevation; requires reboot |
| Reset TCP/IP stack | `netsh int ip reset` | Requires elevation; requires reboot |

**PowerShell equivalents** for several of the above are documented in
[`powershell-command-reference.md`](powershell-command-reference.md). Full diagnostic
procedures using these commands are in
[`networking/network-troubleshooting-guide.md`](../networking/network-troubleshooting-guide.md).

---

## Wireless Network Commands

| Task | Command | Notes |
|---|---|---|
| Show available wireless networks | `netsh wlan show networks mode=bssid` | Includes signal strength per network |
| Show current wireless connection detail | `netsh wlan show interfaces` | Signal, channel, rates, authentication type |
| List saved wireless profiles | `netsh wlan show profiles` | Shows all networks the device has connected to |
| Show saved profile detail with password | `netsh wlan show profile name="SSID" key=clear` | Requires admin for password visibility |
| Delete a saved wireless profile | `netsh wlan delete profile name="SSID"` | Forces full reconnection on next attempt |
| Export a wireless profile | `netsh wlan export profile name="SSID" folder="C:\Temp"` | Useful for replicating working config to another device |
| Import a wireless profile | `netsh wlan add profile filename="C:\Temp\SSID.xml"` | Restores an exported profile |

Full wireless diagnostic procedures are in
[`networking/wifi-diagnostic-guide.md`](../networking/wifi-diagnostic-guide.md).

---

## System Information

| Task | Command | Notes |
|---|---|---|
| Basic system summary | `systeminfo` | OS version, install date, hotfixes, memory |
| Computer name | `hostname` | Quick lookup |
| Current user | `whoami` | Quick lookup |
| Current user with privileges | `whoami /priv` | Shows assigned privileges |
| System uptime | `net statistics workstation` | Look for "Statistics since" line |
| List installed hotfixes | `wmic qfe list` | Legacy but still functional on most systems |
| Open Device Manager | `devmgmt.msc` | GUI tool for hardware/driver management |
| Open Disk Management | `diskmgmt.msc` | GUI tool for disk/volume management |
| Open Services console | `services.msc` | GUI tool for service management |
| Open Event Viewer | `eventvwr.msc` | GUI tool for event log review |
| Open Local Group Policy Editor | `gpedit.msc` | Not available on Home editions |
| Open Local Users and Groups | `lusrmgr.msc` | Not available on Home editions |

---

## File System and Disk

| Task | Command | Notes |
|---|---|---|
| Check disk for errors | `chkdsk C: /f /r` | Requires reboot if drive is in use; `/f` fixes, `/r` recovers bad sectors |
| Check disk (read-only scan) | `chkdsk C:` | No `/f` - reports without fixing |
| System File Checker | `sfc /scannow` | Requires elevation; scans and repairs protected system files |
| DISM health check | `DISM /Online /Cleanup-Image /CheckHealth` | Quick check for component store corruption |
| DISM scan health | `DISM /Online /Cleanup-Image /ScanHealth` | More thorough scan |
| DISM restore health | `DISM /Online /Cleanup-Image /RestoreHealth` | Repairs component store - requires elevation |
| Disk cleanup utility | `cleanmgr` | GUI tool for clearing temporary/system files |
| View disk space (basic) | `wmic logicaldisk get size,freespace,caption` | Legacy but functional |
| Defragment/optimise a drive | `defrag C: /O` | Not needed on SSDs - use `/L` for TRIM instead on SSD |

---

## Process and Service Management

| Task | Command | Notes |
|---|---|---|
| List running processes | `tasklist` | Add `/v` for verbose detail |
| Kill a process by name | `taskkill /IM processname.exe /F` | `/F` forces termination |
| Kill a process by PID | `taskkill /PID 1234 /F` | More precise when multiple instances exist |
| List services | `sc query` | Add service name to query a specific service |
| Query a specific service | `sc query "Spooler"` | Shows current state |
| Start a service | `net start "Spooler"` | Or `sc start "Spooler"` |
| Stop a service | `net stop "Spooler"` | Or `sc stop "Spooler"` |
| Set service startup type | `sc config "Spooler" start=auto` | Options: auto, demand, disabled |

For print spooler-specific procedures see
[`playbooks/printer-not-working.md`](../playbooks/printer-not-working.md).

---

## User and Account Management

| Task | Command | Notes |
|---|---|---|
| List local user accounts | `net user` | Shows all local accounts |
| View a specific user's detail | `net user username` | Shows account flags, group membership |
| Create a local user | `net user username password /add` | Requires elevation |
| Add user to local group | `net localgroup Administrators username /add` | Requires elevation - use cautiously |
| Disable a local account | `net user username /active:no` | Requires elevation |
| Force password change at next logon | `net user username /logonpasswordchg:yes` | Requires elevation |
| Unlock a local account | `net user username /active:yes` | Different from domain unlock - see below |

For Active Directory account commands (domain environments), use the PowerShell
Active Directory module - see
[`powershell-command-reference.md`](powershell-command-reference.md).
Full login fault procedures are in
[`playbooks/user-cannot-login.md`](../playbooks/user-cannot-login.md).

---

## Windows Update

| Task | Command | Notes |
|---|---|---|
| Check for updates (GUI) | `ms-settings:windowsupdate` | Opens Windows Update settings directly |
| Check update history | `wmic qfe list brief /format:table` | Shows installed update history |
| Check for pending restart | Check registry key (see below) | No single native command - see PowerShell reference |

Pending restart check via registry path:
```
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired
```
If this key exists, a restart is pending. See
[`scripts/windows/Get-SystemHealthReport.ps1`](../scripts/windows/Get-SystemHealthReport.ps1)
for an automated check.

---

## Printing

| Task | Command | Notes |
|---|---|---|
| List installed printers | `wmic printer list brief` | Legacy but functional |
| Open printer queue (GUI) | `control printers` | Opens Devices and Printers |
| Restart print spooler (cmd) | `net stop spooler && net start spooler` | Run as administrator |
| Clear stuck print jobs | Delete files in spool folder | `C:\Windows\System32\spool\PRINTERS\*` - stop spooler first |

Full printer diagnostic procedures, including PowerShell-based queue and driver
management, are in [`playbooks/printer-not-working.md`](../playbooks/printer-not-working.md).

---

## Event Logs

| Task | Command | Notes |
|---|---|---|
| Open Event Viewer | `eventvwr.msc` | GUI - primary tool for log review |
| Export event log to file (GUI) | Use Event Viewer "Save All Events As" | Saves as .evtx for sharing |
| Query events via command line | Use PowerShell `Get-WinEvent` | See [`powershell-command-reference.md`](powershell-command-reference.md) |

Automated event log collection is available via
[`scripts/windows/Get-EventLogSummary.ps1`](../scripts/windows/Get-EventLogSummary.ps1).

---

## Remote Access and Connectivity

| Task | Command | Notes |
|---|---|---|
| Open Remote Desktop client | `mstsc` | Add `/v:hostname` to connect directly |
| Test RDP port reachability | `Test-NetConnection -ComputerName host -Port 3389` | PowerShell - confirms port 3389 is open |
| Open Remote Assistance | `msra` | Built-in screen-sharing support tool |

---

## Security and Permissions

| Task | Command | Notes |
|---|---|---|
| View file/folder permissions | `icacls "C:\path"` | Shows ACL entries |
| Grant permission | `icacls "C:\path" /grant username:F` | `F` = full control; use least privilege needed |
| Take ownership of a file/folder | `takeown /f "C:\path"` | Requires elevation |
| Run Windows Defender scan | `ms-settings:windowsdefender` | Opens Defender settings directly |
| Check Defender status (cmd) | Use PowerShell `Get-MpComputerStatus` | See [`powershell-command-reference.md`](powershell-command-reference.md) |

---

## Common Command Patterns for Ticket Documentation

When attaching command output to a ticket, redirect output to a file rather than
manually copying from the console - this preserves exact formatting and avoids
transcription errors.

```cmd
:: Redirect output to a text file
ipconfig /all > C:\Temp\ipconfig-output.txt

:: Append additional command output to the same file
systeminfo >> C:\Temp\ipconfig-output.txt
```

For structured, repeatable diagnostic collection, prefer the PowerShell scripts in
[`scripts/windows/`](../scripts/windows/) over manually chaining individual commands -
they produce consistent, ticket-ready output automatically.

---

## Security Considerations

- Commands that display saved passwords (`netsh wlan show profile ... key=clear`)
  should only be run when necessary and the output should not be left visible or
  saved insecurely
- Commands requiring elevation (`sfc`, `DISM`, `netsh winsock reset`, registry
  edits) should only be run with a clear understanding of their effect - several
  require a reboot and some affect all users on the device
- `icacls` and `takeown` directly modify security permissions - incorrect use can
  expose data or break application functionality; use the least-privilege principle
- Never run commands found in unsolicited instructions (email, chat, forum posts)
  without independently verifying their purpose - command-line instructions are a
  known social engineering vector

---

## Related Documents

| Document | Relationship |
|---|---|
| [`powershell-command-reference.md`](powershell-command-reference.md) | PowerShell cmdlet equivalents and AD-specific commands |
| [`network-ports-protocols.md`](network-ports-protocols.md) | Port and protocol reference for connectivity testing |
| [`../networking/network-troubleshooting-guide.md`](../networking/network-troubleshooting-guide.md) | Full diagnostic procedures using these commands |
| [`../playbooks/`](../playbooks/) | Scenario-specific application of these commands |