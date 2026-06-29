# Escalation Matrix

## Purpose

This document defines when to escalate, who to escalate to, what information must accompany
every escalation, and how to communicate escalations to users and stakeholders.

Escalation is not a last resort. It is a structured handoff between technicians at different
capability or authority levels. Escalating at the right moment - with complete information -
is a professional act that accelerates resolution. Escalating too late, or without sufficient
findings, delays resolution and frustrates both the receiving technician and the user.

Every escalation in this system follows the same rule: **no escalation without a diagnostic
package.**

---

## When to Use This Document

Consult this document when any of the following conditions are met during triage or diagnosis:

- The fault is confirmed but resolution requires access or authority you do not have
- The fault cannot be diagnosed with tools available to you after exhausting your diagnostic steps
- The scope has expanded to departmental level or wider
- The priority is P1 or P2
- A security event has been identified or suspected
- The issue involves a system owned or managed by a third party
- A change is required that falls under change management control
- The user has a hard deadline that cannot be met within your normal resolution window

---

## Escalation Tiers

This matrix defines three escalation tiers suited to SMB IT support environments.
Larger organisations may have additional tiers - map these accordingly.

---

### Tier 1 - Service Desk / First-Line Support

**Who operates here:** IT Support Technicians, Service Desk Analysts, Help Desk Agents

**Scope of authority:**

- User-facing fault diagnosis and resolution
- Standard software reinstallation and configuration
- Password resets and account unlocks (within policy)
- Hardware swap and basic repair
- Network connectivity verification (not network infrastructure changes)
- Printer setup and driver installation
- Standard operating system repair (SFC, DISM, profile repair)

**Escalation trigger - escalate to Tier 2 when:**

- Root cause confirmed but resolution requires server, network infrastructure, or
  directory service access
- Fault is unconfirmed after completing the full diagnostic sequence for the issue type
- Scope has expanded beyond a single user or device
- Priority is P1 or P2
- A security event is suspected or confirmed
- Resolution requires a change to shared infrastructure

**Cannot escalate without:**

- Completed problem statement
- Issue type and scope confirmed
- Priority assigned
- All Tier 1 diagnostic steps completed and results recorded
- Current system state documented
- Actions already taken listed with outcomes

---

### Tier 2 - Senior Technical Support / Systems Administration

**Who operates here:** Senior IT Technicians, Junior Sysadmins, Network Support Technicians,
Desktop Support Engineers

**Scope of authority:**

- Server-side diagnosis and repair (file servers, print servers, application servers)
- Active Directory and Group Policy administration
- Network infrastructure diagnosis (switches, routers, wireless access points)
- DHCP and DNS server administration
- VPN configuration and fault resolution
- Endpoint management platform administration (MDM, SCCM, Intune)
- Change implementation for controlled infrastructure components
- Security event initial response and containment

**Escalation trigger - escalate to Tier 3 when:**

- Fault involves core network infrastructure beyond the scope of SMB administration
- A confirmed security incident requires forensic investigation or regulatory notification
- The fault cannot be resolved within available tooling and access
- A critical system requires vendor engagement
- The incident has organisation-wide impact with no clear resolution path

**Cannot escalate without:**

- Complete Tier 1 diagnostic package
- Tier 2 diagnostic findings appended
- Confirmed or suspected root cause at infrastructure level
- Impact assessment updated with current scope
- Proposed resolution approach and why it requires Tier 3

---

### Tier 3 - Senior Engineering / Vendor Support / Management

**Who operates here:** IT Manager, Senior Infrastructure Engineer, Security Engineer,
Third-Party Vendor Support

**Scope of authority:**

- Core infrastructure changes requiring full change management approval
- Vendor-managed system fault resolution
- Security incident response beyond containment
- Regulatory or compliance-related decisions
- Budget or procurement decisions triggered by hardware failure
- Business continuity decisions during major incidents

**Escalation trigger - escalate externally (vendor) when:**

- Fault is confirmed within a vendor-managed system or licensed platform
- Hardware failure requires manufacturer warranty or RMA process
- Software fault requires vendor patch or hotfix not yet publicly available

---

## Escalation Information Package

Every escalation - regardless of tier - must include the following. This is not optional.
An escalation without this package will be returned for completion.

### Required Escalation Fields

