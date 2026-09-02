#!/bin/bash
#
# connectivity-suite.sh
#
# SYNOPSIS
#   Runs the staged connectivity fault isolation sequence defined in
#   networking/connectivity-fault-isolation.md on macOS endpoints. Mirrors
#   scripts/linux/connectivity-suite.sh and
#   scripts/windows/Test-ConnectivitySuite.ps1 for platform parity.
#
# DESCRIPTION
#   Executes the six-stage isolation sequence (device self-test, gateway,
#   internal reachability, internet egress, DNS, and service port checks),
#   stopping logically once an earlier stage fails, and reporting a clear
#   fault boundary. Also performs traceroute analysis and an optional
#   specific port/service reachability test. Output is formatted to match
#   the escalation package format in networking/connectivity-fault-isolation.md
#   so it can be pasted directly into a ticket.
#
#   This script is read-only. It makes no configuration changes. It is safe
#   to run without administrator privileges.
#
# USAGE
#   ./connectivity-suite.sh
#   ./connectivity-suite.sh -i fileserver.company.local
#   ./connectivity-suite.sh -s mail.company.com -p 993
#
# OPTIONS
#   -o PATH    Custom output file path. Defaults to
#              $HOME/it-diagnostics/connectivity-suite_<timestamp>.txt
#   -i HOST    Internal host to test at Stage 3 (Internal Network Reachability)
#   -s HOST    Service host to test at Stage 6 (Service Port Test)
#   -p PORT    Port to test against the service host (default: 443)
#   -h         Show this help message
#
# COMPATIBILITY
#   Tested against: macOS 12 (Monterey) and later, Intel and Apple Silicon
#   Requires: bash, ping, traceroute (standard on all supported macOS)
#   Optional: nc (netcat) for port testing — falls back to /dev/tcp if
#             unavailable; dig/nslookup for DNS — falls back to dscacheutil
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
INTERNAL_HOST=""
SERVICE_HOST=""
SERVICE_PORT=443
TRACE_TARGET="8.8.8.8"
DEFAULT_DIR="$HOME/it-diagnostics"
DEFAULT_FILE="$DEFAULT_DIR/connectivity-suite_${TIMESTAMP}.txt"

usage() {
    sed -n '2,/^set -uo pipefail/p' "$0" | grep '^#' | sed -e 's/^#//' -e 's/^!.*//'
    exit 0
}

while getopts "o:i:s:p:h" opt; do
    case "$opt" in
        o) OUTPUT_PATH="$OPTARG" ;;
        i) INTERNAL_HOST="$OPTARG" ;;
        s) SERVICE_HOST="$OPTARG" ;;
        p) SERVICE_PORT="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if ! [[ "$SERVICE_PORT" =~ ^[0-9]+$ ]] || [ "$SERVICE_PORT" -lt 1 ] || [ "$SERVICE_PORT" -gt 65535 ]; then
    echo "ERROR: -p port must be a number between 1 and 65535." >&2
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

resolve_host() {
    local target="$1"
    local ip=""
    if command -v dig >/dev/null 2>&1; then
        ip=$(dig +short "$target" A 2>/dev/null | grep -E '^[0-9]+\.' | head -1)
    fi
    if [ -z "$ip" ] && command -v nslookup >/dev/null 2>&1; then
        ip=$(nslookup "$target" 2>/dev/null | awk '/^Address: / {print $2}' | tail -1)
    fi
    if [ -z "$ip" ] && command -v dscacheutil >/dev/null 2>&1; then
        ip=$(dscacheutil -q host -a name "$target" 2>/dev/null | awk '/^ip_address:/ {print $2}' | head -1)
    fi
    echo "$ip"
}

declare -A STAGE_RESULTS
STAGE_ORDER=(
    "Stage 1 - Device Self-Test"
    "Stage 2 - Gateway Reachability"
    "Stage 3 - Internal Reachability"
    "Stage 4 - Internet Egress"
    "Stage 5 - DNS Resolution"
    "Stage 6 - Service Port Test"
)
for stage in "${STAGE_ORDER[@]}"; do
    STAGE_RESULTS["$stage"]="NOT RUN"
done

FAULT_BOUNDARY=""
set_stage_result() {
    local stage="$1"
    local result="$2"
    STAGE_RESULTS["$stage"]="$result"
    if [ "$result" == "FAIL" ] && [ -z "$FAULT_BOUNDARY" ]; then
        FAULT_BOUNDARY="$stage"
    fi
}

# ---------------------------------------------------------------------------
# REPORT HEADER
# ---------------------------------------------------------------------------

