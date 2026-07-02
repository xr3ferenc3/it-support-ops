# Post-Incident Review Template

## Purpose

This template provides a structured format for conducting and documenting a
post-incident review (PIR) - also known as a post-mortem or root cause analysis -
following the resolution of a significant IT incident.

The goal of a post-incident review is not to assign blame. It is to understand
exactly what happened, why it happened, and what concrete changes will prevent
recurrence. A PIR that identifies a person at fault but makes no system or
process change is worthless. A PIR that identifies a failure in a system or
process and produces a concrete prevention action is valuable.

---

## When to Conduct a Post-Incident Review

| Priority | PIR Required | Target Completion |
|---|---|---|
| P1 | Mandatory | Within 24 hours of resolution |
| P2 | Mandatory | Within 48 hours of resolution |
| P3 | Recommended when recurring (3+ tickets for same fault within 30 days) | Within 5 business days |
| P4 | Not required | N/A |

**Who should attend the PIR:**

- The technician(s) who handled the incident
- The Tier 2/3 engineer(s) if the incident was escalated
- The IT lead or manager
- The manager or representative of the most affected team (for P1)
- Any vendor representative if a third-party system was involved

---

## How to Use This Template

Complete every section. Sections that are left blank or marked "N/A" without
explanation undermine the value of the review. If a section genuinely does not
apply, state why in one sentence rather than leaving it empty.

The completed PIR is a permanent record. It should be attached to the incident
ticket and stored in the IT knowledge base or documentation system.

---

# POST-INCIDENT REVIEW

---

## Incident Identification

```
Incident Ticket Reference:   [Ticket Number]
Incident Priority:           [P1 / P2 / P3]
Service / System Affected:   [Name of the affected service or system]
PIR Completed By:            [Name and role of the person completing this document]
PIR Date:                    [Date the review was conducted]
PIR Participants:            [Names and roles of everyone who participated]
```

---

## Incident Timeline

Provide a factual, chronological timeline of key events from first impact to
full resolution. Use exact timestamps where available. This timeline is the
foundation of the entire review - it must be accurate and complete.

| Time | Event |
|---|---|
| [datetime] | First impact - [what happened or what changed] |
| [datetime] | First report received by IT - [who reported, how] |
| [datetime] | Incident declared - [by whom, at what priority] |
| [datetime] | Initial notification sent to [users/stakeholders] |
| [datetime] | Diagnosis started - [assigned to whom] |
| [datetime] | Root cause identified - [brief description] |
| [datetime] | Fix implemented - [brief description of action taken] |
| [datetime] | Service confirmed restored - [by whom, how verified] |
| [datetime] | Resolution notification sent |
| [datetime] | Incident ticket closed |

**Total duration (impact to resolution):** [Calculate from first impact to confirmed restoration]

**Detection gap:** [Time between first impact and first report/detection - if >0, note why]

---

## Impact Assessment

```
Users affected:             [Confirmed number]
Business functions affected:[Which teams, processes, or commitments were disrupted]
Data affected:              [Any data loss, corruption, or exposure - or "None confirmed"]
Financial impact:           [Estimated cost of downtime if known - or "Not calculated"]
SLA breached:               [Yes / No - if yes, which SLA and by how long]
Workaround available:       [Was a workaround in place - describe or "No"]
Workaround effective:       [Did the workaround meaningfully reduce impact - Yes / No]
```

---

## Root Cause Analysis

### Immediate Cause

The immediate cause is the specific technical event or failure that directly
caused the incident. This is what happened, not why it happened.

```
Immediate cause:

[One to three sentences describing the specific technical event.
Example: "The DHCP service on SERVER01 stopped responding after the log
partition reached 100% capacity, preventing new IP leases from being issued."]
```

### Contributing Factors

Contributing factors are the conditions that allowed the immediate cause to occur
or that made its impact worse. A single incident often has multiple contributing
factors. List each one.

```
Contributing factor 1:
[Description]

Contributing factor 2:
[Description]

Contributing factor 3 (if applicable):
[Description]
```

**Example contributing factors to consider:**

- Was monitoring in place that should have detected the condition earlier?
- Was a maintenance window missed or overdue?
- Was a known risk accepted without mitigation?
- Was a configuration change made without sufficient testing or change management?
- Was documentation absent or incorrect, leading to incorrect assumptions?
- Was a vendor patch or firmware update pending?
- Was capacity planning insufficient?

### Root Cause Statement

The root cause statement is a single, clear sentence that identifies the
underlying reason the incident occurred. It must be specific enough that a
prevention action can be directly derived from it.

```
Root cause:

[One sentence. It should answer "why did the immediate cause occur?"
Example: "The log partition on SERVER01 was not included in the standard
capacity monitoring configuration when the server was provisioned 18 months ago,
allowing it to fill without alerting."]
```

**Root cause quality check:**

A valid root cause statement satisfies all three:
1. It explains why the immediate cause occurred (not just what happened)
2. It is specific enough to generate a concrete prevention action
3. Fixing it would prevent this specific incident from recurring in the same way

---

## What Went Well

Document what worked correctly during the incident response. This section is
not optional - understanding what worked helps preserve those practices and
prevents them from being accidentally removed in process changes.