| Field | Content Required |
|---|---|
| **Ticket reference** | Ticket number from the ITSM platform |
| **Escalating technician** | Full name and tier |
| **Receiving technician / team** | Name or team being escalated to |
| **Escalation time** | Date and time of escalation |
| **Priority** | P1 / P2 / P3 / P4 |
| **Issue category** | From the triage classification list |
| **Scope** | Isolated / departmental / site-wide / organisation-wide |
| **Affected users** | Number and names or departments affected |
| **Problem statement** | Factual description - what is failing and how |
| **Timeline** | When the fault started and how it has progressed |
| **Hypothesis tested** | What the suspected cause was |
| **Diagnostic steps completed** | Every step taken, in order, with results |
| **Current system state** | What the system looks like right now |
| **Actions taken** | Everything already done, including reversals |
| **What is needed from Tier 2/3** | Specific ask - access, tooling, authority, vendor contact |
| **User deadline** | Any business deadline driving urgency |
| **Workaround status** | Whether a workaround is in place and what it is |

### Diagnostic Script Output

If a diagnostic script was run, attach the output file to the ticket and reference it in the
escalation package. Do not paste raw script output into the ticket notes field - attach it.

Scripts available for output attachment:

| Environment | Script | Output |
|---|---|---|
| Windows | `Get-SystemHealthReport.ps1` | System state snapshot |
| Windows | `Get-NetworkDiagnostics.ps1` | Network configuration and connectivity |
| Windows | `Get-EventLogSummary.ps1` | Recent errors and warnings |
| Linux | `system-health-report.sh` | System state snapshot |
| Linux | `network-diagnostics.sh` | Network configuration and connectivity |
| Linux | `log-summary.sh` | Recent log errors |

---

## Escalation by Issue Type

Use this table to identify the correct escalation path for each issue category.

| Issue Category | Tier 1 Limit | Escalate to Tier 2 When | Escalate to Tier 3 When |
|---|---|---|---|
| **Network connectivity** | Verify connectivity, check IP/DNS/gateway | Gateway unreachable, switch port fault, DHCP server fault | Core routing fault, ISP fault, firewall policy |
| **Network performance** | Run speed test, check interface stats | Sustained degradation across multiple users, switch congestion | WAN or ISP-level issue, core network fault |
| **Authentication / access** | Password reset, account unlock | AD account fault, GPO-related failure, MFA platform issue | Directory service corruption, identity platform outage |
| **Hardware fault** | Cable swap, peripheral replacement, reimage | Internal component failure (RAM, storage, motherboard) | Warranty / RMA process, bulk hardware failure |
| **Software / application** | Reinstall, repair, licence refresh | Licence server fault, application server-side fault | Vendor support engagement |
| **Operating system** | SFC, DISM, profile repair, OS repair | OS corruption beyond repair tools, domain join failure | OS reinstall decision, volume licence issue |
| **Printing** | Driver reinstall, queue clear, port check | Print server fault, shared printer infrastructure | Vendor support for managed print |
| **Email / communication** | Client reinstall, profile recreate | Mailbox fault, server-side delivery issue | Exchange / M365 tenant issue, vendor support |
| **Storage / file access** | Map drive, check permissions, verify share | File server fault, permission inheritance issue | Storage infrastructure fault |
| **Performance** | Identify process, close application, clear temp | Persistent high resource use linked to OS or background service | Hardware replacement decision |
| **Security event** | Isolate device, capture state, do not remediate | All security events escalate immediately | Confirmed breach, regulatory notification required |
| **Request / provisioning** | Standard account and software provisioning | Non-standard software, server provisioning | Budget approval, vendor procurement |

---

## Security Event Escalation - Special Rules

Security events follow different escalation rules from all other issue types.

**At Tier 1, when a security event is suspected:**

1. Do not attempt to diagnose or remediate
2. Isolate the affected device from the network immediately if possible
   - Windows: disable the network adapter via Device Manager
   - Linux: `sudo ip link set <interface> down`
3. Do not reboot the device - volatile memory evidence will be lost
4. Do not run standard diagnostic scripts on a suspected compromised device
5. Document exactly what the user reported and what you observed
6. Escalate to Tier 2 / Security immediately with the isolation status noted
7. Notify the user that the device is quarantined and provide a replacement if available

**Information required for security escalation:**

- Exact user action that triggered the event (link clicked, file opened, alert received)
- Time of the event
- Device name and current network isolation status
- Whether any other devices or users may have been exposed
- Whether any credentials were entered on a suspicious page or system

---

## Escalation Communication

When escalating, two communications are required:

### 1. Internal escalation message (to receiving technician or team)

Use the template in
[`../incidents/escalation-communication-templates.md`](../incidents/escalation-communication-templates.md).

The internal message must be direct and factual. It is a technical handoff, not a narrative.
Include the ticket reference in the subject or first line.

