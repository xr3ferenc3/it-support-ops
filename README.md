# IT Support Operations Center (`it-support-ops`)

> A structured IT support operations toolkit demonstrating professional troubleshooting methodology,
> network diagnostics, endpoint triage, scripted automation, and incident documentation -
> built to reflect real help desk and desktop support environments.

---

## Purpose

This repository is an operational reference system for IT support technicians working in small-to-medium business (SMB) environments.

It is not a study guide. It is not a cheat sheet collection. It is a structured system built around how IT support work actually happens - from the moment a ticket arrives to the moment an incident is closed and reviewed.

Every file exists to solve a real operational problem:

- Inconsistent troubleshooting that misses root cause
- Slow ticket triage that delays resolution
- Network faults diagnosed by guesswork instead of methodology
- Scripts that run but produce no usable output
- Escalations with insufficient information
- Incidents that repeat because nothing was documented

This system addresses all of them.

---

## Who This Is For

| Role | How to Use This Repository |
|---|---|
| IT Support Technician | Daily reference for triage, scripts, and playbooks |
| Service Desk Analyst | Ticket templates, escalation guides, incident classification |
| Desktop Support Technician | Endpoint playbooks, diagnostic scripts, repair workflows |
| Junior IT Administrator | Network troubleshooting guides, command references, methodology |
| Field IT Technician | Quick-reference playbooks and connectivity diagnostics |

---

## Repository Structure

```
it-support-ops/
│
├── README.md                         ← You are here
├── CHANGELOG.md                      ← Development and update history
├── LICENSE                           ← MIT License
│
├── methodology/                      ← How to think before you act
│   ├── troubleshooting-methodology.md
│   ├── triage-decision-framework.md
│   └── escalation-matrix.md
│
├── networking/                       ← Network fault isolation guides
│   ├── network-troubleshooting-guide.md
│   ├── dns-dhcp-playbook.md
│   ├── wifi-diagnostic-guide.md
│   └── connectivity-fault-isolation.md
│
├── playbooks/                        ← Scenario-specific resolution guides
│   ├── no-network-connectivity.md
│   ├── slow-network-performance.md
│   ├── dns-resolution-failure.md
│   ├── user-cannot-login.md
│   ├── application-not-launching.md
│   ├── printer-not-working.md
│   └── high-cpu-memory-usage.md
│
├── scripts/
│   ├── windows/                      ← PowerShell diagnostic and automation scripts
│   │   ├── Get-SystemHealthReport.ps1
│   │   ├── Get-NetworkDiagnostics.ps1
│   │   ├── Get-DiskHealthReport.ps1
│   │   ├── Get-EventLogSummary.ps1
│   │   └── Test-ConnectivitySuite.ps1
│   └── linux/                        ← Bash diagnostic and automation scripts
│       ├── system-health-report.sh
│       ├── network-diagnostics.sh
│       ├── disk-health-report.sh
│       ├── log-summary.sh
│       └── connectivity-suite.sh
│
├── reference/                        ← Operational command references
│   ├── windows-command-reference.md
│   ├── linux-command-reference.md
│   ├── powershell-command-reference.md
│   └── network-ports-protocols.md
│
├── incidents/                        ← Incident handling documentation
│   ├── incident-classification-guide.md
│   ├── incident-response-checklist.md
│   ├── escalation-communication-templates.md
│   └── post-incident-review-template.md
│
├── templates/                        ← Reusable operational templates
│   ├── ticket-template.md
│   ├── diagnostic-report-template.md
│   └── change-request-template.md
│
└── samples/                          ← Completed examples of templates in use
    ├── sample-diagnostic-report-windows.md
    ├── sample-diagnostic-report-linux.md
    └── sample-completed-ticket.md
```

---

## How to Use This System

### When a ticket arrives

1. Open [`methodology/triage-decision-framework.md`](methodology/triage-decision-framework.md)
2. Classify the issue by type and severity
3. Navigate to the relevant playbook in [`playbooks/`](playbooks/)
4. Run the appropriate diagnostic script from [`scripts/`](scripts/)
5. Document findings using [`templates/diagnostic-report-template.md`](templates/diagnostic-report-template.md)
6. Resolve or escalate using [`methodology/escalation-matrix.md`](methodology/escalation-matrix.md)
7. Close the ticket using [`templates/ticket-template.md`](templates/ticket-template.md)

### When a network fault is reported

1. Open [`networking/network-troubleshooting-guide.md`](networking/network-troubleshooting-guide.md)
2. Begin OSI-layer fault isolation at Layer 1
3. For DNS or DHCP faults: [`networking/dns-dhcp-playbook.md`](networking/dns-dhcp-playbook.md)
4. For Wi-Fi issues: [`networking/wifi-diagnostic-guide.md`](networking/wifi-diagnostic-guide.md)
5. Run [`scripts/windows/Get-NetworkDiagnostics.ps1`](scripts/windows/Get-NetworkDiagnostics.ps1) or [`scripts/linux/network-diagnostics.sh`](scripts/linux/network-diagnostics.sh)
6. Attach script output to ticket before escalating

