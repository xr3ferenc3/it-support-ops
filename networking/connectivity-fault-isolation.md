# Connectivity Fault Isolation

## Purpose

This document provides extended connectivity fault isolation procedures for scenarios
where the standard Layer 1–7 diagnostic sequence in the network troubleshooting guide
has been completed without identifying the root cause, or where the fault pattern is
complex enough to require a more structured isolation approach.

Use this document when:
- The fault is intermittent and not reproducible on demand
- Multiple users are affected but the scope is not yet confirmed
- The fault is partial - some resources are reachable and others are not
- The standard diagnostic sequence has been completed without a clear result
- The fault involves a VPN, proxy, or remote access component

---

## When to Use This Document

This document extends [`network-troubleshooting-guide.md`](network-troubleshooting-guide.md).
Complete that guide's full diagnostic sequence first. Use this document when:

- Layers 1–3 are confirmed functional but the fault persists
- The fault is selective - affecting only certain destinations or protocols
- The fault affects multiple users simultaneously
- Traceroute results are ambiguous or show internal hops dropping
- The fault appeared after a network or infrastructure change

---

## Isolation Principle: Divide and Confirm

Connectivity fault isolation works by progressively narrowing the fault boundary.
At each stage, the goal is to confirm which side of a boundary the fault lives on -
not to fix it yet.

```
Full network path:
Device → Switch → Router → Firewall → ISP → Internet

Isolation sequence:
1. Confirm device is functional (loopback, local IP)
2. Confirm LAN segment is functional (gateway reachable)
3. Confirm internal routing is functional (other internal hosts reachable)
4. Confirm internet egress is functional (external IP reachable)
5. Confirm DNS is functional (name resolution working)
6. Confirm target service is reachable (specific port open)

Stop at the first stage that fails - that boundary contains the fault.
```

---

## Stage 1 - Device Self-Test

Confirm the device's own network stack is functioning before testing anything external.

Windows:
```powershell
# Test 1: Loopback - confirms TCP/IP stack is loaded and functional
ping 127.0.0.1 -n 4

# Test 2: Local IP - confirms NIC is responding to the OS
# Replace with the device's actual IP from ipconfig
ping 192.168.1.50 -n 4

# Test 3: Confirm adapter state
Get-NetAdapter | Select-Object Name, Status, LinkSpeed, MacAddress

# Test 4: Confirm IP configuration is complete
ipconfig /all | Select-String -Pattern "IPv4|Gateway|DNS|DHCP"
```

Linux:
```bash
# Test 1: Loopback
ping -c 4 127.0.0.1

# Test 2: Local IP - replace with actual IP from ip addr show
ping -c 4 192.168.1.50

# Test 3: Adapter state
ip link show
ip addr show

# Test 4: Routing table - confirm default route exists
ip route show
```

**Stage 1 pass criteria:**
- Loopback replies received
- Local IP replies received
- Adapter shows Status: Up with a valid link speed
- IP address present, not APIPA, default gateway listed

**Stage 1 failure:** If loopback fails, the TCP/IP stack is corrupted.

Windows TCP/IP stack reset (requires elevation):
```powershell
# Reset Winsock catalogue
netsh winsock reset

# Reset TCP/IP stack
netsh int ip reset

# Reset firewall to default (if suspected to be blocking loopback)
netsh advfirewall reset

# Reboot required after these commands
Restart-Computer -Force
```

Linux TCP/IP stack reset:
```bash
# Restart networking service
sudo systemctl restart NetworkManager

# If NetworkManager is not in use:
sudo systemctl restart networking

# Reload network interfaces
sudo ip link set lo down && sudo ip link set lo up
```

---

## Stage 2 - LAN Segment Confirmation

Confirm the device can communicate with its default gateway - the boundary between
the local segment and the rest of the network.

