# IT Troubleshooting Methodology

## Purpose

This document defines the structured troubleshooting approach used throughout this repository.
Every playbook, script, and diagnostic guide in this system assumes this methodology as its foundation.

A structured methodology exists for one reason: **it finds root cause faster and more reliably than
intuition alone.** Technicians who skip steps resolve symptoms. Technicians who follow a structured
process resolve problems.

This methodology is grounded in the CompTIA A+ troubleshooting model and extended with real-world
help desk practice for SMB environments.

---

## When to Use This Methodology

Use this methodology for every support request without exception - including requests that appear
simple. The step that gets skipped on an "obvious" ticket is usually the step that would have
revealed the actual cause.

Apply it to:

- User-reported faults (application, hardware, connectivity, login, printing)
- Network performance complaints
- System behaviour changes with no obvious trigger
- Recurring issues that have been "fixed" before
- Any situation where the cause is not immediately and certainly known

---

## The Seven-Step Process

---

### Step 1 — Identify the Problem

**What this means:** Gather all available facts before forming any conclusion.

**Why it matters:** Most incorrect diagnoses happen because the technician assumed they understood
the problem before they had sufficient information. A user who says "the internet is broken" may
have a DNS fault, a failed network adapter, an expired DHCP lease, a proxy misconfiguration, or
a problem with one specific application. The complaint is not the diagnosis.

**Actions at this step:**

- Ask the user to describe the problem in their own words
- Ask when it started - exact time if possible
- Ask what changed before it started (updates, new software, moved location, password change)
- Ask whether anyone else is affected
- Ask whether it has happened before
- Ask whether any error messages appeared - get the exact text, not a paraphrase
- Observe the system yourself before touching anything - what does it look like right now?
- Check recent ticket history for the same user or device

**Questions that define the problem correctly:**

| Question | Why You Ask It |
|---|---|
| What exactly cannot you do? | Separates the symptom from the complaint |
| What do you see when it fails? | Gets evidence, not interpretation |
| When did this start? | Establishes timeline for change correlation |
| Did anything change recently? | Most faults follow a change |
| Is anyone else affected? | Distinguishes user fault from system fault |
| Has this happened before? | Identifies recurring vs. new issues |
| What have you already tried? | Prevents repeating steps and reveals state changes |

**Output of this step:** A written problem statement that a second technician could act on without
asking the user any additional questions.

---

### Step 2 — Establish a Theory of Probable Cause

**What this means:** Form a hypothesis - a specific, testable explanation for what is causing
the observed symptoms - before running any diagnostic commands or making any changes.

**Why it matters:** Running commands without a hypothesis is not troubleshooting. It is random
activity that occasionally produces a correct result by accident and frequently makes things worse.
A hypothesis focuses diagnostic effort on the most likely cause and makes the testing process
efficient.

**How to form a hypothesis:**

- Start with the most common cause for the observed symptom in the current environment
- Apply Occam's Razor: the simplest explanation consistent with the evidence is the best starting point
- Consider what changed recently - most faults are change-correlated
- Consider the scope: one user, one device, one building, the whole network
- Rule out the obvious before the complex: check the cable before suspecting the switch firmware

**Hypothesis quality check:**

A good hypothesis answers all three of these:

1. What specifically is failing?
2. Why is it failing (proposed mechanism)?
3. What evidence would confirm or refute this hypothesis?

**Example — poor hypothesis:** "The network might be broken."

**Example — strong hypothesis:** "The user's workstation has lost its DHCP lease and is
operating with an APIPA address (169.254.x.x), which is why it cannot reach network resources.
Cause is likely the DHCP lease expiring while the machine was off the network. Confirmed by
running `ipconfig` and seeing a 169.254.x.x address with no default gateway."

**Output of this step:** One or two written hypotheses, ranked by probability, each with a
defined test that would confirm or refute them.

---

### Step 3 - Test the Theory to Determine Cause

**What this means:** Run the minimum diagnostic steps required to confirm or refute your hypothesis.
One test at a time. Observe the result before proceeding.

