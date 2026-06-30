# Playbook: Slow Network Performance

## Purpose

This playbook provides a resolution guide for tickets where network connectivity exists
but performance is degraded - slow file transfers, buffering video calls, sluggish
browsing, or delayed application response over the network.

Slow performance is harder to diagnose than total connectivity loss because the network
is partially working, which means more variables are in play: bandwidth, latency, packet
loss, congestion, and contention all need to be separately assessed.

---

## When to Use This Playbook

Use this playbook when the user reports:

- "The internet is really slow"
- "File transfers are taking forever"
- "Video calls keep freezing or breaking up"
- "Pages take a long time to load"
- "It was fine yesterday, now everything is slow"

Do not use this playbook if:
- The user has no connectivity at all - use [`no-network-connectivity.md`](no-network-connectivity.md)
- The issue is isolated to one specific application's internal performance - use
  [`application-not-launching.md`](application-not-launching.md) as a starting reference,
  noting this playbook covers network-caused slowness specifically
- The issue is high local resource usage - use [`high-cpu-memory-usage.md`](high-cpu-memory-usage.md)

---

## Ticket Intake - Required Information

| Field | What to Record |
|---|---|
| What specifically is slow | Browsing, file transfer, video call, specific app |
| When it started | Exact or approximate time |
| Constant or intermittent | Always slow, or slow at certain times |
| Affected scope | Just this user, the team, or everyone |
| Connection type | Wired or wireless |
| What changed recently | New device, software install, moved location |
| Comparison point | Did the user measure speed before, or is this a feeling |

**Priority assessment:**

| Condition | Priority |
|---|---|
| Single user, workaround available | P3 |
| Single critical user with deadline impact | P2 |
| Department or team-wide slowness | P2 - possible infrastructure |
| Organisation-wide slowness | P1 - raise incident |

---

## Step 1 - Establish a Baseline Measurement

Before diagnosing cause, establish factual performance data. "Slow" is subjective -
a measured number is not.

```powershell
# Windows: Test download/upload using built-in tools
# Method 1: Use Test-NetConnection for latency to a known endpoint
Test-NetConnection -ComputerName 8.8.8.8 -InformationLevel Detailed

# Method 2: Measure file copy speed against a known internal share
Measure-Command {
    Copy-Item -Path "\\fileserver\testfile.dat" -Destination "C:\Temp\testfile.dat"
}

# Method 3: Ping with extended count to detect latency variance and loss
ping 8.8.8.8 -n 50
```

```bash
# Linux: Measure latency and loss
ping -c 50 8.8.8.8

# Measure throughput using curl against a known test file
curl -o /dev/null -s -w "Speed: %{speed_download} bytes/sec\nTime: %{time_total}s\n" \
    http://speedtest.tele2.net/10MB.zip

# Measure local file copy speed
time cp /mnt/fileserver/testfile.dat /tmp/testfile.dat
```

**Baseline interpretation:**

| Metric | Good | Degraded | Poor |
|---|---|---|---|
| Latency to gateway | <5ms | 5–20ms | >20ms |
| Latency to internet (8.8.8.8) | <30ms | 30–80ms | >80ms |
| Packet loss | 0% | 1–4% | 5%+ |
| Jitter (latency variance) | <5ms | 5–30ms | >30ms |

Record these numbers in the ticket. They are the evidence for what "slow" means in
this specific case and form the comparison point after resolution.

---

## Step 2 - Determine Scope

```
Is the slowness affecting:
  Only this user?
    → Likely device, local connection, or application-specific cause
    → Continue to Step 3

  This user and nearby colleagues (same switch/AP)?
    → Likely local segment congestion or shared infrastructure fault
    → Check switch port utilisation / AP client count (Tier 2)
    → Escalate if confirmed shared-resource cause

  Everyone in the building?
    → Likely WAN/ISP bandwidth saturation or core infrastructure fault
    → Escalate immediately - Tier 2 / Tier 3
    → Refer to ../incidents/incident-classification-guide.md if widespread

  Only when accessing one specific external service?
    → Likely the destination service is degraded, not the local network
    → Test against multiple destinations to confirm
```