### 2. User update message

The user must be notified every time their ticket changes hands. At minimum, tell them:

- Their ticket has been escalated to a specialist team
- The reason (without technical detail they cannot act on)
- The updated response target
- Who their point of contact is while the ticket is with Tier 2 or Tier 3

**Example user update - P2 escalation:**

> "I've escalated your ticket [reference] to our systems team as the fault is on the server
> side and requires their access to resolve. They are aware of the urgency and will contact
> you within the hour. I'll remain your point of contact - please reach out to me if the
> situation changes."

**What not to say to the user during escalation:**

- Do not explain technical root cause in terms that alarm without informing
- Do not give revised resolution estimates you cannot guarantee
- Do not say "we don't know what's wrong" - say "we're investigating the root cause"
- Do not go silent - a user without an update will call back within 30 minutes

---

## Escalation Decision Tree

```
Fault identified during triage or diagnosis
              │
              ▼
   Is this a security event?
              │
    Yes ──────┼──────────────────────────────────────────────────────────►
              │                                      Isolate device
              │                                      Do not remediate
              │                                      Escalate to Tier 2 / Security immediately
              │
    No        ▼
   Is scope departmental or wider?
              │
    Yes ──────┼──────────────────────────────────────────────────────────►
              │                                      Raise incident
              │                                      Refer to incident-classification-guide.md
              │                                      Escalate to Tier 2
              │
    No        ▼
   Is priority P1 or P2?
              │
    Yes ──────┼──────────────────────────────────────────────────────────►
              │                                      Assign to senior technician immediately
              │                                      Do not queue
              │
    No        ▼
   Have all Tier 1 diagnostic steps been completed?
              │
    No  ──────┼──────────────────────────────────────────────────────────►
              │                                      Return to diagnosis
              │                                      Complete the diagnostic sequence
              │
    Yes       ▼
   Is root cause confirmed?
              │
    Yes ──────┼──────────────────────────────────────────────────────────►
              │          Does resolution require Tier 2 access or authority?
              │                    │
              │          Yes ──────►  Compile escalation package → escalate
              │          No  ──────►  Implement resolution at Tier 1
              │
    No        ▼
   Root cause unconfirmed after full Tier 1 diagnostic sequence
              │
              ▼
   Compile escalation package
   Escalate to Tier 2 with findings and current system state
```

---

## Escalation Quality Checklist

Before submitting any escalation, verify the following:

- [ ] Ticket reference is included
- [ ] Priority is assigned and justified
- [ ] Scope is confirmed - not assumed
- [ ] Problem statement is written in factual, observable terms
- [ ] All Tier 1 diagnostic steps are completed and results recorded
- [ ] Hypothesis is documented - even if unconfirmed
- [ ] Actions taken are listed in order with timestamps
- [ ] Current system state is documented
- [ ] Specific ask from Tier 2 / Tier 3 is stated clearly
- [ ] Diagnostic script output is attached if a script was run
- [ ] User has been notified of the escalation
- [ ] User has been given an updated response target

---

## Common Escalation Failures

| Failure | Effect | Prevention |
|---|---|---|
| Escalating before completing Tier 1 diagnostics | Wastes Tier 2 time on basic steps | Complete the full diagnostic sequence first |
| Escalating without a problem statement | Receiving tech must re-interview the user | Write the statement during triage |
| Escalating without listing actions taken | Tier 2 repeats steps already done | Record every action in the ticket |
| Escalating too late on a P1 | Resolution time breaches SLA | P1 escalates immediately - do not attempt extended Tier 1 diagnosis |
| Failing to notify the user | User calls back repeatedly | Send user update within 5 minutes of escalation |
| Vague escalation ask | Tier 2 does not know what you need | State specifically what access, action, or decision is needed |
| Escalating a security event through standard process | Delayed response to a breach | Security events bypass the standard queue always |

---

## Related Documents

| Document | Relationship |
|---|---|
| [`troubleshooting-methodology.md`](troubleshooting-methodology.md) | Step 5 of the methodology defines when to escalate |
| [`triage-decision-framework.md`](triage-decision-framework.md) | Step 5 of triage defines routing and escalation triggers |
| [`../incidents/incident-classification-guide.md`](../incidents/incident-classification-guide.md) | Used when scope triggers incident declaration |
| [`../incidents/escalation-communication-templates.md`](../incidents/escalation-communication-templates.md) | Message templates for internal and user escalation communication |
| [`../templates/ticket-template.md`](../templates/ticket-template.md) | Contains the escalation package fields in structured format |