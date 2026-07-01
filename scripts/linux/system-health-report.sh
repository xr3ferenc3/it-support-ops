#!/bin/bash
#
# system-health-report.sh
#
# SYNOPSIS
#   Collects a comprehensive system health snapshot for IT support diagnostics
#   on Linux endpoints. Mirrors scripts/windows/Get-SystemHealthReport.ps1
#   for parity across both platforms covered by this repository.
#
# DESCRIPTION
#   Gathers CPU, memory, disk, uptime, and core system information into a
#   single structured report. Designed to be run by a standard (non-root)
#   user during help desk triage to capture evidence before escalation,
#   and to be attached to a ticket per templates/diagnostic-report-template.md.
#
#   This script is read-only. It makes no changes to the system. It is safe
#   to run on any systemd-based Linux distribution without root privileges.
#   Where a check would benefit from root (e.g. full SMART data), the script
#   notes this and continues with the best available non-root alternative.
#
# USAGE
#   ./system-health-report.sh
#   ./system-health-report.sh -o /custom/output/path.txt
#
# OPTIONS
#   -o PATH   Custom output file path. Defaults to
#             $HOME/it-diagnostics/system-health-report_<timestamp>.txt
#   -h        Show this help message
#
# COMPATIBILITY
#   Tested against: Ubuntu 20.04+, Debian 11+, RHEL/CentOS 8+
#   Requires: bash, coreutils (standard on all target distributions)
#
# AUTHOR
#   it-support-ops repository

set -uo pipefail
# -u: treat unset variables as an error (catches typos in variable names)
# -o pipefail: a pipeline fails if any command in it fails, not just the last
# Deliberately NOT using -e: this script collects diagnostic data from many
# independent sources, and one failed check (e.g. a missing optional tool)
# should not abort the entire report. Each section handles its own errors.

# ---------------------------------------------------------------------------
# SETUP
# ---------------------------------------------------------------------------

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
OUTPUT_PATH=""
DEFAULT_DIR="$HOME/it-diagnostics"
DEFAULT_FILE="$DEFAULT_DIR/system-health-report_${TIMESTAMP}.txt"

usage() {
    grep '^#' "$0" | sed -e 's/^#//' -e 's/^!.*//'
    exit 0
}

while getopts "o:h" opt; do
    case "$opt" in
        o) OUTPUT_PATH="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [ -z "$OUTPUT_PATH" ]; then
    if mkdir -p "$DEFAULT_DIR" 2>/dev/null; then
        OUTPUT_PATH="$DEFAULT_FILE"
    else
        echo "WARNING: Could not create $DEFAULT_DIR — output will be console-only." >&2
        OUTPUT_PATH=""
    fi
fi

# All output is written to this temp buffer first, then to console and file
# together at the end. This keeps the write-twice logic (console + file) in
# one place rather than duplicating every echo statement throughout the script.
REPORT_BUFFER=$(mktemp)
trap 'rm -f "$REPORT_BUFFER"' EXIT
# trap ensures the temp file is cleaned up even if the script exits early
# due to an unexpected error — prevents leaving stray temp files behind.