### When an incident is declared

1. Open [`incidents/incident-classification-guide.md`](incidents/incident-classification-guide.md)
2. Assign priority: P1, P2, P3, or P4
3. Follow [`incidents/incident-response-checklist.md`](incidents/incident-response-checklist.md)
4. Use [`incidents/escalation-communication-templates.md`](incidents/escalation-communication-templates.md) for stakeholder updates
5. Complete [`incidents/post-incident-review-template.md`](incidents/post-incident-review-template.md) after resolution

---

## Operational Workflow

```
Ticket received
      │
      ▼
Triage and classify
(methodology/triage-decision-framework.md)
      │
      ├── Network issue? ──► networking/ → relevant script
      │
      ├── Endpoint issue? ──► playbooks/ → relevant script
      │
      └── Incident? ──► incidents/ → escalation templates
                │
                ▼
        Document findings
        (templates/diagnostic-report-template.md)
                │
                ▼
        Resolved? ──► Close ticket (templates/ticket-template.md)
                │
        Not resolved? ──► Escalate with diagnostic output
                │
                ▼
        Post-incident review
        (incidents/post-incident-review-template.md)
```

---

## Scripts at a Glance

### Windows (PowerShell)

| Script | Purpose | Run As |
|---|---|---|
| `Get-SystemHealthReport.ps1` | CPU, memory, disk, uptime snapshot | Standard user |
| `Get-NetworkDiagnostics.ps1` | IP config, DNS, gateway, connectivity | Standard user |
| `Get-DiskHealthReport.ps1` | Disk usage, SMART status, volume health | Standard user |
| `Get-EventLogSummary.ps1` | Recent errors and warnings from Event Log | Standard user |
| `Test-ConnectivitySuite.ps1` | Ping, DNS, traceroute, port reachability | Standard user |

### Linux (Bash)

| Script | Purpose | Run As |
|---|---|---|
| `system-health-report.sh` | CPU, memory, load, uptime snapshot | Standard user |
| `network-diagnostics.sh` | Interface state, IP, DNS, gateway | Standard user |
| `disk-health-report.sh` | Disk usage, mount points, inode status | Standard user |
| `log-summary.sh` | Recent errors from system logs | Standard user |
| `connectivity-suite.sh` | Ping, DNS, traceroute, port reachability | Standard user |

All scripts are safe for standard user execution. No script requires administrative privileges to run its core diagnostic function. Where elevated access improves output, this is clearly noted in the script header.

---

## Environment Requirements

| Requirement | Detail |
|---|---|
| **Windows** | Windows 10 or Windows 11, PowerShell 5.1 or later |
| **Linux** | Any systemd-based distribution (Ubuntu 20.04+, Debian 11+, RHEL/CentOS 8+) |
| **Hardware** | Any laptop or desktop capable of running the OS |
| **Network access** | Not required for most scripts - designed for offline diagnostic use |
| **Cloud services** | None required |
| **Virtualization** | None required |
| **Third-party tools** | None required - built-in OS tools only |

---

## Knowledge Foundation

This system was built using the following foundational references, extended with current industry-standard IT support practices:

- *CompTIA A+ Guide to IT Technical Support*, 11th Edition - Andrews, Shelton, Pierce
- *CompTIA Network+ Guide to Networks*, 10th Edition - West

Where book guidance reflects outdated practices, the relevant file notes the deviation and explains the modern approach.

---

## Methodology Foundation

All troubleshooting workflows follow a structured methodology:

1. **Define the problem** - Gather facts before touching anything
2. **Identify the scope** - One user or many? One system or the network?
3. **Form a hypothesis** - Most probable cause first, based on evidence
4. **Test the hypothesis** - One change at a time
5. **Document as you go** - Notes during the ticket, not after
6. **Resolve or escalate** - With evidence, not assumptions
7. **Prevent recurrence** - Root cause, not just symptom

This sequence is not optional. It is what separates structured technicians from those who run random commands and hope something changes.

---

## Security Considerations

- No script in this repository modifies system configuration without explicit user action
- No script collects or transmits data outside the local system
- No credentials, tokens, or sensitive values are stored in any file
- Scripts write logs to a local output directory only
- All scripts clearly state their actions in inline comments

---

## License

MIT License. See [`LICENSE`](LICENSE) for full terms.

This repository is intended for educational and professional portfolio purposes.
Adapt any component freely for use in real IT support environments.

---

## Author Note

This repository represents how I approach IT support work: systematically, with documented reasoning, and with the end user's resolution time as the primary measure of success.

Every file in this system reflects a real operational need. Nothing was added for appearance.