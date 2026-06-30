# Wi-Fi Diagnostic Guide

## Purpose

This guide provides structured diagnostic procedures for Wi-Fi connectivity faults in SMB
environments. Wireless faults are among the most frequently misdiagnosed help desk issues
because their symptoms - dropped connections, slow speeds, authentication failures, and
inability to connect - can originate at any layer from physical signal strength through
to authentication infrastructure.

This guide separates wireless faults into four distinct fault families and provides a
diagnostic path for each. Following this structure prevents the most common wireless
troubleshooting mistake: treating every Wi-Fi problem as a driver problem or a password
problem.

---

## When to Use This Guide

Use this guide when a user reports any of the following:

- Cannot see the Wi-Fi network (SSID not visible)
- Can see the network but cannot connect
- Connected to Wi-Fi but cannot reach network resources or internet
- Wi-Fi connection drops intermittently
- Wi-Fi speed is significantly slower than expected
- Connected to Wi-Fi but shown as "No internet" or "Limited connectivity"
- Wi-Fi worked yesterday but does not work today with no known changes
- Wi-Fi works on personal devices but not on the work device

---

## The Four Wi-Fi Fault Families

Every Wi-Fi fault belongs to one of these four families. Identifying the family first
directs diagnosis to the correct layer immediately.

| Family | Description | Typical Symptoms |
|---|---|---|
| **Signal / Physical** | Device cannot reach the access point reliably | SSID not visible, drops when moving, weak signal indicator |
| **Authentication** | Device reaches the AP but cannot join the network | Password rejected, certificate error, authentication timeout |
| **IP Assignment** | Authenticated but no usable IP address | Connected but no internet, APIPA address, limited connectivity |
| **Service Reachability** | IP assigned but target resources unreachable | Connected and IP valid but specific sites or services fail |

---

## Pre-Diagnosis: Establish the Fault Family

Answer these questions before running any diagnostic commands:

```
Can the device see the correct SSID in the available network list?
          │
    No ───► Fault Family: Signal / Physical
          │  Go to: Part 1
          │
    Yes   ▼
Can the device connect to the SSID (authentication succeeds)?
          │
    No ───► Fault Family: Authentication
          │  Go to: Part 2
          │
    Yes   ▼
Does the device receive a valid IP address (not 169.254.x.x)?
          │
    No ───► Fault Family: IP Assignment
          │  Go to: Part 3
          │
    Yes   ▼
Can the device reach network resources and internet?
          │
    No ───► Fault Family: Service Reachability
          │  Go to: Part 4
          │
    Yes   ▼
Wi-Fi is functional - fault is application-layer or service-side
Refer to relevant playbook in ../playbooks/
```

---

## Part 1 - Signal and Physical Layer Faults

**What this covers:** The device cannot see the SSID, or sees it intermittently, or
connects only when close to the access point.

> **Book reference:** CompTIA Network+ Guide to Networks (10th Ed.) covers wireless
> standards, frequencies, and signal characteristics. CompTIA A+ Guide to IT Technical
> Support (11th Ed.) covers wireless adapter hardware and driver management. The
> practical steps below apply both.

### 1.1 - Confirm Wi-Fi is Enabled

This is the most common cause of "Wi-Fi not working" calls. Always verify before
assuming a signal or hardware fault.

Windows:
```powershell
# Check wireless adapter state
Get-NetAdapter | Where-Object {$_.PhysicalMediaType -like "*802.11*"} |
    Select-Object Name, Status, PhysicalMediaType

# If Status is "Disabled":
Enable-NetAdapter -Name "Wi-Fi"

# Check if Wi-Fi is disabled at the OS level (Airplane Mode)
# Settings > Network & Internet > Airplane Mode - confirm Off
# Or check via PowerShell:
Get-NetAdapter | Where-Object {$_.Name -like "*Wi-Fi*"} |
    Select-Object Name, Status
```

Linux:
```bash
# Check if wireless interface exists and is up
ip link show

# Check if Wi-Fi is hardware or software blocked
rfkill list all

# Example output showing software block:
# 0: phy0: Wireless LAN
#         Soft blocked: yes    ← Software disabled - fix with rfkill unblock
#         Hard blocked: no

# Unblock software block
rfkill unblock wifi

# Unblock all wireless
rfkill unblock all

# Bring the interface up
sudo ip link set wlan0 up  # Replace wlan0 with actual interface name
```

