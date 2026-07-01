# Network Ports and Protocols Reference

## Purpose

This reference provides common TCP/UDP ports and their associated protocols organised
by operational category - the categories a help desk technician encounters when
diagnosing connectivity faults, not the numerical order found in exhaustive port lists.

Knowing the expected port for a service is essential when using `Test-NetConnection`,
`nc`, or firewall log analysis to determine whether a connectivity fault is a routing
issue or a blocked port.

---

## When to Use This Reference

Use this reference when:

- Testing whether a specific service port is reachable using
  `Test-NetConnection -ComputerName host -Port <port>` or `nc -zv host <port>`
- Investigating firewall logs for blocked traffic
- Confirming which port to specify when a user reports they cannot reach a service
- Verifying that a newly configured service is listening on the expected port

For test command syntax see [`powershell-command-reference.md`](powershell-command-reference.md)
and [`linux-command-reference.md`](linux-command-reference.md).

---

## Web and Browser Traffic

| Port | Protocol | Service | Notes |
|---|---|---|---|
| 80 | TCP | HTTP | Unencrypted web traffic - most sites redirect to HTTPS |
| 443 | TCP | HTTPS | Encrypted web traffic - standard for all modern sites |
| 8080 | TCP | HTTP alternate | Common alternate HTTP port for internal web applications |
| 8443 | TCP | HTTPS alternate | Common alternate HTTPS port for internal applications |

**Connectivity test example:**
```powershell
# Windows
Test-NetConnection -ComputerName google.com -Port 443
```
```bash
# Linux
nc -zv google.com 443
```

---

## Email

| Port | Protocol | Service | Notes |
|---|---|---|---|
| 25 | TCP | SMTP | Server-to-server email delivery - usually blocked at ISP level for end users |
| 587 | TCP | SMTP Submission | Authenticated email sending from client to mail server |
| 465 | TCP | SMTPS | SMTP with implicit TLS - older standard, still used |
| 110 | TCP | POP3 | Incoming email retrieval (older protocol - downloads and removes from server) |
| 995 | TCP | POP3S | POP3 with TLS encryption |
| 143 | TCP | IMAP | Incoming email retrieval (keeps mail on server - modern standard) |
| 993 | TCP | IMAPS | IMAP with TLS encryption |

**Common fault:** A user cannot send or receive email. Test both the sending (587) and
receiving (993/IMAP or 995/POP3) ports separately to isolate the fault direction.

---

## File Sharing and Storage

| Port | Protocol | Service | Notes |
|---|---|---|---|
| 445 | TCP | SMB | Windows file and printer sharing - primary protocol for shared drives |
| 139 | TCP | NetBIOS Session | Legacy SMB over NetBIOS - still used in older networks |
| 137-138 | UDP | NetBIOS Name/Datagram | NetBIOS name resolution and datagram services |
| 2049 | TCP/UDP | NFS | Network File System - Linux/Unix file sharing |
| 21 | TCP | FTP Control | FTP connection control channel |
| 20 | TCP | FTP Data | FTP data transfer channel (active mode) |
| 22 | TCP | SFTP/SCP | Secure file transfer over SSH - preferred over FTP |
| 989-990 | TCP | FTPS | FTP with TLS - explicit (989) and implicit (990) modes |

**Common fault:** User cannot access a shared drive. Test port 445 to the file server
to confirm whether the fault is network-level or authentication/permissions-level.

```powershell
Test-NetConnection -ComputerName fileserver.company.local -Port 445
```

---

## Remote Access and Administration

| Port | Protocol | Service | Notes |
|---|---|---|---|
| 22 | TCP | SSH | Secure Shell - remote terminal access to Linux/Unix systems |
| 3389 | TCP | RDP | Remote Desktop Protocol - Windows remote desktop |
| 5900+ | TCP | VNC | Virtual Network Computing - screen sharing |
| 5985 | TCP | WinRM HTTP | Windows Remote Management - PowerShell remoting |
| 5986 | TCP | WinRM HTTPS | Windows Remote Management over TLS |

