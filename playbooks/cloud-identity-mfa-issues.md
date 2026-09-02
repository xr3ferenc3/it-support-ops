# Playbook: Cloud Identity, MFA & Conditional Access Issues (Microsoft Entra ID / Microsoft 365)

## Purpose

This playbook provides a resolution guide for sign-in failures tied to Microsoft Entra ID
(formerly Azure AD), including multi-factor authentication (MFA) problems, Conditional
Access blocks, self-service password reset (SSPR) failures, and hybrid device join trust
issues. These are distinct from the on-premises Active Directory and local-account
failures covered in [`user-cannot-login.md`](user-cannot-login.md) - cloud identity
failures often have no visible error on the device itself, only a message from the
identity platform, and frequently require checking the Entra admin center rather than
the local machine.

---

## When to Use This Playbook

Use this playbook when the user reports:

- "It's asking me to approve a sign-in but I didn't try to sign in"
- "My authenticator app won't send me a notification" / "I lost my phone with the
  authenticator app on it"
- "It says my organization doesn't allow access from this app or device"
- "I can't reset my password myself - the reset page won't let me"
- "I'm signed into Windows but Outlook / Teams / OneDrive keeps asking me to sign in
  again"
- "It says my sign-in was blocked" with a Conditional Access or "more information
  required" message
- A new or reimaged device won't show as compliant / won't hybrid join

Do not use this playbook if:
- The failure is a local Windows or on-prem AD account issue with no Microsoft 365 /
  cloud component - use [`user-cannot-login.md`](user-cannot-login.md) instead
- The user suspects their account has been compromised (unexpected MFA prompts they
  did not initiate are a strong signal of this) - treat as a security event immediately
  per [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md).
  An MFA prompt the user did not request is not routine noise; it means someone else
  has the user's password.

---

## Ticket Intake - Required Information

| Field | What to Record |
|---|---|
| User Principal Name (UPN) | The user's sign-in email, not just their display name |
| Application affected | Single app (e.g. Outlook only) or all Microsoft 365 apps |
| Exact error/message text | Screenshot if possible - Entra error messages contain error codes that speed up diagnosis |
| Device type | Corporate-managed, personal (BYOD), new/reimaged |
| MFA method registered | Authenticator app, SMS, phone call, hardware key - ask the user what they normally use |
| Did the user initiate this sign-in attempt? | Critical - unrequested MFA prompts are a security signal, not a routine fault |
| Recent changes | New phone, phone number change, recent password reset, recently traveled |

**Security check before proceeding:** As with any identity issue, verify the requester's
identity through an approved method before making any changes to their account,
resetting MFA, or approving a device.

---

## Step 1 - Classify the Cloud Identity Failure

| Symptom | Classification | Go To |
|---|---|---|
| Unexpected MFA prompt the user did not initiate | Possible compromised credentials | Step 2 (security path) |
| MFA notification never arrives / times out | MFA delivery failure | Step 3 |
| Lost, replaced, or wiped phone with the authenticator app | Lost MFA device | Step 4 |
| "Your sign-in was blocked" / "More information required" | Conditional Access block | Step 5 |
| SSPR page rejects the user or won't let them register | Self-service password reset failure | Step 6 |
| Signed into Windows but Microsoft 365 apps keep prompting | Token/session sync issue | Step 7 |
| New or reimaged device not showing as compliant / hybrid joined | Device trust / hybrid join failure | Step 8 |

---

## Step 2 - Unexpected MFA Prompt (Possible Compromise)

**Treat this as a security event, not a routine MFA fault.** An MFA prompt the user did
not request means someone else already has their password and is attempting to
complete sign-in.

1. Instruct the user to **deny/decline** the prompt immediately if they have not already
2. Escalate to Tier 2 / security per
   [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md)
   **before** doing anything else in this playbook
3. Do not reset MFA or approve a device for this user until the security review
   determines the account is not actively compromised
4. Preserve evidence: note the exact time of the prompt, the reported location/device
   shown on the prompt (if the authenticator app displayed one), and whether the user
   has reused this password elsewhere

Only continue with the rest of this playbook once security has confirmed the account
is not compromised and the ticket is reclassified as a routine MFA issue.

---

## Step 3 - MFA Notification Delivery Failure

1. Confirm the user is checking the correct device - a common cause is the
   authenticator app being installed on an old phone that no longer has a working
   data connection
