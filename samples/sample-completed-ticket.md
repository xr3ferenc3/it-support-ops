# Sample: Completed Support Ticket

## About This Sample

This is a completed example of the
[`../templates/ticket-template.md`](../templates/ticket-template.md) for the same
scenario documented in
[`sample-diagnostic-report-windows.md`](sample-diagnostic-report-windows.md):
a user on Windows 11 with no network connectivity, diagnosed as DHCP scope
exhaustion, resolved by Tier 2 after Tier 1 applied a static IP workaround
and escalated with a complete diagnostic package.

This sample demonstrates the full ticket lifecycle - from intake through to closure
with root cause documented - and shows how all eight sections of the ticket template
are completed in a real scenario. The diagnostic report is referenced as an
attachment rather than repeated inline.

All details are fictional (RFC 5737 IPs: 192.0.2.x). Adapt for your environment.

---

## COMPLETED TICKET

```
================================================================================
IT SUPPORT TICKET
================================================================================

TICKET REFERENCE:   INC0008471
DATE CREATED:       2025-06-15 08:58
CREATED BY:         A. Okonkwo - IT Support Technician (Tier 1)

────────────────────────────────────────────────────────────────────────────────
SECTION 1 - REQUESTER INFORMATION
────────────────────────────────────────────────────────────────────────────────

Requester Name:       J. Nkemdirim
Department:           Finance
Location:             Building A, Floor 2, Desk F2-14
Contact Number:       x2214
Contact Email:        j.nkemdirim@company.example
Preferred Contact:    Phone (x2214) during business hours

────────────────────────────────────────────────────────────────────────────────
SECTION 2 - ASSET INFORMATION
────────────────────────────────────────────────────────────────────────────────

Device Hostname:      WKSTN-042
Asset Tag:            IT-WS-0842
Operating System:     Windows 11 Pro - 22H2 (Build 22621.3593)
Device Type:          Desktop Workstation
Serial Number:        N/A - not required for network fault
Connection Type:      Wired (Ethernet)

────────────────────────────────────────────────────────────────────────────────
SECTION 3 - ISSUE CLASSIFICATION
────────────────────────────────────────────────────────────────────────────────

Category:             Network

Priority:             P2 - High

Priority Justification:
  Initially assessed P3 (single user, wired network fault). Upgraded to P2 at
  09:18 when investigation confirmed multiple Floor 2 users affected and the
  Finance team has month-end processing due today. Workarounds applied but
  not scalable to all affected users.

SLA Target Response:  ≤1 hour (P2)
SLA Target Resolve:   8 hours (P2)

────────────────────────────────────────────────────────────────────────────────
SECTION 4 - PROBLEM DESCRIPTION
────────────────────────────────────────────────────────────────────────────────

Summary (one line):
  Floor 2 users unable to obtain DHCP lease - APIPA addresses assigned,
  suspected DHCP scope exhaustion on 192.0.2.0/24.

Detailed Description:
  User J. Nkemdirim called the help desk at 08:52 reporting complete loss of
  network access. Unable to reach internet, internal file server, or any network
  resource. Computer was restarted without restoring connectivity. User had not
  changed anything on the workstation. Issue started when the user arrived this
  morning - network was confirmed working at end of previous business day.

Exact Error Message (if any):
  OS network indicator shows "No internet, secured". Browser displays "No internet"
  on all page load attempts. ipconfig shows "Autoconfiguration IPv4 Address:
  169.254.43.201" with no default gateway listed.

When Did It Start:
  First observed by user at approximately 08:45 when they sat down at their desk.
  Last known working: 2025-06-14 approximately 17:30.

Is It Reproducible:
  Always - every boot attempt results in APIPA address. DHCP renew consistently
  times out.

Recent Changes:
  None reported by user. No Windows Update activity on this device overnight
  (confirmed via Event Log). Building maintenance did not report any network
  work in Building A.

Other Users Affected:
  Yes - confirmed at 09:18. K. Adeyemi at F2-12 has same symptoms. F2-16
  unoccupied workstation also shows APIPA on visual inspection. Floor 1 users
  confirmed unaffected (separate subnet).

Actions Taken by User:
  Restarted computer once before calling IT. No other actions taken.

────────────────────────────────────────────────────────────────────────────────
SECTION 5 - DIAGNOSIS
────────────────────────────────────────────────────────────────────────────────

Triage Assessment:
  Initial: P3 isolated network fault. Upgraded to P2 departmental scope at 09:18
  when adjacent workstations confirmed affected. Category: Network - Layer 3
  DHCP failure.

Hypothesis:
  DHCP scope exhaustion for the Floor 2 subnet (192.0.2.0/24). DHCP server
  (SRV-DHCP01) is online and reachable via ICMP but not responding to lease
  requests - indicates no available addresses in the pool rather than a downed
  server.

Diagnostic Steps Taken:

  [2025-06-15 09:12] Step 1: Checked adapter status
    Result: Ethernet adapter UP, 1Gbps link speed, MAC address present.
    Layer 1 confirmed healthy.

  [2025-06-15 09:13] Step 2: Ran ipconfig /all to confirm APIPA
    Result: IPv4: 169.254.43.201, no gateway, DHCP enabled, no lease.
    APIPA confirmed - DHCP failed.

  [2025-06-15 09:15] Step 3: Attempted ipconfig /release && ipconfig /renew
    Result: Renew timed out - "unable to contact your DHCP server."
    APIPA reassigned. Not a client-side or lease expiry issue.

  [2025-06-15 09:18] Step 4: Physical check of adjacent workstations
    Result: F2-12 (K. Adeyemi) and F2-16 also show APIPA. Floor 1 unaffected.
    Scope upgraded to departmental. Multiple users affected on same subnet.

  [2025-06-15 09:21] Step 5: Temporary static IP applied to confirm routing intact
    Result: Static IP (192.0.2.200/24, gateway 192.0.2.1, DNS 192.0.2.10)
    restored full connectivity. Internet and internal resources accessible.
    Gateway, routing, and DNS all functional. Fault confirmed isolated to DHCP
    not issuing leases. Static IP removed after test.

  [2025-06-15 09:26] Step 6: Confirmed DHCP server is reachable
    Result: ping 192.0.2.5 - 4/4 replies. Server online. Fault is server-side
    scope or lease pool, not a downed server.

Root Cause Confirmed:
  Suspected - DHCP scope exhaustion. DHCP server reachable but not responding
  to lease requests. Server-side access required to confirm and resolve.
  See attached diagnostic report INC0008471-DIAG-20250615 for full test detail.

Diagnostic Output Attached:
  Yes - INC0008471-SystemHealth.txt, INC0008471-NetworkDiag.txt
  (Generated using Get-SystemHealthReport.ps1 and Get-NetworkDiagnostics.ps1)

────────────────────────────────────────────────────────────────────────────────
SECTION 6 - RESOLUTION
────────────────────────────────────────────────────────────────────────────────

Resolution Action:
  Tier 1 (A. Okonkwo): Applied temporary static IPs to WKSTN-042 (192.0.2.195)
  and WKSTN-038 (192.0.2.196) from the IT-reserved static range (192.0.2.190–
  192.0.2.199 per network addressing documentation) to restore Finance team
  productivity during escalation.

  Tier 2 (B. Mwangi, Senior Sysadmin): Accessed SRV-DHCP01 via RDP. Confirmed
  DHCP scope for 192.0.2.0/24 (configured range: 192.0.2.50–192.0.2.180)
  was 100% utilised - 131 active leases, 0 available addresses. Identified
  22 stale leases for devices no longer on the network (decommissioned
  workstations and retired laptops). Cleared stale leases and extended the
  scope upper bound to 192.0.2.220 (added 40 addresses to the pool). DHCP
  service confirmed responding to new requests within 2 minutes of change.

  Tier 1 (A. Okonkwo): Reverted WKSTN-042 and WKSTN-038 from static IPs to
  DHCP (ipconfig /release && ipconfig /renew). Both obtained valid leases
  immediately. Visited F2-12 to assist K. Adeyemi - confirmed lease obtained.

Resolution Time:
  2025-06-15 11:14 - DHCP scope extended on SRV-DHCP01 and leases confirmed
  obtained on all affected workstations.

Verification Method:
  ipconfig /all on WKSTN-042 confirmed:
  - IPv4: 192.0.2.87 (valid lease - not APIPA)
  - Default Gateway: 192.0.2.1
  - DHCP Server: 192.0.2.5 (SRV-DHCP01)
  - Lease Obtained: 2025-06-15 11:15
  ping 8.8.8.8 - 4/4 replies. nslookup google.com - resolved.

User Confirmation:
  Yes - J. Nkemdirim confirmed internet access and file server access at 11:19.
  Month-end processing confirmed underway without further issues.

Workaround Applied:
  Yes - static IPs applied to two workstations during escalation period
  (09:28–11:15). Reverted to DHCP after scope resolution.

────────────────────────────────────────────────────────────────────────────────
SECTION 7 - ESCALATION
────────────────────────────────────────────────────────────────────────────────

Escalated:            Yes
Escalation Time:      2025-06-15 09:35
Escalated To:         B. Mwangi - Senior Systems Administrator (Tier 2)
Escalation Reason:    DHCP server-side access required to review scope
                      utilisation and clear stale leases. Beyond Tier 1
                      access authority.
Escalation Package:   Attached - Yes (INC0008471-DIAG-20250615.md with
                      INC0008471-SystemHealth.txt and INC0008471-NetworkDiag.txt)
Tier 2 Resolution:    Accessed SRV-DHCP01. Confirmed scope exhaustion (131/131
                      leases used). Cleared 22 stale leases for decommissioned
                      devices. Extended scope upper bound from .180 to .220.
                      DHCP service confirmed responding within 2 minutes.
Returned to Tier 1:   Yes - at 11:10, for static IP reversion and user
                      verification.

────────────────────────────────────────────────────────────────────────────────
SECTION 8 - CLOSURE
────────────────────────────────────────────────────────────────────────────────

Root Cause (final):
  The DHCP scope for the Floor 2 subnet (192.0.2.0/24) became exhausted
  because 22 stale leases remained allocated to decommissioned devices that
  were removed from the network without their DHCP leases being released.
  These leases held IP addresses in the pool indefinitely, progressively
  reducing available capacity until no addresses remained for legitimate
  active devices to obtain or renew leases.

Recurrence Risk:
  Medium - DHCP lease pool will grow toward capacity again if decommissioned
  devices continue to leave stale leases. Prevention actions below are designed
  to eliminate this risk.

Prevention Recommendation:
  1. DHCP lease cleanup: B. Mwangi (Tier 2) to add a monthly recurring task
     to review and clear leases for devices absent from the network for
     more than 30 days. Due: 2025-07-01.
  2. DHCP monitoring: Add a DHCP scope utilisation alert at 80% of pool
     capacity to the monitoring platform. Alert to fire to the IT team
     Slack channel. Owner: B. Mwangi. Due: 2025-06-30.
  3. Decommission process: Update the device decommission checklist
     (in IT knowledge base) to include a step for releasing the DHCP lease
     on SRV-DHCP01 before physical removal of any device. Owner: A. Okonkwo.
     Due: 2025-06-20.

Knowledge Base Entry Required:
  Yes - KB article "DHCP Scope Exhaustion - Diagnosis and Resolution" to be
  created. Assigned to A. Okonkwo. References this ticket and the diagnostic
  report. Due: 2025-06-20.

Related Tickets:
  INC0008472 - K. Adeyemi, same fault, same root cause. Linked and resolved
  as part of this incident.

Closed By:            A. Okonkwo
Closure Time:         2025-06-15 11:35
Total Time Open:      2 hours 37 minutes (08:58 to 11:35)
Resolution Category:  Fixed

================================================================================
END OF TICKET
================================================================================
```

