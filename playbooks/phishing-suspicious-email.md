# Playbook: Phishing / Suspicious Email First Response

## Purpose

This playbook provides the immediate, Tier 1 first-response actions for a user who
reports a suspicious email, a suspected phishing attempt, or who believes they have
already clicked a malicious link or entered credentials on a fake page. Speed matters
here more than almost anywhere else in this repository - the gap between a user
clicking a bad link and their credentials being used is often minutes, not hours.

This playbook covers **individual, single-user first response only**. If scope
expands beyond one user, or you find evidence of actual compromise, this playbook
hands off to [`../incidents/incident-classification-guide.md`](../incidents/incident-classification-guide.md)
and [`../incidents/incident-response-checklist.md`](../incidents/incident-response-checklist.md),
which govern the full incident process.

---

## When to Use This Playbook

Use this playbook when the user reports:

- "I got a weird email, is it safe?"
- "I think I clicked something I shouldn't have"
- "I entered my password on a page and now I'm not sure it was real"
- "I got a text/call asking to confirm my MFA code" (smishing/vishing - same triage
  logic applies)
- A colleague, manager, or the security/email filtering platform flags a message the
  user received as suspicious

Do not use this playbook if:
- The user is asking a general "how do I spot phishing" awareness question with no
  specific email in hand - that's a training/awareness matter, not a ticket
- There is already confirmed evidence of a wider compromise (multiple users affected,
  data exfiltration, ransomware indicators) - skip straight to
  [`../incidents/incident-classification-guide.md`](../incidents/incident-classification-guide.md)
  and declare a major incident immediately rather than working this playbook first

---

## Ticket Intake - Required Information

| Field | What to Record |
|---|---|
| Sender address | Full email address, not just the display name (display names are trivially spoofed) |
| Subject line | Exact text |
| Did the user click any link? | Yes/No - and if yes, what happened next (page shown, credentials entered?) |
| Did the user enter credentials or other data? | Yes/No - this is the single most important fact for triage |
| Did the user open any attachment? | Yes/No, and file type if known |
| Did the user reply or forward it? | Especially relevant if forwarded internally - others may now be at risk |
| Time of the event | As precise as the user can give - drives the urgency of session/password actions |
| Device used | Corporate device, personal device, mobile |

**Do not have the user re-click the link or re-open the attachment to "check."** If
you need to examine it, do so from an isolated analysis environment, never the user's
own device, and only if your organization's policy and your role permit it. When in
doubt, preserve and escalate rather than investigate yourself.

---

## Step 1 - Immediate Triage (First 5 Minutes)

Answer this first, before anything else: **did the user enter credentials, or run/open
an attachment?**

- **Credentials entered on a fake page** → Go to Step 2 immediately. This is
  time-critical.
- **Link clicked but no credentials entered, no attachment opened** → Go to Step 3
- **Attachment opened or macro/file executed** → Go to Step 4 immediately. This is
  also time-critical.
- **Email received but nothing clicked or opened** → Go to Step 5

---

## Step 2 - Credentials Entered on a Suspected Fake Page

Treat this as an active compromise in progress, not a "might have happened" situation.

1. **Reset the user's password immediately**, following your identity platform's
   password reset process. If the account uses cloud identity, also see
   [`cloud-identity-mfa-issues.md`](cloud-identity-mfa-issues.md) for MFA-specific
   steps
2. **Revoke active sign-in sessions** for the account so any session the attacker may
   have already established is terminated, not just blocked from future logins. This
   is a separate action from a password reset - a stolen active session can survive a
   password change if it isn't explicitly revoked
3. **Check for mailbox rule tampering** - attackers who gain access frequently create
   auto-forwarding or auto-delete rules to hide their activity. Check the account's
   inbox rules for anything the user did not create, particularly rules that forward
   mail externally or delete/move messages related to security alerts
4. **Check recent sign-in activity** for the account for unfamiliar locations or
   devices around the time of the incident
5. **Escalate immediately** to security/Tier 2 per
   [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) -
   do not treat this as closed once the password is reset. Confirmed credential
   compromise requires the full incident process, and other accounts may be at risk if
   this user has elevated access or the same password reused elsewhere
6. If the user reused this password on any other system, that password needs to
   change there too - ask directly, people are often reluctant to volunteer this

---

## Step 3 - Link Clicked, No Credentials Entered

1. Ask the user to describe exactly what happened after the click - a page that
   looked like a legitimate login page but that they did *not* enter anything into is
   lower risk than a page that silently redirected or showed unexpected content
2. Check the device for signs of compromise: unexpected pop-ups, new browser
   extensions, unusually slow performance, security software alerts