Windows:
```powershell
# Get the default gateway address
$gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0").NextHop
Write-Host "Default gateway: $gateway"

# Ping the gateway
ping $gateway -n 10

# Check for packet loss in the results
# 0% loss = LAN segment functional
# Any loss = potential LAN fault or gateway fault
```

Linux:
```bash
# Get the default gateway
GATEWAY=$(ip route show default | awk '{print $3}')
echo "Default gateway: $GATEWAY"

# Ping the gateway with 10 packets to detect intermittent loss
ping -c 10 "$GATEWAY"

# Check for packet loss in the summary line
# 0% packet loss = LAN segment functional
```

**Interpreting gateway ping results:**

| Result | Meaning | Next Step |
|---|---|---|
| 0% loss, <5ms | LAN segment healthy | Proceed to Stage 3 |
| 0% loss, >50ms | Gateway congested or faulty | Note latency, continue to Stage 3 |
| 10–50% loss | LAN instability or gateway fault | Escalate - infrastructure fault |
| 100% loss | Gateway unreachable | Check Layer 1/2; escalate if confirmed |

**Persistent gateway unreachability after confirming Layer 1 and 2:**

This is a Tier 2 escalation trigger. Before escalating, confirm:
```powershell
# Windows: Check ARP table - gateway MAC should be present
arp -a
# Look for the gateway IP with a resolved MAC address
# If listed as incomplete or absent: ARP failure - Layer 2 fault

# Attempt to force ARP resolution
ping $gateway
arp -a  # Check again after ping
```

```bash
# Linux: Check ARP/neighbour table
ip neigh show
# Gateway should appear with a MAC address and state REACHABLE or STALE
# If state is FAILED or absent after ping: Layer 2 fault
```

---

## Stage 3 - Internal Network Reachability

Confirm the device can reach other systems on the internal network beyond the gateway.
This isolates whether the fault is on the local LAN segment or further into the network.

```powershell
# Windows: Ping another known internal host
# Use a host that is confirmed online (file server, print server, another workstation)
ping 192.168.1.10 -n 4   # Replace with actual internal host IP

# Trace the path to an internal resource
tracert 192.168.1.10

# Test SMB access to a file server (if applicable)
Test-NetConnection -ComputerName fileserver.company.local -Port 445
```

```bash
# Linux: Ping another known internal host
ping -c 4 192.168.1.10   # Replace with actual internal host IP

# Trace the path to an internal resource
traceroute 192.168.1.10

# Test TCP connection to internal service
nc -zv fileserver.company.local 445
```

**Interpreting internal reachability results:**

| Gateway Reachable | Internal Host Reachable | Conclusion |
|---|---|---|
| Yes | Yes | LAN functional - fault is at Stage 4 or above |
| Yes | No | Routing fault beyond gateway, VLAN issue, or host fault |
| No | No | LAN segment or gateway fault - escalate |

---

## Stage 4 - Internet Egress Confirmation

Confirm the device can reach external IP addresses - bypassing DNS to isolate
whether the fault is routing or name resolution.

```powershell
# Windows: Ping external IPs directly (no DNS required)
ping 8.8.8.8 -n 4       # Google DNS
ping 1.1.1.1 -n 4       # Cloudflare DNS
ping 208.67.222.222 -n 4 # OpenDNS

# If all three fail: internet egress blocked or unavailable
# If one succeeds: routing is functional - DNS may be the fault
# If none succeed: firewall, ISP, or upstream routing fault
```

```bash
# Linux
ping -c 4 8.8.8.8
ping -c 4 1.1.1.1
ping -c 4 208.67.222.222
```

**Testing external TCP connectivity (confirms routing AND port access):**

```powershell
# Windows: Test HTTPS connectivity to an external host by IP
# This confirms port 443 is not blocked by the firewall
Test-NetConnection -ComputerName 8.8.8.8 -Port 443
Test-NetConnection -ComputerName 1.1.1.1 -Port 443
```

```bash
# Linux
nc -zv 8.8.8.8 443
nc -zv 1.1.1.1 443
```