### 1.2 - Check Signal Strength and SSID Visibility

Windows:
```powershell
# List all visible wireless networks with signal strength
netsh wlan show networks mode=bssid

# View current connection signal quality
netsh wlan show interfaces

# Key fields in output:
# SSID             : CompanyWifi
# Signal           : 85%          ← Below 50% causes reliability issues
# Radio type       : 802.11ac
# Channel          : 36
# Receive rate     : 400 (Mbps)
# Transmit rate    : 400 (Mbps)
```

Linux:
```bash
# List visible networks with signal levels
nmcli device wifi list

# View current connection details
nmcli device wifi show

# Signal level using iwconfig (older tool, may not be installed)
iwconfig 2>/dev/null | grep -i signal

# More detailed scan using iw
sudo iw dev wlan0 scan | grep -E "SSID|signal|freq"
```

**Signal strength interpretation:**

| Signal Level (Windows %) | Signal Level (Linux dBm) | Quality | Expected Behaviour |
|---|---|---|---|
| 80–100% | -30 to -50 dBm | Excellent | Full speed, stable connection |
| 60–80% | -50 to -65 dBm | Good | Normal operation |
| 40–60% | -65 to -75 dBm | Fair | Reduced speed, occasional drops |
| 20–40% | -75 to -85 dBm | Poor | Frequent drops, very slow |
| Below 20% | Below -85 dBm | Unusable | Cannot maintain connection |

**Signal fault actions:**

| Observation | Action |
|---|---|
| SSID not visible, other SSIDs visible | AP offline, wrong frequency band, or SSID hidden |
| SSID visible on phone but not work device | Band mismatch (5 GHz vs 2.4 GHz) or driver issue |
| SSID visible but very low signal | Move closer to AP, check for physical obstruction |
| Signal good but connection drops | Interference, channel congestion, or AP fault |
| No SSIDs visible at all | Adapter disabled, driver fault, or hardware fault |

### 1.3 - Frequency Band and Channel Awareness

> **Book reference:** CompTIA Network+ Guide to Networks (10th Ed.) covers the differences
> between 2.4 GHz and 5 GHz bands and their respective characteristics.

**Key differences in help desk context:**

| Band | Range | Speed | Congestion | Penetration |
|---|---|---|---|---|
| 2.4 GHz | Longer | Lower | Higher | Better through walls |
| 5 GHz | Shorter | Higher | Lower | Weaker through walls |
| 6 GHz (Wi-Fi 6E) | Shortest | Highest | Lowest | Weakest through walls |

**Common band-related fault:** A device that supports only 2.4 GHz cannot see a 5 GHz-only
SSID. A device in a distant room may drop to 2.4 GHz while the SSID is broadcast on
5 GHz only. This is a configuration decision on the AP - escalate to Tier 2 if band
configuration needs to change.

### 1.4 - Driver and Hardware Checks

Windows:
```powershell
# Check wireless adapter driver status
Get-NetAdapter | Where-Object {$_.PhysicalMediaType -like "*802.11*"} |
    Select-Object Name, Status, DriverVersion, DriverDate

# Check Device Manager for driver errors (look for yellow warning icons)
# Via PowerShell:
Get-PnpDevice | Where-Object {
    $_.Class -eq "Net" -and $_.Status -ne "OK"
} | Select-Object FriendlyName, Status, ProblemCode

# Disable and re-enable the adapter (often resolves driver hangs)
$adapter = Get-NetAdapter | Where-Object {$_.PhysicalMediaType -like "*802.11*"}
Disable-NetAdapter -Name $adapter.Name -Confirm:$false
Start-Sleep -Seconds 5
Enable-NetAdapter -Name $adapter.Name
```

Linux:
```bash
# Check if the wireless driver is loaded
lsmod | grep -i "iwl\|ath\|rtl\|brcm\|mt76"

# View kernel messages for wireless driver errors
dmesg | grep -i "wifi\|wlan\|wireless\|firmware" | tail -20

# Check adapter details
iw dev

# Reload the wireless driver (example for Intel iwlwifi)
# Replace iwlwifi with the actual driver name from lsmod
sudo modprobe -r iwlwifi
sleep 3
sudo modprobe iwlwifi
```

---

## Part 2 - Authentication Faults

**What this covers:** The device can see the SSID and attempts to connect but fails
during the authentication process.

