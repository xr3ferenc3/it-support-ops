# Playbook: No Network Connectivity

## Purpose

This playbook provides a complete resolution guide for tickets where a user reports
total loss of network access - they cannot reach the internet, internal resources,
shared drives, or any network service.

This is one of the highest-volume ticket types in any help desk environment. The fault
can originate at any layer from a loose cable through to a failed DHCP server. This
playbook walks the technician from first contact to verified resolution using a
structured sequence that eliminates the most common causes first.

---

## When to Use This Playbook

Use this playbook when the user reports:

- "I have no internet"
- "I can't access anything on the network"
- "My network has stopped working"
- "I can't get to the shared drive / intranet / email"
- The device shows "No network" or "Not connected" in the OS network indicator

Do not use this playbook if:
- The user can reach some resources but not others - use
  [`../networking/connectivity-fault-isolation.md`](../networking/connectivity-fault-isolation.md)
- The fault is confirmed DNS only - use [`dns-resolution-failure.md`](dns-resolution-failure.md)
- The fault is wireless specific - use
  [`../networking/wifi-diagnostic-guide.md`](../networking/wifi-diagnostic-guide.md)

---

## Ticket Intake - Required Information

Before starting diagnosis, record all of the following:

| Field | What to Record |
|---|---|
| User name and department | Full name, team, location |
| Device hostname | From System Properties or `hostname` command |
| Operating system | Windows 10/11, Ubuntu, etc. |
| Connection type | Wired or wireless |
| Time fault started | Exact or approximate |
| Recent changes | Updates, moved desk, new hardware, password change |
| Other affected users | Has the user checked with colleagues? |
| Error message shown | Exact text from OS network indicator or browser |
| Actions already taken | What has the user tried - reboot, cable swap, etc. |

**Priority assessment:**

| Condition | Priority |
|---|---|
| Single user, wired or wireless, workaround possible | P3 |
| Single critical user (exec, on-call role) with no workaround | P2 |
| Multiple users simultaneously in same area | P2 - potential infrastructure fault |
| Site-wide or organisation-wide loss | P1 - raise incident immediately |

---

## Step 1 - Scope Check Before Touching the Device

Before running a single diagnostic command, determine whether this is an isolated
fault or a wider infrastructure issue.

```
Ask the user: "Have you checked whether anyone else near you has the same problem?"

If yes, others affected:
  → Stop individual diagnosis
  → Check the ticket queue for similar reports from the same area
  → If two or more tickets match: raise as potential incident
  → Refer to ../incidents/incident-classification-guide.md
  → Escalate to Tier 2 with scope confirmed

If no, isolated to this user/device:
  → Continue with Step 2
```

---

## Step 2 - Physical Layer Verification

**Wired connections:**

```powershell
# Windows: Check adapter status
Get-NetAdapter | Select-Object Name, Status, LinkSpeed, MediaType

# Healthy output:
# Name      Status  LinkSpeed  MediaType
# Ethernet  Up      1 Gbps     802.3
```

```bash
# Linux: Check interface state
ip link show eth0   # Replace eth0 with actual interface name

# Healthy output contains: UP,LOWER_UP
# UP = OS has enabled the interface
# LOWER_UP = physical link is detected
```

**Manual physical checks - perform these in parallel:**

- [ ] Cable is fully seated at the device end (listen for the click)
- [ ] Cable is fully seated at the wall port or switch end
- [ ] Link light is present on the NIC port (green or amber)
- [ ] Link light is present on the switch port (if accessible)
- [ ] No visible cable damage (sharp bends, broken clip, cracked housing)

**If no link light:**
1. Swap the cable for a known-good cable
2. Try a different wall port if available
3. If link light still absent after cable swap: suspect switch port fault or NIC fault
4. Escalate to Tier 2 if switch port fault is suspected

**Wireless connections:**

