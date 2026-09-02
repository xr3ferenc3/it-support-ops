# Employee Offboarding Checklist

## Purpose

This checklist ensures a departing employee's access is removed completely and on
schedule. Offboarding failures are a leading cause of avoidable security exposure in
SMB environments - not through anything dramatic, but through the mundane failure of
a former employee's account, VPN access, or file share permissions quietly remaining
active for months after they've left, discovered only during an audit or, worse, an
incident.

This is a **service request**, not an incident, under normal circumstances - see
[`../incidents/incident-classification-guide.md`](../incidents/incident-classification-guide.md).
**Involuntary or contentious departures are the exception** and follow the
accelerated path in Step 0 below.

---

## Step 0 - Determine Departure Type First

The type of departure determines the timeline. Get this from HR before doing anything
else.

| Departure Type | Access Removal Timeline |
|---|---|
| Standard voluntary resignation, notice period served | End of last working day |
| Retirement, planned long-term leave | End of last working day, per HR guidance |
| Involuntary termination, contentious departure, or immediate dismissal | **Immediately, ideally coordinated to happen the moment the employee is notified** - do not wait for "end of day" |
| Death in service | Immediately, coordinate sensitively with HR |

**For involuntary or contentious departures, coordinate timing tightly with HR and
the employee's manager.** Access should be revoked at or before the moment the
employee is informed, not afterward - a gap here is a genuine security risk, not a
procedural formality.

---

## Required Information Before Starting

| Field | Source |
|---|---|
| Employee name and username | HR |
| Last working day / access cutoff time | HR - see Step 0 for departure-type-specific timing |
| Departure type | HR |
| Manager | HR, for data retention/forwarding decisions |
| Equipment to be returned | Asset inventory, matched against employee |
| Data retention/forwarding requirements | Manager - who needs access to this person's files/mailbox after departure, if anyone |

---

## OFFBOARDING CHECKLIST

### Immediate Actions (at the determined cutoff time - see Step 0)

- [ ] Disable the user account (do not delete immediately - see retention note below)
- [ ] Revoke all active sign-in sessions for the account
- [ ] Reset the account password to a random value the departing employee does not know,
      even though the account is disabled - defense in depth in case of a later
      re-enablement error
- [ ] Remove or disable MFA methods registered to the account
- [ ] Disable VPN access
- [ ] Disable remote access tools (RDP, remote support software) for the account
- [ ] Revoke API keys, service accounts, or application-specific passwords owned by
      or associated with this individual
- [ ] Remove from all distribution lists and shared mailbox access
- [ ] If the employee had elevated/admin privileges anywhere, confirm those are
      revoked with particular urgency - this is the highest-risk access category to
      leave active

### Same-Day Actions

- [ ] Set up mailbox forwarding or delegation per manager's documented instruction,
      if approved - do not forward mail without an explicit, documented approval, as
      this is a data access decision, not a routine IT step
- [ ] Set up an out-of-office auto-reply if required by the organization's process
- [ ] Remove from Teams/Slack channels or equivalent collaboration spaces
- [ ] Remove building/badge access (coordinate with facilities if outside IT's system)
- [ ] Notify relevant application owners for any line-of-business system access that
      IT does not directly control, so they can revoke access on their end too

### Within 1-3 Business Days

- [ ] Retrieve company hardware (laptop, phone, peripherals, access cards/tokens)
- [ ] Wipe and re-provision retrieved hardware following your standard asset
      lifecycle process - do not redeploy a former employee's device to someone
      else without a full wipe
- [ ] Update asset inventory to reflect returned/reassigned status
- [ ] Reclaim and reassign or release software licenses held by the account
- [ ] Archive the mailbox per your organization's data retention policy, if the role
      requires retention beyond the account disable date

### 30-90 Days (per organizational retention policy)

- [ ] Delete the disabled account per your organization's defined retention window -
      do not leave disabled accounts indefinitely; they are still a discoverable
      attack surface and an audit finding waiting to happen
- [ ] Confirm no scheduled tasks, automations, or service accounts still reference
      the departed employee's credentials
- [ ] Close out the offboarding ticket with confirmation of all steps completed

---

## Escalation Criteria

Escalate to Tier 2 / IT management / security immediately when:

- [ ] The departure is involuntary or contentious and immediate access revocation is
  required outside normal business hours or standard process timing
- [ ] The departing employee held elevated/administrative access to critical systems
- [ ] There is any indication the employee may have already taken retaliatory action
  (unusual account activity, mass downloads, deleted files) before departure -
  treat as a security event per
  [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md)
- [ ] Data retention or forwarding requirements are unclear or contested between
  departments

---

## Verification Checklist

- [ ] Departure type correctly identified and timeline followed (Step 0)
- [ ] Account disabled, sessions revoked, MFA removed, at or before the correct cutoff time
- [ ] Elevated/admin access specifically confirmed revoked, not assumed covered by
  the general account disable
- [ ] Hardware retrieved and wiped before reassignment
- [ ] Mailbox forwarding, if any, was explicitly approved and documented, not
  configured by default
- [ ] Disabled account scheduled for deletion per retention policy, not left indefinitely

---

## Security Considerations

- Access removal for involuntary departures should be coordinated to happen at or
  before notification, not after - the highest-risk window is the gap between an
  employee learning they are leaving and their access actually being cut off
- Elevated and administrative access is the single most important category to verify
  revoked - a standard user account disable does not automatically revoke separately
  granted admin rights on specific systems
- Never leave a disabled account active indefinitely "just in case" - if there is a
  genuine, specific reason to retain access to the person's data, retain the data
  through proper archival, not by leaving their live account enabled
- Mailbox/data forwarding to another employee requires explicit, documented approval -
  treat it as a data access decision requiring the same rigor as any other access grant

---

## Related Documents

| Document | Relationship |
|---|---|
| [`new-hire-onboarding-checklist.md`](new-hire-onboarding-checklist.md) | The reverse process |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Security event escalation for contentious departures or suspected retaliatory action |
| [`../incidents/incident-classification-guide.md`](../incidents/incident-classification-guide.md) | Confirms standard offboarding is a service request, not an incident |
| [`../reference/powershell-command-reference.md`](../reference/powershell-command-reference.md) | Account disable and session revocation cmdlets |
