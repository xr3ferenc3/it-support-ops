#!/bin/bash
#
# log-summary.sh
#
# SYNOPSIS
#   Collects and summarises recent errors and warnings from the systemd
#   journal for IT support diagnostics. Mirrors
#   scripts/windows/Get-EventLogSummary.ps1 for platform parity.
#
# DESCRIPTION
#   Queries the systemd journal for recent priority-level errors and
#   warnings, groups them by originating unit/service to highlight
#   recurring patterns, and flags specific known conditions that commonly
#   correspond to documented playbook scenarios (application crashes,
#   unexpected shutdowns, service failures, out-of-memory kills).
#
#   This script is read-only. It makes no changes to the system. Standard
#   users can read their own journal entries by default on most
#   distributions; full system journal access may require membership in
#   the 'systemd-journal' group or root, and the script reports this
#   clearly if access is restricted rather than failing silently.
#
# USAGE
#   ./log-summary.sh
#   ./log-summary.sh -o /custom/output/path.txt
#   ./log-summary.sh -t 72 -u nginx
#
# OPTIONS
#   -o PATH   Custom output file path. Defaults to
#             $HOME/it-diagnostics/log-summary_<timestamp>.txt
#   -t HOURS  How many hours back to search (default: 24)
#   -u UNIT   Optional filter to a specific systemd unit/service name
#   -n COUNT  Maximum number of detailed events to display (default: 30)
#   -h        Show this help message
#
# COMPATIBILITY
#   Tested against: Ubuntu 20.04+, Debian 11+, RHEL/CentOS 8+
#   Requires: bash, systemd (journalctl) — standard on all target distributions
#   Falls back to /var/log/syslog or /var/log/messages if journalctl is
#   unavailable (older or non-systemd systems).
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
DEFAULT_FILE="$DEFAULT_DIR/log-summary_${TIMESTAMP}.txt"
HOURS_BACK=24
FILTER_UNIT=""
MAX_EVENTS=30

usage() {
    grep '^#' "$0" | sed -e 's/^#//' -e 's/^!.*//'
    exit 0
}

while getopts "o:t:u:n:h" opt; do
    case "$opt" in
        o) OUTPUT_PATH="$OPTARG" ;;
        t) HOURS_BACK="$OPTARG" ;;
        u) FILTER_UNIT="$OPTARG" ;;
        n) MAX_EVENTS="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if ! [[ "$HOURS_BACK" =~ ^[0-9]+$ ]] || [ "$HOURS_BACK" -lt 1 ]; then
    echo "ERROR: -t hours must be a positive whole number." >&2
    exit 1
fi
if ! [[ "$MAX_EVENTS" =~ ^[0-9]+$ ]] || [ "$MAX_EVENTS" -lt 1 ]; then
    echo "ERROR: -n count must be a positive whole number." >&2
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

# ---------------------------------------------------------------------------
# REPORT HEADER
# ---------------------------------------------------------------------------

report_line "======================================================================"
report_line " IT SUPPORT - LOG SUMMARY"
report_line "======================================================================"
report_line "Generated:    $(date '+%Y-%m-%d %H:%M:%S')"
report_line "Hostname:     $(hostname)"
report_line "Current User: $(whoami)"
report_line "Time Window:  Last ${HOURS_BACK} hour(s)"
if [ -n "$FILTER_UNIT" ]; then
    report_line "Unit Filter:  $FILTER_UNIT"
fi

# ---------------------------------------------------------------------------
# DETERMINE LOGGING BACKEND
# ---------------------------------------------------------------------------

USE_JOURNALCTL=0
if command -v journalctl >/dev/null 2>&1; then
    # Confirm journalctl actually has readable data, not just that the
    # binary exists — on some minimal/container systems the binary is
    # present but the journal is empty or inaccessible.
    if journalctl -n 1 >/dev/null 2>&1; then
        USE_JOURNALCTL=1
    fi
fi

if [ "$USE_JOURNALCTL" -eq 1 ]; then
    report_line "Log Source:   systemd journal (journalctl)"
else
    report_line "Log Source:   Falling back to traditional log files"
    report_line "              (journalctl unavailable or inaccessible)"
