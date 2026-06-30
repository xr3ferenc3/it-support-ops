# Playbook: Printer Not Working

## Purpose

This playbook provides a resolution guide for printer connectivity, driver, queue, and
output faults - the highest-frequency ticket category in most SMB help desk environments.
Printing faults involve more layers than most technicians initially expect: network
connectivity to the printer, the print spooler service, the driver, the print queue,
and the physical device itself.

---

## When to Use This Playbook

Use this playbook when the user reports:

- "The printer isn't printing"
- "It says the printer is offline"
- "My print job is stuck in the queue"
- "It printed but the output looks wrong" (garbled text, wrong formatting)
- "I can't find the printer to add it"
- "It was working, now nothing happens when I print"

---

## Ticket Intake - Required Information

| Field | What to Record |
|---|---|
| Printer name/model | Exact name as shown in the print dialog |
| Connection type | Network printer, USB-direct, or shared via another PC |
| Symptom | Offline / queue stuck / no output / garbled output / cannot find printer |
| Error message | Exact text if shown |
| Scope | This user only, or others also affected by the same printer |
| When it started | Time, and what changed before (driver update, network change, moved printer) |

**Scope check - always ask first:**
```
"Is anyone else having trouble printing to this same printer?"

If yes, others affected → Likely the printer/print server itself, not this user's device
  → Skip to Step 4 (printer-side diagnosis)

If no, isolated to this user → Likely client-side fault
  → Continue from Step 1
```

---

## Step 1 - Confirm the Print Spooler Service Is Running (Windows Client)

The print spooler is the Windows service that manages all print jobs. A stopped or
hung spooler is one of the most common causes of "nothing happens when I print."

```powershell
# Check spooler service status
Get-Service -Name Spooler

# If status is not "Running":
Start-Service -Name Spooler

# Verify it started successfully
Get-Service -Name Spooler

# If the spooler is running but jobs are stuck, restart it to clear the queue
Stop-Service -Name Spooler -Force
Start-Sleep -Seconds 3
Start-Service -Name Spooler
Get-Service -Name Spooler
```

**If the spooler repeatedly crashes or fails to start:**

```powershell
# Check for a corrupted print job stuck in the spool folder causing the crash
# Stop the spooler first
Stop-Service -Name Spooler -Force

# Clear all stuck spool files
Remove-Item -Path "C:\Windows\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue

# Restart the spooler
Start-Service -Name Spooler

# Attempt to print a test page
Get-Service -Name Spooler
```

---

## Step 2 - Check the Print Queue for Stuck Jobs

A stuck job at the top of the queue blocks all subsequent jobs from printing.

```powershell
# View current print jobs for a specific printer
Get-PrintJob -PrinterName "PrinterName"

# Key fields to review:
# JobStatus    : Should show "Normal" - "Error", "Paused", or "Offline" indicates a fault
# SubmittedTime: A job stuck for an extended time confirms the block

# Cancel a specific stuck job
Remove-PrintJob -PrinterName "PrinterName" -ID <JobID>

# Cancel all jobs for this printer (use with caution - clears the entire queue)
Get-PrintJob -PrinterName "PrinterName" | Remove-PrintJob
```

**If `Remove-PrintJob` does not clear the job (common when the spooler is hung):**

```powershell
# Stop spooler, manually clear spool folder, restart spooler
Stop-Service -Name Spooler -Force
Remove-Item -Path "C:\Windows\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
Start-Service -Name Spooler

# Attempt the print job again
```

---

## Step 3 - Verify Printer Status and Connectivity (Client Side)

```powershell
# List all installed printers and their status
Get-Printer | Select-Object Name, PrinterStatus, DriverName, PortName

# Key statuses:
# Normal  - Printer is functioning correctly from the OS perspective
# Offline - OS believes the printer is unreachable
# Error   - Printer reported a fault state

# For a network printer, test connectivity to the printer's IP address
# Find the IP from the port name or printer properties first
Get-PrinterPort -Name "PortName" | Select-Object Name, PrinterHostAddress

# Test reachability
Test-NetConnection -ComputerName "192.168.1.50" -Port 9100
# Port 9100 is the standard raw printing port (JetDirect/AppSocket)
# TcpTestSucceeded: True confirms the printer is reachable on the network
```

**Interpreting connectivity results:**

| PrinterStatus | Port 9100 Reachable | Conclusion |
|---|---|---|
| Normal | True | Printer reachable - fault may be queue/driver related, recheck Steps 1-2 |
| Offline | False | Printer unreachable - network or printer power issue |
| Offline | True | OS/driver believes printer is offline despite being reachable - driver fault |
| Error | True | Printer reachable but reporting a fault - check printer's own display panel |

