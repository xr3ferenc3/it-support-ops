<#
.SYNOPSIS
    Collects and summarises recent errors and warnings from Windows Event
    Logs for IT support diagnostics.

.DESCRIPTION
    Queries the Application and System event logs for recent Error and
    Warning level events, groups them by source to highlight recurring
    patterns, and flags specific Event IDs that commonly correspond to
    documented playbook scenarios (application crashes, disk faults,
    network adapter failures). Supports diagnostic Step 3 in
    playbooks/application-not-launching.md and general incident evidence
    gathering per incidents/incident-response-checklist.md.

    This script is read-only. It makes no changes to the system. Standard
    users can read the Application and System logs by default on most
    Windows configurations; if access is denied, the script reports this
    clearly rather than failing silently.

.NOTES
    Author:         it-support-ops repository
    Run as:         Standard user (no elevation required on most configurations)
    Compatibility:  Windows 10, Windows 11, PowerShell 5.1+
    Output:         Console output + log file in user's Documents folder

.EXAMPLE
    .\Get-EventLogSummary.ps1

    Collects errors and warnings from the last 24 hours and saves output to:
    $env:USERPROFILE\Documents\IT-Diagnostics\EventLogSummary_<timestamp>.txt

.EXAMPLE
    .\Get-EventLogSummary.ps1 -HoursBack 72 -FilterSource "Application Error"

    Collects events from the last 72 hours, filtered to sources matching
    "Application Error".
#>

[CmdletBinding()]
param(
    # Optional custom output path. Defaults to Documents\IT-Diagnostics.
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    # How many hours back to search. Default of 24 covers "it happened
    # earlier today" tickets without producing an overwhelming volume of
    # historical noise for a standard triage pass.
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 720)]
    [int]$HoursBack = 24,

    # Optional filter to narrow results to a specific event source
    # (e.g. "Application Error", "Disk", "e1dexpress" for a NIC driver).
    # Useful when following up on a specific symptom rather than doing
    # a general sweep.
    [Parameter(Mandatory = $false)]
    [string]$FilterSource,

    # Maximum number of events to display per log, to keep the report
    # readable. The full count is still reported even if truncated.
    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 200)]
    [int]$MaxEventsPerLog = 30
)

# ---------------------------------------------------------------------------
# SETUP
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$startTime = (Get-Date).AddHours(-$HoursBack)

if (-not $OutputPath) {
    $diagnosticsFolder = Join-Path $env:USERPROFILE "Documents\IT-Diagnostics"
    if (-not (Test-Path $diagnosticsFolder)) {
        try {
            New-Item -ItemType Directory -Path $diagnosticsFolder -Force | Out-Null
        }
        catch {
            Write-Warning "Could not create diagnostics folder. Output will be console-only."
            $diagnosticsFolder = $null
        }
    }
    if ($diagnosticsFolder) {
        $OutputPath = Join-Path $diagnosticsFolder "EventLogSummary_$timestamp.txt"
    }
}

$reportLines = New-Object System.Collections.Generic.List[string]

function Write-ReportLine {
    param([string]$Text = "")
    Write-Host $Text
    $reportLines.Add($Text)
}

function Write-SectionHeader {
    param([string]$Title)
    Write-ReportLine ""
    Write-ReportLine "=" * 70
    Write-ReportLine " $Title"
    Write-ReportLine "=" * 70
}

# Event IDs with known, documented significance in this repository's
# playbooks. Surfacing these explicitly saves the technician from having
# to recognise them from memory and points directly to the relevant
# troubleshooting document.
$knownEventIds = @{
    1000 = "Application Error (crash) - see playbooks/application-not-launching.md Step 3"
    1001 = "Windows Error Reporting - additional crash detail may be available"
    1002 = "Application Hang - see playbooks/application-not-launching.md Step 2"
    6008 = "Unexpected shutdown (previous session did not close cleanly)"
    41   = "Kernel-Power: system rebooted without a clean shutdown - possible power/hardware issue"
    7000 = "Service failed to start - check the named service status"
    7001 = "Service dependency failure"
    5719 = "Domain trust/logon issue - see playbooks/user-cannot-login.md Step 5"
    4740 = "Account lockout event - see playbooks/user-cannot-login.md Step 3 (requires DC access for full detail)"
}

