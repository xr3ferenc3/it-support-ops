# Escalation and Incident Communication Templates

## Purpose

This document provides ready-to-use message templates for the communications
required during incident handling and ticket escalation. Templates cover the
full lifecycle: initial notification, status updates, escalation handoff,
resolution notification, and post-incident summary.

Consistent, professional communication during an incident reduces user anxiety,
keeps stakeholders informed, and prevents the repeated "what's happening?" calls
that disrupt active troubleshooting. Using a template does not make communication
impersonal - it makes it reliable and complete.

---

## When to Use This Document

Use these templates at the following points in the incident lifecycle:

| Template | When Used | Referenced From |
|---|---|---|
| Initial User Notification | Phase 2 of incident response | `incident-response-checklist.md` |
| Stakeholder Notification (P1/P2) | Phase 2 - priority incidents | `incident-response-checklist.md` |
| Internal Escalation to Tier 2 | Phase 4 - escalation | `incident-response-checklist.md` |
| Status Update | Every 30 minutes during P1 | `incident-response-checklist.md` |
| Workaround Communication | When a workaround becomes available | Any phase |
| Resolution Notification | Phase 6 - recovery communication | `incident-response-checklist.md` |
| Post-Incident Summary | After PIR is complete | `post-incident-review-template.md` |

---

## Template Usage Instructions

Each template includes:

- **[BRACKETS]** for fields to replace with actual information
- **Notes** on what level of technical detail is appropriate for the audience
- **Guidance** on tone and what not to include

**General rules for all incident communications:**

1. Use confirmed facts only - never speculate about root cause in user-facing messages
2. Always include a ticket reference number
3. Always give a next action or next update time - never leave users without
   a "what happens next"
4. Keep user-facing messages in plain language - avoid technical jargon
5. Internal technical messages to Tier 2 can and should include full technical detail

---

## Template 1 - Initial User / Department Notification

**Audience:** Affected users or their manager
**Timing:** Within 15 minutes (P1), 30 minutes (P2), 2 hours (P3) of declaration
**Channel:** Email or ITSM portal notification - phone if P1

---

**Subject:** IT Service Issue - [Service Name] - [Date]

Dear [Name / Team],

