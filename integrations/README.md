# Ticketing Integrations

This folder contains optional integrations that close the gap between
running a diagnostic script and getting its output onto a ticket, without
manually downloading a report file and re-uploading it through a web UI.

**Currently supported:** Freshservice (attaching a report as a note to an
existing ticket). Other platforms (Zendesk, Jira Service Management) are not
built yet - see "Extending to other platforms" below if you want to add one.

**Deliberately out of scope:** creating new tickets. Ticket creation
typically requires organization-specific required fields (priority codes,
status codes, custom fields, workspace IDs) that vary by account
configuration. Guessing at these would produce a script that works in one
organization's Freshservice setup and silently fails or creates malformed
tickets in another's. Attaching evidence to a ticket that already exists
avoids that entirely - it only needs a note body and a file.

---

## Setup

### 1. Get a Freshservice API key

1. Log in to your Freshservice account
2. Click your profile icon in the top-right corner
3. Click **Profile Settings**
4. Find the **API Key** section (you may need to complete a CAPTCHA/"I'm not
   a robot" check to unlock it - this is normal Freshservice behavior, not a
   sign anything is wrong)
5. Copy the key

### 2. Set environment variables

**Never pass the API key as a command-line argument** - both scripts in this
folder deliberately only accept it via environment variable, so it can't end
up in your shell history or be visible to other users on the machine via a
process listing.

**Bash (Linux/macOS/WSL/Git Bash):**

```bash
export FRESHSERVICE_DOMAIN="yourcompany.freshservice.com"
export FRESHSERVICE_API_KEY="your-api-key"
```

Add these to your shell profile (`~/.bashrc`, `~/.zshrc`) if you'll use this
regularly - don't hardcode them into any script or commit them anywhere.

**PowerShell:**

```powershell
$env:FRESHSERVICE_DOMAIN = "yourcompany.freshservice.com"
$env:FRESHSERVICE_API_KEY = "your-api-key"
```

These only persist for the current session. For a persistent setup, use
[Windows Credential Manager](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-credential)
or your organization's secrets manager rather than setting them in a
profile script that could be read by anyone with access to the machine.

### 3. Use it

**Bash / CLI:**

```bash
./integrations/send-to-freshservice.sh -t 12345 -f ~/it-diagnostics/report.txt
```

**PowerShell (standalone script):**

```powershell
.\scripts\windows\Send-ToFreshservice.ps1 -TicketId 12345 -FilePath C:\IT-Diagnostics\report.txt
```

**PowerShell (via the ITSupportOps module):**

```powershell
Import-Module .\module\ITSupportOps -Force
Get-ITNetworkDiagnostics
Send-ITDiagnosticToTicket -TicketId 12345 -FilePath "$env:USERPROFILE\Documents\IT-Diagnostics\NetworkDiagnostics_<timestamp>.txt"
```

By default the note is **private** (visible only to agents, not the
requester). Add `-p` (bash) or `-Public` (PowerShell) to make it public.

---

## Security notes

- The API key grants whatever access your Freshservice account has -
  guard it the same way you'd guard a password
- If a key is ever exposed (committed to a repo, pasted somewhere public,
  shared over an insecure channel), regenerate it immediately from Profile
  Settings rather than trying to "un-expose" it
- Neither script logs or prints the API key at any point, including in
  error messages
- The default private note behavior is intentional - diagnostic report
  content can include internal hostnames, IP ranges, and system detail that
  isn't necessarily appropriate to share with the ticket requester

---

## Extending to other platforms

If you want to add Zendesk or Jira Service Management support, follow the
same shape as `send-to-freshservice.sh`:

- Read credentials from environment variables only, never CLI arguments
- Validate every input with a specific, actionable error message before
  making any network request
- Scope it to attaching evidence to an existing ticket, not creating one,
  unless you're prepared to handle that platform's required-field variance
  properly
- Add a matching PowerShell script in `scripts/windows/` so it flows
  through the existing module-sync tooling (`tools/Build-Module.ps1` and
  the `verify-module-sync` CI check) automatically - see
  `Send-ToFreshservice.ps1` for the pattern
- Do not add it to the CI smoke-test matrices (`smoke-test-bash`,
  `smoke-test-macos`, `smoke-test-powershell`, or the module's cmdlet
  execution step) - those run without credentials and would fail or hang
  waiting for required parameters. Lint and module-sync coverage are
  sufficient for scripts that need live credentials to run meaningfully.