report_line "======================================================================"
report_line " IT SUPPORT - CONNECTIVITY FAULT ISOLATION REPORT (macOS)"
report_line " (Automated six-stage sequence per"
report_line "  networking/connectivity-fault-isolation.md)"
report_line "======================================================================"
report_line "Generated:    $(date '+%Y-%m-%d %H:%M:%S')"
report_line "Hostname:     $(hostname)"
report_line "Current User: $(whoami)"

# ---------------------------------------------------------------------------
# STAGE 1: DEVICE SELF-TEST
# ---------------------------------------------------------------------------

section_header "STAGE 1: DEVICE SELF-TEST"

STAGE1_PASS=1
ACTIVE_INTERFACE=""

# macOS ping's -t sets an overall deadline in seconds, unlike GNU ping's
# per-packet -W — see network-diagnostics.sh for the same note.
LOOPBACK_RESULT=$(ping -c 4 -t 4 127.0.0.1 2>/dev/null)
LOOPBACK_REPLIES=$(echo "$LOOPBACK_RESULT" | awk -F',' '/packets transmitted/ {print $2}' | grep -oE '[0-9]+')
LOOPBACK_REPLIES=${LOOPBACK_REPLIES:-0}
report_line "Loopback (127.0.0.1): ${LOOPBACK_REPLIES}/4 replies"
if [ "$LOOPBACK_REPLIES" -eq 0 ]; then
    STAGE1_PASS=0
fi

if command -v ifconfig >/dev/null 2>&1 && command -v route >/dev/null 2>&1; then
    ACTIVE_INTERFACE=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')

    if [ -z "$ACTIVE_INTERFACE" ]; then
        for iface in $(ifconfig -l 2>/dev/null); do
            [ "$iface" = "lo0" ] && continue
            if ifconfig "$iface" 2>/dev/null | grep -q "status: active"; then
                ACTIVE_INTERFACE="$iface"
                break
            fi
        done
    fi

    if [ -n "$ACTIVE_INTERFACE" ]; then
        report_line "Active Interface: $ACTIVE_INTERFACE"
    else
        report_line "FLAG: No active network interface found."
        STAGE1_PASS=0
    fi
else
    report_line "ERROR: 'ifconfig' or 'route' command not available."
    STAGE1_PASS=0
fi

report_line ""
if [ "$STAGE1_PASS" -eq 1 ]; then
    report_line "RESULT: PASS"
    set_stage_result "Stage 1 - Device Self-Test" "PASS"
else
    report_line "RESULT: FAIL"
    set_stage_result "Stage 1 - Device Self-Test" "FAIL"
fi

# ---------------------------------------------------------------------------
# STAGE 2: GATEWAY REACHABILITY
# ---------------------------------------------------------------------------

section_header "STAGE 2: GATEWAY REACHABILITY"

GATEWAY=""
if [ "${STAGE_RESULTS["Stage 1 - Device Self-Test"]}" == "PASS" ]; then
    GATEWAY=$(route -n get default 2>/dev/null | awk '/gateway:/ {print $2}')

    if [ -n "$GATEWAY" ]; then
        GW_RESULT=$(ping -c 10 -t 10 "$GATEWAY" 2>/dev/null)
        GW_REPLIES=$(echo "$GW_RESULT" | awk -F',' '/packets transmitted/ {print $2}' | grep -oE '[0-9]+')
        GW_REPLIES=${GW_REPLIES:-0}
        LOSS_PCT=$(( (10 - GW_REPLIES) * 10 ))

        report_line "Gateway:          $GATEWAY"
        report_line "Replies Received: ${GW_REPLIES}/10"
        report_line "Packet Loss:      ${LOSS_PCT}%"

        if [ "$GW_REPLIES" -gt 0 ]; then
            AVG_LATENCY=$(echo "$GW_RESULT" | awk -F'/' '/round-trip|rtt/ {print $5}')
            report_line "Average Latency:  ${AVG_LATENCY:-N/A} ms"
            report_line ""
            report_line "RESULT: PASS"
            set_stage_result "Stage 2 - Gateway Reachability" "PASS"
            if [ "$LOSS_PCT" -gt 0 ]; then
                report_line "NOTE: Partial packet loss detected (${LOSS_PCT}%) - may indicate"
                report_line "      an unstable connection even though basic reachability passed."
            fi
        else
            report_line ""
            report_line "RESULT: FAIL"
            set_stage_result "Stage 2 - Gateway Reachability" "FAIL"
        fi
    else
        report_line "FLAG: No default gateway configured."
        report_line ""
        report_line "RESULT: FAIL"
        set_stage_result "Stage 2 - Gateway Reachability" "FAIL"
    fi