**Common fault:** RDP session cannot connect. Test port 3389 to the target to confirm
reachability before investigating credentials or RDP service state.

```powershell
Test-NetConnection -ComputerName remoteserver.company.local -Port 3389
```

---

## Directory Services (Active Directory / LDAP)

| Port | Protocol | Service | Notes |
|---|---|---|---|
| 389 | TCP/UDP | LDAP | Lightweight Directory Access Protocol - AD queries |
| 636 | TCP | LDAPS | LDAP over TLS - secure AD queries |
| 3268 | TCP | Global Catalog | AD Global Catalog LDAP |
| 3269 | TCP | Global Catalog SSL | AD Global Catalog over TLS |
| 88 | TCP/UDP | Kerberos | Authentication protocol - Windows domain authentication |
| 464 | TCP/UDP | Kerberos change/set | Password change operations via Kerberos |

> **Book reference:** CompTIA Network+ Guide to Networks (10th Ed.) covers LDAP and
> Kerberos as foundational directory service protocols. Port 88 being unreachable is
> a common but non-obvious cause of domain authentication failures - Kerberos requires
> this port to reach a domain controller.

**Common fault:** Login failures on domain-joined device. Test port 88 (Kerberos) and
port 389 (LDAP) against a known domain controller to confirm AD reachability.

---

## DNS

| Port | Protocol | Service | Notes |
|---|---|---|---|
| 53 | UDP | DNS | Standard DNS queries - uses UDP for speed |
| 53 | TCP | DNS | DNS zone transfers and large responses fall back to TCP |
| 853 | TCP | DNS over TLS (DoT) | Encrypted DNS - less common in SMB environments |

**Common fault:** DNS resolution fails but IP-level connectivity works. Test port 53
UDP reachability to the configured DNS server - UDP-based tests are less straightforward
than TCP, but TCP port 53 also being blocked is informative.

```powershell
# Test DNS server TCP reachability (not a full DNS query - use nslookup for that)
Test-NetConnection -ComputerName 192.168.1.1 -Port 53
```

For full DNS fault procedures see [`networking/dns-dhcp-playbook.md`](../networking/dns-dhcp-playbook.md).

---

## DHCP

| Port | Protocol | Service | Notes |
|---|---|---|---|
| 67 | UDP | DHCP Server | DHCP server listens on this port |
| 68 | UDP | DHCP Client | DHCP client sends and receives on this port |

> **Note:** DHCP operates via UDP broadcast - standard port connectivity tests
> (`Test-NetConnection`, `nc`) cannot test DHCP reachability directly. DHCP fault
> diagnosis is performed via the lease renewal process described in
> [`networking/dns-dhcp-playbook.md`](../networking/dns-dhcp-playbook.md).

---

## Printing

| Port | Protocol | Service | Notes |
|---|---|---|---|
| 9100 | TCP | RAW / JetDirect | Direct IP printing - most network printers (HP, Xerox, Canon, etc.) |
| 631 | TCP | IPP | Internet Printing Protocol - modern standard |
| 515 | TCP | LPD/LPR | Legacy Unix printing protocol |

**Common fault:** Network printer appears offline. Test port 9100 to the printer's IP
to confirm the printer itself is reachable on the network before investigating drivers
or print spooler.

```powershell
Test-NetConnection -ComputerName 192.168.1.50 -Port 9100
```

---

## Monitoring and Management

| Port | Protocol | Service | Notes |
|---|---|---|---|
| 161 | UDP | SNMP | Simple Network Management Protocol - device monitoring |
| 162 | UDP | SNMP Trap | SNMP alerts/traps sent from device to management system |
| 123 | UDP | NTP | Network Time Protocol - time synchronisation |

> **Book reference:** CompTIA Network+ Guide to Networks (10th Ed.) covers NTP and its
> role in network operations. NTP (port 123) being blocked or misconfigured is a
> frequent and non-obvious cause of Kerberos authentication failures in domain
> environments - Kerberos authentication fails if device time differs from the domain
> controller by more than 5 minutes (default policy).