report_line() {
    # Writes a line to both the console and the report buffer.
    # Centralising this ensures console and file output never drift apart.
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

# ---------------------------------------------------------------------------
# REPORT HEADER
# ---------------------------------------------------------------------------

report_line "======================================================================"
report_line " IT SUPPORT - SYSTEM HEALTH REPORT"
report_line "======================================================================"
report_line "Generated:    $(date '+%Y-%m-%d %H:%M:%S')"
report_line "Hostname:     $(hostname)"
report_line "Current User: $(whoami)"

if command -v lsb_release >/dev/null 2>&1; then
    report_line "Distribution: $(lsb_release -ds 2>/dev/null)"
elif [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    DISTRO_NAME=$(. /etc/os-release && echo "$PRETTY_NAME")
    report_line "Distribution: $DISTRO_NAME"
else
    report_line "Distribution: Could not be determined"
fi

# ---------------------------------------------------------------------------
# SECTION 1: UPTIME
# ---------------------------------------------------------------------------

section_header "UPTIME"

if command -v uptime >/dev/null 2>&1; then
    UPTIME_OUTPUT=$(uptime -p 2>/dev/null || uptime)
    report_line "Uptime: $UPTIME_OUTPUT"

    # Flag long uptime, consistent with the Windows equivalent script, since
    # this gives the technician an immediate actionable observation.
    UPTIME_DAYS=$(awk '{print int($1/86400)}' /proc/uptime 2>/dev/null || echo "0")
    if [ "$UPTIME_DAYS" -ge 14 ]; then
        report_line "NOTE: Uptime exceeds 14 days. Consider recommending a restart"
        report_line "      if the user is experiencing performance issues."
    fi
else
    report_line "ERROR: 'uptime' command not available."
fi

# ---------------------------------------------------------------------------
# SECTION 2: CPU
# ---------------------------------------------------------------------------

section_header "CPU"

if [ -f /proc/cpuinfo ]; then
    CPU_MODEL=$(grep -m 1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')
    CPU_CORES=$(grep -c "^processor" /proc/cpuinfo)
    report_line "Processor:  ${CPU_MODEL:-Unknown}"
    report_line "CPU Cores:  $CPU_CORES"
else
    report_line "ERROR: /proc/cpuinfo not available."
fi

report_line ""
report_line "Current CPU Usage:"

if command -v top >/dev/null 2>&1; then
    # Capture a single top snapshot in batch mode. The CPU line format from
    # `top` varies slightly across distributions, so this is parsed
    # defensively rather than assuming a fixed column position.
    CPU_LINE=$(top -bn1 | grep -i "^%Cpu\|^Cpu(s)" | head -1)
    if [ -n "$CPU_LINE" ]; then
        report_line "  $CPU_LINE"

        # Extract idle percentage to calculate usage, handling both common
        # top output formats ("id," for idle is consistent across formats)
        IDLE_PCT=$(echo "$CPU_LINE" | grep -oP '[0-9.]+(?=\s*%?\s*id)' | head -1)
        if [ -n "$IDLE_PCT" ]; then
            USAGE_PCT=$(awk -v idle="$IDLE_PCT" 'BEGIN { printf "%.1f", 100 - idle }')
            report_line "  Approximate CPU Usage: ${USAGE_PCT}%"

            # Use awk for floating point comparison since bash only handles integers
            if awk -v u="$USAGE_PCT" 'BEGIN { exit !(u >= 85) }'; then
                report_line "  FLAG: CPU usage is critically high (>85%)."
            elif awk -v u="$USAGE_PCT" 'BEGIN { exit !(u >= 60) }'; then
                report_line "  FLAG: CPU usage is elevated (60-85%). Monitor."
            fi
        fi
    else
        report_line "  Could not parse CPU usage line from top output."
    fi
else
    report_line "  'top' command not available — cannot report current CPU usage."
fi

report_line ""
report_line "Load Average (1, 5, 15 min):"
if [ -f /proc/loadavg ]; then
    report_line "  $(cut -d' ' -f1-3 /proc/loadavg)"
else
    report_line "  /proc/loadavg not available."
fi

report_line ""
report_line "Top 10 Processes by CPU:"
if command -v ps >/dev/null 2>&1; then
    ps aux --sort=-%cpu 2>/dev/null | head -11 | tail -10 | \
        awk '{printf "  %-20s PID:%-8s CPU:%-6s MEM:%-6s %s\n", $11, $2, $3"%", $4"%", $1}' \
        >> "$REPORT_BUFFER"
    ps aux --sort=-%cpu 2>/dev/null | head -11 | tail -10 | \
        awk '{printf "  %-20s PID:%-8s CPU:%-6s MEM:%-6s %s\n", $11, $2, $3"%", $4"%", $1}'
else
    report_line "  'ps' command not available."
fi

# ---------------------------------------------------------------------------
# SECTION 3: MEMORY
# ---------------------------------------------------------------------------

section_header "MEMORY"

if command -v free >/dev/null 2>&1; then
    report_line "$(free -h)"
    report_line ""

    # Calculate usage percentage from /proc/meminfo for the flag logic,
    # since `free` output formatting varies and is harder to parse reliably
    # than the raw values in /proc/meminfo.
    if [ -f /proc/meminfo ]; then
        MEM_TOTAL=$(grep "^MemTotal:" /proc/meminfo | awk '{print $2}')
        MEM_AVAILABLE=$(grep "^MemAvailable:" /proc/meminfo | awk '{print $2}')
        if [ -n "$MEM_TOTAL" ] && [ -n "$MEM_AVAILABLE" ] && [ "$MEM_TOTAL" -gt 0 ]; then
            MEM_USED_PCT=$(awk -v t="$MEM_TOTAL" -v a="$MEM_AVAILABLE" \
                'BEGIN { printf "%.1f", ((t - a) / t) * 100 }')
            report_line "Memory Usage: ${MEM_USED_PCT}%"

            if awk -v u="$MEM_USED_PCT" 'BEGIN { exit !(u >= 90) }'; then
                report_line "FLAG: Memory usage is critically high (>90%)."
            elif awk -v u="$MEM_USED_PCT" 'BEGIN { exit !(u >= 75) }'; then
                report_line "FLAG: Memory usage is elevated (75-90%). Monitor."
            fi
        fi
    fi
else
    report_line "ERROR: 'free' command not available."
fi

report_line ""
report_line "Top 10 Processes by Memory:"
if command -v ps >/dev/null 2>&1; then
    ps aux --sort=-%mem 2>/dev/null | head -11 | tail -10 | \
        awk '{printf "  %-20s PID:%-8s MEM:%-6s %s\n", $11, $2, $4"%", $1}' \
        >> "$REPORT_BUFFER"
    ps aux --sort=-%mem 2>/dev/null | head -11 | tail -10 | \
        awk '{printf "  %-20s PID:%-8s MEM:%-6s %s\n", $11, $2, $4"%", $1}'
else
    report_line "  'ps' command not available."
fi

# ---------------------------------------------------------------------------
# SECTION 4: DISK USAGE
# ---------------------------------------------------------------------------

section_header "DISK USAGE"

if command -v df >/dev/null 2>&1; then
    # Exclude pseudo filesystems (tmpfs, devtmpfs, etc.) to keep the report
    # focused on filesystems that actually represent physical or persistent
    # storage a technician would care about for capacity troubleshooting.
    df -h -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | \
        while IFS= read -r line; do
            report_line "  $line"
        done

    report_line ""
    report_line "Volumes below 20% free space:"
    LOW_SPACE_FOUND=0
    while IFS= read -r line; do
        USE_PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')
        MOUNT=$(echo "$line" | awk '{print $6}')
        if [ -n "$USE_PCT" ] && [ "$USE_PCT" -ge 80 ] 2>/dev/null; then
            FREE_PCT=$((100 - USE_PCT))
            report_line "  FLAG: $MOUNT - ${FREE_PCT}% free (${USE_PCT}% used)"
            LOW_SPACE_FOUND=1
        fi
    done < <(df -h -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | tail -n +2)

    if [ "$LOW_SPACE_FOUND" -eq 0 ]; then
        report_line "  None — all volumes have adequate free space."
    fi
else
    report_line "ERROR: 'df' command not available."
fi

# ---------------------------------------------------------------------------
# SECTION 5: NETWORK INTERFACE SUMMARY
# ---------------------------------------------------------------------------
# A brief summary is included for context, matching the equivalent section
# in the Windows script. Full detail belongs in network-diagnostics.sh.

section_header "NETWORK INTERFACE SUMMARY"

if command -v ip >/dev/null 2>&1; then
    ip -brief link show 2>/dev/null | grep -v "^lo " | while IFS= read -r line; do
        report_line "  $line"
    done
else
    report_line "'ip' command not available."
fi

# ---------------------------------------------------------------------------
# SECTION 6: PENDING REBOOT CHECK
# ---------------------------------------------------------------------------

section_header "PENDING REBOOT STATUS"

if [ -f /var/run/reboot-required ]; then
    report_line "FLAG: A system reboot is pending (package updates require restart)."
    if [ -f /var/run/reboot-required.pkgs ]; then
        report_line "Packages requiring reboot:"
        while IFS= read -r pkg; do
            report_line "  - $pkg"
        done < /var/run/reboot-required.pkgs
    fi
else
    report_line "No pending reboot detected."
fi

# ---------------------------------------------------------------------------
# FOOTER AND FILE OUTPUT
# ---------------------------------------------------------------------------

section_header "REPORT COMPLETE"
report_line "Generated: $(date '+%Y-%m-%d %H:%M:%S')"

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