```
1. [What went well - e.g. "The monitoring alert fired within 5 minutes of
   the service becoming unavailable, enabling rapid detection."]

2. [What went well - e.g. "The workaround was identified and communicated to
   users within 20 minutes, significantly reducing business impact."]

3. [What went well]
```

---

## What Could Have Been Better

Document what slowed down detection, diagnosis, or resolution. Be factual and
specific - this section should describe process or system failures, not personal
failures.

```
1. [What could be improved - e.g. "The DHCP server's log partition was not
   included in capacity monitoring, which allowed the condition to develop
   undetected over several weeks."]

2. [What could be improved - e.g. "The on-call escalation path was unclear -
   two technicians contacted the same senior engineer independently, creating
   confusion about who was leading the response."]

3. [What could be improved]
```

---

## Prevention Actions

Prevention actions are specific, concrete changes that will reduce the probability
or impact of this type of incident recurring. Each action must have an owner and
a due date - actions without ownership do not get completed.

| # | Action | Owner | Due Date | Status |
|---|---|---|---|---|
| 1 | [Specific action - e.g. "Add DHCP server log partition to capacity monitoring dashboard with 80% free space alert threshold"] | [Name] | [Date] | Open |
| 2 | [Specific action] | [Name] | [Date] | Open |
| 3 | [Specific action] | [Name] | [Date] | Open |

**Prevention action quality check:**

A valid prevention action:
- Directly addresses the root cause or a contributing factor
- Is specific enough to be verifiably completed
- Has a single named owner
- Has a realistic due date

Vague prevention actions that are not valid:
- "Monitor the system more closely" - not specific
- "Ensure better documentation" - not specific
- "Raise awareness with the team" - not measurable

---

## Monitoring and Detection Improvements

If monitoring, alerting, or detection could have identified this condition earlier
or faster, document the specific improvement needed.

```
Was an alert fired before the incident was user-reported?
[Yes / No]

If No - should an alert have fired?
[Yes / No - explain]

Monitoring improvement required:
[Specific alert, threshold, or monitoring coverage addition needed.
Or: "No monitoring improvement required - condition was not detectable in advance."]
```

---

## Documentation and Knowledge Base

| Item | Action Required |
|---|---|
| Known error documented in knowledge base? | [Yes - link / No - create entry] |
| Runbook or playbook update required? | [Yes - which document / No] |
| Architectural or configuration diagram update required? | [Yes - which diagram / No] |
| New playbook required for this scenario? | [Yes - assigned to / No] |

---

## Communication Review

| Communication | Sent on Time | Effective | Improvement Needed |
|---|---|---|---|
| Initial user notification | [Yes/No] | [Yes/No] | [Description or "None"] |
| Stakeholder notification | [Yes/No] | [Yes/No] | [Description or "None"] |
| Status updates | [Yes/No] | [Yes/No] | [Description or "None"] |
| Resolution notification | [Yes/No] | [Yes/No] | [Description or "None"] |

---

## Response Effectiveness Assessment

Rate the incident response against each dimension. Use: Effective / Partially
Effective / Needs Improvement.

| Dimension | Rating | Notes |
|---|---|---|
| Detection speed | | |
| Initial classification accuracy | | |
| Communication timeliness | | |
| Diagnostic speed | | |
| Escalation appropriateness | | |
| Resolution speed | | |
| Workaround availability | | |
| Documentation quality during incident | | |

---

## Summary and Sign-Off

```
Summary statement:

[2–3 sentences summarising what happened, what caused it, and what
is being done to prevent recurrence. This is the text used in the
management summary communication template.]


PIR completed by:    [Name]
Role:                [Role]
Date:                [Date]

Reviewed by:         [IT Lead / Manager Name]
Date:                [Date]

Incident ticket:     [Ticket Number]
PIR stored at:       [Location - knowledge base link or document path]
```

---

## Action Tracking

At the next IT team meeting or review cycle following this PIR, confirm the
status of each prevention action identified above. Update the status column
in the Prevention Actions table to: Open / In Progress / Completed / Deferred.

A PIR is not complete until all prevention actions are confirmed completed or
formally deferred with documented justification.

---

## Security Considerations

- Post-incident review documents may contain sensitive information about
  infrastructure vulnerabilities, system architecture, and security controls -
  store and share according to your organisation's information classification policy
- For security incidents, the PIR may be subject to legal hold, regulatory
  disclosure requirements, or attorney-client privilege - consult with management
  and legal counsel before distributing widely
- Never include specific exploit details, credential information, or attack
  methodology in a PIR that will be stored in a broadly accessible location
- The blameless PIR principle is both an ethical commitment and a practical one -
  organisations that punish individuals for incidents documented in PIRs receive
  less honest information in future reviews, which makes them less safe

---

## Related Documents

| Document | Relationship |
|---|---|
| [`incident-classification-guide.md`](incident-classification-guide.md) | Priority that determines PIR requirement |
| [`incident-response-checklist.md`](incident-response-checklist.md) | Phase 8 triggers and schedules the PIR |
| [`escalation-communication-templates.md`](escalation-communication-templates.md) | Template 7 uses the PIR summary for management communication |
| [`../templates/ticket-template.md`](../templates/ticket-template.md) | Incident ticket the PIR is attached to |