**Why it matters:** Testing one thing at a time is the only way to know what fixed - or worsened -
the situation. Technicians who change multiple variables simultaneously cannot identify which
change had which effect. This leads to inability to document root cause, inability to prevent
recurrence, and inability to reverse changes that made things worse.

**Rules for this step:**

- Test your highest-probability hypothesis first
- Change one variable per test
- Record the result of each test before moving to the next
- If the hypothesis is refuted, return to Step 2 and form a revised hypothesis
- If the hypothesis is confirmed, proceed to Step 4

**Testing sequence principle - work from simple to complex:**

```
Physical layer first (cable connected? Link light present?)
      │
      ▼
Operating system layer (adapter enabled? Driver loaded? IP assigned?)
      │
      ▼
Network layer (Can it reach the gateway? Correct subnet?)
      │
      ▼
Service layer (DNS resolving? DHCP responding? Authentication working?)
      │
      ▼
Application layer (Is the specific application or service reachable?)
```

This sequence applies to network faults. For non-network faults, the equivalent principle is:
hardware before software, OS before application, configuration before reinstall.

**Output of this step:** Confirmed root cause with the specific test that confirmed it, recorded
in the ticket.

---

### Step 4 - Establish a Plan of Action and Identify Potential Effects

**What this means:** Before making any change, document what you intend to do, why, and what
side effects it could have.

**Why it matters:** Changes made without a plan create new problems. Releasing a DHCP lease on
a server, flushing DNS cache on a shared workstation, or restarting a print spooler affects
anyone connected to that resource. A plan ensures the impact is understood and communicated
before the action is taken.

**Questions to answer before acting:**

| Question | Why It Matters |
|---|---|
| What change am I making? | Forces explicit intent |
| Why will this fix the root cause? | Confirms the action is targeted, not a guess |
| Who or what else does this affect? | Prevents collateral disruption |
| Can this be reversed if it makes things worse? | Rollback planning |
| Does this require change management approval? | Prevents unauthorised changes |
| Do I need to notify anyone before proceeding? | User and stakeholder communication |

**Output of this step:** A documented action plan recorded in the ticket before any change is made.

---

### Step 5 - Implement the Solution or Escalate

**What this means:** Execute the planned action. If the action is outside your authorisation,
skill level, or tooling access, escalate with your complete diagnostic findings.

**Why it matters:** Escalation with complete information is a professional act, not a failure.
Escalation without diagnostic findings wastes the receiving technician's time and delays
resolution for the user.

**If implementing:**

- Execute one action at a time
- Verify the result of each action before the next
- Record every action taken, in order, with timestamps
- If the action makes things worse, reverse it before trying anything else

**If escalating:**

Include all of the following in the escalation:

- Written problem statement from Step 1
- Hypothesis and what was tested from Steps 2 and 3
- Confirmed or suspected root cause
- Actions already taken (and their results)
- Current state of the system
- Impact on the user and any other affected parties
- Urgency and any deadlines

Never escalate with: "I'm not sure what's wrong. Can you take a look?"

**Output of this step:** Resolution applied, or escalation raised with complete diagnostic package.

---

### Step 6 - Verify Full System Functionality

**What this means:** After the fix is applied, confirm that the problem is fully resolved - not
just partially better - and that the fix has not introduced a new problem elsewhere.

**Why it matters:** Partial fixes generate repeat tickets. A user who reports the same fault
three days later is experiencing a technician who closed a ticket without full verification.

**Verification actions:**

- Ask the user to perform the task that was failing - observe the result with them
- Confirm the fix works end-to-end, not just at the point of the repair
- Check adjacent systems or services that the fix could have affected
- Run the relevant diagnostic script and confirm clean output
- Confirm no new errors have appeared in logs or Event Viewer since the fix

**Do not close the ticket until:**

- The user confirms the problem is resolved
- You have independently verified the resolution
- You have checked for side effects

**Output of this step:** Verified resolution, confirmed by both technician observation and
user confirmation.

---

### Step 7 — Document Findings, Actions, and Outcomes

**What this means:** Write a complete record of the problem, diagnosis, actions taken, resolution,
and root cause - in the ticket - before closing.