2. Confirm the phone has network connectivity (Wi-Fi or cellular data) - push
   notifications require it
3. Check for a notification permission issue on the phone (notifications disabled for
   the authenticator app at the OS level)
4. Try the alternate verification method if one is registered (e.g. phone call or SMS
   code instead of push notification) - this is usually offered as a fallback link on
   the sign-in prompt itself
5. If the app shows "network error" or fails to sync, have the user manually refresh
   or reinstall the authenticator app - **do not** have them remove and re-add the
   work account without confirming this won't be treated as a lost-device scenario
   requiring re-registration (see Step 4)

If none of the above resolves it, treat as a lost/inaccessible MFA device (Step 4).

---

## Step 4 - Lost or Inaccessible MFA Device

1. **Verify identity through an approved out-of-band method before proceeding** -
   this step effectively resets the user's second factor, so it carries the same risk
   as a password reset and is a common social-engineering target
2. In the Entra admin center: **Users > [select user] > Authentication methods**
3. Remove the lost/inaccessible method and have the user register a new one, or
   temporarily grant a one-time bypass per your organization's policy if immediate
   access is required and re-registration cannot happen right away
4. Confirm the user successfully registers a new MFA method before closing the ticket
5. If the organization uses hardware security keys or certificate-based auth in
   addition to app-based MFA, confirm which factor was actually lost - do not remove
   methods the user still has access to

> **Note:** exact portal menu names and navigation change periodically as Microsoft
> updates the Entra admin center. If a step above doesn't match what you see, search
> Microsoft's current documentation for "Entra admin center authentication methods"
> rather than assuming the interface described here is stale by design flaw - it may
> simply be a newer or older version of the console.

---

## Step 5 - Conditional Access Block

Conditional Access policies can block sign-in based on device compliance, location,
application, or risk level. The error message usually includes a specific reason.

1. Have the user click "More details" or note the exact error code shown - this
   determines which policy is blocking them
2. Common causes and what to check:
   - **Device not compliant** - the device fails a management policy (e.g. missing
     disk encryption, outdated OS). Check the device's compliance status in Intune
     (or your MDM) rather than trying to override the block
   - **Unfamiliar location / impossible travel** - the user may be signing in from a
     new location (travel, home network change, VPN). This is often a legitimate risk
     signal working as intended, not a bug
   - **Legacy authentication blocked** - an older app or protocol (e.g. an old mail
     client using basic auth) is being blocked because Conditional Access policy
     requires modern authentication. The fix is usually updating or reconfiguring the
     client, not bypassing the policy
   - **Unmanaged/personal device blocked from a specific app** - working as intended
     for BYOD policies; the user needs a managed device or an approved app (e.g. a
     mobile app with app protection policy) to access that resource
3. **Do not disable or exempt a Conditional Access policy to work around a block**
   without change approval - these policies exist for a reason and altering them is a
   security-relevant change, not a routine Tier 1 fix. Escalate per
   [`../templates/change-request-template.md`](../templates/change-request-template.md)
   if a policy change genuinely appears to be needed

---

## Step 6 - Self-Service Password Reset (SSPR) Failure