---

## Step 3 - Wired Connection Speed and Duplex Check

A mismatched or downgraded link speed is a common and easily-missed cause of poor
performance on wired connections.

```powershell
# Windows: Check negotiated link speed
Get-NetAdapter | Select-Object Name, Status, LinkSpeed, MediaType

# A healthy gigabit connection shows: 1 Gbps
# A connection showing 100 Mbps or 10 Mbps on gigabit-rated infrastructure
# indicates a negotiation fault, bad cable, or damaged port
```

```bash
# Linux: Check negotiated speed and duplex
ethtool eth0   # Replace eth0 with actual interface name

# Look for:
# Speed: 1000Mb/s    (or expected speed)
# Duplex: Full        (Half duplex on modern networks = misconfiguration)
# Link detected: yes
```

**Resolution if link speed is degraded:**

1. Swap the cable - older or damaged Cat5 cable may not negotiate gigabit speeds
2. Try a different switch port if accessible
3. Confirm the NIC supports the expected speed (check device specifications)
4. If link speed remains degraded after cable and port swap, escalate to Tier 2 -
   possible switch port hardware fault or auto-negotiation conflict

---

## Step 4 - Wireless-Specific Performance Checks

If the affected connection is Wi-Fi, performance issues are frequently signal or
contention related rather than infrastructure faults.

```powershell
# Windows: Check signal strength and negotiated rate
netsh wlan show interfaces

# Key fields:
# Signal       : should be 70%+ for good performance
# Receive rate : compare against expected (e.g. 400+ Mbps on Wi-Fi 5/6)
# Transmit rate: should be similar to receive rate
# Channel      : note for congestion analysis
```

```bash
# Linux: Check signal and bitrate
nmcli device wifi list | head -5
iw dev wlan0 link

# Key fields:
# signal: should be above -65 dBm for good performance
# tx bitrate: compare against expected for the Wi-Fi standard in use
```

**Wireless performance fault table:**

| Observation | Likely Cause | Action |
|---|---|---|
| Signal good, rate low | Channel congestion or interference | Note channel; escalate for AP channel review |
| Signal poor, rate low | Distance or obstruction | Move closer to AP |
| Rate fluctuating significantly | Interference from other devices | Identify nearby interference sources |
| Good on 5GHz, poor on 2.4GHz | Expected - band capacity difference | Switch to 5GHz if available |
| Slow only at certain times of day | Network-wide congestion | Escalate - capacity planning issue |

For full wireless diagnosis refer to
[`../networking/wifi-diagnostic-guide.md`](../networking/wifi-diagnostic-guide.md).

---

## Step 5 - Local Device Resource Check

Network slowness is sometimes actually a local resource bottleneck masquerading as
a network problem - high CPU usage can delay packet processing, and a saturated disk
can make file transfers appear network-slow when the bottleneck is local storage.

```powershell
# Windows: Quick resource check
Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 2 -MaxSamples 3
Get-Counter '\Memory\Available MBytes'
Get-Counter '\Network Interface(*)\Bytes Total/sec' -SampleInterval 2 -MaxSamples 3

# Check for processes consuming high network bandwidth
Get-NetTCPConnection | Group-Object -Property OwningProcess |
    Sort-Object Count -Descending | Select-Object -First 10
```

```bash
# Linux: Quick resource check
top -bn1 | head -15
free -h

# Check network usage by process (requires nethogs if installed)
command -v nethogs &>/dev/null && sudo nethogs -t -c 5 || \
    echo "nethogs not installed - install with: sudo apt install nethogs"

# Check current network throughput per interface
cat /proc/net/dev
```