fi

# ---------------------------------------------------------------------------
# SECTION 1: ERROR AND WARNING SUMMARY
# ---------------------------------------------------------------------------

section_header "ERRORS AND WARNINGS (PRIORITY: WARNING AND ABOVE)"

TOTAL_EVENTS=0

if [ "$USE_JOURNALCTL" -eq 1 ]; then
    JOURNAL_ARGS=(--since "${HOURS_BACK} hours ago" --priority warning --no-pager)
    if [ -n "$FILTER_UNIT" ]; then
        JOURNAL_ARGS+=(--unit "$FILTER_UNIT")
    fi

    JOURNAL_OUTPUT=$(journalctl "${JOURNAL_ARGS[@]}" 2>/dev/null)
    TOTAL_EVENTS=$(echo "$JOURNAL_OUTPUT" | grep -c . || echo 0)

    if [ "$TOTAL_EVENTS" -eq 0 ] || [ -z "$JOURNAL_OUTPUT" ]; then
        report_line "No warning or error level events found in this window."
    else
        report_line "Total warning/error lines in window: $TOTAL_EVENTS"
        report_line ""

        # Group by reporting unit/process to highlight recurring patterns,
        # consistent with the source-grouping approach in the Windows
        # equivalent script. journalctl entries follow a fairly consistent
        # "hostname process[pid]:" prefix that this extracts the process
        # name from.
        report_line "Events grouped by source (most frequent first):"
        echo "$JOURNAL_OUTPUT" | \
            grep -oP '(?<=\s)[a-zA-Z0-9_.-]+(?=\[\d+\]:|\:)' 2>/dev/null | \
            sort | uniq -c | sort -rn | head -10 | \
            while IFS= read -r line; do
                report_line "  $line"
            done

        report_line ""
        DISPLAY_COUNT=$((TOTAL_EVENTS < MAX_EVENTS ? TOTAL_EVENTS : MAX_EVENTS))
        report_line "Detailed listing (most recent $DISPLAY_COUNT of $TOTAL_EVENTS):"
        report_line "----------------------------------------------------------------------"
        echo "$JOURNAL_OUTPUT" | tail -n "$MAX_EVENTS" | while IFS= read -r line; do
            report_line "  $line"
        done

        if [ "$TOTAL_EVENTS" -gt "$MAX_EVENTS" ]; then
            report_line ""
            report_line "($((TOTAL_EVENTS - MAX_EVENTS)) additional event(s) not shown — increase"
            report_line " -n or review the full journal with: journalctl --since '${HOURS_BACK} hours ago'"
        fi
    fi
else
    # Fallback for non-systemd or restricted environments
    LOG_FILE=""
    for candidate in /var/log/syslog /var/log/messages; do
        if [ -r "$candidate" ]; then
            LOG_FILE="$candidate"
            break
        fi
    done

    if [ -n "$LOG_FILE" ]; then
        report_line "Reading from: $LOG_FILE"
        report_line ""
        GREP_PATTERN="error|warning|warn|fail"
        if [ -n "$FILTER_UNIT" ]; then
            GREP_PATTERN="$FILTER_UNIT"
        fi
        grep -iE "$GREP_PATTERN" "$LOG_FILE" 2>/dev/null | tail -n "$MAX_EVENTS" | \
            while IFS= read -r line; do
                report_line "  $line"
            done
    else
        report_line "ERROR: No accessible log source found (journalctl unavailable,"
        report_line "and neither /var/log/syslog nor /var/log/messages is readable)."
        report_line "This may require elevated permissions on this system."
    fi
fi

# ---------------------------------------------------------------------------
# SECTION 2: KNOWN SIGNIFICANT CONDITIONS
# ---------------------------------------------------------------------------
# Mirrors the $knownEventIds lookup in the Windows script — surfaces
# specific, documented conditions explicitly so the technician doesn't have
# to recognise them by reading raw log text, and points directly to the
# relevant playbook.

section_header "KNOWN SIGNIFICANT CONDITIONS"

