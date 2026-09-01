<#
.SYNOPSIS
    Runs the staged connectivity fault isolation sequence defined in
    networking/connectivity-fault-isolation.md, automated end to end.

.DESCRIPTION
    Executes the six-stage isolation sequence (device self-test, gateway,
    internal reachability, internet egress, DNS, and service port checks),
    stopping logically at the first confirmed failure and reporting a clear
    fault boundary. Also performs traceroute analysis and optional specific
    port/service reachability tests. Designed to produce a ready-to-attach
    escalation package matching the report format defined in
    networking/connectivity-fault-isolation.md.

    This script is read-only. It makes no configuration changes. It is safe
    to run on any Windows 10/11 workstation without administrative
    privileges.

.NOTES
    Author:         it-support-ops repository
    Run as:         Standard user (no elevation required)
    Compatibility:  Windows 10, Windows 11, PowerShell 5.1+
    Output:         Console output + log file in user's Documents folder

.EXAMPLE
    .\Test-ConnectivitySuite.ps1

    Runs the full six-stage connectivity test and saves output to:
    $env:USERPROFILE\Documents\IT-Diagnostics\ConnectivitySuite_<timestamp>.txt

.EXAMPLE
    .\Test-ConnectivitySuite.ps1 -InternalHost "fileserver.company.local" -ServicePort 445

    Runs the full sequence and additionally tests reachability of an
    internal host and a specific service port (e.g. SMB file sharing).
#>

[CmdletBinding()]
param(
    # Optional custom output path. Defaults to Documents\IT-Diagnostics.
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    # Optional internal host to test at Stage 3 (Internal Network Reachability).
    # If not supplied, Stage 3 is noted as skipped rather than guessing an
    # internal address that may not exist in this environment.
    [Parameter(Mandatory = $false)]
    [string]$InternalHost,

    # Optional specific service hostname to test at Stage 6.
    [Parameter(Mandatory = $false)]
    [string]$ServiceHost,

    # Port to test against ServiceHost at Stage 6. Defaults to 443 (HTTPS)
    # as the most broadly applicable example if a host is supplied without
    # a specific port.
    [Parameter(Mandatory = $false)]
    [int]$ServicePort = 443
)

# ---------------------------------------------------------------------------
# SETUP
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

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
        $OutputPath = Join-Path $diagnosticsFolder "ConnectivitySuite_$timestamp.txt"
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

# Stage results are tracked in a structured list so the final summary can
# print a clean PASS/FAIL table matching the escalation report format in
# networking/connectivity-fault-isolation.md exactly — this means a
# technician can copy the summary block directly into a ticket.
$script:stageResults = [ordered]@{
    "Stage 1 - Device Self-Test"      = "NOT RUN"
    "Stage 2 - Gateway Reachability"  = "NOT RUN"
    "Stage 3 - Internal Reachability" = "NOT RUN"
    "Stage 4 - Internet Egress"       = "NOT RUN"
    "Stage 5 - DNS Resolution"        = "NOT RUN"
    "Stage 6 - Service Port Test"     = "NOT RUN"
}
$script:faultBoundary = $null

function Set-StageResult {
    param([string]$Stage, [string]$Result)
    $script:stageResults[$Stage] = $Result
    if ($Result -eq "FAIL" -and -not $script:faultBoundary) {
        $script:faultBoundary = $Stage
    }
}

# ---------------------------------------------------------------------------
# REPORT HEADER
# ---------------------------------------------------------------------------

Write-ReportLine "=" * 70
Write-ReportLine " IT SUPPORT - CONNECTIVITY FAULT ISOLATION REPORT"
Write-ReportLine " (Automated six-stage sequence per"
Write-ReportLine "  networking/connectivity-fault-isolation.md)"
Write-ReportLine "=" * 70
Write-ReportLine "Generated:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-ReportLine "Computer Name: $env:COMPUTERNAME"
Write-ReportLine "Current User:  $env:USERNAME"

# ---------------------------------------------------------------------------
# STAGE 1: DEVICE SELF-TEST
# ---------------------------------------------------------------------------

Write-SectionHeader "STAGE 1: DEVICE SELF-TEST"