```powershell
# Windows: Check wireless adapter
Get-NetAdapter | Where-Object {$_.PhysicalMediaType -like "*802.11*"} |
    Select-Object Name, Status

# Check if Wi-Fi is software-blocked
netsh wlan show interfaces
```

```bash
# Linux: Check for hardware or software block
rfkill list all
# If "Soft blocked: yes" - run: rfkill unblock wifi
```

For full wireless diagnosis refer to
[`../networking/wifi-diagnostic-guide.md`](../networking/wifi-diagnostic-guide.md).

---

## Step 3 - IP Address Verification

```powershell
# Windows: Full IP configuration
ipconfig /all
```

```bash
# Linux: IP address and routing table
ip addr show
ip route show
```

**What to look for and what it means:**

| IP Address Shown | Meaning | Action |
|---|---|---|
| `192.168.x.x` or site range | DHCP lease obtained - proceed to Step 4 | Continue |
| `169.254.x.x` | APIPA - DHCP failed | Go to Step 3a |
| `0.0.0.0` or blank | No address assigned | Go to Step 3a |
| Correct IP but no gateway | DHCP misconfiguration | Go to Step 3a |
| Unexpected IP range | Wrong DHCP scope or static conflict | Note and escalate |

### Step 3a - DHCP Release and Renew

Windows:
```powershell
# Release the failed or expired lease
ipconfig /release

# Wait briefly for the release to complete
Start-Sleep -Seconds 5

# Request a new lease
ipconfig /renew

# Verify the result - look for a valid IP, gateway, and DHCP server
ipconfig /all
```

Linux:
```bash
# Identify the active interface
IFACE=$(ip route show default 2>/dev/null | awk '{print $5}' | head -1)
# If no default route, identify the interface manually:
ip link show

# Release and renew (dhclient)
sudo dhclient -r "$IFACE"
sleep 3
sudo dhclient "$IFACE"

# Verify
ip addr show "$IFACE"
ip route show
```

**If DHCP renewal succeeds:** Skip to Step 6 - verify full connectivity.

**If DHCP renewal fails (APIPA persists):**
- Confirm the physical connection is active (link light present)
- Check whether other devices on the same network have valid IPs
- If others are also failing: DHCP server fault - escalate to Tier 2
- If others are fine: isolated device fault - continue to Step 4

---

## Step 4 - Gateway Reachability Test

A valid IP with an unreachable gateway indicates a routing or infrastructure fault
beyond the device.

```powershell
# Windows: Get gateway and test reachability
$gw = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop
Write-Host "Testing gateway: $gw"
ping $gw -n 4
```

```bash
# Linux: Get gateway and test reachability
GW=$(ip route show default | awk '{print $3}')
echo "Testing gateway: $GW"
ping -c 4 "$GW"
```

| Gateway Ping Result | Conclusion | Action |
|---|---|---|
| Replies received, low latency | Gateway reachable - proceed to Step 5 | Continue |
| Replies received, high latency (>100ms) | Gateway congested or degraded | Note, continue, escalate if persists |
| No replies | Gateway unreachable | Confirm Layer 1/2 OK; escalate to Tier 2 |

---

## Step 5 - Internet and DNS Confirmation

```powershell
# Windows: Test internet routing (bypasses DNS)
ping 8.8.8.8 -n 4

# Test DNS resolution
nslookup google.com

# Flush DNS cache if resolution fails
ipconfig /flushdns
nslookup google.com
```

```bash
# Linux: Test internet routing
ping -c 4 8.8.8.8

# Test DNS resolution
dig google.com +short

# If resolution fails, flush cache
sudo systemd-resolve --flush-caches 2>/dev/null || sudo systemctl restart nscd 2>/dev/null
dig google.com +short
```

**Interpreting results:**

| 8.8.8.8 Reachable | DNS Resolves | Conclusion |
|---|---|---|
| Yes | Yes | Full connectivity confirmed - fault is application-layer |
| Yes | No | DNS fault - refer to [`dns-resolution-failure.md`](dns-resolution-failure.md) |
| No | No | Internet egress blocked - escalate to Tier 2 |

