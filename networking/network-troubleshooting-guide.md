# Network Troubleshooting Guide

## Purpose

This guide defines how to systematically isolate and identify network faults in SMB
environments. It applies OSI model layer-by-layer thinking to real help desk scenarios -
moving from physical layer checks through to application-layer reachability in a defined
sequence that eliminates guesswork and prevents skipping steps that matter.

Every network fault - regardless of how it is reported - has a location in the OSI stack.
Finding that location efficiently is what this guide is designed to do.

---

## When to Use This Guide

Use this guide as the starting point for any ticket where the reported symptom involves:

- Complete loss of network connectivity
- Inability to reach specific resources (shared drives, intranet, internet)
- Intermittent connectivity or unexplained disconnections
- Slow network performance
- DNS resolution failures
- DHCP address assignment failures
- Wi-Fi connectivity problems
- VPN connectivity failures
- Printer or shared resource unreachable over the network

Do not use this guide to diagnose application-layer faults unrelated to network reachability.
If the network is confirmed functional and the application still fails, refer to
[`../playbooks/application-not-launching.md`](../playbooks/application-not-launching.md).

---

## Foundation: The OSI Model in Help Desk Context

The OSI model is the diagnostic framework for every network fault. Each layer depends on the
layer below it functioning correctly. A fault at Layer 2 cannot be fixed by reconfiguring
Layer 4. Always verify lower layers before investigating higher ones.

> **Book reference:** CompTIA Network+ Guide to Networks (10th Ed.) covers the OSI model in
> Chapter 1. The layer sequence below maps that theory to the diagnostic commands and checks
> a help desk technician uses in practice.

| Layer | Name | What It Covers | Diagnostic Focus |
|---|---|---|---|
| 1 | Physical | Cables, ports, NICs, link lights | Cable seated? Link light on? NIC detected? |
| 2 | Data Link | MAC addressing, switching, VLANs | Switch port active? Correct VLAN? No MAC conflict? |
| 3 | Network | IP addressing, routing, subnetting | Valid IP? Correct subnet? Gateway reachable? |
| 4 | Transport | TCP/UDP port communication | Correct ports open? Firewall blocking? |
| 5 | Session | Session establishment and teardown | Authentication succeeding? Session timing out? |
| 6 | Presentation | Data encoding, encryption | TLS/SSL certificate valid? Encoding mismatch? |
| 7 | Application | End-user services and protocols | DNS resolving? Service running? App reachable? |

**The rule:** Confirm each layer is functional before moving to the layer above.
If Layer 3 (IP) is not working, do not investigate Layer 7 (application). Fix the lower
layer first.

---

## Pre-Diagnosis: Establish Scope Before Starting

Before running a single command, answer these questions from the ticket intake:

| Question | Why It Matters |
|---|---|
| Is this one user or many? | One user → likely endpoint fault. Many → likely infrastructure fault |
| Is this one application or all network access? | One app → likely Layer 7. All access → likely Layer 1–3 |
| Is this wired or wireless? | Determines physical layer checks |
| When did it start? | Change correlation - what changed before the fault appeared? |
| Has it worked before on this device? | New device setup vs. regression fault |
| Can the user reach anything at all? | Complete loss vs. partial loss narrows the layer |

**Scope rule:** If more than one user reports the same fault simultaneously, stop individual
diagnosis and refer to [`../incidents/incident-classification-guide.md`](../incidents/incident-classification-guide.md).
A widespread fault is an infrastructure fault, not a user endpoint fault.

---

## Layer 1 - Physical Layer Checks

**What you are confirming:** The physical connection between the device and the network
exists and is active.

**Why this layer first:** More network faults than technicians expect are physical. A cable
that looks connected is not always connected. A port that looks active is not always active.
Eliminating physical causes takes under two minutes and prevents hours of unnecessary
software diagnosis.

### Wired Connection Checks

**Step 1 - Check the cable**

- Confirm the cable is fully seated at both the device end and the wall port or switch end
- A click should be felt and heard when a correctly seated RJ-45 connector is inserted
- Check for visible damage: bent pins, cracked housing, sharp bends in the cable run
- Swap the cable for a known-good cable if any doubt exists - cables are the most common
  physical fault and the cheapest to test