### 2.1 - Identify the Authentication Type

The authentication type determines the correct diagnostic path.

| Auth Type | Where Used | How to Identify |
|---|---|---|
| WPA2/WPA3 Personal (PSK) | Home, small office | Single password for all users |
| WPA2/WPA3 Enterprise (802.1X) | Corporate networks | Username and password, or certificate |
| Open (no password) | Guest networks, public Wi-Fi | No password prompt |
| Captive portal | Guest networks | Redirects browser to login page |

Windows:
```powershell
# View authentication type of saved network profiles
netsh wlan show profiles

# View detailed profile including security type
netsh wlan show profile name="NetworkName" key=clear

# Key fields to check:
# Authentication  : WPA2-Personal or WPA2-Enterprise
# Cipher          : CCMP (AES) - correct | TKIP - older, less secure
# Security key    : Present - for PSK networks
```

### 2.2 - PSK (Password) Authentication Failures

The most common cause is an incorrect, changed, or expired Wi-Fi password.

Windows:
```powershell
# View the stored Wi-Fi password for a saved profile
# (requires elevation on some systems)
netsh wlan show profile name="NetworkName" key=clear
# Look for: Key Content : <password>

# Forget and reconnect with correct password:
# Step 1: Remove the saved profile
netsh wlan delete profile name="NetworkName"

# Step 2: Reconnect via UI - click the network, enter the correct password
# Step 3: Verify connection
netsh wlan show interfaces
```

Linux:
```bash
# View saved Wi-Fi connections
nmcli connection show

# View connection details including stored password
sudo nmcli connection show "NetworkName" | grep psk

# Delete a saved profile and reconnect
nmcli connection delete "NetworkName"

# Connect with correct password
nmcli device wifi connect "NetworkName" password "correct-password"

# Verify connection
nmcli connection show --active
```

### 2.3 - Enterprise (802.1X) Authentication Failures

> **Book reference:** CompTIA Network+ Guide to Networks (10th Ed.) covers 802.1X port-based
> authentication and EAP (Extensible Authentication Protocol). This is standard corporate
> Wi-Fi authentication in SMB and enterprise environments.

Enterprise Wi-Fi authentication failures are more complex than PSK failures because they
involve a RADIUS server, user credentials, and often certificates.

**Common 802.1X failure causes:**

| Cause | Symptom | Tier 1 Action |
|---|---|---|
| Expired user password | Auth failure after password change | User updates Windows credentials; reconnect |
| Account locked | Authentication rejected | Unlock account in Active Directory (if authorised) |
| Certificate expired | Certificate error on connection | Escalate - certificate renewal is Tier 2 |
| RADIUS server unreachable | Authentication timeout | Check network connectivity; escalate |
| Incorrect EAP type configured | Auth failure on new device | Compare profile with known-good device; escalate |
| User not in wireless access group | Auth rejected consistently | Escalate - AD group membership change |

Windows - remove and recreate 802.1X profile:
```powershell
# Export the wireless profile from a working device first
# On working device:
netsh wlan export profile name="NetworkName" folder="C:\Temp"

# On affected device - delete corrupted profile:
netsh wlan delete profile name="NetworkName"

# Import the profile from the working device export:
netsh wlan add profile filename="C:\Temp\NetworkName.xml"

# Reconnect - user will be prompted for credentials
```

Linux - reset 802.1X connection:
```bash
# Delete the existing connection
nmcli connection delete "NetworkName"

# Re-add with 802.1X EAP-PEAP (most common corporate config)
# Replace values with actual network configuration
nmcli connection add \
    type wifi \
    con-name "NetworkName" \
    ssid "NetworkName" \
    wifi-sec.key-mgmt wpa-eap \
    802-1x.eap peap \
    802-1x.phase2-auth mschapv2 \
    802-1x.identity "username@company.com" \
    802-1x.password "UserPassword"

nmcli connection up "NetworkName"
```

---

## Part 3 - IP Assignment Faults

**What this covers:** The device connects to the Wi-Fi network successfully (authentication
passes) but does not receive a valid IP address, or receives an APIPA address.

The diagnostic and resolution steps for IP assignment faults over Wi-Fi are identical to
wired DHCP faults. The wireless medium is the transport - the DHCP process is the same.

**Confirm the fault:**

