<#
.SYNOPSIS
    Attaches an IT support diagnostic report to an existing Freshservice
    ticket as a note.

.DESCRIPTION
    Posts a note (private by default) to an existing Freshservice ticket,
    with the specified file attached. This is intentionally scoped to
    attaching evidence to a ticket that already exists - it does not create
    new tickets, since ticket creation typically requires organization-
    specific required fields (priority, status, custom fields) that this
    script cannot safely guess at. Creating the ticket is left to your
    normal Freshservice workflow; this script closes the gap of manually
    downloading a report file and re-uploading it through the web UI.

    Credentials are read from environment variables only - never from
    command-line arguments - so they cannot leak into shell/PowerShell
    history or be visible to other users via process listings. See
    README.md in integrations/ for setup instructions.

    Targets PowerShell 5.1 for compatibility with the rest of this
    repository, which means multipart/form-data upload is built using
    System.Net.Http.HttpClient directly rather than Invoke-RestMethod's
    -Form parameter (only available in PowerShell 6.1+).

.NOTES
    Author:         it-support-ops repository
    Run as:         Standard user (no elevation required)
    Compatibility:  Windows 10, Windows 11, PowerShell 5.1+
    Required env:   FRESHSERVICE_DOMAIN, FRESHSERVICE_API_KEY

.EXAMPLE
    $env:FRESHSERVICE_DOMAIN = "yourcompany.freshservice.com"
    $env:FRESHSERVICE_API_KEY = "your-api-key"
    .\Send-ToFreshservice.ps1 -TicketId 12345 -FilePath C:\IT-Diagnostics\report.txt

.EXAMPLE
    .\Send-ToFreshservice.ps1 -TicketId 12345 -FilePath report.txt -Message "Diagnostic report attached" -Public

    Posts a public note (visible to the requester) instead of the default private one.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool by design: status and error messages are meant for a human reading the console, not for pipeline consumption.')]
[CmdletBinding()]
param(
    # Ticket ID to attach the report to.
    [Parameter(Mandatory = $true)]
    [int]$TicketId,

    # Path to the file to attach.
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    # Note text. Defaults to a generic "diagnostic report attached" message.
    [Parameter(Mandatory = $false)]
    [string]$Message = "Diagnostic report attached via it-support-ops.",

    # Make the note public (visible to the requester). Default: private.
    [Parameter(Mandatory = $false)]
    [switch]$Public
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------
# Fail clearly and early rather than making a request that will confusingly
# fail server-side. Every check here has a specific, actionable message.

if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

$domain = $env:FRESHSERVICE_DOMAIN
$apiKey = $env:FRESHSERVICE_API_KEY

if ([string]::IsNullOrWhiteSpace($domain)) {
    Write-Error "FRESHSERVICE_DOMAIN environment variable is not set. Run:`n    `$env:FRESHSERVICE_DOMAIN = `"yourcompany.freshservice.com`"`nSee README.md in integrations/ for setup instructions."
    exit 1
}
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Error "FRESHSERVICE_API_KEY environment variable is not set. Run:`n    `$env:FRESHSERVICE_API_KEY = `"your-api-key`"`nSee README.md in integrations/ for how to generate an API key."
    exit 1
}

$isPrivate = -not $Public.IsPresent
if ($Public.IsPresent) {
    Write-Host "NOTE: This note will be PUBLIC and visible to the ticket requester."
}

# ---------------------------------------------------------------------------
# SEND
# ---------------------------------------------------------------------------
# Freshservice API v2: POST /api/v2/tickets/{id}/notes, multipart/form-data
# for attachments, Basic auth with the API key as username and a literal
# "X" as password (the standard Freshworks API auth convention).

$url = "https://$domain/api/v2/tickets/$TicketId/notes"

Add-Type -AssemblyName System.Net.Http

$httpClient = $null
$fileStream = $null
$content = $null

try {
    $httpClient = New-Object System.Net.Http.HttpClient
    $authBytes = [System.Text.Encoding]::ASCII.GetBytes("${apiKey}:X")
    $authValue = [Convert]::ToBase64String($authBytes)
    $httpClient.DefaultRequestHeaders.Authorization = `
        New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Basic", $authValue)

    $content = New-Object System.Net.Http.MultipartFormDataContent
    $content.Add((New-Object System.Net.Http.StringContent($Message)), "body")
    $privateString = if ($isPrivate) { "true" } else { "false" }
    $content.Add((New-Object System.Net.Http.StringContent($privateString)), "private")

    $fileStream = [System.IO.File]::OpenRead((Resolve-Path -LiteralPath $FilePath))
    $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $content.Add($fileContent, "attachments[]", $fileName)

    Write-Host "Attaching $FilePath to ticket #$TicketId on $domain ..."

    $response = $httpClient.PostAsync($url, $content).GetAwaiter().GetResult()
    $statusCode = [int]$response.StatusCode
    $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

    switch ($statusCode) {
        { $_ -in 200, 201 } {
            Write-Host "SUCCESS: Note added to ticket #$TicketId."
        }
        401 {
            Write-Error "Authentication failed (401). Check FRESHSERVICE_API_KEY is correct and has not been regenerated/revoked."
            exit 1
        }
        403 {
            Write-Error "Forbidden (403). This API key does not have permission to add notes to this ticket."
            exit 1
        }
        404 {
            Write-Error "Ticket #$TicketId not found (404). Check the ticket ID and that FRESHSERVICE_DOMAIN points to the correct account."
            exit 1
        }
        429 {
            Write-Error "Rate limited (429). Freshservice's API has a per-account rate limit - wait a moment and try again."
            exit 1
        }
        default {
            Write-Error "Unexpected response (HTTP ${statusCode}): $responseBody"
            exit 1
        }
    }
}
finally {
    if ($null -ne $fileStream) { $fileStream.Dispose() }
    if ($null -ne $content) { $content.Dispose() }
    if ($null -ne $httpClient) { $httpClient.Dispose() }
}
