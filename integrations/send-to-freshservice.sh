#!/bin/bash
#
# send-to-freshservice.sh
#
# SYNOPSIS
#   Attaches an IT support diagnostic report to an existing Freshservice
#   ticket as a note. OS-agnostic (pure curl) - works identically on Linux,
#   macOS, and Windows via WSL or Git Bash. See Send-ToFreshservice.ps1 in
#   scripts/windows for the native PowerShell equivalent.
#
# DESCRIPTION
#   Posts a note (private by default) to an existing Freshservice ticket,
#   with the specified file attached. This is intentionally scoped to
#   attaching evidence to a ticket that already exists - it does not create
#   new tickets, since ticket creation typically requires organization-
#   specific required fields (priority, status, custom fields) that this
#   script cannot safely guess at. Creating the ticket is left to your
#   normal Freshservice workflow; this script closes the gap of manually
#   downloading a report file and re-uploading it through the web UI.
#
#   Credentials are read from environment variables only - never from
#   command-line arguments - so they cannot leak into shell history or be
#   visible to other users via `ps`. See README.md in this folder for setup.
#
# USAGE
#   export FRESHSERVICE_DOMAIN="yourcompany.freshservice.com"
#   export FRESHSERVICE_API_KEY="your-api-key"
#   ./send-to-freshservice.sh -t 12345 -f ~/it-diagnostics/report.txt
#   ./send-to-freshservice.sh -t 12345 -f report.txt -m "Diagnostic report attached" -p
#
# OPTIONS
#   -t ID      Ticket ID to attach the report to (required)
#   -f PATH    Path to the file to attach (required)
#   -m TEXT    Note text. Defaults to a generic "diagnostic report attached" message
#   -p         Make the note public (visible to the requester). Default: private
#   -h         Show this help message
#
# REQUIRED ENVIRONMENT VARIABLES
#   FRESHSERVICE_DOMAIN    Your Freshservice domain, e.g. yourcompany.freshservice.com
#   FRESHSERVICE_API_KEY   Your Freshservice API key (see README.md for how to get one)
#
# COMPATIBILITY
#   Requires: bash, curl
#
# AUTHOR
#   it-support-ops repository

set -uo pipefail

TICKET_ID=""
FILE_PATH=""
NOTE_TEXT="Diagnostic report attached via it-support-ops."
PUBLIC=0

usage() {
    sed -n '2,/^set -uo pipefail/p' "$0" | grep '^#' | sed -e 's/^#//' -e 's/^!.*//'
    exit 0
}

while getopts "t:f:m:ph" opt; do
    case "$opt" in
        t) TICKET_ID="$OPTARG" ;;
        f) FILE_PATH="$OPTARG" ;;
        m) NOTE_TEXT="$OPTARG" ;;
        p) PUBLIC=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

# ---------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------
# Fail clearly and early rather than making a request that will confusingly
# fail server-side. Every check here has a specific, actionable message.

if [ -z "$TICKET_ID" ]; then
    echo "ERROR: -t <ticket ID> is required." >&2
    exit 1
fi
if ! [[ "$TICKET_ID" =~ ^[0-9]+$ ]]; then
    echo "ERROR: -t must be a numeric ticket ID." >&2
    exit 1
fi

if [ -z "$FILE_PATH" ]; then
    echo "ERROR: -f <file path> is required." >&2
    exit 1
fi
if [ ! -f "$FILE_PATH" ]; then
    echo "ERROR: File not found: $FILE_PATH" >&2
    exit 1
fi

if [ -z "${FRESHSERVICE_DOMAIN:-}" ]; then
    echo "ERROR: FRESHSERVICE_DOMAIN environment variable is not set." >&2
    echo "       export FRESHSERVICE_DOMAIN=\"yourcompany.freshservice.com\"" >&2
    echo "       See README.md in this folder for setup instructions." >&2
    exit 1
fi
if [ -z "${FRESHSERVICE_API_KEY:-}" ]; then
    echo "ERROR: FRESHSERVICE_API_KEY environment variable is not set." >&2
    echo "       export FRESHSERVICE_API_KEY=\"your-api-key\"" >&2
    echo "       See README.md in this folder for how to generate an API key." >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: 'curl' is required but not available." >&2
    exit 1
fi

PRIVATE_VALUE="true"
if [ "$PUBLIC" -eq 1 ]; then
    PRIVATE_VALUE="false"
    echo "NOTE: This note will be PUBLIC and visible to the ticket requester."
fi

# ---------------------------------------------------------------------------
# SEND
# ---------------------------------------------------------------------------
# Freshservice API v2: POST /api/v2/tickets/{id}/notes, multipart/form-data
# for attachments, Basic auth with the API key as username and a literal
# "X" as password (the standard Freshworks API auth convention).

URL="https://${FRESHSERVICE_DOMAIN}/api/v2/tickets/${TICKET_ID}/notes"

echo "Attaching $FILE_PATH to ticket #$TICKET_ID on $FRESHSERVICE_DOMAIN ..."

HTTP_STATUS=$(curl -s -o /tmp/freshservice_response.$$ -w "%{http_code}" \
    -u "${FRESHSERVICE_API_KEY}:X" \
    -X POST "$URL" \
    -F "body=${NOTE_TEXT}" \
    -F "private=${PRIVATE_VALUE}" \
    -F "attachments[]=@${FILE_PATH}")
CURL_EXIT=$?

RESPONSE_BODY=$(cat /tmp/freshservice_response.$$ 2>/dev/null)
rm -f /tmp/freshservice_response.$$

if [ "$CURL_EXIT" -ne 0 ]; then
    echo "ERROR: curl failed (exit code $CURL_EXIT) - check network connectivity" >&2
    echo "and that FRESHSERVICE_DOMAIN is correct." >&2
    exit 1
fi

case "$HTTP_STATUS" in
    200|201)
        echo "SUCCESS: Note added to ticket #$TICKET_ID."
        ;;
    401)
        echo "ERROR: Authentication failed (401). Check FRESHSERVICE_API_KEY is" >&2
        echo "correct and has not been regenerated/revoked." >&2
        exit 1
        ;;
    403)
        echo "ERROR: Forbidden (403). This API key does not have permission to" >&2
        echo "add notes to this ticket." >&2
        exit 1
        ;;
    404)
        echo "ERROR: Ticket #$TICKET_ID not found (404). Check the ticket ID and" >&2
        echo "that FRESHSERVICE_DOMAIN points to the correct Freshservice account." >&2
        exit 1
        ;;
    429)
        echo "ERROR: Rate limited (429). Freshservice's API has a per-account" >&2
        echo "rate limit - wait a moment and try again." >&2
        exit 1
        ;;
    *)
        echo "ERROR: Unexpected response (HTTP $HTTP_STATUS):" >&2
        echo "$RESPONSE_BODY" >&2
        exit 1
        ;;
esac
