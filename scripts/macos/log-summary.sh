#!/bin/bash
#
# log-summary.sh
#
# SYNOPSIS
#   Collects and summarises recent errors and warnings from the macOS
#   unified logging system for IT support diagnostics. Mirrors
#   scripts/linux/log-summary.sh and scripts/windows/Get-EventLogSummary.ps1
#   for platform parity.
#
# DESCRIPTION
#   Queries the unified log (via 'log show') for recent Error/Fault level
#   entries, groups them to highlight recurring patterns, and flags specific
#   known conditions that commonly correspond to documented playbook
#   scenarios (memory-pressure kills, failed launchd services, unexpected
#   shutdowns, and application crash reports).
#
#   This script is read-only. It makes no changes to the system. Standard
#   users can read the unified log for their own session and most system
#   activity by default; some entries may be redacted ("<private>") for
#   privacy reasons depending on system configuration, and this is normal,
#   not a script fault.
#
# USAGE
#   ./log-summary.sh
#   ./log-summary.sh -o /custom/output/path.txt
#   ./log-summary.sh -t 72 -u Safari
#
# OPTIONS
#   -o PATH   Custom output file path. Defaults to
#             $HOME/it-diagnostics/log-summary_<timestamp>.txt
#   -t HOURS  How many hours back to search (default: 24)
#   -u NAME   Optional filter to a specific process name
#   -n COUNT  Maximum number of detailed events to display (default: 30)
#   -h        Show this help message
#
# COMPATIBILITY
#   Tested against: macOS 12 (Monterey) and later, Intel and Apple Silicon
#   Requires: bash, log (unified logging, standard on all supported macOS)
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
FILTER_PROCESS=""
MAX_EVENTS=30

usage() {
    sed -n '2,/^set -uo pipefail/p' "$0" | grep '^#' | sed -e 's/^#//' -e 's/^!.*//'
    exit 0
}

while getopts "o:t:u:n:h" opt; do
    case "$opt" in
        o) OUTPUT_PATH="$OPTARG" ;;
        t) HOURS_BACK="$OPTARG" ;;
        u) FILTER_PROCESS="$OPTARG" ;;
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
report_line " IT SUPPORT - LOG SUMMARY (macOS)"
report_line "======================================================================"
report_line "Generated:    $(date '+%Y-%m-%d %H:%M:%S')"
report_line "Hostname:     $(hostname)"
report_line "Current User: $(whoami)"
report_line "Time Window:  Last ${HOURS_BACK} hour(s)"
if [ -n "$FILTER_PROCESS" ]; then
    report_line "Process Filter: $FILTER_PROCESS"
fi

USE_LOG_SHOW=0
if command -v log >/dev/null 2>&1; then
    if log show --last 1m >/dev/null 2>&1; then
        USE_LOG_SHOW=1
    fi
fi

if [ "$USE_LOG_SHOW" -eq 1 ]; then
    report_line "Log Source:   Unified logging (log show)"
else
    report_line "Log Source:   Unavailable — 'log show' could not be run on this system."
fi

# ---------------------------------------------------------------------------
# SECTION 1: ERROR AND FAULT SUMMARY
# ---------------------------------------------------------------------------

section_header "ERRORS AND FAULTS (messageType: Error, Fault)"

TOTAL_EVENTS=0

if [ "$USE_LOG_SHOW" -eq 1 ]; then
    PREDICATE='messageType == "Error" OR messageType == "Fault"'
    LOG_ARGS=(--last "${HOURS_BACK}h" --predicate "$PREDICATE" --style compact)
    if [ -n "$FILTER_PROCESS" ]; then
        LOG_ARGS+=(--process "$FILTER_PROCESS")
    fi

    LOG_OUTPUT=$(log show "${LOG_ARGS[@]}" 2>/dev/null | tail -n +2)
    # The first line of `log show` output is a "Filtering the log..." notice,
    # not a log entry — trimmed above so counts reflect actual entries only.
    TOTAL_EVENTS=$(echo "$LOG_OUTPUT" | grep -c . || echo 0)

    if [ "$TOTAL_EVENTS" -eq 0 ] || [ -z "$LOG_OUTPUT" ]; then
        report_line "No Error/Fault level events found in this window."
    else
        report_line "Total Error/Fault lines in window: $TOTAL_EVENTS"
        report_line ""

        # Group by reporting process to highlight recurring patterns. Compact
        # style places the process name after the message type field; this
        # extraction is a best-effort heuristic on that format, consistent
        # with how the Linux script parses journalctl's prefix.
        report_line "Events grouped by process (most frequent first):"
        echo "$LOG_OUTPUT" | \
            awk '{for(i=1;i<=NF;i++) if ($i ~ /:$/) {print $i; break}}' | \
            tr -d ':' | sort | uniq -c | sort -rn | head -10 | \
            while IFS= read -r line; do
                report_line "  $line"
            done

        report_line ""
        DISPLAY_COUNT=$((TOTAL_EVENTS < MAX_EVENTS ? TOTAL_EVENTS : MAX_EVENTS))
        report_line "Detailed listing (most recent $DISPLAY_COUNT of $TOTAL_EVENTS):"
        report_line "----------------------------------------------------------------------"
        echo "$LOG_OUTPUT" | tail -n "$MAX_EVENTS" | while IFS= read -r line; do
            report_line "  $line"
        done

        if [ "$TOTAL_EVENTS" -gt "$MAX_EVENTS" ]; then
            report_line ""
            report_line "($((TOTAL_EVENTS - MAX_EVENTS)) additional event(s) not shown — increase"
            report_line " -n or review the full log with: log show --last ${HOURS_BACK}h"
            report_line " --predicate '$PREDICATE'"
        fi
    fi
