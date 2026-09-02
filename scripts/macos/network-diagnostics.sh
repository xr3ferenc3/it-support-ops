#!/bin/bash
#
# network-diagnostics.sh
#
# SYNOPSIS
#   Collects a comprehensive network diagnostic snapshot for macOS endpoints,
#   following the same Layer 1-7 sequence used in
#   networking/network-troubleshooting-guide.md and mirroring
#   scripts/linux/network-diagnostics.sh and
#   scripts/windows/Get-NetworkDiagnostics.ps1 for platform parity.
#
# DESCRIPTION
#   Gathers interface status, IP configuration, DHCP/DNS state, gateway
#   reachability, internet egress, and DNS resolution results into a single
#   structured report mapped directly to the documented Layer 1-7 sequence.
#
#   This script is read-only. It makes no configuration changes. It is safe
#   to run without administrator privileges.
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
#   Tested against: macOS 12 (Monterey) and later, Intel and Apple Silicon
#   Requires: bash, standard macOS command-line tools (ifconfig, route, ping)
#   Optional: dig (falls back to nslookup, then dscacheutil, if unavailable —
#             recent macOS releases do not always ship dig by default)
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
    sed -n '2,/^set -uo pipefail/p' "$0" | grep '^#' | sed -e 's/^#//' -e 's/^!.*//'
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

FAULT_LAYER=""
set_fault_layer() {
    if [ -z "$FAULT_LAYER" ]; then
        FAULT_LAYER="$1"
    fi
}

# resolve_host: tries dig, then nslookup, then dscacheutil (the macOS
# directory-service cache, always present even when the other two are not).
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

# ---------------------------------------------------------------------------
# REPORT HEADER
# ---------------------------------------------------------------------------

report_line "======================================================================"
report_line " IT SUPPORT - NETWORK DIAGNOSTIC REPORT (macOS)"
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

if command -v ifconfig >/dev/null 2>&1; then
    for iface in $(ifconfig -l 2>/dev/null); do
        [ "$iface" = "lo0" ] && continue
        STATUS_LINE=$(ifconfig "$iface" 2>/dev/null | grep "status:" | sed 's/^\s*//')
        report_line "  $iface: ${STATUS_LINE:-status unknown}"
    done

    # Identify the active interface via the default route, same logic as the
    # Linux/Windows scripts use — the interface actually carrying default
    # traffic, not just the first one that happens to be UP.
    ACTIVE_INTERFACE=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')

    if [ -z "$ACTIVE_INTERFACE" ]; then
        # Fall back to the first interface reporting "status: active"
        for iface in $(ifconfig -l 2>/dev/null); do
            [ "$iface" = "lo0" ] && continue
            if ifconfig "$iface" 2>/dev/null | grep -q "status: active"; then
                ACTIVE_INTERFACE="$iface"
                break
            fi
        done
    fi

    if [ -n "$ACTIVE_INTERFACE" ]; then
        report_line ""
        report_line "Active Interface: $ACTIVE_INTERFACE"
        IFACE_DETAIL=$(ifconfig "$ACTIVE_INTERFACE" 2>/dev/null)
        report_line "$IFACE_DETAIL"

        if echo "$IFACE_DETAIL" | grep -q "status: active"; then
            report_line "Physical Link: DETECTED (status: active)"
        else
            report_line "FLAG: Physical link not detected on active interface."
            set_fault_layer "Layer 1 (Physical) - No physical link detected"
        fi
    else
        report_line ""
        report_line "FLAG: No active network interface identified."
        set_fault_layer "Layer 1 (Physical) - No active interface"
    fi