If local resource usage is high, refer to
[`high-cpu-memory-usage.md`](high-cpu-memory-usage.md) before continuing network-specific
diagnosis.

---

## Step 6 - Identify Bandwidth-Consuming Background Activity

A common and frequently overlooked cause of perceived slowness is background
applications consuming available bandwidth - cloud sync clients, automatic updates,
or backup software.

```powershell
# Windows: Identify processes with active network connections
Get-NetTCPConnection -State Established |
    Select-Object LocalAddress, RemoteAddress, RemotePort, OwningProcess |
    ForEach-Object {
        $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Process = $proc.ProcessName
            Remote  = $_.RemoteAddress
            Port    = $_.RemotePort
        }
    } | Sort-Object Process | Format-Table -AutoSize

# Common bandwidth consumers to check for:
# - OneDrive, Dropbox, Google Drive sync
# - Windows Update running in background
# - Backup software (Acronis, Veeam Agent, etc.)
# - Cloud-based antivirus scanning
```

```bash
# Linux: Identify active network connections by process
sudo ss -tupn | grep ESTAB

# Check for common bandwidth consumers
ps aux | grep -iE "rsync|backup|sync|update" | grep -v grep
```

**Common findings and actions:**

| Finding | Action |
|---|---|
| Cloud sync client actively uploading large folder | Pause sync temporarily; advise user on sync scheduling |
| Windows Update downloading in background | Allow to complete or schedule for off-hours |
| Backup job running during business hours | Escalate to Tier 2 - reschedule backup window |
| Antivirus performing full scan | Note timing; full scans should be scheduled off-hours |

---

## Step 7 - Traceroute and Hop Latency Analysis

If performance is poor specifically when reaching external destinations, identify
which hop in the path is introducing latency.

```powershell
# Windows
tracert 8.8.8.8
tracert google.com
```

```bash
# Linux
traceroute 8.8.8.8
mtr -r -c 20 8.8.8.8   # If mtr is installed - provides loss percentage per hop
```

**Reading hop latency for performance issues:**

```
Tracing route to 8.8.8.8:
  1     1 ms    1 ms    1 ms   192.168.1.1      ← Gateway: normal
  2     8 ms    9 ms    8 ms   10.0.0.1         ← ISP hop 1: normal
  3   145 ms  148 ms  142 ms   172.16.4.1       ← Latency spike here
  4   146 ms  150 ms  144 ms   74.125.50.149    ← Latency persists from hop 3 onward
  5   145 ms  147 ms  143 ms   8.8.8.8          ← Destination

Conclusion: Latency is introduced at hop 3, outside the local network.
This is an ISP or upstream routing issue - escalate, not a local fault.
```

If the latency spike occurs within the internal network (hops 1–2 in most SMB setups),
this indicates a local infrastructure fault - escalate to Tier 2 with the traceroute
output attached.

If the latency spike occurs at or after the ISP boundary, this is outside local control -
escalate to Tier 2 for ISP engagement, but do not continue extensive local troubleshooting.

---

## Step 8 - Compare Against a Known-Good Device

If available, test the same task on another device on the same network segment.

```
Same network, different device:

Slow on this device only, fast on another device on same network/switch port:
  → Device-specific fault (NIC, driver, local resource contention)
  → Return to Step 3 and Step 5

Slow on all devices on this network segment:
  → Shared infrastructure fault (switch, AP, uplink)
  → Escalate to Tier 2 with scope confirmed

Slow on all devices across the building:
  → WAN/ISP bandwidth saturation
  → Escalate to Tier 2 / Tier 3 - capacity or ISP issue
```

---

## Escalation Criteria

Escalate to Tier 2 when any of the following are confirmed:

- [ ] Link speed is degraded after cable and port swap (possible switch fault)
- [ ] Multiple users on the same segment report slowness simultaneously
- [ ] Traceroute shows latency introduced within the internal network
- [ ] Wireless signal and rate are good but throughput remains poor
  (possible AP capacity or backhaul issue)
