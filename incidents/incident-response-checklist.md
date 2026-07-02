# Incident Response Checklist

## Purpose

This checklist provides a structured, sequential guide for handling an IT incident
from the moment it is declared through to closure and post-incident review. It is
designed to be worked through in order during a live incident - not read as a
reference document after the fact.

Incidents fail to be resolved cleanly when steps are skipped, communications are
delayed, or actions are taken without a record. This checklist prevents all three.

---

## When to Use This Checklist

Use this checklist immediately after an incident is declared per
[`incident-classification-guide.md`](incident-classification-guide.md). It applies
to all priority levels (P1–P4), with P1 and P2 incidents requiring tighter timeframes
and additional stakeholder communication steps.

Print or open this document alongside the incident ticket. Work through each phase
in order. Check each item as it is completed and timestamp actions in the incident
ticket as you go.

---

## Phase 1 - Detection and Declaration

Complete this phase within 15 minutes of identifying a potential incident.

- [ ] Confirm the fault is an incident (not a standard ticket) per
      [`incident-classification-guide.md`](incident-classification-guide.md)
- [ ] Assign priority: P1 / P2 / P3 / P4
- [ ] Confirm scope: Isolated / Departmental / Site-wide / Organisation-wide
- [ ] Identify the affected service or system
- [ ] Record the time of first impact (when the fault started, not when it was reported)
- [ ] Record the time of incident declaration
- [ ] Create the incident ticket with all required fields
- [ ] Link any related individual tickets to the incident ticket

**Incident ticket required fields at declaration:**

```
Priority:          [P1/P2/P3/P4]
Time of Impact:    [datetime - when the fault started]
Time Declared:     [datetime - when incident was formally declared]
Affected Service:  [service or system name]
Scope:             [Isolated/Departmental/Site-wide/Organisation-wide]
Affected Users:    [number and description]
Reported By:       [user name or ticket reference]
Assigned To:       [technician name]
Initial Assessment:[what is known at time of declaration]
Workaround:        [available workaround, or "None"]
```

**Security event check:**
- [ ] If a security event is suspected, stop here and follow the security event
      procedure in [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md)
      before continuing with this checklist

---

## Phase 2 - Initial Communication

Complete initial communications within the timeframes below based on priority.

| Priority | User/Stakeholder Notification | IT Lead Notification |
|---|---|---|
| P1 | Within 15 minutes of declaration | Immediately - call if necessary |
| P2 | Within 30 minutes of declaration | Within 15 minutes |
| P3 | Within 2 hours | Within 1 hour |
| P4 | Within 1 business day | Not required unless requested |

- [ ] Notify affected users or their manager of the incident and expected response time
- [ ] Notify IT lead or senior technician per the priority timeframe above
- [ ] If P1: notify relevant business stakeholders (department heads, management)
      per your organisation's escalation contact list
- [ ] If a workaround is available, communicate it to affected users immediately
- [ ] Record all communication actions and timestamps in the incident ticket

Use templates from
[`escalation-communication-templates.md`](escalation-communication-templates.md)
for initial and update notifications.

---

## Phase 3 - Investigation and Diagnosis

- [ ] Assign the incident to the appropriate technician or team for investigation
- [ ] Confirm the affected service, system, or infrastructure component
- [ ] Gather current diagnostic data using relevant scripts:

**Windows:**
```powershell
# Collect system health snapshot
.\scripts\windows\Get-SystemHealthReport.ps1

# Collect network diagnostic snapshot
.\scripts\windows\Get-NetworkDiagnostics.ps1

# Collect event log summary
.\scripts\windows\Get-EventLogSummary.ps1
```

**Linux:**
```bash
# Collect system health snapshot
./scripts/linux/system-health-report.sh

# Collect network diagnostic snapshot
./scripts/linux/network-diagnostics.sh

# Collect log summary
./scripts/linux/log-summary.sh
```

- [ ] Attach diagnostic script output to the incident ticket
- [ ] Confirm the scope - is it wider or narrower than initially assessed?
      Update the incident ticket if scope changes
- [ ] Form a hypothesis about root cause (document in ticket before testing)
- [ ] Test the hypothesis - one change at a time
- [ ] Record every test performed and its result in the incident ticket with timestamps
- [ ] If root cause is not confirmed after Tier 1 diagnostic steps:
      escalate to Tier 2 with full diagnostic package

**Escalation diagnostic package (must be complete before escalating):**

```
Incident ticket reference:    [number]
Priority:                     [P1/P2/P3/P4]
Scope (confirmed):            [scope level]
Affected users/systems:       [list]
Time of impact:               [datetime]
Symptom description:          [factual, observable]
Hypothesis tested:            [what was suspected and why]
Tests performed:              [every step, in order, with results]
Current system state:         [what the system looks like right now]
Workaround in place:          [yes/no - describe if yes]
Specific escalation request:  [what Tier 2 is being asked to do]
Diagnostic output attached:   [yes/no]
```

---

## Phase 4 - Escalation (If Required)

- [ ] Confirm all Tier 1 diagnostic steps are complete before escalating
- [ ] Complete the escalation diagnostic package above
- [ ] Contact Tier 2 using the internal escalation communication template from
      [`escalation-communication-templates.md`](escalation-communication-templates.md)
- [ ] Notify affected users that the incident has been escalated and provide an
      updated expected resolution time
- [ ] Remain available to Tier 2 for context - do not consider the incident handed off
      until Tier 2 confirms receipt
- [ ] Continue updating the incident ticket during Tier 2 investigation
- [ ] If P1 and Tier 2 escalation is not resolving within the target time:
      escalate to Tier 3 / management

---

## Phase 5 - Resolution