**Why it matters:** Documentation is what separates an IT support professional from someone who
plugs things in and reboots. It enables:

- Future technicians to resolve the same issue faster
- Management to identify recurring problems
- Root cause analysis to prevent future incidents
- Accurate escalation if the problem returns
- Evidence of the technician's reasoning and competence

**Documentation must include:**

| Field | Content |
|---|---|
| Problem statement | Exactly what the user reported and what you observed |
| Root cause | The specific technical reason the fault occurred |
| Actions taken | Every step, in order, with timestamps |
| Resolution | What fixed it and why it worked |
| Verification | How you confirmed it was fully resolved |
| Recurrence risk | Whether this is likely to happen again and why |
| Prevention recommendation | What should change to prevent recurrence |

**Documentation quality standard:**

A second technician reading this ticket must be able to understand exactly what happened,
what was done, and what to do if it happens again - without asking anyone any questions.

**Output of this step:** Complete ticket record closed with full documentation.

---

## Common Methodology Failures

These are the most frequent places where structured troubleshooting breaks down in real
help desk environments. Recognise them to avoid them.

| Failure | What It Looks Like | Why It Is Harmful |
|---|---|---|
| Skipping Step 1 | Jumping to solutions before gathering facts | Solves the wrong problem |
| Anchoring | Committing to the first hypothesis without testing it | Misses the actual cause |
| Changing multiple variables | Updating drivers and rebooting simultaneously | Cannot identify what worked |
| Treating symptoms | Rebooting to resolve high CPU without finding the process | Problem returns immediately |
| Closing without verification | Asking "Does that work?" and closing on "I think so" | Generates repeat tickets |
| Skipping documentation | Resolving the ticket without recording root cause | Knowledge is lost |
| Escalating without findings | Handing off with "Not sure, can you check?" | Wastes senior technician time |
| Confirmation bias | Only running tests that support the initial hypothesis | Misses the real cause |

---

## Methodology and Escalation

The methodology does not stop when a ticket is escalated. The escalating technician is
responsible for:

- Completing Steps 1, 2, and 3 before escalating
- Documenting all findings in the ticket before handoff
- Remaining available to the receiving technician for context

Refer to [`escalation-matrix.md`](escalation-matrix.md) for escalation criteria and required
information by tier.

---

## Relationship to Other Repository Components

| Component | How It Uses This Methodology |
|---|---|
| `triage-decision-framework.md` | Applies Step 1 to ticket intake and classification |
| `escalation-matrix.md` | Defines Step 5 escalation criteria and required information |
| `networking/` guides | Apply Steps 2 and 3 to network-specific fault isolation |
| `playbooks/` | Provide Step 3 testing sequences for common scenarios |
| `scripts/` | Automate data collection for Steps 1 and 3 |
| `templates/diagnostic-report-template.md` | Structures Step 7 documentation output |
| `templates/ticket-template.md` | Captures the complete record across all seven steps |

---

## Quick Reference Card

```
Step 1 — IDENTIFY      Gather facts. Write a problem statement.
Step 2 — HYPOTHESISE   Form a specific, testable explanation.
Step 3 — TEST          One test at a time. Record every result.
Step 4 — PLAN          Document the fix and its potential effects.
Step 5 — ACT           Implement or escalate with full findings.
Step 6 — VERIFY        Confirm full resolution. Check for side effects.
Step 7 — DOCUMENT      Write the complete record before closing.
```

---

## Security Considerations

- Never make changes to production systems without following Steps 4 and 5 planning and approval
- Never act on a user's description alone - verify independently at Step 1
- Never close a ticket based on user assumption - verify independently at Step 6
- Record all actions taken, including those that were reversed, for audit purposes

---

## Escalation Criteria from This Document

Escalate immediately if any of the following apply after completing Steps 1-3:

- Root cause is confirmed but resolution requires elevated access you do not have
- Root cause is unconfirmed after exhausting your diagnostic capability
- The fault affects multiple users or a business-critical system
- The issue requires a configuration change subject to change management

See [`escalation-matrix.md`](escalation-matrix.md) for full escalation procedures.