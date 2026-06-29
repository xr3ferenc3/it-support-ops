# DNS and DHCP Fault Playbook

## Purpose

This playbook provides step-by-step diagnostic and resolution procedures for the two most
common network service failures in SMB environments: DNS resolution failures and DHCP
address assignment failures.

DNS and DHCP are invisible to users until they break. When they break, the reported symptom
is almost always "the internet is down" or "I can't access anything" - which means the
technician must recognise the service-layer fault behind the surface complaint and follow
a structured path to confirm and resolve it.

---

## When to Use This Playbook

Use this playbook when any of the following are reported or observed:

**DNS indicators:**
- User cannot reach websites or internal resources by name
- Browser displays "DNS_PROBE_FINISHED_NXDOMAIN" or "Server not found"
- `ping google.com` fails but `ping 8.8.8.8` succeeds
- `nslookup` returns a timeout or "server failed" response
- Specific internal resources unreachable by hostname while IP access works

**DHCP indicators:**
- Device has an APIPA address (169.254.x.x)
- `ipconfig /all` shows no default gateway
- Device shows IP address of `0.0.0.0`
- User cannot reach anything on the network after returning from travel or sleep
- Multiple users simultaneously reporting loss of connectivity (potential DHCP scope exhaustion)

---

## Background: How DNS and DHCP Work

> **Book reference - DNS:** CompTIA Network+ Guide to Networks (10th Ed.) covers DNS
> hierarchy, record types, and resolution sequence. The practical fault procedures below
> apply that theory to real diagnosis.

> **Book reference - DHCP:** CompTIA Network+ Guide to Networks (10th Ed.) covers the
> DHCP DORA process (Discover, Offer, Request, Acknowledge). Understanding DORA explains
> why a failed DHCP lease produces an APIPA address and why release/renew is the correct
> first response.

### DNS Resolution in Brief

When a user types `intranet.company.local` into a browser:

```
1. Browser checks local DNS cache
         │
         ▼
2. OS checks hosts file (/etc/hosts or C:\Windows\System32\drivers\etc\hosts)
         │
         ▼
3. OS queries configured DNS server (from DHCP or static config)
         │
         ▼
4. DNS server resolves the name (from its own cache or upstream query)
         │
         ▼
5. IP address returned to OS → connection attempted
```

A fault at any stage produces a DNS resolution failure. The diagnostic goal is to identify
which stage is failing.

### DHCP Lease Process in Brief

```
Client: DHCPDISCOVER  →  broadcast to 255.255.255.255
Server: DHCPOFFER     →  "I can give you 192.168.1.50 for 8 hours"
Client: DHCPREQUEST   →  "I'll take 192.168.1.50"
Server: DHCPACK       →  "Confirmed - lease granted"
```

If the DHCPDISCOVER reaches no server (server down, network fault, scope exhausted),
the client assigns itself an APIPA address and retries in the background every few minutes.

---

## Part 1 - DNS Fault Diagnosis and Resolution

### Phase 1: Confirm the DNS Fault

**Test 1 - Ping by IP vs. ping by name:**

Windows:
```powershell
# Ping an external IP directly (bypasses DNS entirely)
ping 8.8.8.8

# Ping by hostname (requires DNS)
ping google.com
```

Linux:
```bash
ping -c 4 8.8.8.8
ping -c 4 google.com
```

**Interpreting the result:**

| 8.8.8.8 result | google.com result | Conclusion |
|---|---|---|
| Replies received | Replies received | DNS working - fault is application-layer |
| Replies received | Request timed out / fails | DNS fault confirmed |
| Request timed out | Request timed out | Layer 3 routing fault - not DNS |
| Request timed out | Request timed out | Check gateway first - see network-troubleshooting-guide.md |

**Test 2 - Direct DNS query:**

Windows:
```powershell
# Query using the system's configured DNS server
nslookup google.com

# Query using a specific DNS server (bypasses local DNS server)
nslookup google.com 8.8.8.8

# Query an internal resource
nslookup intranet.company.local

# View currently configured DNS servers
ipconfig /all | findstr "DNS Servers"
```