- [ ] Confirm the fix resolves the root cause, not just the symptom
- [ ] Test the resolution from the user's perspective - not just from the IT side
- [ ] Confirm the fix does not introduce a new issue elsewhere
- [ ] If a workaround was in place, confirm it has been removed and the permanent
      fix is in effect
- [ ] Ask affected users to confirm the service is working for their specific tasks
- [ ] Verify from multiple affected users if the incident was departmental or wider
- [ ] Record the resolution action and time in the incident ticket

---

## Phase 6 - Recovery Communication

Once the service is confirmed restored, communicate to all affected parties.

- [ ] Notify affected users that the service has been restored
- [ ] Confirm what was done to restore the service (at an appropriate level of
      technical detail for the audience)
- [ ] If a P1 or P2: send a formal resolution notification to business stakeholders
- [ ] If any data loss or data integrity concern exists: notify data owner and
      management immediately - do not include this in a general user notification

Use templates from
[`escalation-communication-templates.md`](escalation-communication-templates.md)
for resolution notifications.

- [ ] Record the time of service restoration in the incident ticket
- [ ] Record the time of resolution notification in the incident ticket

---

## Phase 7 - Incident Closure

Do not close the incident ticket until all of the following are confirmed:

- [ ] Service is confirmed restored for all affected users (not just the original reporter)
- [ ] Root cause is identified and documented - "we restarted the service" is not a
      root cause; "the service crashed due to a disk full condition on the log partition"
      is a root cause
- [ ] Resolution action is documented (what was done, when, by whom)
- [ ] All workarounds have been removed or formally noted as pending permanent fix
- [ ] A post-incident review has been scheduled (mandatory for P1 and P2; recommended
      for P3 with a recurring pattern)
- [ ] All related individual tickets have been updated and closed or linked to the
      incident for closure
- [ ] Time of incident closure is recorded in the ticket

**Minimum ticket documentation before closure:**

```
Root Cause:           [specific technical reason the fault occurred]
Resolution Action:    [what was done to fix it, and when]
Resolution Time:      [datetime service was confirmed restored]
Total Duration:       [time from first impact to restoration]
Users Affected:       [final confirmed count]
Workaround Used:      [yes/no - if yes, describe]
Post-Incident Review: [scheduled/not required - with date if scheduled]
Prevention Action:    [what will prevent recurrence - or reason if none identified]
Closed By:            [technician name]
Closure Time:         [datetime]
```

---

## Phase 8 - Post-Incident Review

Mandatory for P1 and P2. Recommended for recurring P3 incidents.

- [ ] Schedule the post-incident review within 48 hours of resolution (while details
      are still fresh for all participants)
- [ ] Include the technician(s) who handled the incident, the Tier 2/3 team if
      escalated, and the affected team lead or manager
- [ ] Complete [`post-incident-review-template.md`](post-incident-review-template.md)
      as the structured output of the review
- [ ] Identify at least one concrete prevention action from the review
- [ ] Assign ownership of each prevention action with a due date
- [ ] Share the completed PIR with IT management and relevant stakeholders

---

## P1-Specific Additional Requirements

P1 incidents have additional requirements beyond the standard checklist.

- [ ] Incident commander assigned - one named person owns the P1 from declaration
      to closure, even if multiple technicians are working on it
- [ ] Status updates issued every 30 minutes to affected stakeholders until resolution
      (use the status update template in
      [`escalation-communication-templates.md`](escalation-communication-templates.md))
- [ ] All actions logged in real time - no "will update later" during a P1
- [ ] Management notified within 30 minutes of declaration
- [ ] Post-incident review mandatory - to be completed within 24 hours of resolution
- [ ] RCA (Root Cause Analysis) document produced as the post-incident review output

---

## Checklist Completion Tracking

Use this block at the top of your incident ticket notes to track phase completion:

```
INCIDENT RESPONSE CHECKLIST STATUS

Phase 1 - Detection and Declaration:  [ ] COMPLETE  Time: ___________
Phase 2 - Initial Communication:      [ ] COMPLETE  Time: ___________
Phase 3 - Investigation/Diagnosis:    [ ] COMPLETE  Time: ___________
Phase 4 - Escalation (if required):   [ ] COMPLETE  Time: ___________
Phase 5 - Resolution:                 [ ] COMPLETE  Time: ___________
Phase 6 - Recovery Communication:     [ ] COMPLETE  Time: ___________
Phase 7 - Incident Closure:           [ ] COMPLETE  Time: ___________
Phase 8 - Post-Incident Review:       [ ] SCHEDULED  Date: __________

Total Duration (Impact to Resolution): ___________
```

---

## Security Considerations

- During a P1 incident, communication should be limited to confirmed facts only -
  speculating about root cause in stakeholder updates damages credibility and may
  cause unnecessary alarm
- If a security incident is involved, communications should be coordinated with the
  security team before distribution - premature disclosure of a breach may alert
  threat actors or create legal liability
- Incident ticket contents may be subject to discovery in legal proceedings - record
  facts, not opinions or unverified speculation
- All actions taken during the incident (including those that were reversed) must be
  recorded - a complete audit trail is required for both operational learning and
  potential regulatory review

---

## Related Documents

| Document | Relationship |
|---|---|
| [`incident-classification-guide.md`](incident-classification-guide.md) | Produces the priority and scope used at Phase 1 |
| [`escalation-communication-templates.md`](escalation-communication-templates.md) | Message templates used at Phases 2, 4, and 6 |
| [`post-incident-review-template.md`](post-incident-review-template.md) | Structured output of Phase 8 |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Escalation procedures used at Phase 4 |
| [`../templates/ticket-template.md`](../templates/ticket-template.md) | Ticket format for incident records |