<#
.SYNOPSIS
    Collects a comprehensive system health snapshot for IT support diagnostics.

.DESCRIPTION
    Gathers CPU, memory, disk, uptime, and core system information into a single
    structured report. Designed to be run by a standard (non-administrator) user
    during help desk triage to capture evidence before escalation, and to be
    attached to a ticket per the diagnostic-report-template.md format.

    This script is read-only. It makes no changes to the system. It is safe to
    run on any Windows 10/11 workstation without administrative privileges.

.NOTES
    Author:         it-support-ops repository
    Run as:         Standard user (no elevation required)
    Compatibility:  Windows 10, Windows 11, PowerShell 5.1+
    Output:         Console output + log file in user's Documents folder

.EXAMPLE
    .\Get-SystemHealthReport.ps1

    Runs the report and saves output to:
    $env:USERPROFILE\Documents\IT-Diagnostics\SystemHealthReport_<timestamp>.txt

.EXAMPLE
    .\Get-SystemHealthReport.ps1 -OutputPath "C:\Temp\report.txt"

    Runs the report and saves output to the specified custom path.
#>

[CmdletBinding()]
param(
    # Optional custom output path. If not specified, defaults to the user's
    # Documents\IT-Diagnostics folder with a timestamped filename.
    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

# ---------------------------------------------------------------------------
# SETUP: Establish output location and logging
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Continue"  # Continue collecting data even if one section fails
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
        $OutputPath = Join-Path $diagnosticsFolder "SystemHealthReport_$timestamp.txt"
    }
}

# Collect all output into an array so it can be written to console AND file
# without running every command twice.
$reportLines = New-Object System.Collections.Generic.List[string]

function Write-ReportLine {
    <#
        Writes a line to both the console and the in-memory report buffer.
        Centralising this ensures console and file output never drift apart.
    #>
    param([string]$Text = "")
    Write-Host $Text
    $reportLines.Add($Text)
}

function Write-SectionHeader {
    <#
        Standardises section headers across the report for consistent,
        scannable output — important when a technician is reading this
        quickly during a live ticket.
    #>
    param([string]$Title)
    Write-ReportLine ""
    Write-ReportLine "=" * 70
    Write-ReportLine " $Title"
    Write-ReportLine "=" * 70
}

# ---------------------------------------------------------------------------
# REPORT HEADER
# ---------------------------------------------------------------------------

Write-ReportLine "=" * 70
Write-ReportLine " IT SUPPORT - SYSTEM HEALTH REPORT"
Write-ReportLine "=" * 70
Write-ReportLine "Generated:        $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-ReportLine "Computer Name:    $env:COMPUTERNAME"
Write-ReportLine "Current User:     $env:USERNAME"
Write-ReportLine "Domain/Workgroup: $env:USERDOMAIN"

# ---------------------------------------------------------------------------
# SECTION 1: OPERATING SYSTEM INFORMATION
# ---------------------------------------------------------------------------

Write-SectionHeader "OPERATING SYSTEM"

try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $bootTime = $os.LastBootUpTime
    $uptime = (Get-Date) - $bootTime

    Write-ReportLine "OS Name:          $($os.Caption)"
    Write-ReportLine "OS Version:       $($os.Version)"
    Write-ReportLine "OS Architecture:  $($os.OSArchitecture)"
    Write-ReportLine "Last Boot Time:   $($bootTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-ReportLine "Uptime:           $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"

    # Flag long uptime as a potential factor in performance issues —
    # this gives the technician an immediate, actionable observation
    # rather than requiring them to do the date math manually.
    if ($uptime.Days -ge 14) {
        Write-ReportLine "NOTE:             Uptime exceeds 14 days. Consider recommending a restart"
        Write-ReportLine "                  if the user is experiencing performance issues."
    }
}
catch {
    Write-ReportLine "ERROR: Could not retrieve OS information - $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# SECTION 2: CPU INFORMATION AND CURRENT USAGE
# ---------------------------------------------------------------------------

Write-SectionHeader "CPU"

try {
    $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
    Write-ReportLine "Processor:        $($cpu.Name.Trim())"
    Write-ReportLine "Cores:            $($cpu.NumberOfCores)"
    Write-ReportLine "Logical Processors: $($cpu.NumberOfLogicalProcessors)"

    # Sample CPU usage over 3 readings to smooth out momentary spikes
    # that would otherwise give a misleading single-point reading.
    Write-ReportLine ""
    Write-ReportLine "Current CPU Usage (3 samples, 2 seconds apart):"
    $cpuSamples = Get-Counter '\Processor(_Total)\% Processor Time' `
        -SampleInterval 2 -MaxSamples 3 -ErrorAction Stop
    $avgCpu = ($cpuSamples.CounterSamples | Measure-Object -Property CookedValue -Average).Average

    foreach ($sample in $cpuSamples.CounterSamples) {
        Write-ReportLine ("  {0}: {1}%" -f $sample.Timestamp.ToString('HH:mm:ss'),
            [math]::Round($sample.CookedValue, 1))
    }
    Write-ReportLine ("Average CPU Usage: {0}%" -f [math]::Round($avgCpu, 1))

    if ($avgCpu -ge 85) {
        Write-ReportLine "FLAG:             CPU usage is critically high (>85%)."
    }
    elseif ($avgCpu -ge 60) {
        Write-ReportLine "FLAG:             CPU usage is elevated (60-85%). Monitor."
    }
}
catch {
    Write-ReportLine "ERROR: Could not retrieve CPU information - $($_.Exception.Message)"
}

# Top 10 CPU-consuming processes — gives the technician an immediate
# starting point if usage is elevated, without needing a second script.
Write-ReportLine ""
Write-ReportLine "Top 10 Processes by CPU:"
try {
    Get-Process -ErrorAction Stop |
        Sort-Object CPU -Descending |
        Select-Object -First 10 -Property ProcessName, Id, CPU,
            @{Name = "MemoryMB"; Expression = { [math]::Round($_.WorkingSet / 1MB, 1) } } |
        ForEach-Object {
            Write-ReportLine ("  {0,-25} PID:{1,-8} CPU:{2,-10} Mem:{3}MB" -f `
                $_.ProcessName, $_.Id, [math]::Round($_.CPU, 1), $_.MemoryMB)
        }
}
catch {
    Write-ReportLine "ERROR: Could not retrieve process list - $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# SECTION 3: MEMORY
# ---------------------------------------------------------------------------

Write-SectionHeader "MEMORY"

try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $totalMemGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeMemGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedMemGB  = [math]::Round($totalMemGB - $freeMemGB, 2)
    $pctUsed    = [math]::Round(($usedMemGB / $totalMemGB) * 100, 1)

    Write-ReportLine "Total Memory:     ${totalMemGB} GB"
    Write-ReportLine "Used Memory:      ${usedMemGB} GB"
    Write-ReportLine "Free Memory:      ${freeMemGB} GB"
    Write-ReportLine "Usage Percentage: ${pctUsed}%"

    if ($pctUsed -ge 90) {
        Write-ReportLine "FLAG:             Memory usage is critically high (>90%)."
    }
    elseif ($pctUsed -ge 75) {
        Write-ReportLine "FLAG:             Memory usage is elevated (75-90%). Monitor."
    }
}
catch {
    Write-ReportLine "ERROR: Could not retrieve memory information - $($_.Exception.Message)"
}