---

## What This Sample Demonstrates

**Priority upgrade mid-ticket (Section 3):** The ticket was opened as P3 and
upgraded to P2 at 09:18 when scope was confirmed to extend beyond a single user.
The justification - Finance team, month-end processing, not scalable workaround -
is documented explicitly. This is correct triage practice.

**Clean escalation handoff (Sections 5 and 7):** The escalation at 09:35
follows thirty-five minutes of structured Tier 1 diagnosis that: confirmed the
adapter was healthy, confirmed DHCP was failing not the network, identified the
scope of impact, tested routing independently with a static IP, and confirmed the
DHCP server was online. Tier 2 received a complete picture and went directly to the
DHCP console rather than repeating Tier 1 steps.

**Root cause specificity (Section 8):** The root cause statement names the
exact mechanism - stale leases from decommissioned devices holding pool capacity -
rather than stopping at "DHCP scope was full." This is what makes the three
prevention recommendations concrete and assignable rather than vague.

**Three actionable prevention recommendations:** Each prevention recommendation
has a specific named owner and due date. The decommission process update (Action 3)
addresses the original source of the problem. The monitoring alert (Action 2)
catches it before it becomes an incident next time. The monthly cleanup task
(Action 1) catches any leases that slip through. This is layered prevention, not
a single-point fix.

