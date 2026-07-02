# Change Request Template

## Purpose

This template provides a structured format for documenting a request to make a
controlled change to IT infrastructure, configuration, software, or services.
Change management exists for one reason: uncontrolled changes are the leading
cause of self-inflicted IT incidents in SMB environments.

Every change that modifies a production system - regardless of how small it seems -
should be documented before it is made. This template captures what will change,
why, what the risk is, how to reverse it, and how to confirm it worked. A change
that cannot be answered against these questions should not be made.

---

## When to Use This Template

Use this template before making any of the following types of changes:

- Network infrastructure configuration changes (switch, router, firewall, AP)
- Server configuration changes (OS, application, services, storage)
- DNS or DHCP server changes
- Active Directory / Group Policy changes
- Software deployment or removal affecting multiple users
- Scheduled maintenance requiring planned downtime
- Changes to shared printers, print servers, or shared services
- Security policy or firewall rule changes

**Changes that do not require a formal change request (standard changes):**

- Password resets for individual users
- Single-user software installation from approved list
- Printer driver reinstallation on a single workstation
- DHCP release/renew on a user workstation
- Standard ticket resolution not affecting shared infrastructure

If in doubt: if more than one user could be affected by the change going wrong,
use this template.

---

## CHANGE REQUEST TEMPLATE

