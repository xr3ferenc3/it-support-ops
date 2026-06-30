# Playbook: DNS Resolution Failure

## Purpose

This playbook provides a ticket-oriented resolution guide for confirmed DNS resolution
failures - where a device has network connectivity by IP address but cannot resolve
hostnames to reach websites, internal resources, or services by name.

This playbook is the practical, ticket-driven companion to
[`../networking/dns-dhcp-playbook.md`](../networking/dns-dhcp-playbook.md), which contains
the full technical reference. Use this playbook to move quickly through a single ticket
from intake to resolution; refer to the technical reference for deeper diagnosis.

---

## When to Use This Playbook

Use this playbook when the user reports:

- "I can't get to any websites" but other network activity seems to work
- Browser shows "This site can't be reached" / "DNS_PROBE_FINISHED_NXDOMAIN" / "Server not found"
- "I can ping the IP address but not the website name"
- Internal resources (file server, intranet) unreachable by name but reachable by IP
- "The internet was working, now nothing loads"

Do not use this playbook if:
- The user has no connectivity at all (cannot ping anything, including IPs) - use
  [`no-network-connectivity.md`](no-network-connectivity.md)
- DNS resolves correctly but the destination service itself is down - this is not a
  DNS fault; verify with the destination's status page or escalate as a service fault

---

## Ticket Intake - Required Information

| Field | What to Record |
|---|---|
| What fails to load | Specific site/s, all sites, or internal resources only |
| Exact error message | Screenshot or exact text |
| Can the user reach an IP directly | Has this been tested, or needs testing |
| When it started | Exact or approximate time |
| Other users affected | Has the user checked with colleagues |
| Recent changes | New software, VPN connection, network change |

---

## Step 1 - Confirm This Is a DNS Fault, Not a Connectivity Fault

This distinction must be made before proceeding. A DNS fault means IP-level connectivity
works but name resolution does not.

```powershell
# Windows: Test IP connectivity first
ping 8.8.8.8 -n 4

# If this fails, this is NOT a DNS fault - stop here and use
# no-network-connectivity.md instead

# If this succeeds, test name resolution
ping google.com -n 4
nslookup google.com
```

```bash
# Linux: Test IP connectivity first
ping -c 4 8.8.8.8

# If this fails, this is NOT a DNS fault - use no-network-connectivity.md

# If this succeeds, test name resolution
ping -c 4 google.com
dig google.com +short
```

**Confirmation matrix:**

| Ping 8.8.8.8 | Ping google.com | nslookup/dig result | Conclusion |
|---|---|---|---|
| Success | Success | Resolves correctly | Not a DNS fault - investigate application layer |
| Success | Fails | No answer / timeout / SERVFAIL | **DNS fault confirmed** - continue this playbook |
| Fails | Fails | N/A | Not a DNS fault - use no-network-connectivity.md |

---

## Step 2 - Identify the Failure Pattern

Different DNS fault patterns point to different root causes. Test multiple targets to
classify the pattern correctly.

```powershell
# Windows: Test multiple resolution targets
Write-Host "--- External public site ---"
nslookup google.com

Write-Host "--- External, alternate domain ---"
nslookup microsoft.com

Write-Host "--- Internal resource (if applicable) ---"
nslookup fileserver.company.local

Write-Host "--- Using alternate DNS server (bypass local DNS) ---"
nslookup google.com 8.8.8.8
```

```bash
# Linux: Test multiple resolution targets
echo "--- External public site ---"
dig google.com +short

echo "--- External, alternate domain ---"
dig microsoft.com +short

echo "--- Internal resource (if applicable) ---"
dig fileserver.company.local +short

echo "--- Using alternate DNS server (bypass local DNS) ---"
dig @8.8.8.8 google.com +short
```

**Failure pattern classification:**

| Pattern | Likely Cause |
|---|---|
| All external sites fail, internal works | Local or upstream DNS server fault for external resolution |
| All resolution fails (external and internal) | DNS server fully unreachable or misconfigured |
| Only one or two specific sites fail | Stale cache entry for those specific names |
| Fails on local DNS, succeeds via 8.8.8.8 | Local/internal DNS server fault - confirmed |
| Fails on local DNS AND on 8.8.8.8 | Port 53 blocked, or device-level DNS client fault |
| Internal resources fail, external works | Internal DNS server fault - likely isolated to internal zone |

---

## Step 3 - Flush DNS Cache

