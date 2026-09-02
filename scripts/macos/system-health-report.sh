#!/bin/bash
#
# system-health-report.sh
#
# SYNOPSIS
#   Collects a comprehensive system health snapshot for IT support diagnostics
#   on macOS endpoints. Mirrors scripts/linux/system-health-report.sh and
#   scripts/windows/Get-SystemHealthReport.ps1 for parity across all three
#   platforms covered by this repository.
#
# DESCRIPTION
#   Gathers CPU, memory, disk, uptime, and core system information into a
#   single structured report. Designed to be run by a standard (non-admin)
#   user during help desk triage to capture evidence before escalation,
#   and to be attached to a ticket per templates/diagnostic-report-template.md.
#
#   This script is read-only. It makes no changes to the system. It is safe
#   to run without administrator privileges. Where a check would benefit
#   from elevated access, the script notes this and continues with the best
#   available non-admin alternative rather than failing.
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
#   Tested against: macOS 12 (Monterey) and later, Intel and Apple Silicon
#   Requires: bash, standard macOS command-line tools (sysctl, vm_stat, ps, df)
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
    sed -n '2,/^set -uo pipefail/p' "$0" | grep '^#' | sed -e 's/^#//' -e 's/^!.*//'
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

# ---------------------------------------------------------------------------
# REPORT HEADER
# ---------------------------------------------------------------------------

report_line "======================================================================"
report_line " IT SUPPORT - SYSTEM HEALTH REPORT (macOS)"
report_line "======================================================================"
report_line "Generated:    $(date '+%Y-%m-%d %H:%M:%S')"
report_line "Hostname:     $(hostname)"
report_line "Current User: $(whoami)"

if command -v sw_vers >/dev/null 2>&1; then
    report_line "macOS:        $(sw_vers -productName) $(sw_vers -productVersion) (build $(sw_vers -buildVersion))"
else
    report_line "macOS:        Could not be determined"
fi

if command -v sysctl >/dev/null 2>&1; then
    MODEL=$(sysctl -n hw.model 2>/dev/null)
    report_line "Model:        ${MODEL:-Unknown}"
fi

# ---------------------------------------------------------------------------
# SECTION 1: UPTIME
# ---------------------------------------------------------------------------

section_header "UPTIME"

if command -v uptime >/dev/null 2>&1; then
    report_line "Uptime: $(uptime)"

    # macOS has no uptime -p; derive days-since-boot from kern.boottime instead,
    # which reports as "{ sec = 1234567890, usec = 0 } ...".
    BOOT_SEC=$(sysctl -n kern.boottime 2>/dev/null | grep -oE 'sec = [0-9]+' | grep -oE '[0-9]+')
    if [ -n "$BOOT_SEC" ]; then
        NOW_SEC=$(date +%s)
        UPTIME_DAYS=$(( (NOW_SEC - BOOT_SEC) / 86400 ))
        if [ "$UPTIME_DAYS" -ge 14 ]; then
            report_line "NOTE: Uptime exceeds 14 days ($UPTIME_DAYS days). Consider recommending"
            report_line "      a restart if the user is experiencing performance issues."
        fi
    fi
else
    report_line "ERROR: 'uptime' command not available."
fi

# ---------------------------------------------------------------------------
# SECTION 2: CPU
# ---------------------------------------------------------------------------

section_header "CPU"

if command -v sysctl >/dev/null 2>&1; then
    CPU_MODEL=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
    CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null)
    CPU_PHYSICAL=$(sysctl -n hw.physicalcpu 2>/dev/null)
    # machdep.cpu.brand_string is present on Intel Macs and is still exposed
    # (via Rosetta compatibility) on most Apple Silicon systems; hw.model is
    # the reliable fallback either way.
    report_line "Processor:      ${CPU_MODEL:-$(sysctl -n hw.model 2>/dev/null)}"
    report_line "Logical Cores:  ${CPU_CORES:-Unknown}"
    report_line "Physical Cores: ${CPU_PHYSICAL:-Unknown}"
else
    report_line "ERROR: 'sysctl' not available."
fi

report_line ""
report_line "Current CPU Usage:"