```
================================================================================
IT CHANGE REQUEST
================================================================================

CHANGE REQUEST NUMBER:  [CR-YYYY-NNN - assigned sequentially, e.g. CR-2025-042]
DATE SUBMITTED:         [YYYY-MM-DD]
SUBMITTED BY:           [Technician name and role]
TICKET REFERENCE:       [Associated incident or service request ticket, if any]

────────────────────────────────────────────────────────────────────────────────
SECTION 1 - CHANGE CLASSIFICATION
────────────────────────────────────────────────────────────────────────────────

Change Type:

  [ ] Standard  - Pre-approved, low-risk, routine change (e.g. approved software
                  install, scheduled patch application per established schedule)
  [ ] Normal    - Requires review and approval before implementation
  [ ] Emergency - Urgent change required outside normal approval process to
                  resolve a P1/P2 incident (retrospective approval required)

Change Category:
  [ ] Network infrastructure
  [ ] Server / OS configuration
  [ ] Application / Software
  [ ] DNS / DHCP
  [ ] Active Directory / Group Policy
  [ ] Security / Firewall
  [ ] Storage / Backup
  [ ] Scheduled maintenance / Downtime
  [ ] Other: _____________________

Priority:       [High / Medium / Low]

────────────────────────────────────────────────────────────────────────────────
SECTION 2 - CHANGE DESCRIPTION
────────────────────────────────────────────────────────────────────────────────

Summary (one line):
  [Brief description - e.g. "Add monitoring alert for DHCP scope utilisation
  on SERVER01"]

Detailed Description:
  [Full description of what will change. Be specific - include:
  - Which system(s) will be affected
  - Which service, component, or configuration will change
  - What the current state is
  - What the target state will be after the change]

Current State:
  [Exact description of the configuration, setting, or state BEFORE the change]

Target State:
  [Exact description of the configuration, setting, or state AFTER the change]

Business Justification:
  [Why is this change needed? What problem does it solve or what improvement
  does it deliver? Reference the associated ticket if applicable.]

────────────────────────────────────────────────────────────────────────────────
SECTION 3 - IMPACT ASSESSMENT
────────────────────────────────────────────────────────────────────────────────

Systems Affected:
  [List every system, service, or component that will be directly or indirectly
  affected by this change]

Users Affected:
  [Number and description of users who may experience impact - including
  planned downtime or service interruption]

Estimated Downtime:
  [None expected / [Duration] expected for [service] - detail what will be
  unavailable and for how long]

Risk Level:        [High / Medium / Low]

Risk Assessment:
  [What could go wrong with this change? List specific failure scenarios and
  their likelihood. Do not write "Low risk" without explaining why.]

  Risk 1: [Description and likelihood]
  Risk 2: [Description and likelihood]
  Risk 3 (if applicable): [Description and likelihood]

Dependencies:
  [What must be true or in place before this change can be made?
  e.g. "Backup of SERVER01 must be completed and verified before proceeding."]

────────────────────────────────────────────────────────────────────────────────
SECTION 4 - IMPLEMENTATION PLAN
────────────────────────────────────────────────────────────────────────────────

Proposed Implementation Window:
  Date:     [YYYY-MM-DD]
  Time:     [HH:MM - HH:MM (local timezone)]
  Duration: [Estimated time to complete the change]

Reason for Chosen Window:
  [Why this time was chosen - e.g. "Outside business hours", "Lowest user
  activity period", "Before month-end close window"]

Implementation Steps:

  Step 1: [Specific action - include exact commands or settings where possible]
  Step 2: [Specific action]
  Step 3: [Specific action]
  Step 4: [Specific action]
  Step 5: [Specific action]
  (Continue for all steps)

Resources Required:
  [ ] Elevated/admin access to: [system name]
  [ ] Physical access to: [location]
  [ ] Vendor support engaged: [vendor name and reference]
  [ ] Second technician required for: [reason]
  [ ] Other: _____________________

Communication Plan:
  [Who will be notified before, during, and after the change, and via what
  channel - e.g. "Email to Department X at least 2 hours before maintenance
  window starts. IT manager notified at start and completion."]

────────────────────────────────────────────────────────────────────────────────
SECTION 5 - ROLLBACK PLAN
────────────────────────────────────────────────────────────────────────────────

[A change without a rollback plan must not proceed. Every controllable change
can be reversed - document exactly how.]

Rollback Trigger:
  [Under what conditions will rollback be initiated? Be specific.
  e.g. "If the service is not operational within 30 minutes of the change
  being applied, rollback will be initiated."]

Rollback Decision Authority:
  [Who has authority to call the rollback - e.g. "Lead technician on the
  change, or IT manager if unreachable."]

Rollback Steps:

  Step 1: [Specific reversal action]
  Step 2: [Specific reversal action]
  Step 3: [Specific reversal action]
  (Continue for all steps)

Rollback Duration:
  [Estimated time to fully roll back the change]

Rollback Limitations:
  [Are there any aspects of the change that cannot be fully rolled back?
  If so, document the residual state after rollback.
  If none: "Full rollback to current state is possible."]

────────────────────────────────────────────────────────────────────────────────
SECTION 6 - TESTING AND VERIFICATION
────────────────────────────────────────────────────────────────────────────────

[Document exactly how success will be confirmed after the change is applied.
"It seems to be working" is not a verification step.]

Success Criteria:
  [Specific, observable, measurable conditions that must be true for the
  change to be considered successful]

Verification Steps:

  Step 1: [Specific test - e.g. "Confirm DHCP service is running:
           Get-Service -Name DHCPServer | Select Status"]
  Step 2: [Specific test]
  Step 3: [Specific test]
  Step 4: [Specific test - user confirmation: "Confirm with [user/team]
           that [specific function] is working normally"]

Verification Time Required:
  [How long verification will take before the implementation window can be
  considered closed - e.g. "30 minutes of service monitoring after change"]

────────────────────────────────────────────────────────────────────────────────
SECTION 7 - APPROVAL
────────────────────────────────────────────────────────────────────────────────

Submitted By:
  Name:       [Technician name]
  Role:       [Role]
  Date:       [YYYY-MM-DD]
  Signature:  [If paper-based]

Reviewed By:
  Name:       [Reviewer name]
  Role:       [IT Lead / Manager]
  Date:       [YYYY-MM-DD]
  Decision:   [ ] Approved  [ ] Approved with conditions  [ ] Rejected
  Conditions / Reason:
              [If approved with conditions or rejected, state the conditions
              or reason here]

For Emergency Changes - Post-Implementation Approval:
  Name:       [Approver name]
  Role:       [IT Manager / Director]
  Date:       [YYYY-MM-DD]
  Decision:   [ ] Retrospectively approved  [ ] Rejected (rollback required)

────────────────────────────────────────────────────────────────────────────────
SECTION 8 - IMPLEMENTATION RECORD
────────────────────────────────────────────────────────────────────────────────

[Complete this section during and immediately after implementation.]

Implementation Start:    [YYYY-MM-DD HH:MM]
Implementation End:      [YYYY-MM-DD HH:MM]
Implemented By:          [Technician name]

Steps Completed:
  [ ] Step 1 - [brief description]     Time: [HH:MM]
  [ ] Step 2 - [brief description]     Time: [HH:MM]
  [ ] Step 3 - [brief description]     Time: [HH:MM]
  [ ] Step 4 - [brief description]     Time: [HH:MM]
  [ ] Step 5 - [brief description]     Time: [HH:MM]

Deviations from Plan:
  [Any step that was performed differently from the plan - document exactly
  what was done differently and why. "None" if the plan was followed exactly.]

Verification Results:
  [ ] Step 1 verified: [Result]
  [ ] Step 2 verified: [Result]
  [ ] Step 3 verified: [Result]
  [ ] Step 4 verified: [Result - user confirmation obtained]

Rollback Required:       [ ] Yes  [ ] No
If Yes - Rollback Completed:  [YYYY-MM-DD HH:MM]
Rollback Outcome:        [Full / Partial - describe residual state if partial]

Change Outcome:          [ ] Successful  [ ] Successful with issues noted
                         [ ] Rolled back  [ ] Failed - escalated

Notes:
  [Any observations, unexpected findings, or follow-up actions identified
  during implementation]

Closed By:               [Name]
Closure Time:            [YYYY-MM-DD HH:MM]

================================================================================
END OF CHANGE REQUEST
================================================================================
```