$stage1Pass = $true
try {
    $loopback = Test-Connection -ComputerName "127.0.0.1" -Count 4 -ErrorAction Stop
    Write-ReportLine "Loopback (127.0.0.1): $($loopback.Count)/4 replies"
    if ($loopback.Count -eq 0) { $stage1Pass = $false }

    $adapter = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq "Up" } |
        Select-Object -First 1

    if ($adapter) {
        Write-ReportLine "Active Adapter: $($adapter.Name) - Status: $($adapter.Status) - Speed: $($adapter.LinkSpeed)"
    }
    else {
        Write-ReportLine "FLAG: No active network adapter found."
        $stage1Pass = $false
    }
}
catch {
    Write-ReportLine "ERROR during device self-test: $($_.Exception.Message)"
    $stage1Pass = $false
}

if ($stage1Pass) {
    Write-ReportLine ""
    Write-ReportLine "RESULT: PASS"
    Set-StageResult "Stage 1 - Device Self-Test" "PASS"
}
else {
    Write-ReportLine ""
    Write-ReportLine "RESULT: FAIL"
    Set-StageResult "Stage 1 - Device Self-Test" "FAIL"
}

# ---------------------------------------------------------------------------
# STAGE 2: GATEWAY REACHABILITY
# ---------------------------------------------------------------------------

Write-SectionHeader "STAGE 2: GATEWAY REACHABILITY"

$gateway = $null
if ($script:stageResults["Stage 1 - Device Self-Test"] -eq "PASS") {
    try {
        $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction Stop |
            Select-Object -First 1).NextHop

        if ($gateway) {
            $gwPing = Test-Connection -ComputerName $gateway -Count 10 -ErrorAction Stop
            $lossCount = 10 - $gwPing.Count
            $lossPct = [math]::Round(($lossCount / 10) * 100, 0)
            $avgLatency = if ($gwPing.Count -gt 0) {
                [math]::Round(($gwPing | Measure-Object ResponseTime -Average).Average, 1)
            } else { "N/A" }

            Write-ReportLine "Gateway:          $gateway"
            Write-ReportLine "Replies Received: $($gwPing.Count)/10"
            Write-ReportLine "Packet Loss:      $lossPct%"
            Write-ReportLine "Average Latency:  $avgLatency ms"

            if ($gwPing.Count -eq 0) {
                Write-ReportLine ""
                Write-ReportLine "RESULT: FAIL"
                Set-StageResult "Stage 2 - Gateway Reachability" "FAIL"
            }
            else {
                Write-ReportLine ""
                Write-ReportLine "RESULT: PASS"
                Set-StageResult "Stage 2 - Gateway Reachability" "PASS"
                if ($lossPct -gt 0) {
                    Write-ReportLine "NOTE: Partial packet loss detected ($lossPct%) - may indicate"
                    Write-ReportLine "      an unstable connection even though basic reachability passed."
                }
            }
        }
        else {
            Write-ReportLine "FLAG: No default gateway configured."
            Write-ReportLine ""
            Write-ReportLine "RESULT: FAIL"
            Set-StageResult "Stage 2 - Gateway Reachability" "FAIL"
        }
    }
    catch {
        Write-ReportLine "ERROR: $($_.Exception.Message)"
        Write-ReportLine ""
        Write-ReportLine "RESULT: FAIL"
        Set-StageResult "Stage 2 - Gateway Reachability" "FAIL"
    }
}
else {
    Write-ReportLine "SKIPPED - Stage 1 did not pass."
    Set-StageResult "Stage 2 - Gateway Reachability" "SKIPPED"
}

# ---------------------------------------------------------------------------
# STAGE 3: INTERNAL NETWORK REACHABILITY
# ---------------------------------------------------------------------------

Write-SectionHeader "STAGE 3: INTERNAL NETWORK REACHABILITY"