if command -v top >/dev/null 2>&1; then
    # `top -l 1` takes one sample and exits. The summary line looks like:
    # "CPU usage: 5.12% user, 10.34% sys, 84.54% idle"
    CPU_LINE=$(top -l 1 2>/dev/null | grep "^CPU usage")
    if [ -n "$CPU_LINE" ]; then
        report_line "  $CPU_LINE"

        IDLE_PCT=$(echo "$CPU_LINE" | grep -oE '[0-9.]+% idle' | grep -oE '[0-9.]+')
        if [ -n "$IDLE_PCT" ]; then
            USAGE_PCT=$(awk -v idle="$IDLE_PCT" 'BEGIN { printf "%.1f", 100 - idle }')
            report_line "  Approximate CPU Usage: ${USAGE_PCT}%"

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
if command -v sysctl >/dev/null 2>&1; then
    LOADAVG=$(sysctl -n vm.loadavg 2>/dev/null | tr -d '{}')
    report_line "  ${LOADAVG:-Not available}"
else
    report_line "  Not available."
fi

report_line ""
report_line "Top 10 Processes by CPU:"
if command -v ps >/dev/null 2>&1; then
    # BSD ps: -r sorts by current CPU usage, descending.
    ps -Ao pid,pcpu,pmem,comm -r 2>/dev/null | head -11 | tail -10 | \
        awk '{printf "  PID:%-8s CPU:%-6s%% MEM:%-6s%% %s\n", $1, $2, $3, $4}' \
        >> "$REPORT_BUFFER"
    ps -Ao pid,pcpu,pmem,comm -r 2>/dev/null | head -11 | tail -10 | \
        awk '{printf "  PID:%-8s CPU:%-6s%% MEM:%-6s%% %s\n", $1, $2, $3, $4}'
else
    report_line "  'ps' command not available."
fi

# ---------------------------------------------------------------------------
# SECTION 3: MEMORY
# ---------------------------------------------------------------------------

section_header "MEMORY"

if command -v vm_stat >/dev/null 2>&1 && command -v sysctl >/dev/null 2>&1; then
    PAGE_SIZE=$(vm_stat 2>/dev/null | head -1 | grep -oE '[0-9]+')
    MEM_TOTAL_BYTES=$(sysctl -n hw.memsize 2>/dev/null)

    VM_STAT_OUT=$(vm_stat 2>/dev/null)
    PAGES_FREE=$(echo "$VM_STAT_OUT" | grep "Pages free" | grep -oE '[0-9]+')
    PAGES_ACTIVE=$(echo "$VM_STAT_OUT" | grep "Pages active" | grep -oE '[0-9]+')
    PAGES_WIRED=$(echo "$VM_STAT_OUT" | grep "Pages wired down" | grep -oE '[0-9]+')
    PAGES_COMPRESSED=$(echo "$VM_STAT_OUT" | grep "Pages occupied by compressor" | grep -oE '[0-9]+')

    if [ -n "$PAGE_SIZE" ] && [ -n "$MEM_TOTAL_BYTES" ] && [ "$MEM_TOTAL_BYTES" -gt 0 ]; then
        MEM_TOTAL_GB=$(awk -v b="$MEM_TOTAL_BYTES" 'BEGIN { printf "%.1f", b / 1073741824 }')
        report_line "Total Physical Memory: ${MEM_TOTAL_GB} GB"

        if [ -n "$PAGES_ACTIVE" ] && [ -n "$PAGES_WIRED" ]; then
            # Used = active + wired + compressed (compressed counts as "in use"
            # even though the underlying pages are freed on disk). Free/inactive
            # pages are reclaimable and not counted as used, consistent with how
            # Activity Monitor's memory pressure gauge treats them.
            USED_PAGES=$(( PAGES_ACTIVE + PAGES_WIRED + ${PAGES_COMPRESSED:-0} ))
            MEM_USED_PCT=$(awk -v used="$USED_PAGES" -v ps="$PAGE_SIZE" -v total="$MEM_TOTAL_BYTES" \
                'BEGIN { printf "%.1f", (used * ps / total) * 100 }')
            report_line "Memory Usage: ${MEM_USED_PCT}%"

            if awk -v u="$MEM_USED_PCT" 'BEGIN { exit !(u >= 90) }'; then
                report_line "FLAG: Memory usage is critically high (>90%)."
            elif awk -v u="$MEM_USED_PCT" 'BEGIN { exit !(u >= 75) }'; then
                report_line "FLAG: Memory usage is elevated (75-90%). Monitor."
            fi
        fi

        if [ -n "$PAGES_FREE" ]; then
            FREE_GB=$(awk -v p="$PAGES_FREE" -v ps="$PAGE_SIZE" 'BEGIN { printf "%.2f", (p * ps) / 1073741824 }')
            report_line "Free (reclaimable): ${FREE_GB} GB"
        fi
    fi