**Common fault:** Domain authentication intermittently fails on a specific device.
Check time synchronisation (`w32tm /query /status` on Windows, `timedatectl` on Linux)
before investigating credentials or AD health.

---

## VPN Protocols

| Port | Protocol | Service | Notes |
|---|---|---|---|
| 1194 | UDP/TCP | OpenVPN | Common open-source VPN |
| 1701 | UDP | L2TP | Layer 2 Tunnelling Protocol |
| 500 | UDP | IKE/ISAKMP | IPSec key exchange - used with L2TP/IPSec |
| 4500 | UDP | IPSec NAT-T | IPSec NAT traversal - required when client is behind NAT |
| 1723 | TCP | PPTP | Point-to-Point Tunnelling Protocol - older, avoid if possible |
| 443 | TCP | SSL VPN | Many commercial VPN clients use HTTPS port for compatibility |
| 51820 | UDP | WireGuard | Modern, increasingly common VPN protocol |

**Common fault:** VPN connection fails at a specific site or network. The relevant
UDP port being blocked by a local firewall or ISP is a common cause - check with the
VPN vendor which ports their implementation uses.

---

## Database Ports (Common)

| Port | Protocol | Service | Notes |
|---|---|---|---|
| 1433 | TCP | MS SQL Server | Microsoft SQL Server default instance |
| 3306 | TCP | MySQL / MariaDB | MySQL and MariaDB default |
| 5432 | TCP | PostgreSQL | PostgreSQL default |
| 1521 | TCP | Oracle | Oracle Database default |

These are relevant when a user reports that a business application cannot connect to
its database. Test the relevant port from the application server to the database server
to confirm network-level reachability before investigating connection strings or
credentials.

---

## Port Status Interpretation

When using `Test-NetConnection` or `nc` to test a port:

| Result | Meaning |
|---|---|
| `TcpTestSucceeded: True` / `Connection succeeded` | Port is open and the service is accepting TCP connections |
| `TcpTestSucceeded: False` / `Connection refused` | Host is reachable but the port is closed or the service is not running |
| Connection timed out (no response) | Host is unreachable, or the port is blocked by a firewall that silently drops packets |

**Refused vs. timeout is a meaningful distinction:**

- **Refused** means the host received the connection attempt and rejected it - the
  network path works but the service is down or on a different port
- **Timeout** means the packet never reached the host (or the host never responded) -
  the fault may be routing, firewall, or the host being offline

---

## Firewall-Friendly Testing

Some ports cannot be tested with standard ICMP ping. For example, many servers block
ICMP but allow TCP on specific ports - in these cases, use TCP port tests rather than
ping to confirm reachability.

```powershell
# Windows: A server might not respond to ping but still serve HTTPS
Test-NetConnection -ComputerName server.company.com -Port 443

# This will show TcpTestSucceeded: True even if ping fails,
# confirming the server is up and the service is running
```

```bash
# Linux equivalent
nc -zv -w 5 server.company.com 443
```

---

## Security Considerations

- Port scanning beyond individual port tests (nmap-style full port sweeps) should
  not be performed without explicit authorisation from the infrastructure/security team
  - unauthorised scanning may be detected as an attack and trigger incident response
- `Test-NetConnection` and `nc -zv` generate real connection attempts that appear in
  firewall and server logs - this is expected during normal diagnostics but should
  be noted if unusual activity is subsequently investigated
- Finding an unexpected open port on an internal device (particularly high-numbered
  ports or well-known malware ports) should be escalated as a potential security
  concern rather than dismissed as irrelevant to the current ticket

---

## Related Documents

| Document | Relationship |
|---|---|
| [`powershell-command-reference.md`](powershell-command-reference.md) | Test-NetConnection syntax and usage |
| [`linux-command-reference.md`](linux-command-reference.md) | nc and ss command syntax |
| [`../networking/connectivity-fault-isolation.md`](../networking/connectivity-fault-isolation.md) | Stage 6 service port testing procedures |
| [`../networking/dns-dhcp-playbook.md`](../networking/dns-dhcp-playbook.md) | DNS (port 53) and DHCP fault procedures |