Windows:
```powershell
ipconfig /all
# Look for: IPv4 Address beginning with 169.254 (APIPA)
# Look for: Default Gateway blank or missing
```

Linux:
```bash
ip addr show wlan0  # Replace with actual wireless interface
# Look for: inet 169.254.x.x - link-local (APIPA equivalent)
# Or: no inet line - no address assigned
```

**Resolution - DHCP release and renew over Wi-Fi:**

Windows:
```powershell
# Release and renew on the wireless adapter specifically
$wifiAdapter = (Get-NetAdapter | Where-Object {
    $_.PhysicalMediaType -like "*802.11*" -and $_.Status -eq "Up"
}).Name

ipconfig /release "$wifiAdapter"
Start-Sleep -Seconds 5
ipconfig /renew "$wifiAdapter"
ipconfig /all
```

Linux:
```bash
# Restart the wireless connection via NetworkManager
CONNECTION=$(nmcli -t -f NAME connection show --active | head -1)
nmcli connection down "$CONNECTION"
sleep 5
nmcli connection up "$CONNECTION"

ip addr show wlan0
```

If DHCP renewal fails over Wi-Fi after confirming authentication succeeds, refer to
[`dns-dhcp-playbook.md`](dns-dhcp-playbook.md) Part 2 for extended DHCP fault diagnosis.

---

## Part 4 - Service Reachability Faults

**What this covers:** The device is connected to Wi-Fi, has a valid IP address, but
cannot reach specific or all network resources. This is not a wireless fault - it is a
network service fault that happens to present on a wireless device.

**Confirm the IP is valid (not APIPA):**
```powershell
ipconfig /all  # Confirm 192.168.x.x or similar, not 169.254.x.x
```

**Then follow the Layer 3–7 diagnostic sequence from:**
[`network-troubleshooting-guide.md`](network-troubleshooting-guide.md)

The wireless connection is confirmed functional. The fault is above Layer 2.

---

## Intermittent Wi-Fi Fault Diagnosis

Intermittent faults are the hardest wireless faults to diagnose because they are not
present during the diagnostic session. Use these techniques to capture evidence of
intermittent faults.

### Identify the Pattern

Ask the user:

| Question | What It Reveals |
|---|---|
| Does it drop at a specific time of day? | Interference from other devices or traffic peaks |
| Does it drop in a specific location? | Signal range or dead zone |
| Does it drop for everyone or just this user? | AP fault vs. device fault |
| Does it recover on its own or require action? | Temporary interference vs. adapter fault |
| What was happening when it dropped? | Traffic pattern correlation |

### Capture Signal Data During the Fault

Windows - continuous signal monitoring:
```powershell
# Log signal strength every 10 seconds to a file
# Run this before the expected fault window
$logFile = "$env:USERPROFILE\Desktop\wifi-signal-log.txt"
Write-Output "Timestamp,SSID,Signal,RadioType" | Out-File $logFile

while ($true) {
    $wlan = netsh wlan show interfaces
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $ssid    = ($wlan | Select-String "SSID" | Select-Object -First 1).ToString().Trim()
    $signal  = ($wlan | Select-String "Signal").ToString().Trim()
    $radio   = ($wlan | Select-String "Radio type").ToString().Trim()
    "$timestamp | $ssid | $signal | $radio" | Out-File $logFile -Append
    Start-Sleep -Seconds 10
}
# Stop with Ctrl+C - attach the log file to the ticket
```

Linux - continuous signal monitoring:
```bash
# Log signal strength every 10 seconds
INTERFACE="wlan0"
LOGFILE="$HOME/wifi-signal-log.txt"
echo "Timestamp,Interface,Signal_dBm,SSID" > "$LOGFILE"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    SIGNAL=$(iwconfig "$INTERFACE" 2>/dev/null | \
        grep -oP 'Signal level=\K[^\s]+')
    SSID=$(iwconfig "$INTERFACE" 2>/dev/null | \
        grep -oP 'ESSID:"\K[^"]+')
    echo "$TIMESTAMP | $INTERFACE | ${SIGNAL:-N/A} dBm | ${SSID:-N/A}" \
        >> "$LOGFILE"
    sleep 10
done
# Stop with Ctrl+C - attach log to ticket
```

### Common Intermittent Fault Causes