if ($script:stageResults["Stage 2 - Gateway Reachability"] -eq "PASS") {
    if ($InternalHost) {
        try {
            $internalPing = Test-Connection -ComputerName $InternalHost -Count 4 -ErrorAction Stop
            Write-ReportLine "Internal Host:    $InternalHost"
            Write-ReportLine "Replies Received: $($internalPing.Count)/4"

            if ($internalPing.Count -eq 0) {
                Write-ReportLine ""
                Write-ReportLine "RESULT: FAIL"
                Set-StageResult "Stage 3 - Internal Reachability" "FAIL"
            }
            else {
                Write-ReportLine ""
                Write-ReportLine "RESULT: PASS"
                Set-StageResult "Stage 3 - Internal Reachability" "PASS"
            }
        }
        catch {
            Write-ReportLine "ERROR: $InternalHost unreachable - $($_.Exception.Message)"
            Write-ReportLine ""
            Write-ReportLine "RESULT: FAIL"
            Set-StageResult "Stage 3 - Internal Reachability" "FAIL"
        }
    }
    else {
        Write-ReportLine "SKIPPED - No -InternalHost parameter supplied."
        Write-ReportLine "Run with -InternalHost <hostname> to test a specific internal resource."
        Set-StageResult "Stage 3 - Internal Reachability" "SKIPPED"
    }
}
else {
    Write-ReportLine "SKIPPED - Stage 2 did not pass."
    Set-StageResult "Stage 3 - Internal Reachability" "SKIPPED"
}

# ---------------------------------------------------------------------------
# STAGE 4: INTERNET EGRESS
# ---------------------------------------------------------------------------

Write-SectionHeader "STAGE 4: INTERNET EGRESS"

if ($script:stageResults["Stage 2 - Gateway Reachability"] -eq "PASS") {
    $externalTargets = @("8.8.8.8", "1.1.1.1")
    $anyReachable = $false

    foreach ($target in $externalTargets) {
        try {
            $result = Test-Connection -ComputerName $target -Count 4 -ErrorAction Stop
            $latency = if ($result.Count -gt 0) {
                [math]::Round(($result | Measure-Object ResponseTime -Average).Average, 1)
            } else { "N/A" }
            Write-ReportLine "$target : $($result.Count)/4 replies, avg ${latency}ms"
            if ($result.Count -gt 0) { $anyReachable = $true }
        }
        catch {
            Write-ReportLine "$target : UNREACHABLE"
        }
    }

    Write-ReportLine ""
    if ($anyReachable) {
        Write-ReportLine "RESULT: PASS"
        Set-StageResult "Stage 4 - Internet Egress" "PASS"
    }
    else {
        Write-ReportLine "RESULT: FAIL"
        Set-StageResult "Stage 4 - Internet Egress" "FAIL"
    }
}
else {
    Write-ReportLine "SKIPPED - Stage 2 did not pass."
    Set-StageResult "Stage 4 - Internet Egress" "SKIPPED"
}

# ---------------------------------------------------------------------------
# STAGE 5: DNS RESOLUTION
# ---------------------------------------------------------------------------

Write-SectionHeader "STAGE 5: DNS RESOLUTION"

if ($script:stageResults["Stage 4 - Internet Egress"] -eq "PASS") {
    $dnsTargets = @("google.com", "microsoft.com")
    $dnsFailures = 0

    foreach ($target in $dnsTargets) {
        try {
            $dnsResult = Resolve-DnsName -Name $target -ErrorAction Stop |
                Where-Object { $_.Type -eq "A" } | Select-Object -First 1
            if ($dnsResult) {
                Write-ReportLine "$target : RESOLVED -> $($dnsResult.IPAddress)"
            }
            else {
                Write-ReportLine "$target : NO A RECORD"
                $dnsFailures++
            }
        }
        catch {
            Write-ReportLine "$target : RESOLUTION FAILED"
            $dnsFailures++
        }
    }

    Write-ReportLine ""
    if ($dnsFailures -eq 0) {
        Write-ReportLine "RESULT: PASS"
        Set-StageResult "Stage 5 - DNS Resolution" "PASS"
    }
    else {
        Write-ReportLine "RESULT: FAIL ($dnsFailures of $($dnsTargets.Count) lookups failed)"
        Set-StageResult "Stage 5 - DNS Resolution" "FAIL"
    }
}
else {
    Write-ReportLine "SKIPPED - Stage 4 did not pass."
    Set-StageResult "Stage 5 - DNS Resolution" "SKIPPED"
}

# ---------------------------------------------------------------------------
# STAGE 6: SERVICE PORT TEST
# ---------------------------------------------------------------------------

Write-SectionHeader "STAGE 6: SERVICE PORT TEST"