else
    report_line "Skipped - 'log show' is unavailable on this system."
fi

# ---------------------------------------------------------------------------
# SECTION 2: KNOWN SIGNIFICANT CONDITIONS
# ---------------------------------------------------------------------------

section_header "KNOWN SIGNIFICANT CONDITIONS"

FOUND_ANY=0

if [ "$USE_LOG_SHOW" -eq 1 ]; then
    # Memory-pressure kills (Jetsam) — directly relevant to
    # high-cpu-memory-usage.md. macOS logs these under the Jetsam subsystem
    # when a process is terminated for exceeding memory limits under
    # pressure, the closest macOS equivalent to Linux's OOM-killer.
    JETSAM_COUNT=$(log show --last "${HOURS_BACK}h" \
        --predicate 'eventMessage CONTAINS[c] "jetsam"' 2>/dev/null | \
        grep -ic "killed\|memorystatus" || echo 0)
    if [ "$JETSAM_COUNT" -gt 0 ]; then
        FOUND_ANY=1
        report_line "FLAG: $JETSAM_COUNT possible memory-pressure kill event(s) found (Jetsam)."
        report_line "      See playbooks/high-cpu-memory-usage.md"
        report_line ""
    fi

    # Unexpected shutdown indicator — macOS records a shutdown cause code on
    # every boot; codes other than a clean/normal shutdown indicate a panic
    # or unexpected power loss.
    SHUTDOWN_CAUSE=$(log show --last "${HOURS_BACK}h" \
        --predicate 'eventMessage CONTAINS "Previous shutdown cause"' 2>/dev/null | tail -1)
    if [ -n "$SHUTDOWN_CAUSE" ]; then
        FOUND_ANY=1
        report_line "Previous shutdown cause entry found:"
        report_line "  $SHUTDOWN_CAUSE"
        report_line "  A negative or unexpected cause code can indicate an unclean"
        report_line "  shutdown or kernel panic. See playbooks/application-not-launching.md"
        report_line "  Step 6 if this correlates with the reported issue."
        report_line ""
    fi
else
    report_line "Skipped - known condition checks require 'log show'."
fi

# Failed launchd services — relevant to printer/application playbooks.
# launchctl list's second column is the last exit status; non-zero and
# non-dash values indicate the job exited with an error.
if command -v launchctl >/dev/null 2>&1; then
    FAILED_JOBS=$(launchctl list 2>/dev/null | awk '$2 != "0" && $2 != "-" {print}')
    if [ -n "$FAILED_JOBS" ]; then
        FOUND_ANY=1
        report_line "FLAG: launchd job(s) with a non-zero last exit status:"
        echo "$FAILED_JOBS" | head -10 | while IFS= read -r line; do
            report_line "  $line"
        done
        report_line "      Note: some non-zero statuses are expected/benign for jobs that"
        report_line "      run once and exit — treat this as a starting point, not a"
        report_line "      definitive fault list."
        report_line ""
    fi
fi

# Recent application crash reports — macOS writes a dedicated report per
# crash rather than logging a bare "segfault" line, which is a more
# reliable and native signal than grepping the unified log for crash text.
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
if [ -d "$CRASH_DIR" ]; then
    RECENT_CRASHES=$(find "$CRASH_DIR" -maxdepth 1 -type f \( -name "*.crash" -o -name "*.ips" \) \
        -mtime "-$((HOURS_BACK / 24 + 1))" 2>/dev/null)
    if [ -n "$RECENT_CRASHES" ]; then
        FOUND_ANY=1
        CRASH_COUNT=$(echo "$RECENT_CRASHES" | grep -c .)
        report_line "FLAG: $CRASH_COUNT application crash report(s) found in this window."
        report_line "      See playbooks/application-not-launching.md Step 3."
        echo "$RECENT_CRASHES" | head -5 | while IFS= read -r f; do
            report_line "    - $(basename "$f")"
        done
        report_line ""
    fi
fi

if [ "$FOUND_ANY" -eq 0 ]; then
    report_line "None of the documented significant conditions were found in this window."
fi

# ---------------------------------------------------------------------------
# SECTION 3: RECENT BOOT HISTORY
# ---------------------------------------------------------------------------

section_header "RECENT BOOT HISTORY"

if command -v last >/dev/null 2>&1; then
    BOOT_LIST=$(last reboot 2>/dev/null | grep -v "^$" | head -5)
    if [ -n "$BOOT_LIST" ]; then
        report_line "$BOOT_LIST"
    else
        report_line "Could not retrieve boot history."
    fi
else
    report_line "'last' command not available — cannot retrieve boot history."
fi

# ---------------------------------------------------------------------------
# FOOTER AND FILE OUTPUT
# ---------------------------------------------------------------------------

section_header "REPORT COMPLETE"
report_line "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
report_line ""
report_line "Reminder: This report is a triage starting point. For full log detail,"
report_line "use: log show --last ${HOURS_BACK}h for complete context."

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