**Stage 4 fault matrix:**

| Internal Reachable | External IP Reachable | Conclusion |
|---|---|---|
| Yes | Yes | Routing functional - fault is DNS or service-layer |
| Yes | No | Internet egress blocked - firewall or ISP fault |
| No | No | Internal routing fault - escalate |

---

## Stage 5 - DNS Confirmation

After confirming IP-level internet egress at Stage 4, confirm name resolution is functional.

```powershell
# Windows: Test external DNS resolution
nslookup google.com
nslookup microsoft.com

# Test internal DNS resolution (if applicable)
nslookup fileserver.company.local
nslookup intranet.company.local

# Test with alternative DNS server to isolate local DNS fault
nslookup google.com 8.8.8.8
nslookup google.com 1.1.1.1

# Flush DNS cache before retesting
ipconfig /flushdns
nslookup google.com
```

```bash
# Linux: Test external DNS resolution
dig google.com +short
dig microsoft.com +short

# Test with alternative DNS server
dig @8.8.8.8 google.com +short
dig @1.1.1.1 google.com +short

# Check configured DNS resolvers
cat /etc/resolv.conf
resolvectl status 2>/dev/null || systemd-resolve --status 2>/dev/null
```

For full DNS fault isolation refer to [`dns-dhcp-playbook.md`](dns-dhcp-playbook.md).

---

## Stage 6 - Service and Port Reachability

Confirm the specific service the user needs is reachable at the TCP/UDP port level.

```powershell
# Windows: Test reachability of specific services
# Web (HTTPS)
Test-NetConnection -ComputerName google.com -Port 443

# Email (IMAP)
Test-NetConnection -ComputerName mail.company.com -Port 993

# RDP
Test-NetConnection -ComputerName remoteserver.company.local -Port 3389

# File sharing (SMB)
Test-NetConnection -ComputerName fileserver.company.local -Port 445

# Active Directory (LDAP)
Test-NetConnection -ComputerName dc01.company.local -Port 389
```

```bash
# Linux: Test reachability of specific services
# Web
nc -zv google.com 443

# Email (IMAP)
nc -zv mail.company.com 993

# SSH
nc -zv remoteserver.company.local 22

# File sharing (SMB)
nc -zv fileserver.company.local 445

# Test with a timeout to prevent hanging
nc -zv -w 5 fileserver.company.local 445
```

**Stage 6 results:**

| Port Test Result | Conclusion |
|---|---|
| TcpTestSucceeded: True / Connection succeeded | Service reachable at network level - fault is application-layer |
| TcpTestSucceeded: False / Connection refused | Port blocked by firewall, or service not running on that port |
| Connection timed out | Host unreachable or port silently dropped by firewall |

---

## Traceroute Analysis

Traceroute identifies exactly where in the network path packets stop reaching their
destination. Use it after confirming Stage 2 (gateway reachable) when internet or
remote resources are unreachable.

Windows:
```powershell
# Trace to an external destination
tracert google.com

# Trace to an internal resource
tracert fileserver.company.local

# Increase hop limit for long paths
tracert -h 30 google.com
```

Linux:
```bash
# Trace to external destination
traceroute google.com

# Use ICMP instead of UDP (more likely to pass through firewalls)
traceroute -I google.com

# Use TCP traceroute on a specific port (most reliable through firewalls)
traceroute -T -p 443 google.com
```

**Reading traceroute output:**

```
tracert google.com

Tracing route to google.com [142.250.80.46]
over a maximum of 30 hops:

  1     1 ms    1 ms    1 ms   192.168.1.1        ← Default gateway (LAN)
  2     8 ms    9 ms    8 ms   10.0.0.1           ← ISP first hop
  3    12 ms   11 ms   12 ms   172.16.4.1         ← ISP internal routing
  4    15 ms   14 ms   15 ms   74.125.50.149      ← Google network
  5    14 ms   14 ms   14 ms   142.250.80.46      ← Destination reached
```