---

## Change Request Numbering

Maintain a sequential change request log to prevent duplicate numbers and provide
a searchable history. Use the format `CR-YYYY-NNN` where NNN resets each calendar
year:

```
CR-2025-001 - First change request of 2025
CR-2025-002 - Second change request of 2025
CR-2026-001 - First change request of 2026
```

Store the change request log as a running document or spreadsheet in your
IT documentation system, linked from each change request ticket.

---

## Emergency Change Process

Emergency changes bypass the standard pre-approval process when a P1/P2 incident
requires an immediate change to restore service. The process is:

1. The on-call or lead technician verbally authorises the emergency change
2. The change is implemented to restore service
3. The change request template is completed immediately after (within 2 hours)
4. Retrospective approval is obtained from the IT manager within 24 hours
5. The completed change request is attached to the incident ticket

Emergency changes are not exempt from documentation - they are exempt only from
pre-approval timing. All other fields must be completed.

---

## Security Considerations

- Changes to firewall rules, security policies, or access controls require
  security team review before approval regardless of other factors
- Changes that affect authentication or authorisation mechanisms (Active Directory,
  Group Policy, MFA configuration) require explicit approval from the IT manager
  or security lead - not just IT peer review
- The rollback plan for any security-related change must be reviewed to confirm
  that rollback does not inadvertently re-introduce a known vulnerability or
  security gap
- Emergency changes to security controls require the highest level of retrospective
  scrutiny - document the business justification for bypassing the pre-approval
  process explicitly in Section 7

---

## Related Documents

| Document | Relationship |
|---|---|
| [`ticket-template.md`](ticket-template.md) | Change requests are linked to incident or service request tickets |
| [`../incidents/incident-response-checklist.md`](../incidents/incident-response-checklist.md) | Phase 5 resolution may trigger a change request |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Changes requiring Tier 2 authority reference the escalation matrix |