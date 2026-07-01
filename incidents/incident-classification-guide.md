# Incident Classification Guide

## Purpose

This guide defines how to classify an IT support situation as an incident, assign
a priority level (P1–P4), and make the initial decisions that determine how the
incident is handled from that point forward.

Classification is the most consequential decision in incident management. An
incorrectly classified incident either over-escalates low-impact events (wasting
senior engineering time) or under-escalates high-impact events (leaving users or
business operations without appropriate response). This guide removes ambiguity
from that decision.

---

## When to Use This Guide

Use this guide when:

- A ticket is received that may affect more than one user or system
- Multiple tickets arrive simultaneously with similar symptoms
- A single ticket describes a fault in a shared or business-critical service
- A monitoring alert indicates a service or infrastructure component is down
- Triage identifies a scope that is departmental, site-wide, or organisation-wide
- A security event is suspected or confirmed

This guide is referenced from:
- [`../methodology/triage-decision-framework.md`](../methodology/triage-decision-framework.md) Step 3 (scope assessment)
- [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) (incident triggers)

---

## Incident vs. Service Request vs. Standard Ticket

Not every problem is an incident. Classification begins with determining which
category the situation falls into.

| Category | Definition | Example | Handling |
|---|---|---|---|
| **Standard ticket** | A fault affecting one user or device with no shared service impact | User's application crashes | Follow relevant playbook |
| **Service request** | A request for something new - no fault | New user account, software install | Route to provisioning queue |
| **Incident** | A fault affecting or potentially affecting multiple users, a shared service, or a business-critical system | Email server unavailable, network switch offline | Follow this guide |
| **Major incident** | An incident with significant business impact, executive visibility, or regulatory implication | Data breach, prolonged site-wide outage | Escalate to Tier 3 immediately |

---

## Step 1 - Identify Whether This Is an Incident

Answer these questions in order:

```
1. Does the fault affect more than one user or device?
      Yes → Potential incident - continue to Step 2
      No  → Check Step 1b before treating as standard ticket

1b. Is the affected service shared by multiple users even if only one
    user has reported it?
      Yes → Potential incident - continue to Step 2
            (One report does not mean one impact - others may not have
             reported yet or may not yet be affected)
      No  → Treat as standard ticket per relevant playbook

2. Does the fault affect a business-critical service?
   (email, file sharing, internet access, ERP, finance systems,
    authentication, core networking infrastructure)
      Yes → Incident - continue to Step 3
      No  → Assess scope at Step 3 before deciding

3. Is a security event suspected or confirmed?
      Yes → Incident - escalate immediately regardless of scope
            See security event handling below
      No  → Continue to Step 3
```

---

## Step 2 - Confirm Incident Scope

Scope is the number of affected users, systems, or locations. Confirming scope
determines priority and escalation path.

| Scope Level | Definition |
|---|---|
| **Isolated** | One user or device - not incident criteria unless service is shared |
| **Departmental** | Multiple users in one team, floor, or location |
| **Site-wide** | All users at one physical location |
| **Organisation-wide** | Multiple sites or all users across the organisation |

**How to confirm scope quickly:**

```
1. Check the ticket queue - are other tickets arriving with the same symptom?
2. Ask the reporting user to check with one or two colleagues immediately
3. Check any monitoring platform for alerts (if available)
4. Attempt to replicate the fault from a different device on the same network
5. Check the affected service from IT's own device or system
```

Once scope is confirmed (not assumed), proceed to priority assignment.

---

## Step 3 - Assign Priority (P1–P4)

Priority is determined by **impact** (how many people/systems are affected and
how severely) crossed with **urgency** (how quickly the situation will worsen
and how time-critical the business function is).

### Priority Definitions

---

**P1 - Critical**

| Criteria | Detail |
|---|---|
| Impact | Business-critical service completely unavailable for multiple users or the whole organisation |
| Urgency | Revenue, safety, regulatory compliance, or legal obligation directly at risk |
| Workaround | None available |
| Examples | Email server down, core network switch offline, finance system unavailable during month-end close, confirmed security breach, site-wide internet outage |

Response target: Immediate - work begins within 15 minutes of declaration.
Resolution target: 4 hours or escalate to Tier 3.
Stakeholder notification: Required within 30 minutes of declaration.
Out-of-hours response: Yes - escalate to on-call if outside business hours.

---

**P2 - High**

| Criteria | Detail |
|---|---|
| Impact | Significant fault affecting one or more users with no acceptable workaround, or a critical user/role fully impacted |
| Urgency | Business function is materially impaired; a deadline or business commitment is at risk |
| Workaround | None, or a workaround exists but is operationally unacceptable |
| Examples | Senior manager or on-call engineer cannot access email, VPN unavailable for remote team during critical work period, shared printer offline for department with an imminent deadline |

Response target: Within 1 hour.
Resolution target: 8 hours or next business day if discovered late in the working day.
Stakeholder notification: Affected manager notified at declaration.
Out-of-hours response: Yes, for P2 affecting on-call or business-critical roles.

---

**P3 - Medium**

| Criteria | Detail |
|---|---|
| Impact | A fault affecting one or several users where a workaround is available and core work can continue |
| Urgency | Business impact is real but manageable; no immediate deadline at risk |
| Workaround | Available and operationally acceptable |
| Examples | User's second monitor not working (can work on primary), non-critical application unavailable, slow network speed on one workstation |