**Step 2 - Check link lights**

- The NIC port on the device should show a link light (usually green or amber) when
  physically connected to an active switch port
- No link light = no physical connection. This is Layer 1, not a software problem.
- The switch port should also show a link light - check both ends if accessible

**Step 3 - Check the NIC**

Windows:
```powershell
# Check adapter status
Get-NetAdapter | Select-Object Name, Status, LinkSpeed, MediaType

# Expected output for a healthy wired connection:
# Name       Status   LinkSpeed  MediaType
# Ethernet   Up       1 Gbps     802.3
```

Linux:
```bash
# Check interface state
ip link show

# Expected output for a healthy wired interface:
# 2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
# UP and LOWER_UP both present = physically connected and active
```

**Layer 1 fault indicators:**

| Observation | Likely Cause |
|---|---|
| No link light on NIC | Cable fault, switch port fault, or NIC fault |
| Link light present but connection fails | Layer 2 or Layer 3 fault - proceed upward |
| NIC shown as disabled in OS | Adapter disabled in Device Manager or OS settings |
| NIC not detected | Driver fault or hardware fault |

### Wireless Connection Checks

- Confirm Wi-Fi is enabled (hardware switch, function key, or OS toggle)
- Confirm the device can see the correct SSID in the available network list
- If the SSID is not visible: signal issue, SSID broadcasting disabled, or band mismatch
- For full Wi-Fi fault diagnosis refer to [`wifi-diagnostic-guide.md`](wifi-diagnostic-guide.md)

---

## Layer 2 - Data Link Layer Checks

**What you are confirming:** The device is communicating correctly at the switch level -
it has a valid MAC address, is on the correct VLAN, and the switch port is active.

**Note on Tier 1 access:** Tier 1 technicians typically cannot access switch management
interfaces. Layer 2 checks at Tier 1 focus on the device side. If a switch-side fault
is suspected, escalate to Tier 2 with Layer 1 confirmed and Layer 2 suspected.

### Device-Side Layer 2 Checks

**Check the MAC address is present and valid:**

Windows:
```powershell
# View MAC address for all adapters
Get-NetAdapter | Select-Object Name, MacAddress, Status

# A valid MAC address is six pairs of hex digits: 00-1A-2B-3C-4D-5E
# All zeros (00-00-00-00-00-00) indicates a driver or hardware fault
```

Linux:
```bash
# View MAC address
ip link show

# Look for: link/ether xx:xx:xx:xx:xx:xx
# All zeros indicates a driver or hardware fault
```

**Check for duplicate IP or ARP conflict:**

Windows:
```powershell
# View ARP cache - look for duplicate IP entries with different MACs
arp -a
```

Linux:
```bash
# View ARP table
arp -n
# or
ip neigh show
```

**Layer 2 fault indicators:**

| Observation | Likely Cause | Action |
|---|---|---|
| Valid MAC, link light present, no IP | DHCP fault (Layer 3) | Proceed to Layer 3 |
| No MAC visible | Driver not loaded or NIC hardware fault | Reinstall driver or replace NIC |
| Duplicate MAC or ARP conflict | IP conflict on the network | Escalate to Tier 2 |
| Connection drops after a few seconds | Switch port security or 802.1X authentication | Escalate to Tier 2 |

---

## Layer 3 - Network Layer Checks

**What you are confirming:** The device has a valid IP address, correct subnet mask,
and a reachable default gateway. This is the most common fault layer for help desk tickets.

### IP Address Verification

Windows:
```powershell
# Full IP configuration
ipconfig /all

# What to look for:
# IPv4 Address: should match the expected network range (e.g. 192.168.1.x)
# Subnet Mask:  should match network policy (e.g. 255.255.255.0)
# Default Gateway: should be present and non-zero
# DHCP Enabled: Yes (for most user workstations)
# Lease Obtained / Lease Expires: should be current dates
```