**Traceroute fault patterns:**

| Pattern | Meaning | Action |
|---|---|---|
| Stops at hop 1 (gateway) | Gateway or LAN fault | Escalate - infrastructure |
| Stops at hop 2–3 (ISP) | ISP routing fault | Escalate - ISP issue |
| `* * *` on all hops after a point | Firewall dropping ICMP | Try TCP traceroute |
| High latency spike at one hop | Congestion or fault at that router | Note the hop, escalate |
| Reaches destination but service fails | Network path is fine - service fault | Stage 6 port tests |

> **Note on `* * *` responses:** Routers that do not respond to ICMP TTL-exceeded messages
> show `* * *` in traceroute output. This does not always indicate a fault - many firewalls
> and routers are configured to drop these packets silently. If the traceroute reaches the
> destination despite intermediate `* * *` hops, the path is functional.

---

## Partial Connectivity Fault Isolation

Partial connectivity - where some resources are reachable and others are not - requires
a different isolation approach. The goal is to identify what the unreachable resources
have in common.

**Isolation questions:**

| Question | What It Isolates |
|---|---|
| Are all unreachable resources on the same subnet? | Routing fault for that subnet |
| Are all unreachable resources accessed by hostname? | DNS fault for those names |
| Are all unreachable resources on the same port? | Firewall rule for that port |
| Are all unreachable resources external? | Internet egress fault |
| Are all unreachable resources internal? | Internal routing or VLAN fault |
| Does the fault affect only this user or all users? | User/device fault vs. infrastructure |

**Partial connectivity test matrix:**