else
    report_line "SKIPPED - Stage 1 did not pass."
    set_stage_result "Stage 2 - Gateway Reachability" "SKIPPED"
fi

# ---------------------------------------------------------------------------
# STAGE 3: INTERNAL NETWORK REACHABILITY
# ---------------------------------------------------------------------------

section_header "STAGE 3: INTERNAL NETWORK REACHABILITY"

if [ "${STAGE_RESULTS["Stage 2 - Gateway Reachability"]}" == "PASS" ]; then
    if [ -n "$INTERNAL_HOST" ]; then
        INTERNAL_RESULT=$(ping -c 4 -t 4 "$INTERNAL_HOST" 2>/dev/null)
        INTERNAL_REPLIES=$(echo "$INTERNAL_RESULT" | awk -F',' '/packets transmitted/ {print $2}' | grep -oE '[0-9]+')
        INTERNAL_REPLIES=${INTERNAL_REPLIES:-0}

        report_line "Internal Host:    $INTERNAL_HOST"
        report_line "Replies Received: ${INTERNAL_REPLIES}/4"
        report_line ""

        if [ "$INTERNAL_REPLIES" -gt 0 ]; then
            report_line "RESULT: PASS"
            set_stage_result "Stage 3 - Internal Reachability" "PASS"
        else
            report_line "RESULT: FAIL"
            set_stage_result "Stage 3 - Internal Reachability" "FAIL"
        fi
    else
        report_line "SKIPPED - No -i (internal host) parameter supplied."
        report_line "Run with -i <hostname> to test a specific internal resource."
        set_stage_result "Stage 3 - Internal Reachability" "SKIPPED"
    fi
else
    report_line "SKIPPED - Stage 2 did not pass."
    set_stage_result "Stage 3 - Internal Reachability" "SKIPPED"
fi

# ---------------------------------------------------------------------------
# STAGE 4: INTERNET EGRESS
# ---------------------------------------------------------------------------

section_header "STAGE 4: INTERNET EGRESS"

INTERNET_REACHABLE=0
if [ "${STAGE_RESULTS["Stage 2 - Gateway Reachability"]}" == "PASS" ]; then
    for target in "8.8.8.8" "1.1.1.1"; do
        RESULT=$(ping -c 4 -t 6 "$target" 2>/dev/null)
        REPLIES=$(echo "$RESULT" | awk -F',' '/packets transmitted/ {print $2}' | grep -oE '[0-9]+')
        REPLIES=${REPLIES:-0}

        if [ "$REPLIES" -gt 0 ]; then
            INTERNET_REACHABLE=1
            LATENCY=$(echo "$RESULT" | awk -F'/' '/round-trip|rtt/ {print $5}')
            report_line "$target : ${REPLIES}/4 replies, avg ${LATENCY:-N/A}ms"
        else
            report_line "$target : UNREACHABLE"
        fi
    done

    report_line ""
    if [ "$INTERNET_REACHABLE" -eq 1 ]; then
        report_line "RESULT: PASS"
        set_stage_result "Stage 4 - Internet Egress" "PASS"
    else
        report_line "RESULT: FAIL"
        set_stage_result "Stage 4 - Internet Egress" "FAIL"
    fi
else
    report_line "SKIPPED - Stage 2 did not pass."
    set_stage_result "Stage 4 - Internet Egress" "SKIPPED"
fi

# ---------------------------------------------------------------------------
# STAGE 5: DNS RESOLUTION
# ---------------------------------------------------------------------------

section_header "STAGE 5: DNS RESOLUTION"

if [ "${STAGE_RESULTS["Stage 4 - Internet Egress"]}" == "PASS" ]; then
    DNS_TARGETS=("google.com" "microsoft.com")
    DNS_FAILURES=0

    for target in "${DNS_TARGETS[@]}"; do
        RESOLVED_IP=$(resolve_host "$target")
        if [ -n "$RESOLVED_IP" ]; then
            report_line "$target : RESOLVED -> $RESOLVED_IP"
        else
            report_line "$target : RESOLUTION FAILED"
            DNS_FAILURES=$((DNS_FAILURES + 1))
        fi
    done

    report_line ""
    if [ "$DNS_FAILURES" -eq 0 ]; then
        report_line "RESULT: PASS"
        set_stage_result "Stage 5 - DNS Resolution" "PASS"
    else
        report_line "RESULT: FAIL ($DNS_FAILURES of ${#DNS_TARGETS[@]} lookups failed)"
        set_stage_result "Stage 5 - DNS Resolution" "FAIL"
    fi