Linux:
```bash
# IP address and subnet
ip addr show

# Default gateway
ip route show
# Look for: default via x.x.x.x dev <interface>
```

**APIPA Detection - Critical Check:**

An IPv4 address in the range `169.254.0.1` – `169.254.255.254` is an APIPA (Automatic
Private IP Addressing) address. This means the device attempted DHCP and received no response.

> **Book reference:** CompTIA A+ Guide to IT Technical Support (11th Ed.) covers APIPA in
> the context of TCP/IP configuration. APIPA addresses are assigned by the OS when DHCP
> fails - they allow local subnet communication only and cannot reach a gateway or
> internet resources.

An APIPA address means:
- The device cannot reach the DHCP server
- The device cannot reach the default gateway
- The device cannot reach internet resources
- All Layer 4–7 diagnosis is pointless until this is resolved

**DHCP Release and Renew:**

Windows:
```powershell
# Release the current lease
ipconfig /release

# Request a new lease
ipconfig /renew

# Verify the result
ipconfig /all
```

Linux:
```bash
# For DHCP-managed interfaces (using dhclient)
sudo dhclient -r <interface>   # Release
sudo dhclient <interface>      # Renew

# For NetworkManager-managed interfaces
nmcli connection down <connection-name>
nmcli connection up <connection-name>
```

### Gateway Reachability Test

```powershell
# Windows - ping the default gateway
# Replace 192.168.1.1 with the actual gateway address from ipconfig
ping 192.168.1.1

# Expected result: 4 replies with <10ms latency on a LAN
# No reply = gateway unreachable = routing or physical fault at the infrastructure level
```

```bash
# Linux - ping the default gateway
# Replace 192.168.1.1 with the actual gateway from ip route show
ping -c 4 192.168.1.1
```

**Layer 3 fault indicators:**

| Observation | Likely Cause | Action |
|---|---|---|
| APIPA address (169.254.x.x) | DHCP server unreachable | Attempt DHCP renew; if fails, escalate |
| Valid IP, gateway unreachable | Routing fault or gateway down | Escalate to Tier 2 |
| Valid IP, gateway reachable, internet fails | DNS fault (Layer 7) or upstream routing | Proceed to Layer 7 DNS check |
| IP address in wrong subnet | DHCP misconfiguration or static IP conflict | Check static IP settings; escalate |
| No default gateway listed | DHCP fault or static config error | Check configuration; attempt renew |

---

## Layer 4 - Transport Layer Checks

**What you are confirming:** The specific TCP or UDP ports required by the service are
reachable and not blocked by a firewall or security policy.

**When to check Layer 4:** Only after Layers 1–3 are confirmed functional.
Layer 4 checks are relevant when: the gateway is reachable but a specific service is not,
or when one application fails while others on the same network work correctly.

### Port Reachability Test

Windows (PowerShell):
```powershell
# Test if a specific TCP port is reachable
# Example: Test HTTPS (port 443) to a web server
Test-NetConnection -ComputerName example.com -Port 443

# Expected output for open port:
# TcpTestSucceeded: True

# Expected output for blocked port:
# TcpTestSucceeded: False
```

Linux:
```bash
# Test port reachability using nc (netcat)
nc -zv example.com 443

# Alternative using curl for HTTP/HTTPS
curl -v --connect-timeout 5 https://example.com

# Check which ports are currently listening locally
ss -tuln
```

**Common ports reference:**

| Port | Protocol | Service |
|---|---|---|
| 80 | TCP | HTTP |
| 443 | TCP | HTTPS |
| 53 | UDP/TCP | DNS |
| 25 | TCP | SMTP (email sending) |
| 587 | TCP | SMTP (authenticated submission) |
| 110 | TCP | POP3 |
| 143 | TCP | IMAP |
| 3389 | TCP | RDP (Remote Desktop) |
| 445 | TCP | SMB (file sharing) |
| 389 | TCP | LDAP (Active Directory) |
| 636 | TCP | LDAPS (Active Directory secure) |

For full port and protocol reference see [`../reference/network-ports-protocols.md`](../reference/network-ports-protocols.md).