else
    report_line "ERROR: 'vm_stat' or 'sysctl' not available."
fi

report_line ""
report_line "Top 10 Processes by Memory:"
if command -v ps >/dev/null 2>&1; then
    # BSD ps: -m sorts by memory usage, descending.
    ps -Ao pid,pmem,pcpu,comm -m 2>/dev/null | head -11 | tail -10 | \
        awk '{printf "  PID:%-8s MEM:%-6s%% CPU:%-6s%% %s\n", $1, $2, $3, $4}' \
        >> "$REPORT_BUFFER"
    ps -Ao pid,pmem,pcpu,comm -m 2>/dev/null | head -11 | tail -10 | \
        awk '{printf "  PID:%-8s MEM:%-6s%% CPU:%-6s%% %s\n", $1, $2, $3, $4}'
else
    report_line "  'ps' command not available."
fi

# ---------------------------------------------------------------------------
# SECTION 4: DISK USAGE
# ---------------------------------------------------------------------------

section_header "DISK USAGE"

if command -v df >/dev/null 2>&1; then
    # BSD df has no -x exclude flag like GNU df; filter out devfs (the
    # pseudo device filesystem) after the fact instead.
    df -H 2>/dev/null | grep -v "devfs" | while IFS= read -r line; do
        report_line "  $line"
    done

    report_line ""
    report_line "Volumes below 20% free space:"
    LOW_SPACE_FOUND=0
    while IFS= read -r line; do
        USE_PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')
        MOUNT=$(echo "$line" | awk '{$1=$2=$3=$4=$5=""; print $0}' | sed 's/^ *//')
        if [ -n "$USE_PCT" ] && [ "$USE_PCT" -ge 80 ] 2>/dev/null; then
            FREE_PCT=$((100 - USE_PCT))
            report_line "  FLAG: $MOUNT - ${FREE_PCT}% free (${USE_PCT}% used)"
            LOW_SPACE_FOUND=1
        fi
    done < <(df -H 2>/dev/null | grep -v "devfs" | tail -n +2)

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
# in the Linux and Windows scripts. Full detail belongs in network-diagnostics.sh.

section_header "NETWORK INTERFACE SUMMARY"

if command -v ifconfig >/dev/null 2>&1; then
    for iface in $(ifconfig -l 2>/dev/null); do
        [ "$iface" = "lo0" ] && continue
        STATUS_LINE=$(ifconfig "$iface" 2>/dev/null | grep "status:" | sed 's/^\s*//')
        INET_LINE=$(ifconfig "$iface" 2>/dev/null | grep "inet " | awk '{print $2}')
        if [ -n "$STATUS_LINE" ] || [ -n "$INET_LINE" ]; then
            report_line "  $iface: ${STATUS_LINE:-no status} ${INET_LINE:+(inet $INET_LINE)}"
        fi
    done
else
    report_line "'ifconfig' command not available."
fi

# ---------------------------------------------------------------------------
# SECTION 6: SOFTWARE UPDATE STATUS
# ---------------------------------------------------------------------------
# A live check (softwareupdate -l) requires network access and can take a
# long time, which is a poor fit for a fast triage script. Instead this
# reads the last cached result macOS already recorded, which is instant and
# makes no network call — a real signal, just not a freshly-forced one.

section_header "SOFTWARE UPDATE STATUS (cached)"

if command -v defaults >/dev/null 2>&1; then
    LAST_CHECK=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate LastSuccessfulDate 2>/dev/null)
    PENDING_COUNT=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate LastUpdatesAvailable 2>/dev/null)
    if [ -n "$LAST_CHECK" ]; then
        report_line "Last successful update check: $LAST_CHECK"
    fi
    if [ -n "$PENDING_COUNT" ] && [ "$PENDING_COUNT" != "0" ]; then
        report_line "FLAG: $PENDING_COUNT update(s) were pending as of the last check."
        report_line "      Run 'softwareupdate -l' or check System Settings for current status"
        report_line "      (not run automatically here — it requires network access and can be slow)."
    else
        report_line "No pending updates recorded as of the last check."
    fi
else
    report_line "Could not read cached software update status."
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