Linux:
```bash
# Query using the system's configured DNS server
dig google.com

# Short output only
dig google.com +short

# Query using a specific DNS server
dig @8.8.8.8 google.com

# Query an internal resource
dig intranet.company.local

# View configured DNS servers
cat /etc/resolv.conf
```

**Reading nslookup output:**

```
# Healthy response:
Server:   192.168.1.1        ← DNS server being queried
Address:  192.168.1.1#53

Non-authoritative answer:
Name:    google.com
Address: 142.250.80.46       ← IP address returned - resolution succeeded

# Failed response:
Server:   192.168.1.1
Address:  192.168.1.1#53
** server can't find google.com: SERVFAIL   ← DNS server contacted but cannot resolve
```

---

### Phase 2: Isolate the DNS Fault Location

```
DNS fault confirmed (8.8.8.8 reachable, name resolution failing)
                    │
                    ▼
       nslookup google.com 8.8.8.8
       (bypass local DNS, query Google directly)
                    │
          ┌─────────┴─────────┐
        Fails               Succeeds
          │                   │
          ▼                   ▼
   Upstream routing    Local DNS server fault
   or firewall         ├── DNS server down
   blocking port 53    ├── DNS server misconfigured
   → Escalate          ├── DHCP pushed wrong DNS address
                       └── Proceed to Phase 3
```

### Phase 3: Resolve DNS Faults at Tier 1

**Resolution 1 - Flush the DNS cache**

Stale or corrupt cache entries cause resolution failures for specific names while others
work correctly.

Windows:
```powershell
# Flush DNS resolver cache
ipconfig /flushdns

# Verify cache is cleared
ipconfig /displaydns

# Re-test resolution after flush
nslookup google.com
```

Linux:
```bash
# Flush DNS cache - method depends on the DNS caching service running

# systemd-resolved (Ubuntu 18.04+, Debian 10+)
sudo systemd-resolve --flush-caches
sudo systemd-resolve --statistics  # Verify cache size dropped to 0

# nscd (older distributions)
sudo systemctl restart nscd

# dnsmasq
sudo systemctl restart dnsmasq
```

**When to flush:** Cache flush resolves issues where a specific name stopped resolving
after working previously, or where a server IP address changed and the old entry is cached.

---

**Resolution 2 - Check and correct the DNS server address**

Windows:
```powershell
# View current DNS server configuration
ipconfig /all

# If DNS server address is incorrect or missing:
# Option A - Release and renew DHCP (if DHCP-managed)
ipconfig /release
ipconfig /renew
ipconfig /all  # Verify DNS server address is now correct

# Option B - Set DNS server manually (if static IP)
# Run in elevated PowerShell
$adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex `
    -ServerAddresses ("192.168.1.1","8.8.8.8")

# Verify
Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex
```

Linux:
```bash
# View current DNS configuration
cat /etc/resolv.conf

# For NetworkManager-managed systems - view connection DNS settings
nmcli connection show <connection-name> | grep dns

# Set DNS server via NetworkManager
nmcli connection modify <connection-name> ipv4.dns "192.168.1.1 8.8.8.8"
nmcli connection up <connection-name>

# Verify
resolvectl status   # systemd-resolved systems
cat /etc/resolv.conf
```

---

**Resolution 3 - Check the hosts file**

The hosts file is checked before DNS. An incorrect entry here overrides DNS for that name.

Windows:
```powershell
# View the hosts file
Get-Content "C:\Windows\System32\drivers\etc\hosts"

# Look for entries that should not be there:
# - Entries pointing internal names to wrong IPs
# - Entries added by malware redirecting common sites
# - Duplicate entries for the same hostname

# Edit the hosts file (requires elevation)
# Open Notepad as administrator, then open the file above
# Remove incorrect entries and save
```

Linux:
```bash
# View the hosts file
cat /etc/hosts

