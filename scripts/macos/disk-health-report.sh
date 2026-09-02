#!/bin/bash
#
# disk-health-report.sh
#
# SYNOPSIS
#   Collects disk usage, volume health, and physical disk status for macOS
#   endpoints. Mirrors scripts/linux/disk-health-report.sh and
#   scripts/windows/Get-DiskHealthReport.ps1 for platform parity.
#
# DESCRIPTION
#   Gathers free space and inode usage per mounted volume, SMART health
#   status where available, disk I/O activity as a bottleneck indicator, and
#   the largest top-level folders in the user's home directory. Supports the
#   diagnostic steps in playbooks/high-cpu-memory-usage.md (Step 8) and
#   playbooks/application-not-launching.md (Step 1).
#
#   This script is read-only. It makes no changes to the system. All
#   functionality works without administrator privileges; SMART health
#   detail is read via 'diskutil info', which does not require elevation
#   on macOS (unlike smartctl on Linux).
#
# USAGE
#   ./disk-health-report.sh
#   ./disk-health-report.sh -o /custom/output/path.txt
#   ./disk-health-report.sh -l 15
#
# OPTIONS
#   -o PATH   Custom output file path. Defaults to
#             $HOME/it-diagnostics/disk-health-report_<timestamp>.txt
#   -l PCT    Low space warning threshold as a percentage free (default: 20)
#   -c PCT    Critical space threshold as a percentage free (default: 10)
#   -h        Show this help message
#
# COMPATIBILITY
#   Tested against: macOS 12 (Monterey) and later, Intel and Apple Silicon
#   Requires: bash, diskutil, df, du (standard on all macOS systems)
#
# AUTHOR
#   it-support-ops repository

set -uo pipefail
# See system-health-report.sh header comment for rationale on omitting -e.

# ---------------------------------------------------------------------------
# SETUP
# ---------------------------------------------------------------------------

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
OUTPUT_PATH=""
DEFAULT_DIR="$HOME/it-diagnostics"
DEFAULT_FILE="$DEFAULT_DIR/disk-health-report_${TIMESTAMP}.txt"
LOW_THRESHOLD=20
CRITICAL_THRESHOLD=10

usage() {
    sed -n '2,/^set -uo pipefail/p' "$0" | grep '^#' | sed -e 's/^#//' -e 's/^!.*//'
    exit 0
}

while getopts "o:l:c:h" opt; do
    case "$opt" in
        o) OUTPUT_PATH="$OPTARG" ;;
        l) LOW_THRESHOLD="$OPTARG" ;;
        c) CRITICAL_THRESHOLD="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if ! [[ "$LOW_THRESHOLD" =~ ^[0-9]+$ ]] || [ "$LOW_THRESHOLD" -lt 1 ] || [ "$LOW_THRESHOLD" -gt 100 ]; then
    echo "ERROR: -l threshold must be a number between 1 and 100." >&2
    exit 1
fi
if ! [[ "$CRITICAL_THRESHOLD" =~ ^[0-9]+$ ]] || [ "$CRITICAL_THRESHOLD" -lt 1 ] || [ "$CRITICAL_THRESHOLD" -gt 100 ]; then
    echo "ERROR: -c threshold must be a number between 1 and 100." >&2
    exit 1
fi

if [ -z "$OUTPUT_PATH" ]; then
    if mkdir -p "$DEFAULT_DIR" 2>/dev/null; then
        OUTPUT_PATH="$DEFAULT_FILE"
    else
        echo "WARNING: Could not create $DEFAULT_DIR — output will be console-only." >&2
        OUTPUT_PATH=""
    fi
fi

REPORT_BUFFER=$(mktemp)
trap 'rm -f "$REPORT_BUFFER"' EXIT

report_line() {
    local text="${1:-}"
    echo "$text"
    echo "$text" >> "$REPORT_BUFFER"
}

section_header() {
    local title="$1"
    report_line ""
    report_line "======================================================================"
    report_line " $title"
    report_line "======================================================================"
}

FLAGS=()
add_flag() {
    FLAGS+=("$1")
}

# ---------------------------------------------------------------------------
# REPORT HEADER
# ---------------------------------------------------------------------------

report_line "======================================================================"
report_line " IT SUPPORT - DISK HEALTH REPORT (macOS)"
report_line "======================================================================"
report_line "Generated:    $(date '+%Y-%m-%d %H:%M:%S')"
report_line "Hostname:     $(hostname)"
report_line "Current User: $(whoami)"
report_line "Thresholds:   Low <${LOW_THRESHOLD}% free | Critical <${CRITICAL_THRESHOLD}% free"