- [ ] Slowness correlates with a known scheduled job (backup, replication) running
  during business hours
- [ ] Organisation-wide or site-wide slowness is reported

**Escalation package must include:**

- Baseline measurements (latency, packet loss, jitter) from Step 1
- Link speed and duplex results from Step 3
- Signal strength and negotiated rate (if wireless) from Step 4
- Traceroute output with hop latency noted from Step 7
- Comparison result against a known-good device if tested
- Scope confirmation (isolated, departmental, site-wide)

---

## Expected Results After Successful Resolution

```
Baseline comparison example:

BEFORE:
  Latency to gateway: 45ms (degraded)
  Packet loss: 6%
  Link speed: 100 Mbps (expected 1 Gbps)

AFTER (cable replaced):
  Latency to gateway: 1ms
  Packet loss: 0%
  Link speed: 1 Gbps

User confirms: file transfer that previously took 8 minutes now completes in 45 seconds.
```

---

## Common Fault Patterns and Quick Resolutions

| Symptom Pattern | Most Likely Cause | First Action |
|---|---|---|
| Slow only on this device, others fine | Bad cable or NIC fault | Swap cable; check link speed |
| Slow on Wi-Fi, fine on wired | Signal or channel congestion | Check signal strength, try 5GHz |
| Slow at specific times of day | Network or ISP congestion at peak hours | Document pattern; escalate for capacity review |
| Slow only to one external website | Destination-side issue, not local network | Test other sites to confirm; no local fix needed |
| Gradually worsening over weeks | Cumulative cable degradation or growing user count | Escalate - infrastructure review needed |
| Sudden slowness after software install | Background sync or update consuming bandwidth | Identify and pause/schedule the process |
| Slow file transfers, fine browsing | Possible local disk bottleneck, not network | Check disk health - see high-cpu-memory-usage.md |

---

## Verification Checklist

- [ ] Baseline measurement taken before changes
- [ ] Root cause identified and documented
- [ ] Resolution applied
- [ ] Post-fix measurement taken and compared against baseline
- [ ] User has independently confirmed improved performance for their specific task
- [ ] No new issues introduced (e.g. connectivity lost during driver/cable changes)
- [ ] If escalated, scope and findings clearly documented for Tier 2

---

## Security Considerations

- Unexpected high bandwidth usage by an unfamiliar process may indicate malware
  (data exfiltration, cryptomining, or botnet activity) - if a process consuming
  significant bandwidth cannot be identified as legitimate software, escalate as a
  potential security event rather than continuing standard performance troubleshooting
- Do not disable antivirus or security scanning to "test" performance without
  authorisation - this creates a security gap and the scan can usually be rescheduled instead
- Traceroute output reveals internal network structure - handle in line with the
  security guidance in [`../networking/connectivity-fault-isolation.md`](../networking/connectivity-fault-isolation.md)

---

## Related Documents

| Document | Relationship |
|---|---|
| [`../networking/network-troubleshooting-guide.md`](../networking/network-troubleshooting-guide.md) | OSI-layer foundation |
| [`../networking/wifi-diagnostic-guide.md`](../networking/wifi-diagnostic-guide.md) | Full wireless performance diagnosis |
| [`../networking/connectivity-fault-isolation.md`](../networking/connectivity-fault-isolation.md) | Traceroute and staged isolation detail |
| [`high-cpu-memory-usage.md`](high-cpu-memory-usage.md) | When local resources are the actual bottleneck |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Escalation criteria and package requirements |
| [`../scripts/windows/Test-ConnectivitySuite.ps1`](../scripts/windows/Test-ConnectivitySuite.ps1) | Automated latency and connectivity baseline |
| [`../scripts/linux/connectivity-suite.sh`](../scripts/linux/connectivity-suite.sh) | Automated latency and connectivity baseline |