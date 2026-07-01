#!/bin/bash
#
# network-diagnostics.sh
#
# SYNOPSIS
#   Collects a comprehensive network diagnostic snapshot for Linux endpoints,
#   following the same Layer 1-7 sequence used in
#   networking/network-troubleshooting-guide.md and mirroring
#   scripts/windows/Get-NetworkDiagnostics.ps1 for platform parity.
#
# DESCRIPTION
#   Gathers interface status, IP configuration, DHCP/DNS state, gateway
#   reachability, internet egress, and DNS resolution results into a single
#   structured report mapped directly to the documented Layer 1-7 sequence.
#
#   This script is read-only. It makes no configuration changes. It is safe
#   to run on any systemd-based Linux distribution without root privileges.
#
# USAGE
#   ./network-diagnostics.sh
#   ./network-diagnostics.sh -o /custom/output/path.txt
#   ./network-diagnostics.sh -t intranet.company.local
#
# OPTIONS
#   -o PATH   Custom output file path. Defaults to
#             $HOME/it-diagnostics/network-diagnostics_<timestamp>.txt
#   -t HOST   Additional internal hostname to test reachability and DNS
#             resolution against, alongside standard external tests.
#   -h        Show this help message
#
# COMPATIBILITY
#   Tested against: Ubuntu 20.04+, Debian 11+, RHEL/CentOS 8+
#   Requires: bash, iproute2 (ip command), standard on all target distributions
#   Optional: dig (for full DNS detail — falls back to getent if unavailable)
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
TEST_HOST=""
DEFAULT_DIR="$HOME/it-diagnostics"
DEFAULT_FILE="$DEFAULT_DIR/network-diagnostics_${TIMESTAMP}.txt"

usage() {
    grep '^#' "$0" | sed -e 's/^#//' -e 's/^!.*//'
    exit 0
}

while getopts "o:t:h" opt; do
    case "$opt" in
        o) OUTPUT_PATH="$OPTARG" ;;
        t) TEST_HOST="$OPTARG" ;;
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

# Tracks the first layer at which a failure is detected, mirroring the
# Set-FaultLayer pattern in the Windows equivalent script, so the report
# gives a clear single-line conclusion rather than requiring the reader
# to infer it from scattered results.
FAULT_LAYER=""
set_fault_layer() {
    if [ -z "$FAULT_LAYER" ]; then
        FAULT_LAYER="$1"
    fi
}

# ---------------------------------------------------------------------------
# REPORT HEADER
# ---------------------------------------------------------------------------

report_line "======================================================================"
report_line " IT SUPPORT - NETWORK DIAGNOSTIC REPORT"
report_line " (Layer 1-7 sequence per networking/network-troubleshooting-guide.md)"
report_line "======================================================================"
report_line "Generated:    $(date '+%Y-%m-%d %H:%M:%S')"
report_line "Hostname:     $(hostname)"
report_line "Current User: $(whoami)"

# ---------------------------------------------------------------------------
# LAYER 1/2: NETWORK INTERFACES
# ---------------------------------------------------------------------------

section_header "LAYER 1-2: NETWORK INTERFACES"

ACTIVE_INTERFACE=""

if command -v ip >/dev/null 2>&1; then
    # List all interfaces except loopback
    ip -brief link show 2>/dev/null | grep -v "^lo " | while IFS= read -r line; do
        report_line "  $line"
    done

    # Identify the active interface (state UP, has a default route association)
    ACTIVE_INTERFACE=$(ip route show default 2>/dev/null | awk '{print $5}' | head -1)

    if [ -z "$ACTIVE_INTERFACE" ]; then
        # Fall back to first interface that is UP, if no default route exists yet
        ACTIVE_INTERFACE=$(ip -brief link show 2>/dev/null | grep -v "^lo " | \
            awk '$2 == "UP" {print $1; exit}')
    fi

    if [ -n "$ACTIVE_INTERFACE" ]; then
        report_line ""
        report_line "Active Interface: $ACTIVE_INTERFACE"
        IFACE_DETAIL=$(ip link show "$ACTIVE_INTERFACE" 2>/dev/null)
        report_line "$IFACE_DETAIL"

        if echo "$IFACE_DETAIL" | grep -q "LOWER_UP"; then
            report_line "Physical Link: DETECTED (LOWER_UP present)"
        else
            report_line "FLAG: Physical link not detected (LOWER_UP absent)."
            set_fault_layer "Layer 1 (Physical) - No physical link detected"
        fi
    else
        report_line ""
        report_line "FLAG: No active network interface identified."
        set_fault_layer "Layer 1 (Physical) - No active interface"
    fi