```powershell
# Windows: Systematic reachability test across multiple targets
$targets = @(
    @{Name="Gateway";      Address="192.168.1.1";  Port=$null},
    @{Name="DNS Server";   Address="192.168.1.1";  Port=53},
    @{Name="File Server";  Address="192.168.1.10"; Port=445},
    @{Name="Google DNS";   Address="8.8.8.8";      Port=$null},
    @{Name="Google HTTPS"; Address="google.com";   Port=443}
)

foreach ($target in $targets) {
    if ($target.Port) {
        $result = Test-NetConnection -ComputerName $target.Address `
                    -Port $target.Port -WarningAction SilentlyContinue
        $status = if ($result.TcpTestSucceeded) {"REACHABLE"} else {"UNREACHABLE"}
        Write-Host "$($target.Name) ($($target.Address):$($target.Port)): $status"
    } else {
        $ping = Test-Connection -ComputerName $target.Address `
                    -Count 2 -Quiet -ErrorAction SilentlyContinue
        $status = if ($ping) {"REACHABLE"} else {"UNREACHABLE"}
        Write-Host "$($target.Name) ($($target.Address)): $status"
    }
}
```

```bash
# Linux: Systematic reachability test
declare -A TARGETS=(
    ["Gateway"]="192.168.1.1"
    ["DNS_Server"]="192.168.1.1"
    ["File_Server"]="192.168.1.10"
    ["Google_DNS"]="8.8.8.8"
    ["Google"]="google.com"
)

echo "=== Connectivity Test: $(date) ==="
for NAME in "${!TARGETS[@]}"; do
    ADDRESS="${TARGETS[$NAME]}"
    if ping -c 2 -W 2 "$ADDRESS" &>/dev/null; then
        echo "$NAME ($ADDRESS): REACHABLE"
    else
        echo "$NAME ($ADDRESS): UNREACHABLE"
    fi
done
```

---

## VPN Connectivity Fault Isolation

VPN faults present as connectivity failures but require a different isolation path
because the VPN creates a virtual network interface with its own IP, routing, and DNS.

**Identify whether the fault is VPN-related:**
- Does the fault only occur when VPN is connected?
- Does disconnecting VPN restore connectivity to local resources?
- Does the fault affect resources only accessible via VPN?

**VPN connectivity test sequence:**

```powershell
# Windows: Check VPN adapter state
Get-NetAdapter | Where-Object {$_.InterfaceDescription -like "*VPN*" -or
                                $_.InterfaceDescription -like "*TAP*" -or
                                $_.InterfaceDescription -like "*tunnel*"}

# View routing table with VPN connected - look for routes added by VPN
route print

# Check if VPN has pushed a default route (split tunnel vs. full tunnel)
# Full tunnel: all traffic goes through VPN (0.0.0.0/0 route via VPN adapter)
# Split tunnel: only corporate traffic goes through VPN

# Test DNS with VPN connected
nslookup intranet.company.local    # Should resolve if VPN is working
nslookup google.com                # Should resolve regardless
```

```bash
# Linux: Check VPN interface
ip link show | grep -i "tun\|tap\|vpn\|wg"

# View routing with VPN connected
ip route show

# Check if VPN routes are present
ip route show table all | grep -v "^local\|^broadcast"

# Test DNS via VPN
dig intranet.company.local
dig google.com
```

**VPN fault escalation:** VPN faults almost always require Tier 2 access to the VPN
server or concentrator configuration. Document the fault isolation findings and escalate
with the VPN adapter state, routing table output, and DNS test results attached.

---

## Fault Isolation Summary and Escalation Package

When escalating after completing this isolation procedure, include:

```
CONNECTIVITY FAULT ISOLATION REPORT

Date/Time:          [timestamp]
Ticket Reference:   [number]
Affected User:      [name]
Device:             [hostname and OS]
Network Type:       [Wired / Wi-Fi / VPN]

STAGE RESULTS:
Stage 1 - Device Self-Test:       PASS / FAIL
Stage 2 - Gateway Reachability:   PASS / FAIL  (latency: X ms, loss: X%)
Stage 3 - Internal Reachability:  PASS / FAIL
Stage 4 - Internet Egress:        PASS / FAIL
Stage 5 - DNS Resolution:         PASS / FAIL
Stage 6 - Service Port Test:      PASS / FAIL  (port tested: XX)

FAULT BOUNDARY:
[State which stage first failed and what was observed]

TRACEROUTE SUMMARY:
[State where traceroute stopped or note if completed successfully]

PARTIAL CONNECTIVITY PATTERN:
[If applicable - list which resources are reachable and which are not]

ESCALATION REQUEST:
[State specifically what Tier 2 access or action is needed]
```

---

## Security Considerations

- Do not run port scans against systems you are not authorised to test - `Test-NetConnection`
  and `nc` probe specific ports and generate connection log entries on the target
- Traceroute reveals internal network topology - do not share traceroute output outside
  the IT team or attach it to tickets accessible to non-IT staff
- VPN routing table output may reveal internal subnet ranges - handle accordingly
- If a traceroute reveals unexpected hops within the internal network (unknown IP addresses
  between known infrastructure), escalate as a potential security concern

---

## Related Documents

| Document | Relationship |
|---|---|
| [`network-troubleshooting-guide.md`](network-troubleshooting-guide.md) | Foundation - complete before using this document |
| [`dns-dhcp-playbook.md`](dns-dhcp-playbook.md) | Stage 5 DNS fault procedures |
| [`wifi-diagnostic-guide.md`](wifi-diagnostic-guide.md) | Wireless-specific Stage 1–2 procedures |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Escalation package requirements |
| [`../scripts/windows/Test-ConnectivitySuite.ps1`](../scripts/windows/Test-ConnectivitySuite.ps1) | Automates Stages 1–5 on Windows |
| [`../scripts/linux/connectivity-suite.sh`](../scripts/linux/connectivity-suite.sh) | Automates Stages 1–5 on Linux |
| [`../templates/diagnostic-report-template.md`](../templates/diagnostic-report-template.md) | Format for attaching isolation results to ticket |