if [ "$USE_JOURNALCTL" -eq 1 ]; then
    FOUND_ANY=0

    # Out-of-memory kills — directly relevant to high-cpu-memory-usage.md
    OOM_COUNT=$(journalctl --since "${HOURS_BACK} hours ago" --no-pager 2>/dev/null | \
        grep -ic "out of memory\|oom-killer\|oom_kill" || echo 0)
    if [ "$OOM_COUNT" -gt 0 ]; then
        FOUND_ANY=1
        report_line "FLAG: $OOM_COUNT out-of-memory event(s) found."
        report_line "      See playbooks/high-cpu-memory-usage.md"
        journalctl --since "${HOURS_BACK} hours ago" --no-pager 2>/dev/null | \
            grep -i "out of memory\|oom-killer\|oom_kill" | head -3 | \
            while IFS= read -r line; do
                report_line "    $line"
            done
        report_line ""
    fi

    # Failed systemd services — relevant to printer/application playbooks
    FAILED_UNITS=$(systemctl --failed --no-legend 2>/dev/null)
    if [ -n "$FAILED_UNITS" ]; then
        FOUND_ANY=1
        report_line "FLAG: Failed systemd unit(s) detected:"
        echo "$FAILED_UNITS" | while IFS= read -r line; do
            report_line "  $line"
        done
        report_line "      Check the relevant service with: systemctl status <unit-name>"
        report_line ""
    fi

    # Unexpected shutdown / unclean restart indicators
    UNCLEAN_SHUTDOWN=$(journalctl --since "${HOURS_BACK} hours ago" --no-pager 2>/dev/null | \
        grep -ic "unclean shutdown\|unexpectedly\|watchdog.*reboot" || echo 0)
    if [ "$UNCLEAN_SHUTDOWN" -gt 0 ]; then
        FOUND_ANY=1
        report_line "FLAG: $UNCLEAN_SHUTDOWN possible unclean shutdown indicator(s) found."
        report_line "      Unexpected shutdowns are a common cause of profile or"
        report_line "      application configuration corruption. See"
        report_line "      playbooks/application-not-launching.md Step 6."
        report_line ""
    fi

    # Segmentation faults — relevant to application-not-launching.md
    SEGFAULT_COUNT=$(journalctl --since "${HOURS_BACK} hours ago" --no-pager 2>/dev/null | \
        grep -ic "segfault" || echo 0)
    if [ "$SEGFAULT_COUNT" -gt 0 ]; then
        FOUND_ANY=1
        report_line "FLAG: $SEGFAULT_COUNT segmentation fault(s) found."
        report_line "      See playbooks/application-not-launching.md Step 3."
        journalctl --since "${HOURS_BACK} hours ago" --no-pager 2>/dev/null | \
            grep -i "segfault" | head -3 | \
            while IFS= read -r line; do
                report_line "    $line"
            done
        report_line ""
    fi

    if [ "$FOUND_ANY" -eq 0 ]; then
        report_line "None of the documented significant conditions were found in this window."
    fi
else
    report_line "Skipped - known condition checks require journalctl, which is"
    report_line "unavailable or inaccessible on this system."
fi

# ---------------------------------------------------------------------------
# SECTION 3: BOOT HISTORY (RECENT BOOTS)
# ---------------------------------------------------------------------------
# Useful context when correlating a reported issue with a specific session —
# if the user says "it started this morning," knowing exactly when the
# system last booted narrows the investigation considerably.

section_header "RECENT BOOT HISTORY"

if [ "$USE_JOURNALCTL" -eq 1 ]; then
    BOOT_LIST=$(journalctl --list-boots --no-pager 2>/dev/null | tail -5)
    if [ -n "$BOOT_LIST" ]; then
        report_line "$BOOT_LIST"
    else
        report_line "Could not retrieve boot history (may require elevated permissions)."
    fi
else
    report_line "Skipped - boot history requires journalctl."
fi

# ---------------------------------------------------------------------------
# FOOTER AND FILE OUTPUT
# ---------------------------------------------------------------------------

section_header "REPORT COMPLETE"
report_line "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
report_line ""
report_line "Reminder: This report is a triage starting point. For full log detail,"
report_line "use: journalctl --since '${HOURS_BACK} hours ago' for complete context."

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