3. Run an on-demand malware/antivirus scan on the device as a precaution
4. Report the email to your organization's phishing reporting channel (mail-flow
   report button, security mailbox, or equivalent) so it can be blocked
   organization-wide before others click it too
5. No password reset is required based on a click alone with no credential entry, but
   stay alert for any follow-up symptoms over the next 24-48 hours and encourage the
   user to report anything unusual

---

## Step 4 - Attachment Opened or File Executed

1. **Disconnect the device from the network immediately** - unplug the ethernet cable
   or disable Wi-Fi. Do not shut the device down first; a live, network-isolated
   device preserves more forensic information than a powered-off one, and shutting
   down can be what certain malware is specifically waiting for
2. Do not attempt to "clean" the device yourself at Tier 1 - escalate immediately.
   Running your own scans or deleting files can destroy evidence needed for proper
   analysis and doesn't reliably remove sophisticated malware
3. Escalate to security/Tier 2 immediately per
   [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) as a
   security event, and follow
   [`../incidents/incident-classification-guide.md`](../incidents/incident-classification-guide.md)
   to assess whether this needs to be declared as a formal incident (it usually does)
4. Note the exact file name, type, and what the user observed when opening it
   (nothing visible, a document that looked normal, an error message, a
   ransom/lock-screen message) - this materially changes the urgency and response
5. If a ransom note or file-locking behavior is observed, this is a P1 by definition -
   escalate as a major incident without delay

---

## Step 5 - Suspicious Email, Nothing Clicked or Opened

The lowest-risk path, but still worth handling properly so the organization benefits
from the report.

1. Report the email through your organization's phishing reporting mechanism
2. If other users may have received the same email (check sender, subject, and
   timing against any organization-wide alerts), flag it for a broader block at the
   mail-filtering level rather than handling it as an isolated ticket
3. Thank the user for reporting it - reinforcing good reporting behavior, even for a
   false positive, is worth more long-term than any single ticket
4. No further action required if genuinely nothing was clicked or opened

---

## Escalation Criteria

Escalate to Tier 2 / security immediately when:

- [ ] Credentials were entered on a suspected fake page (always - see Step 2)
- [ ] An attachment was opened or a file was executed (always - see Step 4)
- [ ] Ransom notes, file-locking, or other clear compromise indicators are observed
- [ ] Mailbox rules the user did not create are found
- [ ] Sign-in activity from an unfamiliar location or device is found on the account
- [ ] Multiple users report receiving the same or similar suspicious email in a short
  window - this may indicate a targeted campaign, escalate scope assessment per
  [`../incidents/incident-classification-guide.md`](../incidents/incident-classification-guide.md)

**Escalation package must include:**

- Sender address, subject, and time received
- What the user clicked/entered/opened, in their own words plus your assessment
- Actions already taken (password reset, session revocation, device isolation)
- Device isolation status if applicable
- Whether the password was reused elsewhere

---

## Verification Checklist

- [ ] Immediate triage question answered first (credentials entered? attachment
  opened?) before any other step
- [ ] If credentials were entered: password reset, sessions revoked, mailbox rules
  checked, security escalation made
- [ ] If a file was executed: device isolated from network, security escalation made,
  no self-remediation attempted at Tier 1
- [ ] Email reported through the organization's phishing reporting channel
- [ ] User was not made to feel blamed or discouraged from reporting in future -
  reporting behavior is something to reinforce, not punish

---

## Security Considerations

- **Speed matters more here than in almost any other playbook in this repository.**
  The window between credential entry and account misuse is frequently measured in
  minutes. Do not let ticket-queue triage delay Step 2 or Step 4 actions
- Never have a user re-click a suspicious link "to check if it's really bad" -
  this simply repeats the exposure
- A user coming forward to report a mistake (clicking a link, entering credentials)
  should never be treated punitively during the interaction itself - punitive
  responses teach people to hide future incidents instead of reporting them quickly,
  which is far more costly to the organization
- Password reuse across the compromised account and other systems is common and
  often not volunteered - ask directly rather than assuming it didn't happen

---

## Related Documents

| Document | Relationship |
|---|---|
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Security event escalation criteria and contacts |
| [`../incidents/incident-classification-guide.md`](../incidents/incident-classification-guide.md) | Determines if this needs to become a formal incident and at what priority |
| [`../incidents/incident-response-checklist.md`](../incidents/incident-response-checklist.md) | Full incident process once this is escalated beyond first response |
| [`cloud-identity-mfa-issues.md`](cloud-identity-mfa-issues.md) | MFA reset and session revocation steps for cloud identity accounts |
| [`../templates/ticket-template.md`](../templates/ticket-template.md) | Ticket format for this scenario |