# Edit if required (requires sudo)
sudo nano /etc/hosts

# After editing, flush DNS cache to apply changes
sudo systemd-resolve --flush-caches
```

---

**Resolution 4 - Test with an alternative DNS server temporarily**

If the configured DNS server is confirmed faulty and Tier 2 is not immediately available,
a temporary workaround is to point the device at a known-good public DNS server.

> **Important:** This is a temporary workaround only. It bypasses the internal DNS server,
> which means internal resources (intranet sites, file servers by name, printers by hostname)
> will not resolve. Document this workaround in the ticket and escalate.

Windows (temporary manual DNS - requires elevation):
```powershell
$adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex `
    -ServerAddresses ("8.8.8.8","1.1.1.1")

# Test
nslookup google.com

# DOCUMENT IN TICKET: Manual DNS set to 8.8.8.8 as workaround.
# Internal DNS server fault. Ticket escalated to Tier 2.
# Revert to DHCP-assigned DNS when server is restored: ipconfig /release && ipconfig /renew
```

Linux:
```bash
# Temporary override (reverts on network restart)
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# Test
dig google.com +short

# Note: On NetworkManager systems this file may be overwritten automatically
# Use nmcli to make persistent changes if needed
```

---

### DNS Escalation Criteria

Escalate to Tier 2 when:

- DNS fault persists after cache flush and DNS server address is confirmed correct
- `nslookup google.com 8.8.8.8` also fails (port 53 may be blocked - firewall issue)
- Multiple users on the same network have DNS failures simultaneously
- Internal DNS server is confirmed unreachable
- DNS server address received via DHCP is incorrect (DHCP server misconfiguration)

---

## Part 2 - DHCP Fault Diagnosis and Resolution

### Phase 1: Confirm the DHCP Fault

**Test 1 - Identify the IP address type:**

Windows:
```powershell
ipconfig /all

# DHCP fault indicators in output:
# IPv4 Address: 169.254.x.x         ← APIPA - DHCP failed
# IPv4 Address: 0.0.0.0             ← No address assigned
# DHCP Enabled: No                  ← Static IP - DHCP not in use (may be intentional)
# Lease Expires: date in the past   ← Lease expired and not renewed
# Default Gateway: (blank)          ← No gateway - DHCP likely failed
```

Linux:
```bash
ip addr show

# DHCP fault indicators:
# inet 169.254.x.x/16              ← APIPA equivalent (link-local address)
# No inet line for the interface   ← No address assigned at all

ip route show
# No default route line            ← No gateway - DHCP likely failed
```

**Test 2 - Check DHCP lease status:**

Windows:
```powershell
# View full DHCP lease information
ipconfig /all | Select-String -Pattern "DHCP|Lease|Gateway|DNS"

# Check DHCP client service is running
Get-Service -Name Dhcp | Select-Object Name, Status, StartType
```

Linux:
```bash
# View DHCP lease file (path varies by DHCP client)
# dhclient:
cat /var/lib/dhclient/dhclient.leases 2>/dev/null || \
cat /var/lib/dhcp/dhclient.leases 2>/dev/null

# NetworkManager lease:
ls /var/lib/NetworkManager/
```

---

### Phase 2: Attempt DHCP Lease Renewal

This is the correct first action for any confirmed APIPA or missing-IP condition.

Windows:
```powershell
# Step 1: Release the current (failed) lease
ipconfig /release

# Step 2: Wait 5 seconds
Start-Sleep -Seconds 5

# Step 3: Request a new lease
ipconfig /renew

# Step 4: Verify the result
ipconfig /all

# Expected result after successful renewal:
# IPv4 Address: 192.168.x.x (in the expected network range)
# Default Gateway: 192.168.x.1 (or site gateway)
# DHCP Server: should show the DHCP server's IP address
# Lease Obtained: today's date and time
```