---

## Layer 7 - Application Layer Checks (DNS Focus)

**What you are confirming:** DNS is resolving names to IP addresses correctly, and the
target service is reachable by name.

DNS is the most common Layer 7 fault in help desk environments. A device with a valid IP,
reachable gateway, and open ports will still fail to reach internet or intranet resources
if DNS is broken.

> **Book reference:** CompTIA Network+ Guide to Networks (10th Ed.) covers DNS in detail.
> The practical diagnostic commands below extend the book's conceptual coverage.

### DNS Resolution Test

Windows:
```powershell
# Test DNS resolution
nslookup google.com

# Expected output:
# Server:   192.168.1.1 (or your DNS server)
# Address:  192.168.1.1#53
# Non-authoritative answer:
# Name:    google.com
# Address: 142.250.x.x

# Test with a specific DNS server
nslookup google.com 8.8.8.8

# Flush DNS cache (clears stale or corrupt cached entries)
ipconfig /flushdns
```

Linux:
```bash
# Test DNS resolution
dig google.com

# Simple resolution check
nslookup google.com

# Test with a specific DNS server
dig @8.8.8.8 google.com

# Check which DNS servers are configured
cat /etc/resolv.conf
```

**DNS fault diagnosis sequence:**

```
Can the device ping its gateway by IP?
          │
    No ───► Layer 3 fault - resolve before DNS diagnosis
          │
    Yes   ▼
Can the device ping 8.8.8.8 (Google DNS) by IP?
          │
    No ───► Upstream routing fault - escalate
          │
    Yes   ▼
Does nslookup google.com return an IP address?
          │
    No ───► DNS fault confirmed
          │   ├── Check DNS server address in ipconfig /all
          │   ├── Try nslookup google.com 8.8.8.8 (bypass local DNS)
          │   ├── If 8.8.8.8 works: local DNS server fault - escalate
          │   └── If 8.8.8.8 fails: upstream DNS or firewall - escalate
          │
    Yes   ▼
Can the device reach the service by name (e.g. browser loads a page)?
          │
    No ───► Application or proxy fault - check browser/proxy settings
          │
    Yes   ▼
DNS and network confirmed functional - fault is application-layer or service-side
```

For full DNS and DHCP fault procedures refer to [`dns-dhcp-playbook.md`](dns-dhcp-playbook.md).

---

## Connectivity Testing - Full Sequence

Use this command sequence when performing a complete connectivity diagnosis.
Run in order. Stop at the first failure - that layer is where the fault lives.

### Windows - Full Connectivity Test Sequence

```powershell
# Step 1: Confirm IP address and DHCP state
ipconfig /all

# Step 2: Ping loopback (confirms TCP/IP stack is functional)
ping 127.0.0.1

# Step 3: Ping own IP (confirms NIC is responding)
# Replace with actual IP from ipconfig
ping 192.168.1.50

# Step 4: Ping default gateway (confirms Layer 3 routing)
# Replace with actual gateway from ipconfig
ping 192.168.1.1

# Step 5: Ping external IP (confirms internet routing - bypasses DNS)
ping 8.8.8.8

# Step 6: Test DNS resolution
nslookup google.com

# Step 7: Ping external hostname (confirms DNS + internet routing)
ping google.com

# Step 8: Trace route to identify where packets stop
tracert google.com
```

### Linux - Full Connectivity Test Sequence

```bash
# Step 1: Confirm IP address and interface state
ip addr show && ip route show

# Step 2: Ping loopback
ping -c 4 127.0.0.1

# Step 3: Ping own IP
# Replace with actual IP from ip addr show
ping -c 4 192.168.1.50

# Step 4: Ping default gateway
# Replace with actual gateway from ip route show
ping -c 4 192.168.1.1

# Step 5: Ping external IP
ping -c 4 8.8.8.8

# Step 6: Test DNS resolution
dig google.com +short

# Step 7: Ping external hostname
ping -c 4 google.com

# Step 8: Trace route
traceroute google.com
```

**Reading traceroute output:**

