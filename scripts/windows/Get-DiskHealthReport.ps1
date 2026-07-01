<#
.SYNOPSIS
    Collects disk usage, volume health, and physical disk status for IT
    support diagnostics.

.DESCRIPTION
    Gathers free space per volume, physical disk health status (where
    available without elevation), disk queue length as an I/O bottleneck
    indicator, and flags any volume approaching capacity. Supports the
    diagnostic steps in playbooks/high-cpu-memory-usage.md (Step 8) and
    playbooks/application-not-launching.md (Step 1).

    This script is read-only. It makes no changes to the system. Most
    functionality works without administrative privileges; sections that
    require elevation for fuller detail (SMART status access in some
    environments) are clearly marked and degrade gracefully if unavailable.

.NOTES
    Author:         it-support-ops repository
    Run as:         Standard user (no elevation required; some SMART detail
                    may be limited without elevation depending on hardware
                    and driver configuration)
    Compatibility:  Windows 10, Windows 11, PowerShell 5.1+
    Output:         Console output + log file in user's Documents folder

.EXAMPLE
    .\Get-DiskHealthReport.ps1

    Runs the disk health report and saves output to:
    $env:USERPROFILE\Documents\IT-Diagnostics\DiskHealthReport_<timestamp>.txt

.EXAMPLE
    .\Get-DiskHealthReport.ps1 -LowSpaceThresholdPercent 15

    Runs the report using a custom low-space warning threshold of 15% free
    instead of the default 20%.
#>