Linux:
```bash
# Method 1: dhclient
INTERFACE="eth0"  # Replace with actual interface name from ip link show

sudo dhclient -r "$INTERFACE"    # Release
sleep 3
sudo dhclient "$INTERFACE"       # Request new lease

# Verify
ip addr show "$INTERFACE"
ip route show

# Method 2: NetworkManager
CONNECTION=$(nmcli -t -f NAME connection show --active | head -1)
nmcli connection down "$CONNECTION"
sleep 3
nmcli connection up "$CONNECTION"

# Verify
nmcli connection show "$CONNECTION" | grep -E "IP4|DHCP"
```

---

### Phase 3: Diagnose Persistent DHCP Failure

If lease renewal fails (APIPA address persists after renew), the fault is not on the
device - it is on the network path to the DHCP server or on the DHCP server itself.

**Diagnostic sequence for persistent DHCP failure:**

```
ipconfig /renew returns APIPA or times out
                    │
                    ▼
     Check physical connection (Layer 1)
     Link light present? NIC detected?
                    │
          ┌─────────┴─────────┐
     No link light         Link light present
          │                   │
          ▼                   ▼
    Physical fault      Check if other devices
    Fix cable/port      on same network have IP
    before continuing        │
                    ┌────────┴────────┐
              Others OK         Others also APIPA
                    │                │
                    ▼                ▼
           Fault is isolated    DHCP server fault
           to this device       or network-wide issue
                    │                │
                    ▼                ▼
           Check NIC driver    Escalate to Tier 2
           Check DHCP service  (DHCP server down,
           Rejoin network      scope exhausted,
                               relay agent fault)
```

**Check the DHCP client service (Windows):**

```powershell
# Verify DHCP client service is running
Get-Service -Name Dhcp

# If stopped:
Start-Service -Name Dhcp

# Verify service is set to start automatically
Set-Service -Name Dhcp -StartupType Automatic

# Retry renewal
ipconfig /renew
```

**Check for DHCP scope exhaustion indicators:**

DHCP scope exhaustion occurs when all available IP addresses in the DHCP pool have been
assigned and no new leases can be granted. Signs include:

- Multiple users simultaneously unable to obtain an IP address
- All affected devices show APIPA addresses at the same time
- The fault started after a large number of new devices joined the network
- The DHCP server is reachable but renewal requests time out

> This condition requires Tier 2 access to the DHCP server to extend the scope or
> clear stale leases. Escalate with scope exhaustion as the suspected cause.

---

### Phase 4: Workaround - Static IP Assignment

If DHCP renewal fails and the user has an urgent business need, a temporary static IP
can restore connectivity. This requires knowing the correct network addressing scheme.

**Before assigning a static IP, confirm from Tier 2 or documentation:**
- Available IP address in the correct range (outside the DHCP pool)
- Subnet mask
- Default gateway address
- DNS server address

Windows (requires elevation):
```powershell
# Assign a static IP temporarily
$adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}

New-NetIPAddress `
    -InterfaceIndex $adapter.InterfaceIndex `
    -IPAddress "192.168.1.200" `
    -PrefixLength 24 `
    -DefaultGateway "192.168.1.1"

Set-DnsClientServerAddress `
    -InterfaceIndex $adapter.InterfaceIndex `
    -ServerAddresses ("192.168.1.1","8.8.8.8")

# Verify
ipconfig /all

# IMPORTANT: Document in ticket. Revert to DHCP when server is restored:
# Set-NetIPInterface -InterfaceIndex $adapter.InterfaceIndex -Dhcp Enabled
# Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses
# ipconfig /renew
```

Linux:
```bash
# Assign a static IP temporarily using ip command
# (does not persist across reboot - workaround only)
INTERFACE="eth0"
IP="192.168.1.200"
GATEWAY="192.168.1.1"
PREFIX=24

# Remove existing address if present
sudo ip addr flush dev "$INTERFACE"

# Assign static address
sudo ip addr add "$IP/$PREFIX" dev "$INTERFACE"
sudo ip link set "$INTERFACE" up
sudo ip route add default via "$GATEWAY"

# Set DNS temporarily
echo "nameserver 192.168.1.1" | sudo tee /etc/resolv.conf

# Verify
ip addr show "$INTERFACE"
ip route show
ping -c 4 "$GATEWAY"
```