- Each line is one hop (one router) between the device and the destination
- Three time values per hop are the round-trip times for three test packets
- `* * *` means the router at that hop did not respond - not necessarily a fault
- The hop where responses stop is the location of the fault or blockage

---

## Interpreting Results and Next Steps

| Test Result | Layer | Diagnosis | Next Step |
|---|---|---|---|
| No link light, NIC not detected | Layer 1 | Physical fault | Swap cable, check port, replace NIC |
| Link light, no IP address | Layer 2/3 | DHCP or switch fault | Release/renew, check switch port |
| APIPA address (169.254.x.x) | Layer 3 | DHCP server unreachable | Release/renew, escalate if persists |
| Valid IP, gateway unreachable | Layer 3 | Routing or gateway fault | Escalate to Tier 2 |
| Gateway reachable, 8.8.8.8 unreachable | Layer 3/4 | Upstream routing or firewall | Escalate to Tier 2 |
| 8.8.8.8 reachable, DNS fails | Layer 7 | DNS server fault | Flush DNS, check DNS server, escalate |
| DNS resolves, service unreachable | Layer 4/7 | Port blocked or service down | Port test, check service status |
| All tests pass, application fails | Layer 7 | Application or proxy fault | Application-layer diagnosis |

---

## When to Escalate

Escalate to Tier 2 when any of the following are confirmed:

- Default gateway is unreachable after confirming Layer 1 and 2 are functional
- DHCP renew fails to obtain an address after two attempts
- DNS fault persists after flushing cache and testing with an alternative DNS server
- The fault affects more than one user on the same network segment
- Switch port, VLAN, or wireless infrastructure involvement is suspected
- The traceroute stops within the internal network (before the ISP boundary)

Include the full Layer 1–7 test sequence results in the escalation package.
Refer to [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md).

---

## Network Troubleshooting Quick Reference

```
Layer 1 - Physical
  Windows: Get-NetAdapter | Select Name, Status, LinkSpeed
  Linux:   ip link show
  Manual:  Check cable, link lights, port seating

Layer 2 - Data Link
  Windows: Get-NetAdapter | Select Name, MacAddress
           arp -a
  Linux:   ip link show | grep ether
           ip neigh show

Layer 3 - Network
  Windows: ipconfig /all
           ping <gateway>
           ipconfig /release && ipconfig /renew
  Linux:   ip addr show && ip route show
           ping -c 4 <gateway>
           dhclient -r && dhclient <interface>

Layer 4 - Transport
  Windows: Test-NetConnection -ComputerName <host> -Port <port>
  Linux:   nc -zv <host> <port>
           ss -tuln

Layer 7 - Application (DNS)
  Windows: nslookup <hostname>
           ipconfig /flushdns
  Linux:   dig <hostname>
           cat /etc/resolv.conf
```

---

## Security Considerations

- Do not run traceroute or port scans against systems you do not have authorisation to test
- Do not change DNS server settings on shared infrastructure without Tier 2 approval
- DHCP release/renew on a server or shared device affects all users - confirm before running
- If a device is suspected of being compromised, do not run standard network diagnostics -
  isolate and escalate per security event procedures in
  [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md)

---

## Related Documents

| Document | Relationship |
|---|---|
| [`dns-dhcp-playbook.md`](dns-dhcp-playbook.md) | Detailed DNS and DHCP fault procedures |
| [`wifi-diagnostic-guide.md`](wifi-diagnostic-guide.md) | Wireless-specific Layer 1–3 diagnosis |
| [`connectivity-fault-isolation.md`](connectivity-fault-isolation.md) | Extended connectivity fault workflows |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Escalation criteria and package requirements |
| [`../scripts/windows/Get-NetworkDiagnostics.ps1`](../scripts/windows/Get-NetworkDiagnostics.ps1) | Automated Windows network diagnostic collector |
| [`../scripts/linux/network-diagnostics.sh`](../scripts/linux/network-diagnostics.sh) | Automated Linux network diagnostic collector |
| [`../reference/network-ports-protocols.md`](../reference/network-ports-protocols.md) | Common ports and protocols reference |