# ---------------------------------------------------------------------------
# REPORT HEADER
# ---------------------------------------------------------------------------

Write-ReportLine "=" * 70
Write-ReportLine " IT SUPPORT - EVENT LOG SUMMARY"
Write-ReportLine "=" * 70
Write-ReportLine "Generated:       $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-ReportLine "Computer Name:   $env:COMPUTERNAME"
Write-ReportLine "Current User:    $env:USERNAME"
Write-ReportLine "Time Window:     Last $HoursBack hour(s) (since $($startTime.ToString('yyyy-MM-dd HH:mm:ss')))"
if ($FilterSource) {
    Write-ReportLine "Source Filter:   $FilterSource"
}

# ---------------------------------------------------------------------------
# FUNCTION: Process a single log
# ---------------------------------------------------------------------------

function Get-LogSummary {
    param(
        [string]$LogName
    )

    Write-SectionHeader "$LogName LOG - ERRORS AND WARNINGS"

    try {
        $filterHash = @{
            LogName   = $LogName
            Level     = 2, 3   # 2 = Error, 3 = Warning
            StartTime = $startTime
        }

        $events = Get-WinEvent -FilterHashtable $filterHash -ErrorAction Stop

        if ($FilterSource) {
            $events = $events | Where-Object { $_.ProviderName -like "*$FilterSource*" }
        }

        if (-not $events -or $events.Count -eq 0) {
            Write-ReportLine "No Error or Warning events found in this window."
            return
        }

        $totalCount = $events.Count
        Write-ReportLine "Total Error/Warning events in window: $totalCount"
        Write-ReportLine ""

        # Group by source to highlight recurring patterns — a single source
        # generating dozens of events is a stronger diagnostic signal than
        # a long flat list of unique one-off events.
        Write-ReportLine "Events grouped by source (most frequent first):"
        $events | Group-Object -Property ProviderName |
            Sort-Object Count -Descending |
            Select-Object -First 10 |
            ForEach-Object {
                Write-ReportLine ("  {0,-40} {1} event(s)" -f $_.Name, $_.Count)
            }

        # Flag any known significant Event IDs found in this window
        Write-ReportLine ""
        Write-ReportLine "Known significant Event IDs found in this window:"
        $foundKnown = $false
        foreach ($id in $knownEventIds.Keys) {
            $matchez = $events | Where-Object { $_.Id -eq $id }
            if ($matchez) {
                $foundKnown = $true
                Write-ReportLine ("  ID {0}: {1} occurrence(s) - {2}" -f $id, $matchez.Count, $knownEventIds[$id])
            }
        }
        if (-not $foundKnown) {
            Write-ReportLine "  None of the documented significant Event IDs were found."
        }

        # Detailed listing, capped to keep the report readable
        Write-ReportLine ""
        $displayCount = [math]::Min($totalCount, $MaxEventsPerLog)
        Write-ReportLine "Detailed listing (most recent $displayCount of $totalCount):"
        Write-ReportLine ("-" * 70)

        $events | Select-Object -First $MaxEventsPerLog | ForEach-Object {
            $levelLabel = if ($_.LevelDisplayName) { $_.LevelDisplayName } else { "Unknown" }
            Write-ReportLine ""
            Write-ReportLine ("[{0}] {1} - {2}" -f $_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'), `
                $levelLabel, $_.ProviderName)
            Write-ReportLine ("  Event ID: {0}" -f $_.Id)

            # Truncate long messages for readability in the summary report —
            # the full event remains available via Event Viewer using the
            # timestamp and Event ID recorded here if deeper detail is needed.
            $message = $_.Message
            if ($message) {
                $shortMessage = if ($message.Length -gt 200) {
                    $message.Substring(0, 200) + "... (truncated)"
                } else {
                    $message
                }
                $shortMessage = $shortMessage -replace "`r`n", " " -replace "`n", " "
                Write-ReportLine ("  Message:  {0}" -f $shortMessage)
            }
        }

        if ($totalCount -gt $MaxEventsPerLog) {
            Write-ReportLine ""
            Write-ReportLine "($($totalCount - $MaxEventsPerLog) additional event(s) not shown — increase"
            Write-ReportLine " -MaxEventsPerLog or review the full log in Event Viewer for complete detail.)"
        }
    }
    catch [System.Exception] {
        if ($_.Exception.Message -like "*No events were found*") {
            Write-ReportLine "No Error or Warning events found in this window."
        }
        else {
            Write-ReportLine "ERROR: Could not query $LogName log - $($_.Exception.Message)"
            Write-ReportLine "This may require administrator privileges depending on local"
            Write-ReportLine "Group Policy configuration of event log access."
        }
    }
}