We are aware that [Service Name / "some users"] are currently experiencing
[brief plain-language description of the symptom - e.g. "difficulty accessing
email" / "issues connecting to the shared drive" / "problems with internet access"].

We are investigating the cause and are working to restore normal service as
quickly as possible.

**Ticket reference:** [Ticket Number]
**Priority:** [P1 / P2 / P3]

[If a workaround is available:]
**Workaround:** While we investigate, you can [workaround description - e.g.
"access your email via the web browser at [URL]" / "save files locally to your
desktop until the shared drive is restored"].

We will provide an update by [specific time - e.g. "12:30 PM" or "within
the next 30 minutes"].

If you have urgent questions, please contact the IT help desk at [contact number
or channel] and quote ticket reference [Ticket Number].

Regards,
[Your Name]
IT Support

---

**What not to include in this message:**
- Root cause speculation ("we think the server crashed")
- Technical details the user cannot act on
- Overly optimistic resolution estimates you cannot guarantee
- Any information about a security event beyond "we are investigating a service issue"

---

## Template 2 - Stakeholder Notification (P1 / P2)

**Audience:** Department heads, management, business owners of the affected service
**Timing:** Within 30 minutes of P1 declaration; within 1 hour of P2 declaration
**Channel:** Email, then phone confirmation for P1

---

**Subject:** [P1/P2] IT Incident - [Service Name] - [Date] - [Time]

[Name],

I am writing to notify you of a [P1 Critical / P2 High] priority IT incident
that is currently affecting [affected service or function].

**Incident summary:**
- **Service affected:** [Service Name]
- **Impact:** [Plain-language description - e.g. "All staff at [location] are
  unable to access the shared drive" / "Email is unavailable for the [Department]
  team"]
- **Users affected:** Approximately [number] users
- **Time of impact:** [datetime - when the fault started]
- **Ticket reference:** [Ticket Number]

**Current status:** We are actively investigating the root cause. [If Tier 2 is
involved:] Our senior technical team is engaged.

**Workaround:** [Available workaround, or "No workaround is currently available."]

**Next update:** I will provide a further update at [specific time], or sooner
if the situation changes.

Please contact me directly at [contact number] if you need to discuss this further.

[Your Name]
IT Support - [Your Role]

---

## Template 3 - Internal Escalation to Tier 2

**Audience:** Senior technician, systems administrator, or Tier 2 team
**Timing:** Immediately when escalation criteria are met (Phase 4)
**Channel:** ITSM platform escalation + direct contact (phone/message for P1)

---

**Subject:** ESCALATION - [Ticket Number] - [P1/P2/P3] - [Service/System Name]

Hi [Name / Team],

Please see the escalation detail below for ticket [Ticket Number]. I have
completed Tier 1 diagnostic steps and require [specific ask - e.g. "server-side
access to diagnose the DHCP service" / "review of the Active Directory account
lockout source" / "investigation of the core switch at [location]"].

**Escalation package:**

```
Ticket Reference:    [Number]
Priority:            [P1/P2/P3]
Incident Declared:   [datetime]
Assigned From:       [Your Name]

AFFECTED SCOPE:
  Service:           [Service name]
  Users affected:    [Number and description]
  Scope level:       [Isolated/Departmental/Site-wide/Organisation-wide]

SYMPTOM DESCRIPTION:
  [Factual, observable description of what is happening]
  [Include exact error messages if visible]
  [Include when it started and any known correlation to a change event]

DIAGNOSTIC STEPS COMPLETED:
  [Step 1 - what was tested - result]
  [Step 2 - what was tested - result]
  [Step 3 - what was tested - result]
  (Continue for all steps performed)

HYPOTHESIS:
  [What you believe the root cause is and why]
  [Or: Root cause unconfirmed - explain what you ruled out]

CURRENT SYSTEM STATE:
  [IP configuration, service status, error log findings, or other relevant
  current state data]

WORKAROUND:
  [In place and active / None available]

DIAGNOSTIC OUTPUT:
  [Attached to ticket: Yes/No - list which scripts were run]

ESCALATION REQUEST:
  [Specific action or access needed from Tier 2]

BUSINESS IMPACT:
  [Current number of affected users / business function at risk]
  [Any deadline or time constraint]
```

Diagnostic script output is attached to the ticket. Please confirm receipt and
let me know if you need any additional information.

[Your Name]
[Contact number]

---

## Template 4 - Status Update (P1 - Every 30 Minutes)

**Audience:** Affected users and/or stakeholders notified at Phase 2
**Timing:** Every 30 minutes during a P1 incident until resolution
**Channel:** Same channel as initial notification (email, ITSM portal)

---

**Subject:** UPDATE [#N] - IT Incident - [Service Name] - [Date] [Time]

Dear [Name / Team],

This is update [number, e.g. "2 of [ongoing]"] on the IT incident affecting
[Service Name] (ticket reference [Ticket Number]).

**Current status:** [One of the following:]
- We are continuing to investigate the root cause.
- We have identified [brief factual description of finding] and are working on
  a resolution.
- We have implemented a fix and are verifying it has resolved the issue.

**Time of last change:** [datetime of most recent action taken]

[If workaround status has changed:]
**Workaround update:** [New workaround available / Existing workaround still in place]

**Next update:** [specific time]

[Your Name]
IT Support - [Your Role]
Ticket: [Ticket Number]

---

**What not to include in status updates:**
- Speculation about when it will be fixed if you do not know
- Detailed technical root cause language in user-facing updates
- Blame attribution (toward vendors, other teams, or specific individuals)

---

## Template 5 - Workaround Communication

**Audience:** Affected users
**Timing:** As soon as a workaround is confirmed available
**Channel:** Email or ITSM portal notification

---

**Subject:** WORKAROUND AVAILABLE - [Service Name] issue - [Ticket Number]

Dear [Name / Team],

While we continue to investigate and resolve the issue affecting [Service Name]
(ticket [Ticket Number]), a workaround is now available that will allow you to
continue working.

**Workaround steps:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

[Note any limitations of the workaround - e.g. "Note: Files saved using this
method will need to be moved to the shared drive once it is restored."]

We will notify you when the full service has been restored and the workaround
is no longer necessary.

[Your Name]
IT Support

---

## Template 6 - Resolution Notification

**Audience:** Affected users and stakeholders
**Timing:** As soon as service is confirmed restored (Phase 6)
**Channel:** Email and ITSM portal notification

---

**Subject:** RESOLVED - IT Incident - [Service Name] - [Date]

Dear [Name / Team],

We are pleased to confirm that the IT incident affecting [Service Name] (ticket
reference [Ticket Number]) has been resolved. Service was restored at [time].

**Summary:**
- **Service affected:** [Service Name]
- **Impact period:** [Start datetime] to [End datetime] ([duration])
- **Users affected:** Approximately [number]
- **Resolution:** [Plain-language description of what was done - e.g.
  "The service has been restored following a configuration change to the
  [component]." Avoid technical detail that would not be meaningful to
  the audience.]

If you are still experiencing any issues, please contact the IT help desk
at [contact] and quote ticket reference [Ticket Number].

We apologise for the disruption this caused to your work. [For P1/P2:]
We will be conducting a review of this incident to identify steps to prevent
recurrence.

[Your Name]
IT Support - [Your Role]

---

## Template 7 - Post-Incident Summary to Management

**Audience:** IT management, affected department heads
**Timing:** After the post-incident review is complete
**Channel:** Email

---

**Subject:** Post-Incident Review Summary - [Service Name] - [Date of Incident]

[Name],

Following the IT incident on [date] affecting [Service Name], we have completed
our post-incident review. Please find the summary below.

**Incident overview:**
- **Service affected:** [Service Name]
- **Priority:** [P1/P2]
- **Duration:** [Start to resolution - total time]
- **Users affected:** Approximately [number]
- **Root cause:** [Factual, non-jargon description of the root cause]

**What happened:**
[2–3 sentence plain-language timeline of the incident - onset, discovery,
escalation, and resolution]

**What we are doing to prevent recurrence:**

| Action | Owner | Due Date |
|---|---|---|
| [Prevention action 1] | [Name] | [Date] |
| [Prevention action 2] | [Name] | [Date] |

**Full post-incident review document:** Available on request - ticket reference
[Ticket Number].

Please let me know if you have any questions or would like to discuss this
further.

[Your Name]
IT Support - [Your Role]

---

## Communication Timing Summary

| Priority | Initial Notification | Status Updates | Resolution Notification |
|---|---|---|---|
| P1 | ≤15 minutes | Every 30 minutes | Immediately on resolution |
| P2 | ≤30 minutes | Every 60 minutes | Within 30 minutes of resolution |
| P3 | ≤2 hours | If duration exceeds 1 business day | Within 2 hours of resolution |
| P4 | ≤1 business day | Not required | At ticket closure |

---

## Security Considerations

- Never include specific details of a security event (nature of breach, data affected,
  affected systems by name) in general user-facing notifications - coordinate all
  security incident communications with the security team and management before sending
- Resolution notifications for security incidents should be reviewed by management
  before distribution - they may be subject to legal or regulatory requirements
- Do not communicate root cause of a security incident to general users - this
  information should be limited to need-to-know parties
- All incident communications are business records - use professional language,
  state facts only, and avoid anything that could create legal liability

---

## Related Documents

| Document | Relationship |
|---|---|
| [`incident-classification-guide.md`](incident-classification-guide.md) | Priority classification that determines notification timing |
| [`incident-response-checklist.md`](incident-response-checklist.md) | References these templates at Phases 2, 4, and 6 |
| [`post-incident-review-template.md`](post-incident-review-template.md) | Source for the management summary template (Template 7) |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Escalation criteria that trigger Template 3 |