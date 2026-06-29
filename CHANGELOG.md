# Changelog

All notable changes to this repository are documented here.

This changelog follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) formatting conventions.
Entries are ordered newest first within each version.

---

## Format Reference

Each entry uses one or more of the following change types:

| Type | Meaning |
|---|---|
| `Added` | New files, sections, scripts, or documentation |
| `Changed` | Updates to existing content or logic |
| `Fixed` | Corrections to errors, broken steps, or inaccurate guidance |
| `Removed` | Files or sections retired from the repository |
| `Security` | Changes related to safe handling, script safety, or access controls |
| `Deprecated` | Content still present but scheduled for removal or replacement |

---

## [Unreleased]

Changes staged for the next release are tracked here during active development.

### Added
- Initial repository structure established
- README with operational workflow, structure map, and usage guide
- CHANGELOG with format reference and versioning convention

---

## [0.1.0] - Repository Foundation

### Added

#### Core Files
- `README.md` - Repository entry point with full structure map, operational workflow diagram,
  script reference table, environment requirements, and methodology foundation summary
- `CHANGELOG.md` - This file. Tracks all repository changes with typed entries and version history
- `LICENSE` - MIT License authorizing free use and adaptation

#### Methodology
- `methodology/troubleshooting-methodology.md` - Structured seven-step troubleshooting approach
  grounded in CompTIA A+ methodology, extended with real-world help desk practice
- `methodology/triage-decision-framework.md` - Ticket intake and severity classification framework
  covering issue type identification, scope assessment, and priority assignment
- `methodology/escalation-matrix.md` - Escalation criteria, escalation paths by issue type,
  and required information for each escalation tier

#### Networking
- `networking/network-troubleshooting-guide.md` - OSI-layer fault isolation guide applied to
  practical help desk scenarios from physical cable checks through application-layer faults
- `networking/dns-dhcp-playbook.md` - Step-by-step DNS resolution failure and DHCP lease fault
  diagnosis with verification commands for both Windows and Linux
- `networking/wifi-diagnostic-guide.md` - Wi-Fi troubleshooting covering signal quality,
  authentication failures, IP assignment issues, and driver-related faults
- `networking/connectivity-fault-isolation.md` - Systematic connectivity fault isolation workflow
  from Layer 1 physical checks through Layer 7 application reachability

#### Playbooks
- `playbooks/no-network-connectivity.md` - Full resolution guide for complete network loss
- `playbooks/slow-network-performance.md` - Diagnosis and resolution for degraded network speed
- `playbooks/dns-resolution-failure.md` - DNS fault isolation and resolution steps
- `playbooks/user-cannot-login.md` - Login failure triage for Windows and Linux environments
- `playbooks/application-not-launching.md` - Application fault diagnosis and repair workflow
- `playbooks/printer-not-working.md` - Printer connectivity, driver, and queue fault resolution
- `playbooks/high-cpu-memory-usage.md` - Resource usage diagnosis and remediation guide

#### Scripts — Windows (PowerShell)
- `scripts/windows/Get-SystemHealthReport.ps1` - CPU, memory, disk, and uptime snapshot
- `scripts/windows/Get-NetworkDiagnostics.ps1` - IP configuration, DNS, gateway, and connectivity
- `scripts/windows/Get-DiskHealthReport.ps1` - Disk usage, volume health, and SMART status
- `scripts/windows/Get-EventLogSummary.ps1` - Recent errors and warnings from Windows Event Log
- `scripts/windows/Test-ConnectivitySuite.ps1` - Ping, DNS resolution, traceroute, and port tests

#### Scripts — Linux (Bash)
- `scripts/linux/system-health-report.sh` - CPU, memory, load average, and uptime snapshot
- `scripts/linux/network-diagnostics.sh` - Interface state, IP, DNS, and gateway diagnostics
- `scripts/linux/disk-health-report.sh` - Disk usage, mount points, and inode status
- `scripts/linux/log-summary.sh` - Recent errors extracted from system logs
- `scripts/linux/connectivity-suite.sh` - Ping, DNS, traceroute, and port reachability tests

#### Reference
- `reference/windows-command-reference.md` - Windows diagnostic commands organized by task
- `reference/linux-command-reference.md` - Linux diagnostic commands organized by task
- `reference/powershell-command-reference.md` - PowerShell cmdlets for IT support tasks
- `reference/network-ports-protocols.md` - Common ports and protocols for network fault diagnosis

#### Incidents
- `incidents/incident-classification-guide.md` - P1-P4 classification criteria and decision guide
- `incidents/incident-response-checklist.md` - Step-by-step incident handling checklist
- `incidents/escalation-communication-templates.md` - Stakeholder update message templates
- `incidents/post-incident-review-template.md` - Structured post-incident review format

#### Templates
- `templates/ticket-template.md` - Structured ticket format compatible with ITSM platforms
- `templates/diagnostic-report-template.md` - Diagnostic findings report for ticket attachment
- `templates/change-request-template.md` - Change request format for controlled modifications

#### Samples
- `samples/sample-diagnostic-report-windows.md` - Completed Windows diagnostic report example
- `samples/sample-diagnostic-report-linux.md` - Completed Linux diagnostic report example
- `samples/sample-completed-ticket.md` - Completed ticket example showing full lifecycle

---

## Versioning Convention

This repository uses a simplified semantic versioning approach suited to documentation and operational toolkits:

| Version Component | Meaning |
|---|---|
| Major (`1.x.x`) | Structural overhaul or complete section replacement |
| Minor (`x.1.x`) | New files, scripts, playbooks, or significant additions |
| Patch (`x.x.1`) | Corrections, clarifications, formatting fixes, minor updates |

Version `0.x.x` indicates the repository is in active initial build phase.
Version `1.0.0` will be tagged when all planned files are complete and verified.

---

## Commit Message Convention

All commits to this repository follow this format:

```
type: short description of change

Optional longer explanation if the change is non-obvious.
```

| Prefix | Used For |
|---|---|
| `docs:` | Documentation files (markdown) |
| `scripts:` | PowerShell or Bash script additions or changes |
| `fix:` | Corrections to any file |
| `refactor:` | Restructuring without content change |
| `chore:` | Housekeeping (license, changelog, gitignore) |

---

## Maintenance Notes

- All scripts are tested against their target OS before inclusion
- Playbooks are reviewed against current SMB IT support practices
- Network guides are aligned with CompTIA Network+ (10th Edition) methodology,
  extended where book content does not reflect current tooling
- Command references reflect tools available in stock OS installations without third-party software