---

### DHCP Escalation Criteria

Escalate to Tier 2 when:

- DHCP renewal fails on a device with confirmed physical connectivity
- Multiple users simultaneously cannot obtain a DHCP address
- DHCP scope exhaustion is suspected
- DHCP server IP address in `ipconfig /all` is blank or shows the APIPA server (itself)
- Static IP workaround has been applied and DHCP server restoration is required
- DHCP lease is obtained but with incorrect gateway or DNS addresses
  (DHCP server misconfiguration - requires server-side fix)

---

## Common DNS and DHCP Fault Patterns

| Symptom | Likely Cause | Resolution |
|---|---|---|
| "Internet not working" - 8.8.8.8 reachable | DNS fault | Flush cache, check DNS server address |
| Specific website unreachable, others work | Stale DNS cache entry | Flush DNS cache |
| Internal resources by name fail, external works | Internal DNS server fault | Escalate - internal DNS only |
| All name resolution fails, IP access works | DNS server down or wrong address | Check DNS config, set temp DNS, escalate |
| APIPA address after boot | DHCP server unreachable or lease expired | Release/renew; escalate if persists |
| IP obtained but wrong gateway | DHCP misconfiguration | Escalate to Tier 2 - server-side fix |
| Multiple users simultaneously lose connectivity | DHCP scope exhausted or server down | Escalate immediately - infrastructure fault |
| Works in office, fails on return from travel | Lease expired while off network | Release/renew - usually self-resolving |
| Correct IP, no internet, internal works | ISP or upstream routing fault | Confirm internal vs. external; escalate |

---

## Expected Results After Successful Resolution

**DNS resolved:**
```
nslookup google.com
Server:   192.168.1.1
Address:  192.168.1.1#53
Non-authoritative answer:
Name:    google.com
Address: 142.250.x.x
```

**DHCP resolved:**
```
ipconfig /all showing:
DHCP Enabled: Yes
IPv4 Address: 192.168.x.x (network range - not 169.254.x.x)
Default Gateway: 192.168.x.1
DHCP Server: 192.168.x.x (server's IP)
Lease Obtained: [today's date]
Lease Expires: [future date]
```

---

## Security Considerations

- Do not configure public DNS servers (8.8.8.8, 1.1.1.1) as permanent replacements
  without Tier 2 authorisation - internal DNS servers may enforce security policies,
  content filtering, or split-DNS for internal resources
- Static IP assignments must use addresses outside the DHCP pool to prevent IP conflicts -
  always confirm the safe range with Tier 2 before assigning
- Unexpected DHCP server addresses in `ipconfig /all` may indicate a rogue DHCP server -
  escalate immediately if the DHCP server IP does not match the known server address
- Multiple simultaneous DHCP failures with no server fault can indicate a network
  infrastructure problem or a DHCP starvation attack - escalate as a security event

---

## Related Documents

| Document | Relationship |
|---|---|
| [`network-troubleshooting-guide.md`](network-troubleshooting-guide.md) | Layer 3 checks that precede this playbook |
| [`connectivity-fault-isolation.md`](connectivity-fault-isolation.md) | Extended connectivity fault workflows |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Escalation criteria and package requirements |
| [`../scripts/windows/Get-NetworkDiagnostics.ps1`](../scripts/windows/Get-NetworkDiagnostics.ps1) | Automated network diagnostic collection |
| [`../scripts/linux/network-diagnostics.sh`](../scripts/linux/network-diagnostics.sh) | Automated network diagnostic collection |
| [`../playbooks/dns-resolution-failure.md`](../playbooks/dns-resolution-failure.md) | Ticket-oriented DNS resolution playbook |
| [`../playbooks/no-network-connectivity.md`](../playbooks/no-network-connectivity.md) | Full connectivity loss playbook |