# ---------------------------------------------------------------------------
# SECTION 1: FILESYSTEM USAGE
# ---------------------------------------------------------------------------

section_header "FILESYSTEM USAGE"

if command -v df >/dev/null 2>&1; then
    while IFS= read -r line; do
        FILESYSTEM=$(echo "$line" | awk '{print $1}')
        SIZE=$(echo "$line" | awk '{print $2}')
        USED=$(echo "$line" | awk '{print $3}')
        AVAIL=$(echo "$line" | awk '{print $4}')
        USE_PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')
        MOUNT=$(echo "$line" | awk '{$1=$2=$3=$4=$5=""; print $0}' | sed 's/^ *//')

        if ! [[ "$USE_PCT" =~ ^[0-9]+$ ]]; then
            continue
        fi
        FREE_PCT=$((100 - USE_PCT))

        report_line "Mount: $MOUNT"
        report_line "  Filesystem: $FILESYSTEM"
        report_line "  Size:       $SIZE"
        report_line "  Used:       $USED ($USE_PCT%)"
        report_line "  Available:  $AVAIL (${FREE_PCT}% free)"

        if [ "$FREE_PCT" -lt "$CRITICAL_THRESHOLD" ]; then
            report_line "  STATUS:     CRITICAL - free space below ${CRITICAL_THRESHOLD}%"
            add_flag "Mount $MOUNT: CRITICAL low disk space (${FREE_PCT}% free)"
        elif [ "$FREE_PCT" -lt "$LOW_THRESHOLD" ]; then
            report_line "  STATUS:     LOW - free space below ${LOW_THRESHOLD}%"
            add_flag "Mount $MOUNT: LOW disk space (${FREE_PCT}% free)"
        else
            report_line "  STATUS:     OK"
        fi
        report_line ""
    done < <(df -H 2>/dev/null | grep -v "devfs" | tail -n +2)
else
    report_line "ERROR: 'df' command not available."
fi

# ---------------------------------------------------------------------------
# SECTION 2: INODE USAGE
# ---------------------------------------------------------------------------

section_header "INODE USAGE"

if command -v df >/dev/null 2>&1; then
    # macOS df -i column layout: Filesystem Size Used Avail Capacity iused
    # ifree %iused Mounted on — %iused is field 8, mount point starts at
    # field 9 (may itself contain spaces, e.g. "Macintosh HD").
    while IFS= read -r line; do
        IUSE_PCT=$(echo "$line" | awk '{print $8}' | tr -d '%')
        MOUNT=$(echo "$line" | awk '{for(i=9;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')

        if [[ "$IUSE_PCT" =~ ^[0-9]+$ ]]; then
            report_line "  $MOUNT: ${IUSE_PCT}% inodes used"
            if [ "$IUSE_PCT" -ge 90 ]; then
                report_line "  FLAG: Inode usage critically high on $MOUNT (${IUSE_PCT}%)."
                add_flag "Mount $MOUNT: CRITICAL inode usage (${IUSE_PCT}%)"
            elif [ "$IUSE_PCT" -ge 80 ]; then
                report_line "  FLAG: Inode usage elevated on $MOUNT (${IUSE_PCT}%)."
                add_flag "Mount $MOUNT: Elevated inode usage (${IUSE_PCT}%)"
            fi
        fi
    done < <(df -i 2>/dev/null | grep -v "devfs" | tail -n +2)
else
    report_line "ERROR: 'df' command not available."
fi

# ---------------------------------------------------------------------------
# SECTION 3: SMART DISK HEALTH (IF AVAILABLE)
# ---------------------------------------------------------------------------
# Unlike Linux (smartctl, typically root-only) and matching the Windows
# script's non-elevated capability, macOS exposes SMART status directly via
# 'diskutil info' without requiring administrator privileges.

section_header "PHYSICAL DISK HEALTH (SMART)"