[CmdletBinding()]
param(
    # Optional custom output path. Defaults to Documents\IT-Diagnostics.
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    # Percentage of free space below which a volume is flagged as low.
    # Default of 20 aligns with the threshold used in the high-cpu-memory
    # playbook for consistency across the repository.
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$LowSpaceThresholdPercent = 20,

    # Percentage of free space below which a volume is flagged as critical.
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$CriticalSpaceThresholdPercent = 10
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
        $OutputPath = Join-Path $diagnosticsFolder "DiskHealthReport_$timestamp.txt"
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

# Accumulates flags across all sections so the summary at the end can list
# every concern in one place rather than requiring the reader to scroll
# back through the full report to find them.
$script:flags = New-Object System.Collections.Generic.List[string]
function Add-Flag {
    param([string]$Message)
    $script:flags.Add($Message)
}

# ---------------------------------------------------------------------------
# REPORT HEADER
# ---------------------------------------------------------------------------

Write-ReportLine "=" * 70
Write-ReportLine " IT SUPPORT - DISK HEALTH REPORT"
Write-ReportLine "=" * 70
Write-ReportLine "Generated:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-ReportLine "Computer Name: $env:COMPUTERNAME"
Write-ReportLine "Current User:  $env:USERNAME"
Write-ReportLine "Thresholds:    Low <$LowSpaceThresholdPercent% free | Critical <$CriticalSpaceThresholdPercent% free"

# ---------------------------------------------------------------------------
# SECTION 1: VOLUME / FILE SYSTEM USAGE
# ---------------------------------------------------------------------------

Write-SectionHeader "VOLUME USAGE"

try {
    $volumes = Get-PSDrive -PSProvider FileSystem -ErrorAction Stop |
        Where-Object { $_.Used -gt 0 }

    if (-not $volumes) {
        Write-ReportLine "No file system volumes with usable data were found."
    }

    foreach ($vol in $volumes) {
        $usedGB  = [math]::Round($vol.Used / 1GB, 2)
        $freeGB  = [math]::Round($vol.Free / 1GB, 2)
        $totalGB = $usedGB + $freeGB
        $pctFree = if ($totalGB -gt 0) { [math]::Round(($freeGB / $totalGB) * 100, 1) } else { 0 }

        Write-ReportLine "Volume $($vol.Name):"
        Write-ReportLine "  Used:       $usedGB GB"
        Write-ReportLine "  Free:       $freeGB GB"
        Write-ReportLine "  Total:      $totalGB GB"
        Write-ReportLine "  Free %:     $pctFree%"

        if ($pctFree -lt $CriticalSpaceThresholdPercent) {
            Write-ReportLine "  STATUS:     CRITICAL - free space below ${CriticalSpaceThresholdPercent}%"
            Add-Flag "Volume $($vol.Name): CRITICAL low disk space ($pctFree% free)"
        }
        elseif ($pctFree -lt $LowSpaceThresholdPercent) {
            Write-ReportLine "  STATUS:     LOW - free space below ${LowSpaceThresholdPercent}%"
            Add-Flag "Volume $($vol.Name): LOW disk space ($pctFree% free)"
        }
        else {
            Write-ReportLine "  STATUS:     OK"
        }
        Write-ReportLine ""
    }
}
catch {
    Write-ReportLine "ERROR: Could not retrieve volume information - $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# SECTION 2: PHYSICAL DISK HEALTH
# ---------------------------------------------------------------------------

Write-SectionHeader "PHYSICAL DISK HEALTH"

try {
    $physicalDisks = Get-PhysicalDisk -ErrorAction Stop

    if (-not $physicalDisks) {
        Write-ReportLine "No physical disk information available via Get-PhysicalDisk on this system."
    }

    foreach ($disk in $physicalDisks) {
        Write-ReportLine "Disk: $($disk.FriendlyName)"
        Write-ReportLine "  Media Type:         $($disk.MediaType)"
        Write-ReportLine "  Health Status:      $($disk.HealthStatus)"
        Write-ReportLine "  Operational Status: $($disk.OperationalStatus)"
        Write-ReportLine "  Size:               $([math]::Round($disk.Size / 1GB, 1)) GB"

        if ($disk.HealthStatus -ne "Healthy") {
            Write-ReportLine "  STATUS:             FLAG - disk health is not reporting Healthy"
            Add-Flag "Physical disk '$($disk.FriendlyName)': HealthStatus = $($disk.HealthStatus)"
        }
        Write-ReportLine ""
    }
}
catch {
    # Get-PhysicalDisk can fail or return limited info without elevation or
    # on certain virtualised/managed hardware. Degrade gracefully rather
    # than treating this as a hard failure of the whole script.
    Write-ReportLine "Could not retrieve physical disk health via Get-PhysicalDisk."
    Write-ReportLine "This may require administrator privileges on this system, or the"
    Write-ReportLine "disk controller may not expose health data through this interface."
    Write-ReportLine "Detail: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# SECTION 3: DISK I/O PERFORMANCE INDICATOR
# ---------------------------------------------------------------------------
# Disk queue length is a useful proxy for whether the disk itself is a
# bottleneck, distinct from raw capacity. A sustained high queue length
# with otherwise normal CPU/memory usage points the technician toward
# storage hardware rather than continuing to chase a phantom CPU issue.

Write-SectionHeader "DISK I/O PERFORMANCE INDICATOR"

try {
    $queueSamples = Get-Counter '\PhysicalDisk(_Total)\Current Disk Queue Length' `
        -SampleInterval 2 -MaxSamples 3 -ErrorAction Stop

    $avgQueue = ($queueSamples.CounterSamples | Measure-Object -Property CookedValue -Average).Average
    Write-ReportLine "Average Disk Queue Length (3 samples, 2s apart): $([math]::Round($avgQueue, 2))"

    # A queue length sustained above 2 per physical disk is a commonly used
    # rule-of-thumb threshold indicating the disk cannot keep up with demand.
    if ($avgQueue -gt 2) {
        Write-ReportLine "STATUS: FLAG - sustained disk queue length above 2 indicates a"
        Write-ReportLine "        potential I/O bottleneck. The disk may be a limiting factor"
        Write-ReportLine "        in perceived system slowness."
        Add-Flag "Disk queue length elevated (avg $([math]::Round($avgQueue,2))) - possible I/O bottleneck"
    }
    else {
        Write-ReportLine "STATUS: OK"
    }
}
catch {
    Write-ReportLine "Could not retrieve disk queue length counter - $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# SECTION 4: LARGEST FOLDERS ON SYSTEM DRIVE (TOP-LEVEL ONLY)
# ---------------------------------------------------------------------------
# A common follow-up question once low disk space is identified is "what is
# actually using the space?" This gives an immediate, low-cost starting
# point (top-level user profile folders only — deliberately not a full
# recursive scan, which would be slow and is not necessary for triage).

Write-SectionHeader "LARGEST TOP-LEVEL FOLDERS IN USER PROFILE"

try {
    $profilePath = $env:USERPROFILE
    Get-ChildItem -Path $profilePath -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
            $folder = $_
            try {
                $size = (Get-ChildItem -Path $folder.FullName -Recurse -Force `
                            -ErrorAction SilentlyContinue |
                         Measure-Object -Property Length -Sum).Sum
                [PSCustomObject]@{
                    Folder = $folder.Name
                    SizeGB = if ($size) { [math]::Round($size / 1GB, 2) } else { 0 }
                }
            }
            catch {
                [PSCustomObject]@{ Folder = $folder.Name; SizeGB = "N/A" }
            }
        } |
        Sort-Object SizeGB -Descending |
        Select-Object -First 8 |
        ForEach-Object {
            Write-ReportLine ("  {0,-25} {1} GB" -f $_.Folder, $_.SizeGB)
        }

    Write-ReportLine ""
    Write-ReportLine "Note: This scan covers the current user's profile only and may take"
    Write-ReportLine "a moment to complete on profiles with large amounts of data."
}
catch {
    Write-ReportLine "Could not calculate folder sizes - $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------------------

Write-SectionHeader "DIAGNOSTIC SUMMARY"

if ($script:flags.Count -eq 0) {
    Write-ReportLine "No disk-related issues flagged. All volumes and disks within"
    Write-ReportLine "normal thresholds."
}
else {
    Write-ReportLine "$($script:flags.Count) issue(s) flagged:"
    Write-ReportLine ""
    foreach ($flag in $script:flags) {
        Write-ReportLine "  - $flag"
    }
    Write-ReportLine ""
    Write-ReportLine "Refer to playbooks/high-cpu-memory-usage.md (Step 8) for next steps"
    Write-ReportLine "on disk-related performance issues, or escalate per"
    Write-ReportLine "methodology/escalation-matrix.md if a physical disk health"
    Write-ReportLine "issue was identified."
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