---

## Step 4 - Physical and Network Checks (Printer Side)

**Physical checks at the printer:**

- [ ] Confirm the printer is powered on
- [ ] Check the printer's own display panel for error messages (paper jam, low toner,
  tray empty, cover open)
- [ ] Confirm network cable is connected if the printer is wired (check link light on printer NIC)
- [ ] If wireless, confirm the printer shows as connected to the correct Wi-Fi network
  on its own display
- [ ] Check for paper jams, even if not indicated on the display - physically inspect trays

**Network printer connectivity from a different device:**

If available, test the printer's IP from another known-good device to confirm whether
the fault is the printer/network or specific to the original user's device.

```powershell
# From a second device
Test-NetConnection -ComputerName "192.168.1.50" -Port 9100
ping 192.168.1.50 -n 4
```

```bash
# Linux equivalent
ping -c 4 192.168.1.50
nc -zv 192.168.1.50 9100
```

**If unreachable from multiple devices:** This confirms a printer or network-side fault,
not a client issue. Proceed to printer-specific checks below.

```powershell
# Verify the printer's expected IP has not changed (common after DHCP renewal
# on a printer that should have a static or reserved IP)
arp -a | Select-String "192.168.1.50"

# If the printer's IP has changed, this typically requires a DHCP reservation fix
# (Tier 2) or updating the printer's static IP configuration
```

---

## Step 5 - Driver Verification and Reinstallation

A mismatched, outdated, or corrupted driver causes the printer to appear offline,
produce garbled output, or fail silently.

```powershell
# Check the driver currently associated with the printer
Get-Printer -Name "PrinterName" | Select-Object Name, DriverName

# List all installed print drivers on the system
Get-PrinterDriver | Select-Object Name, Manufacturer, DriverVersion

# Remove the printer and its driver, then reinstall cleanly
Remove-Printer -Name "PrinterName"

# Remove the driver (requires no other printer using it)
Remove-PrinterDriver -Name "DriverName" -ErrorAction SilentlyContinue

# Reinstall the printer - for network printers, recreate the port and add fresh
Add-PrinterPort -Name "IP_192.168.1.50" -PrinterHostAddress "192.168.1.50"
Add-PrinterDriver -Name "DriverName"
Add-Printer -Name "PrinterName" -DriverName "DriverName" -PortName "IP_192.168.1.50"

# Verify
Get-Printer -Name "PrinterName" | Select-Object Name, PrinterStatus, DriverName
```

> **Note:** Use the manufacturer's official driver package where available rather
> than a generic Windows in-box driver, especially for multifunction devices with
> scanning or advanced finishing features. Download drivers only from the manufacturer's
> official support site or your organisation's approved software repository.

**Garbled or incorrect output specifically (printer prints, but output is wrong):**

This is almost always a driver/language mismatch (e.g. PCL vs. PostScript mismatch).

```powershell
# Check the printer's configured driver language matches what the printer expects
# Reinstalling with the correct manufacturer driver (above) typically resolves this

# If using a generic driver, switch to the manufacturer-specific driver
# matching the exact model number
```

---

## Step 6 - Shared Printer Faults (Printer Shared via Another PC)

If the printer is shared through another user's workstation rather than connected
directly to the network, additional checks apply.

```powershell
# On the hosting PC - confirm the printer share is active
Get-Printer -Name "PrinterName" | Select-Object Name, Shared, ShareName

# Confirm the hosting PC itself is online and reachable
Test-Connection -ComputerName "HostingPCName" -Count 4

# Check the Print Spooler service status on the HOSTING PC, not just the client
Get-Service -Name Spooler -ComputerName "HostingPCName"
```

**Common shared-printer fault:** The hosting PC was shut down, put to sleep, or
disconnected from the network - this takes the shared printer offline for everyone
relying on it.

**Recommendation:** Document and flag this for Tier 2 - shared printing via a user's
workstation is fragile for business-critical printing and a dedicated print server or
direct network printing should be considered to avoid recurring single-point-of-failure
tickets.

---

## Step 7 - Linux Printing Diagnosis (CUPS)

For Linux endpoints, printing is managed via CUPS (Common Unix Printing System).

```bash
# Check CUPS service status
systemctl status cups

# If not running
sudo systemctl start cups
sudo systemctl enable cups

# List configured printers and their status
lpstat -p -d

# Key statuses:
# "printer PrinterName is idle" - ready and functioning
# "printer PrinterName disabled" - printer is disabled, needs re-enabling

# Re-enable a disabled printer
sudo cupsenable PrinterName

# Check the print queue
lpstat -o

# Clear stuck jobs
cancel -a PrinterName   # Cancel all jobs for this printer

# Test connectivity to a network printer
ping -c 4 192.168.1.50
nc -zv 192.168.1.50 9100   # Raw printing port
nc -zv 192.168.1.50 631    # IPP port

# Access the CUPS web interface for detailed diagnostics (local access)
# Open in browser: http://localhost:631

# View CUPS error log for detailed fault information
sudo tail -50 /var/log/cups/error_log
```

