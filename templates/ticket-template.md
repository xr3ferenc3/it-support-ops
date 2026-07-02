# IT Support Ticket Template

## Purpose

This template provides a structured format for documenting IT support tickets from
initial intake through to closure. It is compatible with ITSM platforms such as
ServiceNow, Jira Service Management, Freshservice, and Zendesk - the field names
align with standard ITSM terminology used across these platforms.

A well-documented ticket is the primary evidence of professional IT support work.
It enables faster resolution on repeat issues, supports escalation with complete
information, and demonstrates operational discipline to anyone who reviews the
ticket history.

---

## How to Use This Template

Copy the template below into the ticket body or notes field of your ITSM platform.
Complete all fields at intake; update progressive fields (diagnosis, actions, resolution)
as the ticket progresses. Do not leave fields blank - if a field is genuinely not
applicable, write "N/A" with a brief reason.

---

## TICKET TEMPLATE

```
================================================================================
IT SUPPORT TICKET
================================================================================

TICKET REFERENCE:   [Auto-assigned by ITSM platform, or manual if paper-based]
DATE CREATED:       [YYYY-MM-DD HH:MM]
CREATED BY:         [Technician name]

────────────────────────────────────────────────────────────────────────────────
SECTION 1 - REQUESTER INFORMATION
────────────────────────────────────────────────────────────────────────────────

Requester Name:       [Full name]
Department:           [Team or department]
Location:             [Building, floor, desk number, or remote]
Contact Number:       [Phone or extension]
Contact Email:        [Email address]
Preferred Contact:    [Phone / Email / ITSM portal]

────────────────────────────────────────────────────────────────────────────────
SECTION 2 - ASSET INFORMATION
────────────────────────────────────────────────────────────────────────────────

Device Hostname:      [Computer name - from System Properties or hostname command]
Asset Tag:            [Physical asset tag number if applicable]
Operating System:     [Windows 10/11, Ubuntu 22.04, etc.]
Device Type:          [Laptop / Desktop / Workstation / Server / Mobile / Printer]
Serial Number:        [If relevant - particularly for hardware faults]
Connection Type:      [Wired / Wi-Fi / VPN / Remote / N/A]

────────────────────────────────────────────────────────────────────────────────
SECTION 3 - ISSUE CLASSIFICATION
────────────────────────────────────────────────────────────────────────────────

Category:             [Network / Hardware / Software / Authentication / Printing /
                       Email / Storage / Performance / Security / Request / Other]

Priority:             [P1 - Critical / P2 - High / P3 - Medium / P4 - Low]

Priority Justification:
  [Brief explanation of why this priority was assigned - number of users affected,
  business function impacted, deadline risk, etc.]

SLA Target Response:  [≤15 min (P1) / ≤1hr (P2) / ≤4hr (P3) / ≤1 day (P4)]
SLA Target Resolve:   [4hr (P1) / 8hr (P2) / 3 days (P3) / 5 days (P4)]

────────────────────────────────────────────────────────────────────────────────
SECTION 4 - PROBLEM DESCRIPTION
────────────────────────────────────────────────────────────────────────────────

Summary (one line):
  [Brief description suitable for ticket list view - e.g. "User cannot access
  shared drive - APIPA address detected on wired connection"]

Detailed Description:
  [Full description of the reported problem in the user's own words where possible.
  Include what the user cannot do, not just what they observe.]

Exact Error Message (if any):
  [Copy the exact error text or attach a screenshot - do not paraphrase]

When Did It Start:
  [Date and time, or "unknown - first noticed at [time]"]

Is It Reproducible:
  [Always / Sometimes / Happened once / Cannot reproduce]

Recent Changes:
  [Anything the user changed or that changed in their environment before this
  started - software updates, moved location, password change, new hardware, etc.]

Other Users Affected:
  [Yes - [description] / No - confirmed / Unknown - not checked]

Actions Taken by User:
  [What the user already tried before contacting IT - reboots, cable checks, etc.]

────────────────────────────────────────────────────────────────────────────────
SECTION 5 - DIAGNOSIS
────────────────────────────────────────────────────────────────────────────────

Triage Assessment:
  [Summary of triage decision - issue type, scope confirmed, priority reasoning]

Hypothesis:
  [Most probable cause based on the evidence at intake - be specific]

Diagnostic Steps Taken:
  [Each step in order, with timestamp and result]

  [YYYY-MM-DD HH:MM] Step 1: [What was tested / checked]
    Result: [Exact result - pass/fail, output, observation]

  [YYYY-MM-DD HH:MM] Step 2: [What was tested / checked]
    Result: [Exact result]

  [YYYY-MM-DD HH:MM] Step 3: [What was tested / checked]
    Result: [Exact result]

  (Continue for all steps taken)

Root Cause Confirmed:
  [Yes - [description of confirmed root cause]
   No - [reason unconfirmed, and what escalation is planned]]

Diagnostic Output Attached:
  [Yes - [list scripts run and filenames] / No]

────────────────────────────────────────────────────────────────────────────────
SECTION 6 - RESOLUTION
────────────────────────────────────────────────────────────────────────────────

Resolution Action:
  [Exactly what was done to resolve the fault - specific commands run, settings
  changed, hardware replaced, or configuration updated]

Resolution Time:
  [YYYY-MM-DD HH:MM - when the fix was applied]

Verification Method:
  [How it was confirmed the fix worked - test performed, user confirmation,
  script re-run, etc.]

User Confirmation:
  [Yes - user confirmed resolution at [HH:MM] / No - could not reach user -
  follow-up scheduled]

Workaround Applied:
  [Yes - [describe workaround and whether a permanent fix is pending] / No]

────────────────────────────────────────────────────────────────────────────────
SECTION 7 - ESCALATION (COMPLETE IF ESCALATED)
────────────────────────────────────────────────────────────────────────────────

Escalated:            [Yes / No]
Escalation Time:      [YYYY-MM-DD HH:MM]
Escalated To:         [Tier 2 technician name or team]
Escalation Reason:    [Why escalation was required - access, skill, scope, etc.]
Escalation Package:   [Attached - Yes / No]
Tier 2 Resolution:    [What Tier 2 did to resolve the fault]
Returned to Tier 1:   [Yes - at [time] / No - resolved at Tier 2]

────────────────────────────────────────────────────────────────────────────────
SECTION 8 - CLOSURE
────────────────────────────────────────────────────────────────────────────────

Root Cause (final):
  [Confirmed root cause - must be specific. "We restarted the service" is not
  a root cause. "The print spooler service crashed due to a corrupted spool
  file from an incomplete print job on [date]" is a root cause.]

Recurrence Risk:
  [High / Medium / Low - and why]

Prevention Recommendation:
  [Specific action that would prevent this from recurring - or "None identified"
  with justification. Do not leave blank.]

Knowledge Base Entry Required:
  [Yes - [topic and assigned author] / No - already documented at [link]]

Related Tickets:
  [List any related ticket numbers - recurring issues, same user, same asset]

Closed By:            [Technician name]
Closure Time:         [YYYY-MM-DD HH:MM]
Total Time Open:      [Duration from created to closed]
Resolution Category:  [Fixed / Workaround / User Education / No Fault Found /
                       Duplicate / Referred to Third Party]

================================================================================
END OF TICKET
================================================================================
```