else
    report_line "ERROR: 'ip' command not available — cannot assess network interfaces."
    set_fault_layer "Layer 1 (Physical) - Diagnostic tool unavailable"
fi

# ---------------------------------------------------------------------------
# LAYER 3: IP CONFIGURATION
# ---------------------------------------------------------------------------

section_header "LAYER 3: IP CONFIGURATION"

IPV4_ADDRESS=""
GATEWAY=""
IS_APIPA=0

if [ -n "$ACTIVE_INTERFACE" ] && [ -z "$FAULT_LAYER" ]; then
    IPV4_ADDRESS=$(ip -4 addr show "$ACTIVE_INTERFACE" 2>/dev/null | \
        grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    GATEWAY=$(ip route show default 2>/dev/null | awk '{print $3}' | head -1)

    report_line "Interface:       $ACTIVE_INTERFACE"
    report_line "IPv4 Address:    ${IPV4_ADDRESS:-Not assigned}"
    report_line "Default Gateway: ${GATEWAY:-Not configured}"

    if command -v resolvectl >/dev/null 2>&1; then
        DNS_SERVERS=$(resolvectl status "$ACTIVE_INTERFACE" 2>/dev/null | \
            grep "DNS Servers" | sed 's/.*DNS Servers: //')
        report_line "DNS Servers:     ${DNS_SERVERS:-Not found via resolvectl}"
    elif [ -f /etc/resolv.conf ]; then
        DNS_SERVERS=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')
        report_line "DNS Servers:     ${DNS_SERVERS:-Not found in /etc/resolv.conf}"
    fi

    # APIPA / link-local detection (169.254.x.x) — same diagnostic
    # significance on Linux as on Windows: DHCP failed to assign an address.
    if [[ "$IPV4_ADDRESS" == 169.254.* ]]; then
        IS_APIPA=1
        report_line ""
        report_line "FLAG: Link-local address detected (169.254.x.x)."
        report_line "      This indicates DHCP failed to assign an address."
        report_line "      See networking/dns-dhcp-playbook.md Part 2."
        set_fault_layer "Layer 3 (Network) - Link-local address / DHCP failure"
    elif [ -z "$IPV4_ADDRESS" ]; then
        report_line ""
        report_line "FLAG: No IPv4 address assigned."
        set_fault_layer "Layer 3 (Network) - No IP address"
    fi

    if [ -z "$GATEWAY" ] && [ "$IS_APIPA" -eq 0 ]; then
        report_line "FLAG: No default gateway configured."
        set_fault_layer "Layer 3 (Network) - No default gateway"
    fi
else
    report_line "Skipped - no active interface identified in Layer 1-2 section."
fi

# ---------------------------------------------------------------------------
# LAYER 3: GATEWAY REACHABILITY
# ---------------------------------------------------------------------------

section_header "LAYER 3: GATEWAY REACHABILITY"

if [ -n "$GATEWAY" ] && [ "$IS_APIPA" -eq 0 ]; then
    PING_RESULT=$(ping -c 4 -W 2 "$GATEWAY" 2>/dev/null)
    REPLIES=$(echo "$PING_RESULT" | grep -oP '\d+(?=\s+received)' | head -1)
    REPLIES=${REPLIES:-0}

    report_line "Gateway:          $GATEWAY"
    report_line "Replies Received: ${REPLIES}/4"

    if [ "$REPLIES" -gt 0 ]; then
        AVG_LATENCY=$(echo "$PING_RESULT" | grep -oP '(?<=/)[\d.]+(?=/[\d.]+/[\d.]+\s*ms)' | head -1)
        report_line "Average Latency:  ${AVG_LATENCY:-N/A} ms"

        if [ -n "$AVG_LATENCY" ] && awk -v l="$AVG_LATENCY" 'BEGIN { exit !(l > 100) }'; then
            report_line "FLAG: High latency to gateway (>100ms)."
        fi
    else
        report_line "FLAG: Gateway is unreachable."
        set_fault_layer "Layer 3 (Network) - Gateway unreachable"
    fi
else
    report_line "Skipped - no valid gateway available to test (see Layer 3 IP section above)."
fi

# ---------------------------------------------------------------------------
# LAYER 3/4: INTERNET EGRESS
# ---------------------------------------------------------------------------

section_header "INTERNET EGRESS (BYPASSING DNS)"

INTERNET_REACHABLE=0

if [ -n "$GATEWAY" ] && [ "$IS_APIPA" -eq 0 ] && [ -z "$FAULT_LAYER" ]; then
    for target in "8.8.8.8" "1.1.1.1"; do
        PING_RESULT=$(ping -c 2 -W 2 "$target" 2>/dev/null)
        REPLIES=$(echo "$PING_RESULT" | grep -oP '\d+(?=\s+received)' | head -1)
        REPLIES=${REPLIES:-0}

        if [ "$REPLIES" -gt 0 ]; then
            INTERNET_REACHABLE=1
            AVG_LATENCY=$(echo "$PING_RESULT" | grep -oP '(?<=/)[\d.]+(?=/[\d.]+/[\d.]+\s*ms)' | head -1)
            report_line "$target : REACHABLE (avg ${AVG_LATENCY:-N/A} ms)"
        else
            report_line "$target : UNREACHABLE"
        fi
    done

    if [ "$INTERNET_REACHABLE" -eq 0 ]; then
        report_line ""
        report_line "FLAG: No external IP addresses reachable. Internet egress is blocked"
        report_line "      or there is an upstream routing fault."
        set_fault_layer "Layer 3/4 - Internet egress unreachable"
    fi
else
    report_line "Skipped - gateway not reachable, internet test would not be informative."
fi

# ---------------------------------------------------------------------------
# LAYER 7: DNS RESOLUTION
# ---------------------------------------------------------------------------

section_header "LAYER 7: DNS RESOLUTION"

if [ "$INTERNET_REACHABLE" -eq 1 ]; then
    DNS_TARGETS=("google.com" "microsoft.com")
    if [ -n "$TEST_HOST" ]; then
        DNS_TARGETS+=("$TEST_HOST")
    fi

    DNS_FAILURES=0
    for target in "${DNS_TARGETS[@]}"; do
        RESOLVED_IP=""
        if command -v dig >/dev/null 2>&1; then
            RESOLVED_IP=$(dig +short "$target" A 2>/dev/null | head -1)
        elif command -v getent >/dev/null 2>&1; then
            RESOLVED_IP=$(getent hosts "$target" 2>/dev/null | awk '{print $1}' | head -1)
        fi

        if [ -n "$RESOLVED_IP" ]; then
            report_line "$target : RESOLVED -> $RESOLVED_IP"
        else
            report_line "$target : RESOLUTION FAILED"
            DNS_FAILURES=$((DNS_FAILURES + 1))
        fi
    done

    if [ "$DNS_FAILURES" -gt 0 ]; then
        report_line ""
        report_line "FLAG: $DNS_FAILURES of ${#DNS_TARGETS[@]} DNS lookups failed."
        report_line "      See networking/dns-dhcp-playbook.md Part 1."
        set_fault_layer "Layer 7 (Application) - DNS resolution failure"
    fi
else
    report_line "Skipped - internet egress not confirmed, DNS test would not be informative."
fi

# ---------------------------------------------------------------------------
# WIRELESS DETAIL (IF APPLICABLE)
# ---------------------------------------------------------------------------

section_header "WIRELESS DETAIL (IF APPLICABLE)"

WIRELESS_FOUND=0
if command -v iw >/dev/null 2>&1; then
    for iface in $(ip -brief link show 2>/dev/null | awk '{print $1}'); do
        if iw dev "$iface" info >/dev/null 2>&1; then
            WIRELESS_FOUND=1
            report_line "Interface: $iface"
            iw dev "$iface" link 2>/dev/null | while IFS= read -r line; do
                report_line "  $line"
            done
        fi
    done
fi

if [ "$WIRELESS_FOUND" -eq 0 ]; then
    report_line "No active wireless interface detected (wired connection, Wi-Fi"
    report_line "disabled, or 'iw' command not available)."
fi

# ---------------------------------------------------------------------------
# SUMMARY AND CONCLUSION
# ---------------------------------------------------------------------------

section_header "DIAGNOSTIC SUMMARY"

if [ -n "$FAULT_LAYER" ]; then
    report_line "FAULT BOUNDARY IDENTIFIED: $FAULT_LAYER"
    report_line ""
    report_line "Refer to the corresponding section of"
    report_line "networking/network-troubleshooting-guide.md or the relevant playbook"
    report_line "for next steps."
else
    report_line "No fault detected in Layers 1-7 automated checks."
    report_line "If the user is still reporting an issue, the fault is likely"
    report_line "application-specific or intermittent. Refer to"
    report_line "networking/connectivity-fault-isolation.md for extended diagnosis."
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