**Verification is specific (Section 6):** The verification section does not
say "we confirmed it was working." It quotes the actual ipconfig output values
that confirmed a valid lease - IP in the correct range, gateway populated, DHCP
server address correct, lease timestamp of today. A second technician reading
this ticket knows exactly what the verified healthy state looks like.

---

## Repository Complete

This is the final file in the `it-support-ops` repository.

The complete repository contains 41 files across 9 sections:

| Section | Files | Description |
|---|---|---|
| Core | 3 | README, CHANGELOG, LICENSE |
| Methodology | 3 | Troubleshooting, triage, escalation |
| Networking | 4 | Network guide, DNS/DHCP, Wi-Fi, connectivity isolation |
| Playbooks | 7 | Seven common IT support scenarios |
| Windows Scripts | 5 | PowerShell diagnostic and automation scripts |
| Linux Scripts | 5 | Bash diagnostic and automation scripts |
| Reference | 4 | Windows, Linux, PowerShell, and ports/protocols |
| Incidents | 4 | Classification, checklist, templates, PIR |
| Templates | 3 | Ticket, diagnostic report, change request |
| Samples | 3 | Completed Windows report, Linux report, ticket |

---

## Related Documents

| Document | Relationship |
|---|---|
| [`../templates/ticket-template.md`](../templates/ticket-template.md) | Template this sample is based on |
| [`sample-diagnostic-report-windows.md`](sample-diagnostic-report-windows.md) | Diagnostic report attached to this ticket |
| [`../networking/dns-dhcp-playbook.md`](../networking/dns-dhcp-playbook.md) | Playbook followed during diagnosis |
| [`../playbooks/no-network-connectivity.md`](../playbooks/no-network-connectivity.md) | Initial playbook consulted at intake |