Write-ReportLine ""
Write-ReportLine "Top 10 Processes by Memory:"
try {
    Get-Process -ErrorAction Stop |
        Sort-Object WorkingSet -Descending |
        Select-Object -First 10 -Property ProcessName, Id,
            @{Name = "MemoryMB"; Expression = { [math]::Round($_.WorkingSet / 1MB, 1) } } |
        ForEach-Object {
            Write-ReportLine ("  {0,-25} PID:{1,-8} Mem:{2}MB" -f `
                $_.ProcessName, $_.Id, $_.MemoryMB)
        }
}
catch {
    Write-ReportLine "ERROR: Could not retrieve process list - $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# SECTION 4: DISK
# ---------------------------------------------------------------------------

Write-SectionHeader "DISK USAGE"

try {
    Get-PSDrive -PSProvider FileSystem -ErrorAction Stop |
        Where-Object { $_.Used -gt 0 } |
        ForEach-Object {
            $usedGB  = [math]::Round($_.Used / 1GB, 2)
            $freeGB  = [math]::Round($_.Free / 1GB, 2)
            $totalGB = $usedGB + $freeGB
            $pctFree = if ($totalGB -gt 0) { [math]::Round(($freeGB / $totalGB) * 100, 1) } else { 0 }

            Write-ReportLine ("Drive {0}: Used: {1}GB | Free: {2}GB | Total: {3}GB | {4}% Free" -f `
                $_.Name, $usedGB, $freeGB, $totalGB, $pctFree)

            if ($pctFree -lt 10) {
                Write-ReportLine "  FLAG: Critically low disk space (<10% free)."
            }
            elseif ($pctFree -lt 20) {
                Write-ReportLine "  FLAG: Low disk space (<20% free). Monitor."
            }
        }
}
catch {
    Write-ReportLine "ERROR: Could not retrieve disk information - $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# SECTION 5: NETWORK ADAPTER SUMMARY
# ---------------------------------------------------------------------------
# A brief network summary is included here for context — the full diagnostic
# detail belongs in Get-NetworkDiagnostics.ps1, but a basic adapter status
# check is valuable in a general health report since network state often
# correlates with reported performance issues.

Write-SectionHeader "NETWORK ADAPTER SUMMARY"

try {
    Get-NetAdapter -ErrorAction Stop |
        Where-Object { $_.Status -eq "Up" } |
        Select-Object Name, Status, LinkSpeed, MacAddress |
        ForEach-Object {
            Write-ReportLine ("Adapter: {0,-20} Status: {1,-8} Speed: {2}" -f `
                $_.Name, $_.Status, $_.LinkSpeed)
        }
}
catch {
    Write-ReportLine "ERROR: Could not retrieve network adapter information - $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# SECTION 6: PENDING RESTART CHECK
# ---------------------------------------------------------------------------

Write-SectionHeader "PENDING RESTART STATUS"

try {
    $rebootPending = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    if ($rebootPending) {
        Write-ReportLine "FLAG: A system restart is pending (Windows Update)."
    }
    else {
        Write-ReportLine "No pending restart detected from Windows Update."
    }
}
catch {
    Write-ReportLine "Could not determine pending restart status - $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# REPORT FOOTER AND FILE OUTPUT
# ---------------------------------------------------------------------------

Write-SectionHeader "REPORT COMPLETE"
Write-ReportLine "Generated:  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

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