**Re-add a printer that fails to communicate:**

```bash
# Remove the existing printer configuration
sudo lpadmin -x PrinterName

# Re-add using the appropriate driver/PPD
# List available drivers first
lpinfo -m | grep -i "manufacturer-name"

# Add the printer (example using IPP)
sudo lpadmin -p PrinterName -E -v ipp://192.168.1.50/ipp/print -m everywhere

# Set as default if needed
lpoptions -d PrinterName

# Print a test page
echo "Test print from $(hostname)" | lp -d PrinterName
```

---

## Escalation Criteria

Escalate to Tier 2 when:

- [ ] Printer is unreachable from multiple devices on the network (infrastructure-side fault)
- [ ] Print server (if in use) shows a service fault requiring server access
- [ ] Driver reinstallation does not resolve persistent offline status or garbled output
- [ ] Printer's IP address requires a DHCP reservation fix
- [ ] Shared printer hosting PC is consistently unavailable - recommend dedicated
  print solution
- [ ] Printer hardware fault is suspected (error codes on display panel indicating
  internal fault, not consumables)
- [ ] Multiple printers across the network show simultaneous faults (possible print
  server or VLAN issue)

**Escalation package must include:**

- Printer model, IP address, and connection type
- PrinterStatus and port reachability test results
- Whether the fault is isolated to one user or affects multiple users
- Driver name and version currently in use
- Any error codes shown on the printer's own display panel
- Spooler and queue status from client-side checks

---

## Expected Results After Successful Resolution

```
Get-Printer -Name "PrinterName"

Name          : PrinterName
PrinterStatus : Normal
DriverName    : [Manufacturer Driver Name]

Test print job submitted and confirmed printed by the user.
No jobs stuck in queue (Get-PrintJob returns empty or "Normal" status only).
Spooler service status: Running.
```

---

## Common Fault Patterns and Quick Resolutions

| Symptom Pattern | Most Likely Cause | First Action |
|---|---|---|
| Nothing happens when printing | Spooler stopped or hung | Restart spooler (Step 1) |
| Shows "Offline" but printer is powered on | Stale status or driver fault | Check port reachability (Step 3); restart spooler |
| One job stuck, blocking all others | Corrupted job in queue | Clear spool folder (Step 1/2) |
| Garbled or wrong characters printed | Wrong driver / language mismatch | Reinstall correct manufacturer driver (Step 5) |
| Works for some users, not others | Driver installed differently per device | Check driver consistency across affected devices |
| Was working, fails after office move | Printer IP changed (DHCP) | Verify current IP; update port configuration |
| Shared printer suddenly unavailable | Hosting PC offline/asleep | Check hosting PC status (Step 6) |
| Print queue shows job but printer idle | Spooler/printer communication fault | Restart spooler; verify port reachability |

---

## Verification Checklist

- [ ] Spooler service confirmed running (Windows) or CUPS running (Linux)
- [ ] Print queue is clear of stuck jobs
- [ ] Printer status shows Normal/Idle, not Offline or Error
- [ ] Test print successfully completes and output is correct
- [ ] User has independently confirmed they can print their actual document
- [ ] If driver was reinstalled, confirm correct manufacturer driver is in use
- [ ] Root cause documented in the ticket

---

## Security Considerations

- Only install printer drivers from the manufacturer's official site or the
  organisation's approved software repository - third-party driver download sites
  are a known malware distribution vector
- Network printers with default or weak admin credentials on their web management
  interface are a common attack surface - flag any printer found with default
  credentials still active for Tier 2 / security review
- Print jobs containing sensitive documents stuck in a queue accessible to other
  users represent a data exposure risk - clear stuck sensitive print jobs promptly
  and consider secure/pull-printing solutions for sensitive environments

---

## Related Documents

| Document | Relationship |
|---|---|
| [`../networking/network-troubleshooting-guide.md`](../networking/network-troubleshooting-guide.md) | Layer 3 connectivity checks for network printers |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Escalation criteria and package requirements |
| [`../reference/powershell-command-reference.md`](../reference/powershell-command-reference.md) | Full printer management cmdlet reference |
| [`../reference/linux-command-reference.md`](../reference/linux-command-reference.md) | Full CUPS command reference |
| [`../templates/ticket-template.md`](../templates/ticket-template.md) | Ticket format for this scenario |