| Pattern | Likely Cause | Action |
|---|---|---|
| Drops at the same time each day | Interference from scheduled device | Identify source; escalate AP channel change |
| Drops only in one room | Dead zone or signal obstruction | Move user closer to AP or request AP placement review |
| Drops for all users simultaneously | AP fault or upstream fault | Escalate - infrastructure issue |
| Drops only for this user on this device | Adapter or driver fault | Update driver, check power management |
| Gradually worse over the day | AP overloaded or memory fault | Escalate - AP restart may be needed |

### Power Management Interference (Windows)

Windows sometimes reduces wireless adapter power to save battery, which causes drops.

```powershell
# Disable power management for the wireless adapter (requires elevation)
$adapter = Get-NetAdapter | Where-Object {$_.PhysicalMediaType -like "*802.11*"}
$adapterIndex = $adapter.InterfaceIndex

# Disable power management via registry approach
# Note: This setting can also be found in Device Manager >
# Wireless Adapter > Properties > Power Management >
# Uncheck "Allow the computer to turn off this device to save power"

powercfg /change monitor-timeout-ac 0  # Prevent display sleep affecting tests

# Set adapter to maximum performance in Power Options
powercfg /setacvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 `
    12bbebe6-58d6-4636-95bb-3217ef867c1a 0
```

---

## Wi-Fi Diagnostic Escalation Criteria

Escalate to Tier 2 when:

- SSID is not visible on any device - AP may be offline or misconfigured
- Authentication fails for all users - RADIUS server or AP authentication fault
- Signal strength is confirmed adequate but connections are unstable across multiple devices
- Channel interference is suspected - requires AP management access to change
- Band configuration needs to change (5 GHz only vs. dual-band)
- 802.1X certificate has expired
- Multiple access points in the same area are causing roaming problems
- DHCP renewal fails on wireless after confirming authentication succeeds
- Any AP hardware fault is suspected

Include in Wi-Fi escalation package:
- Output of `netsh wlan show interfaces` or `nmcli device wifi list`
- Signal strength at time of fault
- Authentication type confirmed
- Whether other devices on the same network are affected
- Signal monitoring log if intermittent fault

---

## Wi-Fi Diagnostic Quick Reference

```
Step 1: Is Wi-Fi enabled?
  Windows: Get-NetAdapter (Status = Up?)
  Linux:   rfkill list all (blocked?)

Step 2: Is the SSID visible?
  Windows: netsh wlan show networks mode=bssid
  Linux:   nmcli device wifi list

Step 3: What is the signal strength?
  Windows: netsh wlan show interfaces (Signal %)
  Linux:   nmcli device wifi list (SIGNAL column)

Step 4: Can the device connect (auth)?
  PSK:        Check saved password - delete profile, reconnect
  Enterprise: Check credentials, certificate, RADIUS reachability

Step 5: Does the device get a valid IP?
  Windows: ipconfig /all (not 169.254.x.x)
  Linux:   ip addr show wlan0

Step 6: Can the device reach network resources?
  Ping gateway → Ping 8.8.8.8 → nslookup google.com
  If all pass: application-layer fault, not wireless
```

---

## Security Considerations

- Never retrieve or display Wi-Fi passwords in a shared or public location
- Enterprise Wi-Fi passwords stored in the OS credential store should be managed through
  official IT provisioning - do not manually enter another user's credentials
- If a device connects to an unexpected SSID or an SSID with a name similar to the
  corporate network, disconnect immediately and escalate - this may be an evil twin attack
- Do not connect corporate devices to personal or guest Wi-Fi networks without policy
  authorisation - corporate traffic must traverse monitored infrastructure
- Report any access point you do not recognise appearing in the available network list

---

## Related Documents

| Document | Relationship |
|---|---|
| [`network-troubleshooting-guide.md`](network-troubleshooting-guide.md) | OSI-layer context for wireless fault families |
| [`dns-dhcp-playbook.md`](dns-dhcp-playbook.md) | Part 3 IP assignment faults reference this |
| [`connectivity-fault-isolation.md`](connectivity-fault-isolation.md) | Extended connectivity fault procedures |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Escalation criteria and package requirements |
| [`../scripts/windows/Get-NetworkDiagnostics.ps1`](../scripts/windows/Get-NetworkDiagnostics.ps1) | Includes wireless adapter diagnostic collection |
| [`../scripts/linux/network-diagnostics.sh`](../scripts/linux/network-diagnostics.sh) | Includes wireless interface diagnostic collection |