---

## Step 6 - Network Stack Reset (Windows)

If Steps 1–5 confirm the physical connection is intact but the device still cannot
reach the network despite a valid IP and reachable gateway, reset the Windows
network stack. This resolves driver hangs, corrupt Winsock entries, and TCP/IP
stack corruption.

```powershell
# Requires elevated PowerShell (Run as Administrator)

# Step 1: Reset Winsock catalogue
netsh winsock reset

# Step 2: Reset TCP/IP stack
netsh int ip reset

# Step 3: Release and flush
ipconfig /release
ipconfig /flushdns

# Step 4: Reset firewall to defaults (if Windows Firewall is suspected)
netsh advfirewall reset

# Step 5: Reboot - these changes require a restart
Write-Host "Network stack reset complete. Rebooting in 30 seconds."
Write-Host "Save all open work now."
Start-Sleep -Seconds 30
Restart-Computer -Force
```

After reboot:
```powershell
# Verify connectivity is restored
ipconfig /all
ping 8.8.8.8
nslookup google.com
```

---

## Step 7 - Linux Network Service Restart

Linux equivalent of a network stack reset for persistent faults after confirming
physical and IP configuration are correct.

```bash
# Restart NetworkManager (most desktop distributions)
sudo systemctl restart NetworkManager
sleep 5

# Verify interfaces came back up
ip addr show
ip route show

# If using systemd-networkd instead:
sudo systemctl restart systemd-networkd
sudo systemctl restart systemd-resolved

# Reload network interfaces manually if service restart is insufficient
IFACE="eth0"  # Replace with actual interface
sudo ip link set "$IFACE" down
sleep 2
sudo ip link set "$IFACE" up
sleep 3
sudo dhclient "$IFACE"

# Verify
ip addr show "$IFACE"
ping -c 4 8.8.8.8
```

---

## Step 8 - Driver Reinstallation (Windows)

If the network stack reset does not resolve the fault, the NIC driver may be
corrupted or incompatible.

```powershell
# Identify the NIC driver in use
Get-NetAdapter | Select-Object Name, DriverName, DriverVersion, DriverDate

# Open Device Manager to uninstall and reinstall the driver:
devmgmt.msc

# In Device Manager:
# 1. Expand "Network Adapters"
# 2. Right-click the ethernet or wireless adapter
# 3. Select "Uninstall device"
# 4. Check "Delete the driver software for this device" if prompted
# 5. Action menu > Scan for hardware changes
# Windows will reinstall the driver automatically

# After reinstall - verify adapter is detected and up
Get-NetAdapter
ipconfig /all
ping 8.8.8.8
```

> **Note:** For wireless adapters, updated drivers are available from the laptop or
> motherboard manufacturer's support page. Generic Windows drivers may lack features
> or have known connectivity issues that manufacturer drivers resolve.

---

## Escalation Criteria

Escalate to Tier 2 if any of the following apply:

- [ ] Physical connection confirmed but gateway is unreachable after cable swap
- [ ] DHCP renewal fails after two attempts on a device with confirmed link
- [ ] More than one user on the same network segment is affected
- [ ] Network stack reset and driver reinstall do not restore connectivity
- [ ] Device obtains a DHCP address but from the wrong scope (wrong IP range)
- [ ] Switch port fault is suspected (no link light after cable and port swap)
- [ ] Traceroute stops inside the internal network

**Escalation package must include:**

- Output of `ipconfig /all` (Windows) or `ip addr show && ip route show` (Linux)
- Result of gateway ping (success/fail, latency, packet loss percentage)
- Result of `ping 8.8.8.8` and `nslookup google.com`
- Physical checks completed and result
- Actions taken and outcomes (DHCP renew result, stack reset if performed)
- Whether other users are affected and what their status is

---

## Expected Results After Successful Resolution

