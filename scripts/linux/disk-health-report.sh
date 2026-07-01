#!/bin/bash
#
# disk-health-report.sh
#
# SYNOPSIS
#   Collects disk usage, mount point status, inode usage, and physical disk
#   health for Linux endpoints. Mirrors
#   scripts/windows/Get-DiskHealthReport.ps1 for platform parity.
#
# DESCRIPTION
#   Gathers free space and inode usage per mounted filesystem, SMART health
#   status where available, disk I/O wait as a bottleneck indicator, and the
#   largest top-level folders in the user's home directory. Supports the
#   diagnostic steps in playbooks/high-cpu-memory-usage.md (Step 8) and
#   playbooks/application-not-launching.md (Step 1).
#
#   This script is read-only. It makes no changes to the system. Most
#   functionality works without root privileges; SMART health checks
#   typically require root (via sudo) for full detail and degrade
#   gracefully with a clear note if unavailable.
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
#   Tested against: Ubuntu 20.04+, Debian 11+, RHEL/CentOS 8+
#   Requires: bash, coreutils, df, du (standard on all target distributions)
#   Optional: smartmontools (for SMART health detail — degrades gracefully
#             if not installed)
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
    grep '^#' "$0" | sed -e 's/^#//' -e 's/^!.*//'
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

# Validate threshold inputs are numeric and sensible — a malformed argument
# here should fail clearly rather than silently producing wrong comparisons
# later in the script.
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

# Accumulates flags across all sections, mirroring the Add-Flag pattern in
# the Windows equivalent script, so the summary at the end lists every
# concern in one place.
FLAGS=()
add_flag() {
    FLAGS+=("$1")
}

# ---------------------------------------------------------------------------
# REPORT HEADER
# ---------------------------------------------------------------------------

report_line "======================================================================"
report_line " IT SUPPORT - DISK HEALTH REPORT"
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
        MOUNT=$(echo "$line" | awk '{print $6}')

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
    done < <(df -h -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | tail -n +2)
else
    report_line "ERROR: 'df' command not available."
fi

# ---------------------------------------------------------------------------
# SECTION 2: INODE USAGE
# ---------------------------------------------------------------------------
# A filesystem can show plenty of free space by capacity while still being
# completely full on inodes (common with filesystems holding huge numbers
# of very small files, e.g. mail spools or cache directories). This is a
# distinct failure mode that capacity checks alone would miss entirely.

section_header "INODE USAGE"

if command -v df >/dev/null 2>&1; then
    while IFS= read -r line; do
        MOUNT=$(echo "$line" | awk '{print $6}')
        IUSE_PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')

        # Some filesystems report inode usage as "-" (not applicable, e.g.
        # certain network filesystems) — skip those rather than miscounting.
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
    done < <(df -i -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | tail -n +2)
else
    report_line "ERROR: 'df' command not available."
fi

# ---------------------------------------------------------------------------
# SECTION 3: SMART DISK HEALTH (IF AVAILABLE)
# ---------------------------------------------------------------------------

section_header "PHYSICAL DISK HEALTH (SMART)"

if command -v smartctl >/dev/null 2>&1; then
    # Identify physical disk devices (excludes partitions and loop devices)
    DISKS=$(lsblk -d -n -o NAME,TYPE 2>/dev/null | awk '$2 == "disk" {print $1}')

    if [ -z "$DISKS" ]; then
        report_line "Could not identify physical disk devices via lsblk."
    else
        for disk in $DISKS; do
            report_line "Disk: /dev/$disk"

            # SMART checks typically require root. Try without sudo first
            # (works on some systems with appropriate udev/group permissions),
            # then note clearly if elevation would be needed for full detail.
            SMART_OUTPUT=$(smartctl -H "/dev/$disk" 2>&1)
            SMART_EXIT=$?

            if [ $SMART_EXIT -eq 0 ] || echo "$SMART_OUTPUT" | grep -qi "SMART overall-health"; then
                HEALTH_LINE=$(echo "$SMART_OUTPUT" | grep -i "overall-health")
                report_line "  $HEALTH_LINE"

                if echo "$HEALTH_LINE" | grep -qi "PASSED"; then
                    report_line "  STATUS: OK"
                else
                    report_line "  STATUS: FLAG - SMART health check did not report PASSED"
                    add_flag "Disk /dev/$disk: SMART health check did not report PASSED"
                fi
            else
                report_line "  Could not retrieve SMART health status."
                report_line "  This typically requires root privileges. Re-run with:"
                report_line "    sudo smartctl -H /dev/$disk"
                report_line "  for full detail."
            fi
            report_line ""
        done
    fi
else
    report_line "'smartctl' not installed — physical disk health detail unavailable."
    report_line "Install with: sudo apt install smartmontools  (Debian/Ubuntu)"
    report_line "          or: sudo yum install smartmontools  (RHEL/CentOS)"
fi

# ---------------------------------------------------------------------------
# SECTION 4: DISK I/O PERFORMANCE INDICATOR
# ---------------------------------------------------------------------------

section_header "DISK I/O PERFORMANCE INDICATOR"

if command -v iostat >/dev/null 2>&1; then
    report_line "I/O wait and utilisation (2-second sample):"
    IOSTAT_OUTPUT=$(iostat -x 2 2 2>/dev/null | tail -n +$(($(iostat -x 2 2 2>/dev/null | wc -l) / 2 + 1)))
    report_line "$IOSTAT_OUTPUT"
else
    # Fall back to the %wa (I/O wait) figure from top, which is available
    # on virtually all systems without needing an additional package.
    if command -v top >/dev/null 2>&1; then
        report_line "'iostat' not installed (install sysstat package for full detail)."
        report_line "Falling back to I/O wait percentage from top:"
        CPU_LINE=$(top -bn1 | grep -i "^%Cpu\|^Cpu(s)" | head -1)
        WAIT_PCT=$(echo "$CPU_LINE" | grep -oP '[0-9.]+(?=\s*%?\s*wa)' | head -1)
        if [ -n "$WAIT_PCT" ]; then
            report_line "  I/O Wait: ${WAIT_PCT}%"
            if awk -v w="$WAIT_PCT" 'BEGIN { exit !(w > 10) }'; then
                report_line "  FLAG: Elevated I/O wait (>10%) may indicate a disk bottleneck."
                add_flag "Elevated I/O wait detected (${WAIT_PCT}%) - possible disk bottleneck"
            fi
        else
            report_line "  Could not parse I/O wait from top output."
        fi
    else
        report_line "Neither 'iostat' nor 'top' available — cannot assess disk I/O performance."
    fi
fi

# ---------------------------------------------------------------------------
# SECTION 5: LARGEST TOP-LEVEL FOLDERS IN HOME DIRECTORY
# ---------------------------------------------------------------------------
# Deliberately limited to top-level folders in $HOME only — a full recursive
# scan of the filesystem would be slow and is unnecessary for triage. This
# gives an immediate starting point for "what's using my space" follow-ups.

section_header "LARGEST TOP-LEVEL FOLDERS IN HOME DIRECTORY"

if command -v du >/dev/null 2>&1; then
    report_line "Scanning $HOME (this may take a moment)..."
    report_line ""
    du -h --max-depth=1 "$HOME" 2>/dev/null | sort -rh | head -9 | tail -8 | \
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