else
    report_line "SKIPPED - Stage 4 did not pass."
    set_stage_result "Stage 5 - DNS Resolution" "SKIPPED"
fi

# ---------------------------------------------------------------------------
# STAGE 6: SERVICE PORT TEST
# ---------------------------------------------------------------------------

section_header "STAGE 6: SERVICE PORT TEST"

if [ -n "$SERVICE_HOST" ]; then
    PORT_OPEN=0

    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 5 "$SERVICE_HOST" "$SERVICE_PORT" 2>/dev/null; then
            PORT_OPEN=1
        fi
    else
        if timeout 5 bash -c "exec 3<>/dev/tcp/${SERVICE_HOST}/${SERVICE_PORT}" 2>/dev/null; then
            PORT_OPEN=1
            exec 3>&- 2>/dev/null
            exec 3<&- 2>/dev/null
        fi
    fi

    report_line "Target:    ${SERVICE_HOST}:${SERVICE_PORT}"
    report_line "Reachable: $([ "$PORT_OPEN" -eq 1 ] && echo "true" || echo "false")"
    report_line ""

    if [ "$PORT_OPEN" -eq 1 ]; then
        report_line "RESULT: PASS"
        set_stage_result "Stage 6 - Service Port Test" "PASS"
    else
        report_line "RESULT: FAIL"
        set_stage_result "Stage 6 - Service Port Test" "FAIL"
    fi
else
    report_line "SKIPPED - No -s (service host) parameter supplied."
    report_line "Run with -s <hostname> -p <port> to test a specific service"
    report_line "(e.g. -s mail.company.com -p 993)."
    set_stage_result "Stage 6 - Service Port Test" "SKIPPED"
fi

# ---------------------------------------------------------------------------
# TRACEROUTE (only run if Stage 1 passed)
# ---------------------------------------------------------------------------

section_header "TRACEROUTE TO $TRACE_TARGET"

if [ "${STAGE_RESULTS["Stage 1 - Device Self-Test"]}" == "PASS" ]; then
    if command -v traceroute >/dev/null 2>&1; then
        report_line "Running traceroute (this may take up to 30 seconds)..."
        report_line ""
        TRACE_OUTPUT=$(traceroute -w 2 -q 1 "$TRACE_TARGET" 2>/dev/null)
        echo "$TRACE_OUTPUT" | while IFS= read -r line; do
            report_line "  $line"
        done
    else
        report_line "'traceroute' command not available on this system."
    fi
else
    report_line "SKIPPED - Stage 1 did not pass; traceroute would not be informative."
fi

# ---------------------------------------------------------------------------
# ESCALATION REPORT SUMMARY
# ---------------------------------------------------------------------------

section_header "CONNECTIVITY FAULT ISOLATION SUMMARY"

report_line "Date/Time: $(date '+%Y-%m-%d %H:%M:%S')"
report_line "Device:    $(hostname)"
report_line ""
report_line "STAGE RESULTS:"
for stage in "${STAGE_ORDER[@]}"; do
    printf -v PADDED_LINE "  %-35s %s" "$stage" "${STAGE_RESULTS[$stage]}"
    report_line "$PADDED_LINE"
done

report_line ""
if [ -n "$FAULT_BOUNDARY" ]; then
    report_line "FAULT BOUNDARY: $FAULT_BOUNDARY"
    report_line ""
    report_line "Refer to the corresponding stage in"
    report_line "networking/connectivity-fault-isolation.md for next steps and"
    report_line "escalation guidance."
else
    SKIPPED_COUNT=0
    for stage in "${STAGE_ORDER[@]}"; do
        if [ "${STAGE_RESULTS[$stage]}" == "SKIPPED" ]; then
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        fi
    done

    if [ "$SKIPPED_COUNT" -eq 0 ]; then
        report_line "All stages passed. No connectivity fault detected by this automated"
        report_line "sequence. If the user is still reporting an issue, the fault is"
        report_line "likely application-specific, intermittent, or requires the optional"
        report_line "-i / -s parameters to test the specific resource the user is"
        report_line "trying to reach."
    else
        report_line "All executed stages passed; $SKIPPED_COUNT of ${#STAGE_ORDER[@]} stage(s) were"
        report_line "skipped (optional parameters not supplied). Re-run with -i and/or"
        report_line "-s for complete coverage if the issue persists."
    fi
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