# ---------------------------------------------------------------------------
# RUN AGAINST BOTH LOGS
# ---------------------------------------------------------------------------

Get-LogSummary -LogName "Application"
Get-LogSummary -LogName "System"

# ---------------------------------------------------------------------------
# UNEXPECTED SHUTDOWN CHECK
# ---------------------------------------------------------------------------
# Specifically surfaces unclean shutdowns (Event ID 41 and 6008), since
# these are a common root cause of profile corruption and application
# config corruption documented elsewhere in the repository, and are easy
# to miss in a general scan if not called out directly.

Write-SectionHeader "UNEXPECTED SHUTDOWN CHECK"

try {
    $shutdownEvents = Get-WinEvent -FilterHashtable @{
        LogName   = "System"
        Id        = 41, 6008
        StartTime = $startTime
    } -ErrorAction Stop

    if ($shutdownEvents) {
        Write-ReportLine "FLAG: $($shutdownEvents.Count) unexpected shutdown event(s) found in this window."
        foreach ($evt in $shutdownEvents | Select-Object -First 5) {
            Write-ReportLine ("  [{0}] Event ID {1}" -f $evt.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'), $evt.Id)
        }
        Write-ReportLine ""
        Write-ReportLine "Unexpected shutdowns are a common cause of profile or application"
        Write-ReportLine "configuration corruption. See playbooks/user-cannot-login.md Step 6"
        Write-ReportLine "and playbooks/application-not-launching.md Step 6 if related symptoms"
        Write-ReportLine "are also present."
    }
    else {
        Write-ReportLine "No unexpected shutdown events found in this window."
    }
}
catch [System.Exception] {
    if ($_.Exception.Message -like "*No events were found*") {
        Write-ReportLine "No unexpected shutdown events found in this window."
    }
    else {
        Write-ReportLine "Could not check for unexpected shutdown events - $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# FOOTER AND FILE OUTPUT
# ---------------------------------------------------------------------------

Write-SectionHeader "REPORT COMPLETE"
Write-ReportLine "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-ReportLine ""
Write-ReportLine "Reminder: This report is a triage starting point. For full event detail,"
Write-ReportLine "use Event Viewer with the timestamps and Event IDs noted above."

if ($OutputPath) {
    try {
        $reportLines | Out-File -FilePath $OutputPath -Encoding UTF8 -ErrorAction Stop
        Write-Host ""
        Write-Host "Report saved to: $OutputPath" -ForegroundColor Green
        Write-Host "Attach this file to the ticket per diagnostic-report-template.md" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not save report to file: $($_.Exception.Message)"
        Write-Warning "Report was displayed in console only — copy manually if needed."
    }
}
else {
    Write-Host ""
    Write-Host "No output file path available — report displayed in console only." -ForegroundColor Yellow
}