if ($ServiceHost) {
    try {
        $portResult = Test-NetConnection -ComputerName $ServiceHost -Port $ServicePort `
            -WarningAction SilentlyContinue -ErrorAction Stop

        Write-ReportLine "Target:    ${ServiceHost}:${ServicePort}"
        Write-ReportLine "Reachable: $($portResult.TcpTestSucceeded)"

        if ($portResult.TcpTestSucceeded) {
            Write-ReportLine ""
            Write-ReportLine "RESULT: PASS"
            Set-StageResult "Stage 6 - Service Port Test" "PASS"
        }
        else {
            Write-ReportLine ""
            Write-ReportLine "RESULT: FAIL"
            Set-StageResult "Stage 6 - Service Port Test" "FAIL"
        }
    }
    catch {
        Write-ReportLine "ERROR: $($_.Exception.Message)"
        Write-ReportLine ""
        Write-ReportLine "RESULT: FAIL"
        Set-StageResult "Stage 6 - Service Port Test" "FAIL"
    }
}
else {
    Write-ReportLine "SKIPPED - No -ServiceHost parameter supplied."
    Write-ReportLine "Run with -ServiceHost <hostname> -ServicePort <port> to test a"
    Write-ReportLine "specific service (e.g. -ServiceHost mail.company.com -ServicePort 993)."
    Set-StageResult "Stage 6 - Service Port Test" "SKIPPED"
}

# ---------------------------------------------------------------------------
# TRACEROUTE (only run if a fault boundary was found beyond Stage 1)
# ---------------------------------------------------------------------------

Write-SectionHeader "TRACEROUTE TO 8.8.8.8"

if ($script:stageResults["Stage 1 - Device Self-Test"] -eq "PASS") {
    try {
        Write-ReportLine "Running traceroute (this may take up to 30 seconds)..."
        Write-ReportLine ""
        $trace = Test-NetConnection -ComputerName "8.8.8.8" -TraceRoute -ErrorAction Stop
        $hopNumber = 1
        foreach ($hop in $trace.TraceRoute) {
            Write-ReportLine ("  Hop {0,-3} {1}" -f $hopNumber, $hop)
            $hopNumber++
        }
    }
    catch {
        Write-ReportLine "Could not complete traceroute - $($_.Exception.Message)"
    }
}
else {
    Write-ReportLine "SKIPPED - Stage 1 did not pass; traceroute would not be informative."
}

# ---------------------------------------------------------------------------
# ESCALATION REPORT SUMMARY
# ---------------------------------------------------------------------------
# This block intentionally mirrors the escalation package format documented
# in networking/connectivity-fault-isolation.md so it can be copied directly
# into a ticket without reformatting.

Write-SectionHeader "CONNECTIVITY FAULT ISOLATION SUMMARY"

Write-ReportLine "Date/Time:          $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-ReportLine "Device:             $env:COMPUTERNAME"
Write-ReportLine ""
Write-ReportLine "STAGE RESULTS:"
foreach ($stage in $script:stageResults.Keys) {
    Write-ReportLine ("  {0,-35} {1}" -f $stage, $script:stageResults[$stage])
}

Write-ReportLine ""
if ($script:faultBoundary) {
    Write-ReportLine "FAULT BOUNDARY: $script:faultBoundary"
    Write-ReportLine ""
    Write-ReportLine "Refer to the corresponding stage in"
    Write-ReportLine "networking/connectivity-fault-isolation.md for next steps and"
    Write-ReportLine "escalation guidance."
}
else {
    $skippedOnly = ($script:stageResults.Values | Where-Object { $_ -eq "SKIPPED" }).Count
    $totalStages = $script:stageResults.Count
    if ($skippedOnly -eq 0) {
        Write-ReportLine "All stages passed. No connectivity fault detected by this automated"
        Write-ReportLine "sequence. If the user is still reporting an issue, the fault is"
        Write-ReportLine "likely application-specific, intermittent, or requires the optional"
        Write-ReportLine "-InternalHost / -ServiceHost parameters to test the specific"
        Write-ReportLine "resource the user is trying to reach."
    }
    else {
        Write-ReportLine "All executed stages passed; $skippedOnly of $totalStages stage(s) were"
        Write-ReportLine "skipped (optional parameters not supplied). Re-run with -InternalHost"
        Write-ReportLine "and/or -ServiceHost for complete coverage if the issue persists."
    }
}

Write-ReportLine ""
Write-ReportLine "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# ---------------------------------------------------------------------------
# FILE OUTPUT
# ---------------------------------------------------------------------------

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