---

## Field Completion Standards

| Field | Standard |
|---|---|
| Summary | Maximum 120 characters - must be searchable and meaningful |
| Detailed description | Minimum 2 sentences - enough for a second technician to act without contacting the user |
| Exact error message | Verbatim - never paraphrase error messages |
| Diagnostic steps | Timestamped - every step, in order, with its result |
| Root cause | Specific and factual - must answer "why did this happen" not "what happened" |
| Prevention recommendation | Actionable - must be something concrete, not "be more careful" |

---

## Common Completion Errors

| Error | Why It Matters | Standard |
|---|---|---|
| Paraphrased error message | Loses diagnostic detail needed for future reference | Copy exact text or attach screenshot |
| Missing timestamps on diagnostic steps | Cannot reconstruct the response timeline | Timestamp every action |
| "User confirmed" without contact method | Unverifiable | Record how and when confirmation was obtained |
| Vague root cause ("service issue", "software problem") | No learning value, cannot prevent recurrence | Must be technically specific |
| Blank prevention recommendation | Recurrence is preventable and will not be prevented | Always record something - even "no prevention action available due to third-party dependency" |
| Closing without user confirmation | User may still have the fault | Confirm before closing or schedule follow-up |

---

## Relationship to Other Repository Components

| Component | How It Uses This Template |
|---|---|
| `methodology/troubleshooting-methodology.md` | Seven steps map to Sections 4, 5, 6, and 8 |
| `methodology/triage-decision-framework.md` | Output populates Sections 3 and 4 |
| `methodology/escalation-matrix.md` | Escalation package populates Section 7 |
| `scripts/windows/` and `scripts/linux/` | Diagnostic output is attached per Section 5 |
| `incidents/incident-response-checklist.md` | Incident tickets use this template with Sections 1–8 all required |

---

## Security Considerations

- Never record credentials, passwords, or authentication tokens in a ticket -
  these are frequently accessible to multiple people and are not stored securely
  in ITSM platforms
- Ticket contents should be classified at the level of the most sensitive
  information they contain - a ticket referencing a security event may need
  access restricted to the security team
- Resolution actions that include configuration changes should record what was
  changed and from what value to what value - this creates an audit trail and
  enables reversal if the change causes issues
- Do not close a security-related ticket without confirming with the security
  team that closure is appropriate - some security events require extended
  monitoring after initial resolution