Response target: Within 4 hours.
Resolution target: 3 business days.
Stakeholder notification: Not required unless the fault worsens.
Out-of-hours response: No - next business day.

---

**P4 - Low**

| Criteria | Detail |
|---|---|
| Impact | Minor inconvenience with no meaningful productivity impact |
| Urgency | No time pressure |
| Workaround | Not needed or already in use naturally |
| Examples | Cosmetic display issue, keyboard shortcut preference, non-urgent software feature request, cable management issue |

Response target: Within 1 business day.
Resolution target: 5 business days or next maintenance window.
Stakeholder notification: Not required.
Out-of-hours response: No.

---

### Priority Decision Matrix

```
                   HIGH URGENCY         LOW URGENCY
HIGH IMPACT    │   P1 - Critical    │   P2 - High    │
LOW IMPACT     │   P3 - Medium      │   P4 - Low     │
```

**When in doubt, assign the higher priority and review.** It is always better to
over-escalate and revise downward than to under-escalate and miss a SLA or cause
a preventable business impact.

---

## Step 4 - Declare the Incident

Once priority is confirmed, formally declare the incident by:

1. Creating an incident ticket (separate from any individual user tickets that
   triggered the identification)
2. Recording the classification: priority, scope, affected service, and time of
   declaration
3. Linking any related individual tickets to the incident ticket
4. Notifying the appropriate tier immediately per the escalation matrix

**Incident ticket minimum required fields at declaration:**

```
Priority:          P1 / P2 / P3 / P4
Time Declared:     [datetime]
Affected Service:  [service name]
Scope:             Isolated / Departmental / Site-wide / Organisation-wide
Affected Users:    [number or description]
Reported By:       [name or ticket reference]
Assigned To:       [technician or team]
Initial Assessment:[brief description of what is known at time of declaration]
Workaround:        [description, or "None"]
```

---

## Security Event Classification - Special Rules

Security events follow a separate classification path that bypasses the standard
priority matrix.

**Treat as a security incident and escalate immediately if any of the following are
observed or reported:**

- User clicked a suspicious link or opened an unexpected attachment
- Unexpected account activity or login from an unfamiliar location
- Ransomware behaviour (files being renamed, encryption notices appearing)
- Antivirus or endpoint protection quarantined an item
- Unexpected outbound network traffic from a device
- User reports being asked to provide credentials on an unfamiliar site
- Device behaving abnormally (unexpected processes, spontaneous reboots, unusual
  network activity)
- Any report of data being accessed, copied, or exfiltrated without authorisation

**Security incident immediate actions (Tier 1):**

1. Isolate the affected device from the network immediately if possible
2. Do not reboot the device - volatile memory evidence is lost on reboot
3. Do not run standard diagnostic scripts on the suspected device
4. Document exactly what was reported and what you observed
5. Escalate to Tier 2 / Security immediately - declare P1 regardless of apparent scope
6. Notify the user that the device is quarantined and provide a replacement if available

See [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) for
the full security event escalation procedure and required information.

---

## Recurring Incident Pattern

A standard ticket becomes an incident candidate if it is a recurring fault that
was previously "resolved" without identifying root cause. Three or more tickets
for the same symptom on the same system or for the same user within 30 days is a
pattern that warrants incident-level handling for root cause elimination.

**Root cause investigation is not optional for recurring incidents.** A recurring
fault is evidence that the previous resolution addressed symptoms, not cause. Escalate
to Tier 2 for root cause investigation rather than applying the same surface fix again.

---

## Downgrading an Incident

An incident can be downgraded in priority if:

- Scope is confirmed to be narrower than initially assessed
- A workaround is confirmed to be operationally acceptable
- The business impact is confirmed to be lower than initially assessed

**Always document the reason for a priority downgrade in the incident ticket.**
A downgrade without justification cannot be reviewed and may be reversed by a
senior technician or manager.

---

## Classification Common Errors

| Error | Effect | Prevention |
|---|---|---|
| Treating a shared service fault as an isolated ticket | Delayed response to a wider impact | Always check whether the affected service is shared before classifying |
| Assigning priority based on user urgency rather than business impact | P4 tasks block P1 resolution | Use the impact × urgency matrix, not the user's tone |
| Waiting for multiple reports before declaring | Extended impact while waiting for confirmation | One report of a shared service fault is sufficient to begin incident assessment |
| Not linking related tickets to the incident | Fragmented picture of scope | Always search for and link related tickets at declaration |
| Closing an incident before root cause is identified | Recurrence | Incidents do not close without a confirmed root cause |

---

## Related Documents

| Document | Relationship |
|---|---|
| [`incident-response-checklist.md`](incident-response-checklist.md) | Step-by-step handling after classification |
| [`escalation-communication-templates.md`](escalation-communication-templates.md) | Stakeholder notification messages |
| [`post-incident-review-template.md`](post-incident-review-template.md) | Root cause and prevention documentation after closure |
| [`../methodology/triage-decision-framework.md`](../methodology/triage-decision-framework.md) | Triage process that feeds into incident classification |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Escalation paths by tier and issue type |
| [`../templates/ticket-template.md`](../templates/ticket-template.md) | Ticket format used for incident records |