This is the fastest resolution for stale or corrupted cache entries and should always
be attempted first.

```powershell
# Windows
ipconfig /flushdns

# Confirm cache was cleared
ipconfig /displaydns | Select-String "Record Name" | Measure-Object

# Re-test
nslookup google.com
```

```bash
# Linux - method depends on the DNS caching service in use

# systemd-resolved (most modern distributions)
sudo systemd-resolve --flush-caches
sudo systemd-resolve --statistics

# nscd
sudo systemctl restart nscd

# dnsmasq
sudo systemctl restart dnsmasq

# Re-test
dig google.com +short
```

**If resolution succeeds after flush:** Proceed to Step 7 (verification) - fault resolved.

**If resolution still fails after flush:** Continue to Step 4.

---

## Step 4 - Verify DNS Server Configuration

```powershell
# Windows: View configured DNS servers
ipconfig /all | Select-String -Pattern "DNS Servers" -Context 0,2

# Confirm the DNS server address matches the expected internal DNS server
# or a known-good public DNS server
```

```bash
# Linux: View configured DNS servers
cat /etc/resolv.conf

# For systemd-resolved systems
resolvectl status
```

**Verification checks:**

- [ ] Is a DNS server address present at all (not blank)?
- [ ] Does the DNS server address match the expected internal DNS server IP?
- [ ] Is the DNS server address reachable (`ping <dns-server-ip>`)?

```powershell
# Windows: Test DNS server reachability
ping 192.168.1.1 -n 4   # Replace with actual configured DNS server IP
```

```bash
# Linux: Test DNS server reachability
ping -c 4 192.168.1.1   # Replace with actual configured DNS server IP
```

**If the DNS server is unreachable:** This indicates either the DNS server is down or
there is a routing fault to it. Escalate to Tier 2.

**If the DNS server is reachable but resolution still fails:** Continue to Step 5.

---

## Step 5 - Renew DHCP to Refresh DNS Settings

If the device received an incorrect DNS server address via DHCP (e.g. from a
misconfigured scope, or a stale lease from before a DNS server change), renewing
the DHCP lease will refresh this.

```powershell
# Windows
ipconfig /release
Start-Sleep -Seconds 5
ipconfig /renew

# Verify DNS server address updated
ipconfig /all | Select-String "DNS Servers"

# Re-test
nslookup google.com
```

```bash
# Linux
IFACE=$(ip route show default | awk '{print $5}')
sudo dhclient -r "$IFACE"
sleep 3
sudo dhclient "$IFACE"

# Verify
cat /etc/resolv.conf

# Re-test
dig google.com +short
```

---

## Step 6 - Check the Hosts File for Incorrect Entries

The hosts file overrides DNS for any matching entry. A stray or malicious entry here
will cause resolution failures or redirects for that specific name regardless of DNS
server health.

```powershell
# Windows
Get-Content "C:\Windows\System32\drivers\etc\hosts" |
    Where-Object { $_ -notmatch "^\s*#" -and $_.Trim() -ne "" }

# Review any entries shown. Legitimate entries are rare on standard
# workstations. Unexpected entries - especially redirecting common
# domains - may indicate malware. Do not delete entries without
# understanding their purpose; if uncertain, escalate.
```

```bash
# Linux
grep -v "^#" /etc/hosts | grep -v "^\s*$"

# Review entries. Standard entries are typically limited to:
# 127.0.0.1 localhost
# ::1 localhost
# Any additional entries should be understood before modification.
```

**If unexpected entries are found:**
1. Do not assume they are safe to remove without understanding their origin
2. Document the exact entries found in the ticket
3. If entries redirect known legitimate domains to unexpected IPs, treat as a
   potential security event and escalate per
   [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md)

---

## Step 7 - Apply Temporary DNS Workaround (If Authorised)

If the fault is confirmed to be the configured DNS server and Tier 2 is not immediately
available, a temporary public DNS workaround can restore external connectivity while
the underlying server issue is escalated.

> **Document this as a temporary workaround in the ticket.** Internal resources will
> not resolve while this workaround is active. Revert once the DNS server is restored.

```powershell
# Windows (requires elevation)
$adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex `
    -ServerAddresses ("8.8.8.8","1.1.1.1")

# Test
nslookup google.com

# To revert later (after DNS server is restored):
# Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses
# ipconfig /renew
```

```bash
# Linux (temporary - does not persist across reboot on most configurations)
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf

