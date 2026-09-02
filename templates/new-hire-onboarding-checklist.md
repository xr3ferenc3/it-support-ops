# New Hire Onboarding Checklist

## Purpose

This checklist ensures a new employee's IT provisioning is complete, correct, and
ready before their first day - not assembled reactively while they sit unable to
work. A missed step here doesn't surface as an obvious fault; it surfaces as a new
hire's first impression of the organization being "IT wasn't ready for me," which is
disproportionately damaging to morale for how small the underlying task usually is.

This is a **service request**, not an incident - see
[`../incidents/incident-classification-guide.md`](../incidents/incident-classification-guide.md)
for that distinction. It should be triggered by HR/manager notification with enough
lead time to complete before day one, not by the new hire's own first ticket.

---

## When to Use This Checklist

Use this checklist when:

- HR or a hiring manager notifies IT of a confirmed start date for a new employee
- A contractor or temporary worker requires provisioning for a defined engagement

Trigger this **at least 3-5 business days before the start date** wherever possible.
Same-day or next-day onboarding requests should still use this checklist in full;
they simply compress the timeline and may require prioritizing hardware procurement
or expedited account creation.

---

## Required Information Before Starting

| Field | Source |
|---|---|
| Full legal name | HR |
| Start date | HR / hiring manager |
| Department and manager | HR |
| Job title / role | HR |
| Required access level / role template | Manager, mapped to your organization's role-based access groups |
| Work location (office, remote, hybrid) | HR / manager |
| Equipment requirements (standard laptop, specific software, peripherals) | Manager |
| Employment type (full-time, contractor, temporary) | HR - affects account expiration policy |

**Do not begin account creation without a confirmed start date and manager approval
of access level.** Provisioning ahead of confirmed approval risks granting access
that is later hard to reconcile with what was actually authorized.

---

## ONBOARDING CHECKLIST

### Phase 1 - Account and Identity (complete 3-5 days before start date)

- [ ] Create user account in identity platform (on-prem AD and/or Entra ID as applicable)
- [ ] Set account expiration date if employment type is contractor/temporary
- [ ] Assign to correct organizational unit / security groups per role template
- [ ] Generate temporary initial password following organizational policy - do not
      reuse a predictable pattern (e.g. company name + birth year)
- [ ] Register the account for MFA enrollment (to be completed by the user on day one,
      not pre-configured on their behalf)
- [ ] Create mailbox and assign to correct distribution lists / shared mailboxes per role
- [ ] Provision licenses (Microsoft 365, or equivalent productivity suite) matching role requirements

### Phase 2 - Hardware and Endpoint (complete 1-3 days before start date)

- [ ] Confirm hardware availability (laptop/desktop, monitor, peripherals) - order if
      not in stock, accounting for lead time
- [ ] Image/configure device with standard organizational build
- [ ] Enroll device in device management (Intune or equivalent) and confirm compliance
      policy applies correctly before handoff
- [ ] Install required standard software per role template
- [ ] Install and license any role-specific software identified by the manager
- [ ] Label/tag asset and record in asset inventory with serial number, assigned user,
      and assignment date
- [ ] Test the device end-to-end: login, network/Wi-Fi connectivity, VPN if required,
      printer access, and core applications launch correctly

### Phase 3 - Access Provisioning (complete 1-2 days before start date)

- [ ] Grant access to required file shares / SharePoint sites / shared drives per role
- [ ] Grant access to required line-of-business applications
- [ ] Provision phone/extension or softphone if role requires it
- [ ] Add to relevant Teams/Slack channels or equivalent collaboration spaces per manager guidance
- [ ] Confirm building/badge access request has been submitted to facilities if
      applicable (often outside IT's direct control, but worth confirming it's not
      been missed)

### Phase 4 - Day One

- [ ] Deliver device and credentials to the new hire (in person or via manager, per
      organizational process) - never send initial credentials and account details
      together in the same channel (e.g. don't email both the username and the
      temporary password in the same message)
- [ ] Walk the new hire through first login and force password change
- [ ] Assist with MFA enrollment
- [ ] Confirm the new hire can access: email, core applications, file shares, and any
      role-specific tools
- [ ] Provide basic orientation on how to submit future IT tickets
- [ ] Record completion date and confirm with the hiring manager that provisioning is
      fully functional

---

## Escalation Criteria

Escalate to Tier 2 / IT management when:

- [ ] Required hardware cannot be procured in time for the start date
- [ ] Access level requested by the manager conflicts with standard role templates and
  needs an exception approval
- [ ] License availability is insufficient for the required software
- [ ] The role requires access to a system outside standard IT administration (e.g. a
  specialized industry application requiring vendor-side provisioning)

---

## Verification Checklist

- [ ] All Phase 1-3 items completed before start date
- [ ] Device tested end-to-end before handoff, not assumed working from imaging alone
- [ ] New hire successfully logged in, changed password, and enrolled MFA on day one
- [ ] New hire confirmed access to all systems required for their role
- [ ] Asset recorded in inventory with correct assignment
- [ ] Hiring manager notified of completion

---

## Security Considerations

- Temporary initial passwords must be delivered through a secure, separate channel
  from the username - never send both together
- Access should be provisioned to the role template, not to whatever the previous
  person in a similar role happened to accumulate over time (access creep) - if the
  manager requests broader access "to be safe," push back and provision to actual
  need, expanding later if a genuine gap appears
- Confirm the account expiration date is set correctly for contractors/temporary
  staff at creation time, not left open-ended and relying on someone remembering to
  offboard them later

---

## Related Documents

| Document | Relationship |
|---|---|
| [`employee-offboarding-checklist.md`](employee-offboarding-checklist.md) | The reverse process - use when this employee eventually leaves |
| [`../incidents/incident-classification-guide.md`](../incidents/incident-classification-guide.md) | Confirms this is a service request, not an incident |
| [`change-request-template.md`](change-request-template.md) | Use if provisioning requires a change outside standard role templates |
| [`../reference/powershell-command-reference.md`](../reference/powershell-command-reference.md) | Account creation and group assignment cmdlets |