1. Confirm SSPR is actually enabled for this user - not every organization enables it
   for every user group, and if it's disabled, the user needs an admin-performed reset
   instead (verify identity, then reset via the Entra admin center or on-prem AD as
   appropriate for the account's source)
2. If SSPR is enabled but fails, the most common cause is the user never completed
   their security info registration (backup email, phone number) or the registered
   info is now out of date (old phone number, inaccessible personal email)
3. Have the user check they're using the correct reset URL for your organization
   (there is sometimes confusion between a personal Microsoft account reset page and
   the organizational one)
4. If registered security info is stale, an admin must update or reset it after
   identity verification - the user cannot self-correct stale recovery info through
   SSPR itself, since SSPR relies on that same info being reachable

---

## Step 7 - Signed Into Windows But Microsoft 365 Apps Keep Prompting

This usually indicates a stale or corrupted authentication token cache, not an account
problem.

1. Have the user fully sign out of the affected app (not just close the window)
2. Clear cached credentials:
   - Windows: **Settings > Accounts > Email & accounts**, or Credential Manager, to
     remove stale saved credentials for Microsoft 365
   - Outlook specifically: closing Outlook and removing the cached profile token via
     Credential Manager (entries starting `MicrosoftOffice16_Data:`) often resolves
     repeated prompting without a full profile rebuild
3. Confirm system clock and time zone are correct - authentication tokens are
   time-sensitive, and a clock drifted by more than a few minutes will cause
   repeated, confusing auth failures that look unrelated to time
4. Restart the app and sign in fresh
5. If it recurs consistently across multiple apps, check whether the user's account had
   a recent password reset or MFA re-registration - old cached tokens issued before
   that change will keep failing until cleared

---

## Step 8 - Device Trust / Hybrid Join Failure

New or reimaged devices that fail to register correctly will show as non-compliant or
unmanaged even if the user can otherwise sign in.

1. Check hybrid join status from an elevated command prompt on the device:
   ```
   dsregcmd /status
   ```
   Look at `AzureAdJoined`, `DomainJoined`, and `AzureAdPrt` (Primary Refresh Token)
   fields - a healthy hybrid-joined device shows both as `YES` and a valid PRT
2. If `AzureAdJoined` is `NO`, the device failed to register with Entra ID. Confirm
   the device has connectivity to the required Microsoft endpoints and that automatic
   registration is enabled via Group Policy or Intune for this device's OU
3. If `DomainJoined` is `YES` but `AzureAdJoined` is `NO`, force a registration attempt:
   ```
   # Run as the affected user, not as an admin, in an elevated prompt
   dsregcmd /leave
   dsregcmd /join
   ```
4. Confirm the device appears in the Entra admin center under **Devices** after a
   successful join, and that compliance policy evaluates within the expected window
   (this can take up to several hours depending on Intune sync policy - don't assume
   failure if it hasn't shown compliant within minutes)

---

## Escalation Criteria

Escalate to Tier 2 when:

- [ ] An unexpected/unrequested MFA prompt was reported (escalate immediately, see Step 2)
- [ ] A Conditional Access policy appears to be misconfigured rather than working as
  intended, and a policy change is being considered
- [ ] Hybrid join repeatedly fails after a `dsregcmd /leave` + `/join` retry
- [ ] SSPR is failing for multiple users simultaneously (possible tenant-wide
  configuration or outage issue)
- [ ] The user's registered security info needs correction and requires admin-level
  identity platform access beyond Tier 1 permissions
- [ ] Any suspicion of account compromise beyond a single unexpected MFA prompt
  (e.g. mail rules the user didn't create, sign-ins from unfamiliar countries in the
  sign-in log)

**Escalation package must include:**

- User's UPN and the exact error code/message shown
- Whether the user initiated the sign-in attempt in question
- MFA method(s) currently registered and which one is failing
- `dsregcmd /status` output if device trust is involved
- Steps already attempted and their results

---

## Verification Checklist

- [ ] User identity verified before any MFA reset, credential change, or device approval
- [ ] Root cause identified and documented (not just "MFA reset and it worked")
- [ ] User successfully signs into the affected app(s) and confirms access is restored
- [ ] If MFA was re-registered, confirm the user completed setup of a new method, not
  just removal of the old one
- [ ] If a Conditional Access block was involved, confirm no policy was bypassed or
  weakened without documented change approval
- [ ] Unexpected/unrequested MFA prompts were escalated as a security event, not
  resolved as a routine fault

---

## Security Considerations

- An MFA prompt the user did not request is one of the strongest available signals
  that a password has already been compromised - treat it as a security event first,
  an inconvenience second
- Removing or resetting a user's MFA method is functionally equivalent to a password
  reset in terms of account access risk - verify identity with the same rigor
- Never disable or exempt a Conditional Access policy as a quick fix without change
  approval - these policies are security controls, and weakening one for convenience
  can have effects far beyond the single ticket in front of you
- Be cautious of users asking to add MFA on a second, unfamiliar device "just to make
  it easier" - confirm this is the user's own device through an approved verification
  method before approving

---

## Related Documents

| Document | Relationship |
|---|---|
| [`user-cannot-login.md`](user-cannot-login.md) | On-premises AD / local account login failures - use that playbook instead if there's no cloud identity component |
| [`../methodology/escalation-matrix.md`](../methodology/escalation-matrix.md) | Security event and Tier 2 escalation criteria |
| [`../incidents/incident-classification-guide.md`](../incidents/incident-classification-guide.md) | For suspected unauthorised access scenarios |
| [`../templates/change-request-template.md`](../templates/change-request-template.md) | Required for any Conditional Access policy change |
| [`../templates/ticket-template.md`](../templates/ticket-template.md) | Ticket format for this scenario |