# Test
dig google.com +short
```

---

## Step 8 - Verify Resolution

```powershell
# Windows: Confirm resolution is working across multiple targets
nslookup google.com
nslookup microsoft.com
ping google.com -n 4
```

```bash
# Linux
dig google.com +short
dig microsoft.com +short
ping -c 4 google.com
```

Ask the user to open a browser and confirm pages load normally before closing the ticket.

---

## Escalation Criteria

Escalate to Tier 2 when:

- [ ] DNS server is confirmed unreachable
- [ ] DNS server is reachable but fails to resolve any queries (server-side fault)
- [ ] Resolution fails via local DNS but succeeds via 8.8.8.8 (internal DNS server fault)
- [ ] Resolution fails even via 8.8.8.8 (possible port 53 block - firewall investigation needed)
- [ ] Multiple users report DNS failures simultaneously
- [ ] Unexpected or suspicious hosts file entries are found
- [ ] DHCP is delivering an incorrect DNS server address (server-side DHCP misconfiguration)

**Escalation package must include:**

- Results of the failure pattern classification (Step 2)
- DNS server address configured and its reachability status
- Result of flush attempt
- Result of testing against 8.8.8.8 directly
- Any hosts file findings
- Whether a temporary workaround was applied

---

## Expected Results After Successful Resolution

```
nslookup google.com

Server:   192.168.1.1
Address:  192.168.1.1#53

Non-authoritative answer:
Name:    google.com
Address: 142.250.80.46

ping google.com

Pinging google.com [142.250.80.46] with 32 bytes of data:
Reply from 142.250.80.46: bytes=32 time=14ms TTL=118
(4 replies received, 0% loss)
```

---

## Common Fault Patterns and Quick Resolutions

| Symptom Pattern | Most Likely Cause | First Action |
|---|---|---|
| One specific site fails, others work | Stale DNS cache entry | Flush DNS cache |
| All resolution fails suddenly | DNS server down or DHCP pushed wrong address | Check DNS server reachability; renew DHCP |
| Internal names fail, external works | Internal DNS server fault | Escalate - internal DNS zone issue |
| Works on phone (cellular), fails on work device | Local network DNS fault, not user's device | Confirm with 8.8.8.8 direct test; escalate |
| Intermittent - sometimes resolves, sometimes not | DNS server overloaded or flapping | Note pattern; escalate for server health check |
| Resolves to wrong/unexpected IP | Hosts file tampering or DNS cache poisoning | Check hosts file; escalate as possible security event |

---

## Verification Checklist

- [ ] IP-level connectivity confirmed before starting DNS-specific diagnosis
- [ ] Failure pattern classified (which targets fail, which succeed)
- [ ] DNS cache flushed and re-tested
- [ ] DNS server configuration verified and reachability confirmed
- [ ] Hosts file checked for unexpected entries
- [ ] Resolution confirmed across multiple test domains
- [ ] User has independently confirmed browsing works normally
- [ ] Any temporary workaround documented with a reversal plan
- [ ] Root cause documented in the ticket

---

## Security Considerations

- Hosts file entries redirecting legitimate domains to unexpected IP addresses are a
  known malware technique - treat any unexplained entry as a potential security event
- Resolution to an unexpected IP address for a well-known domain (DNS spoofing or
  poisoning) should be escalated immediately, not resolved by simply flushing cache
- Do not permanently configure public DNS servers without Tier 2 authorisation -
  internal DNS may enforce content filtering or security policy that public DNS bypasses
- If multiple users report sudden simultaneous DNS failures with no known server-side
  cause, consider this may be a DNS hijack or man-in-the-middle scenario and escalate
  accordingly

---

## Related Documents

| Document | Relationship |
|---|---|
| [`../networking/dns-dhcp-playbook.md`](../networking/dns-dhcp-playbook.md) | Full technical reference for DNS and DHCP faults |
| [`no-network-connectivity.md`](no-network-connectivity.md) | Use instead if IP-level connectivity also fails |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Escalation criteria and package requirements |
| [`../scripts/windows/Get-NetworkDiagnostics.ps1`](../scripts/windows/Get-NetworkDiagnostics.ps1) | Automated DNS and network diagnostic collection |
| [`../scripts/linux/network-diagnostics.sh`](../scripts/linux/network-diagnostics.sh) | Automated DNS and network diagnostic collection |