if command -v diskutil >/dev/null 2>&1; then
    DISKS=$(diskutil list 2>/dev/null | grep -oE '^/dev/disk[0-9]+' | sed 's|/dev/||')

    if [ -z "$DISKS" ]; then
        report_line "Could not identify physical disk devices via diskutil list."
    else
        for disk in $DISKS; do
            report_line "Disk: /dev/$disk"

            DISK_INFO=$(diskutil info "/dev/$disk" 2>/dev/null)
            SMART_LINE=$(echo "$DISK_INFO" | grep -i "SMART Status" | sed 's/^ *//')

            if [ -n "$SMART_LINE" ]; then
                report_line "  $SMART_LINE"

                if echo "$SMART_LINE" | grep -qi "Verified"; then
                    report_line "  STATUS: OK"
                elif echo "$SMART_LINE" | grep -qi "Not Supported"; then
                    report_line "  STATUS: SMART not supported on this device (common for"
                    report_line "          external, virtual, or some Apple Silicon internal"
                    report_line "          NVMe storage) - not itself a fault indicator."
                else
                    report_line "  STATUS: FLAG - SMART health check did not report Verified"
                    add_flag "Disk /dev/$disk: SMART health check did not report Verified"
                fi
            else
                report_line "  Could not retrieve SMART status for this device."
            fi
            report_line ""
        done
    fi
else
    report_line "'diskutil' not available — physical disk health detail unavailable."
fi

# ---------------------------------------------------------------------------
# SECTION 4: DISK I/O PERFORMANCE INDICATOR
# ---------------------------------------------------------------------------

section_header "DISK I/O PERFORMANCE INDICATOR"

if command -v iostat >/dev/null 2>&1; then
    report_line "I/O activity (2-second sample):"
    # BSD iostat: two samples, the second reflects the interval average
    # rather than since-boot totals like the first sample does.
    IOSTAT_OUTPUT=$(iostat -w 2 -c 2 2>/dev/null | tail -n 2)
    report_line "$IOSTAT_OUTPUT"

    CPU_ID=$(echo "$IOSTAT_OUTPUT" | tail -1 | awk '{print $NF}')
    if [[ "$CPU_ID" =~ ^[0-9.]+$ ]]; then
        IO_BUSY=$(awk -v id="$CPU_ID" 'BEGIN { printf "%.1f", 100 - id }')
        report_line ""
        report_line "Approximate CPU non-idle time during sample: ${IO_BUSY}%"
        report_line "(A high figure alongside heavy disk activity above suggests the"
        report_line " disk may be a bottleneck; this is an indicator, not a precise"
        report_line " disk-specific utilisation percentage.)"
    fi
else
    report_line "'iostat' command not available — cannot assess disk I/O performance."
fi

# ---------------------------------------------------------------------------
# SECTION 5: LARGEST TOP-LEVEL FOLDERS IN HOME DIRECTORY
# ---------------------------------------------------------------------------

section_header "LARGEST TOP-LEVEL FOLDERS IN HOME DIRECTORY"

if command -v du >/dev/null 2>&1; then
    report_line "Scanning $HOME (this may take a moment)..."
    report_line ""
    # BSD du: -d 1 limits depth (equivalent to GNU's --max-depth=1)
    du -h -d 1 "$HOME" 2>/dev/null | sort -rh | head -9 | tail -8 | \
        while IFS= read -r line; do
            report_line "  $line"
        done
    report_line ""
    report_line "Note: This scan covers the current user's home directory only."
else
    report_line "'du' command not available."
fi

# ---------------------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------------------

section_header "DIAGNOSTIC SUMMARY"

if [ ${#FLAGS[@]} -eq 0 ]; then
    report_line "No disk-related issues flagged. All filesystems and disks within"
    report_line "normal thresholds."
else
    report_line "${#FLAGS[@]} issue(s) flagged:"
    report_line ""
    for flag in "${FLAGS[@]}"; do
        report_line "  - $flag"
    done
    report_line ""
    report_line "Refer to playbooks/high-cpu-memory-usage.md (Step 8) for next steps"
    report_line "on disk-related performance issues, or escalate per"
    report_line "methodology/escalation-matrix.md if a physical disk health"
    report_line "issue was identified."
fi

report_line ""
report_line "Generated: $(date '+%Y-%m-%d %H:%M:%S')"

# ---------------------------------------------------------------------------
# FILE OUTPUT
# ---------------------------------------------------------------------------

if [ -n "$OUTPUT_PATH" ]; then
    if cp "$REPORT_BUFFER" "$OUTPUT_PATH" 2>/dev/null; then
        echo ""
        echo "Report saved to: $OUTPUT_PATH"
        echo "Attach this file to the ticket per templates/diagnostic-report-template.md"
    else
        echo ""
        echo "WARNING: Could not save report to $OUTPUT_PATH — report was displayed" >&2
        echo "in console only. Copy manually if needed." >&2
    fi
else
    echo ""
    echo "No output file path available — report displayed in console only."
fi