else
    report_line "ERROR: 'ifconfig' command not available — cannot assess network interfaces."
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
    IPV4_ADDRESS=$(ifconfig "$ACTIVE_INTERFACE" 2>/dev/null | awk '/inet / {print $2}' | head -1)
    GATEWAY=$(route -n get default 2>/dev/null | awk '/gateway:/ {print $2}')

    report_line "Interface:       $ACTIVE_INTERFACE"
    report_line "IPv4 Address:    ${IPV4_ADDRESS:-Not assigned}"
    report_line "Default Gateway: ${GATEWAY:-Not configured}"

    if command -v scutil >/dev/null 2>&1; then
        DNS_SERVERS=$(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/ {print $3}' | sort -u | tr '\n' ' ')
        report_line "DNS Servers:     ${DNS_SERVERS:-Not found via scutil --dns}"
    fi

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

    # DHCP lease detail, when available — macOS exposes this directly via
    # ipconfig getpacket, unlike Linux where it must be inferred from logs.
    if command -v ipconfig >/dev/null 2>&1; then
        LEASE_INFO=$(ipconfig getpacket "$ACTIVE_INTERFACE" 2>/dev/null)
        if [ -n "$LEASE_INFO" ]; then
            report_line ""
            report_line "DHCP Lease Detail (ipconfig getpacket $ACTIVE_INTERFACE):"
            LEASE_TIME=$(echo "$LEASE_INFO" | awk '/lease_time/ {print $3}')
            DHCP_SERVER=$(echo "$LEASE_INFO" | awk '/server_identifier/ {print $3}')
            [ -n "$LEASE_TIME" ] && report_line "  Lease Time:  $LEASE_TIME"
            [ -n "$DHCP_SERVER" ] && report_line "  DHCP Server: $DHCP_SERVER"
        fi
    fi
else
    report_line "Skipped - no active interface identified in Layer 1-2 section."
fi

# ---------------------------------------------------------------------------
# LAYER 3: GATEWAY REACHABILITY
# ---------------------------------------------------------------------------

section_header "LAYER 3: GATEWAY REACHABILITY"

if [ -n "$GATEWAY" ] && [ "$IS_APIPA" -eq 0 ]; then
    # macOS ping's -t sets an overall deadline in seconds (unlike GNU ping's
    # per-packet -W), so this bounds total wait time to roughly 6 seconds.
    PING_RESULT=$(ping -c 4 -t 6 "$GATEWAY" 2>/dev/null)
    REPLIES=$(echo "$PING_RESULT" | awk -F',' '/packets transmitted/ {print $2}' | grep -oE '[0-9]+')
    REPLIES=${REPLIES:-0}

    report_line "Gateway:          $GATEWAY"
    report_line "Replies Received: ${REPLIES}/4"

    if [ "$REPLIES" -gt 0 ]; then
        AVG_LATENCY=$(echo "$PING_RESULT" | awk -F'/' '/round-trip|rtt/ {print $5}')
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
        PING_RESULT=$(ping -c 2 -t 4 "$target" 2>/dev/null)
        REPLIES=$(echo "$PING_RESULT" | awk -F',' '/packets transmitted/ {print $2}' | grep -oE '[0-9]+')
        REPLIES=${REPLIES:-0}

        if [ "$REPLIES" -gt 0 ]; then
            INTERNET_REACHABLE=1
            AVG_LATENCY=$(echo "$PING_RESULT" | awk -F'/' '/round-trip|rtt/ {print $5}')
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
        RESOLVED_IP=$(resolve_host "$target")
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
if command -v networksetup >/dev/null 2>&1; then
    WIFI_SERVICE=$(networksetup -listallhardwareports 2>/dev/null | \
        awk '/Wi-Fi|AirPort/{getline; print $2}')
    if [ -n "$WIFI_SERVICE" ]; then
        CURRENT_NETWORK=$(networksetup -getairportnetwork "$WIFI_SERVICE" 2>/dev/null)
        if echo "$CURRENT_NETWORK" | grep -qv "not associated"; then
            WIRELESS_FOUND=1
            report_line "Interface: $WIFI_SERVICE"
            report_line "  $CURRENT_NETWORK"
        fi
    fi
fi

if [ "$WIRELESS_FOUND" -eq 0 ]; then
    report_line "No active wireless connection detected (wired connection, Wi-Fi"
    report_line "disabled, or 'networksetup' command not available)."
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