```
ipconfig /all - Windows healthy output:
  DHCP Enabled: Yes
  IPv4 Address: 192.168.x.x (site range - not 169.254.x.x)
  Subnet Mask:  255.255.255.0 (or site mask)
  Default Gateway: 192.168.x.1
  DHCP Server:  192.168.x.x
  DNS Servers:  192.168.x.x (and/or secondary)
  Lease Obtained: [today's date]

ping 8.8.8.8 - healthy output:
  Reply from 8.8.8.8: bytes=32 time<10ms TTL=118
  (4 replies, 0% loss)

nslookup google.com - healthy output:
  Server:  192.168.x.x
  Name:    google.com
  Address: 142.250.x.x
```

---

## Common Fault Patterns and Quick Resolutions

| Symptom Pattern | Most Likely Cause | First Action |
|---|---|---|
| No link light after reboot | Cable dislodged during move or reboot | Re-seat cable; swap if no improvement |
| APIPA after returning from travel | DHCP lease expired while off network | `ipconfig /release && ipconfig /renew` |
| Valid IP, gateway unreachable | Switch port fault | Swap port; escalate if persists |
| Valid IP, gateway reachable, no internet | Firewall or ISP fault | Escalate to Tier 2 |
| Worked yesterday, fails today, no changes | DHCP lease expiry or driver hang | Renew lease; restart network service |
| Wi-Fi shows connected but no access | IP assignment failure | DHCP renew on wireless adapter |
| Network works then drops every few minutes | Driver power management | Disable adapter power saving |
| No connectivity after Windows Update | Driver or stack regression | Network stack reset; driver rollback |

---

## Verification Checklist

Before closing the ticket, confirm all of the following:

- [ ] User can access the internet (open a browser, confirm a page loads)
- [ ] User can access internal resources (shared drive, intranet, or email)
- [ ] `ipconfig /all` shows a valid IP, gateway, and DHCP server
- [ ] Ping to 8.8.8.8 returns 0% packet loss
- [ ] DNS resolution confirmed via `nslookup google.com`
- [ ] User has confirmed the specific task that was failing now works
- [ ] Root cause is documented in the ticket
- [ ] Any temporary workarounds have been reversed or noted for follow-up

---

## Security Considerations

- Do not reset the Windows Firewall (`netsh advfirewall reset`) without confirming
  with the user that no custom firewall rules are in place - this will remove them
- If the device had no connectivity and is now reconnected after an extended offline
  period, allow Windows Update to run before returning the device to the user
- An unexplained complete loss of connectivity on a previously healthy device may
  indicate malware activity affecting network drivers - if driver reinstall does not
  resolve the fault and no infrastructure cause is found, escalate with a note
  that malware should not be excluded

---

## Related Documents

| Document | Relationship |
|---|---|
| [`../networking/network-troubleshooting-guide.md`](../networking/network-troubleshooting-guide.md) | OSI-layer foundation for all steps in this playbook |
| [`../networking/dns-dhcp-playbook.md`](../networking/dns-dhcp-playbook.md) | Extended DNS and DHCP fault procedures |
| [`../networking/wifi-diagnostic-guide.md`](../networking/wifi-diagnostic-guide.md) | Full wireless fault procedures |
| [`../networking/connectivity-fault-isolation.md`](../networking/connectivity-fault-isolation.md) | Extended isolation for partial or complex faults |
| [`dns-resolution-failure.md`](dns-resolution-failure.md) | DNS-specific resolution playbook |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Escalation criteria and package requirements |
| [`../scripts/windows/Get-NetworkDiagnostics.ps1`](../scripts/windows/Get-NetworkDiagnostics.ps1) | Automated Windows network diagnostic collection |
| [`../scripts/linux/network-diagnostics.sh`](../scripts/linux/network-diagnostics.sh) | Automated Linux network diagnostic collection |
| [`../templates/ticket-template.md`](../templates/ticket-template.md) | Ticket format for this scenario |