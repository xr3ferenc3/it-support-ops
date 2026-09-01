# Contributing to IT Support Operations Center

Thanks for considering a contribution. This repo is meant to grow through real-world IT support experience - if you've fixed something faster with a different method, written a better script, or caught something outdated, this is the place for it.

---

## Ways to Contribute

You don't need to write code to help. Contributions fall into a few categories:

| Type | Examples |
|---|---|
| **Corrections** | Fixing outdated commands, wrong file paths, broken links, factual errors |
| **New scripts** | A PowerShell or Bash script that solves a diagnostic/triage problem not yet covered |
| **New playbooks** | A scenario-specific resolution guide (e.g. `vpn-connection-failure.md`) |
| **Improvements** | Clarifying existing methodology, adding edge cases to a playbook, improving script output/logging |
| **Templates** | Better ticket, incident, or change-request templates |
| **Documentation** | Typos, formatting, clearer explanations |

---

## Before You Start

1. **Check existing issues** to see if your idea or fix is already being discussed.
2. **Open an issue first** for anything non-trivial (a new script, playbook, or structural change) so we can align before you put in the work. Small fixes (typos, broken links) can go straight to a PR.
3. Keep contributions **scoped** - one script, one playbook, or one fix per PR. Easier to review, easier to merge.

---

## How to Submit a Change

1. **Fork** the repository
2. **Create a branch** with a descriptive name:
   ```
   git checkout -b add-vpn-playbook
   ```
3. **Make your change**, following the placement guide below
4. **Test scripts locally** before submitting - see [Script Requirements](#script-requirements)
5. **Commit** with a clear message:
   ```
   git commit -m "Add VPN connection failure playbook"
   ```
6. **Push and open a Pull Request** against `main`, with:
   - What the change does
   - Why it's needed (what gap it fills)
   - Any testing you did (OS/version, if a script)

---

## Where Things Go

Match the existing repo structure:

```
methodology/   → troubleshooting logic, triage frameworks, escalation criteria
networking/    → network fault isolation guides
playbooks/     → scenario-specific resolution guides (one issue = one file)
scripts/windows/  → PowerShell diagnostic/automation scripts
scripts/linux/    → Bash diagnostic/automation scripts
reference/     → command references, ports/protocols, quick lookups
incidents/     → incident classification, response, post-incident review docs
templates/     → reusable blank templates
samples/       → completed example of a template in use
```

If you're not sure where something belongs, say so in your issue or PR - happy to help place it.

---

## Script Requirements

To keep scripts consistent and safe to run:

- **No admin/root required for core functionality.** If elevated access improves output, note it clearly in the script header - don't require it.
- **No data leaves the local machine.** Scripts should not transmit output anywhere.
- **Inline comments** explaining what each major block does.
- **Header block** at the top of the script with: purpose, run-as requirement, and example usage.
- **Consistent naming**: PowerShell scripts use `Verb-Noun.ps1` (e.g. `Get-DiskHealthReport.ps1`); Bash scripts use `kebab-case.sh` (e.g. `disk-health-report.sh`).
- Test on the OS/version you're targeting before submitting, and mention that version in your PR.

---

## Style Guide for Docs (Playbooks, Methodology, etc.)

- Follow the existing structure of similar files in the same folder - consistency matters more than personal formatting preference.
- Write for someone mid-ticket, under time pressure. Be direct and scannable - use numbered steps and short sections, not long prose.
- Where relevant, follow the repo's core methodology sequence: **define → scope → hypothesis → test → document → resolve/escalate → prevent recurrence.**
- Note outdated practices explicitly rather than silently replacing them, so readers understand *why* the guidance changed.

---

## Code of Conduct

Be respectful. Assume good intent. Corrections and disagreements are welcome - keep them focused on the content, not the contributor.

---

## Questions?

Open an issue with the `question` label, or start a discussion. No contribution is too small - a single corrected command or fixed typo genuinely helps.