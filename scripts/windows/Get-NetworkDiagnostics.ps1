<#
.SYNOPSIS
    Collects a comprehensive network diagnostic snapshot following OSI-layer
    methodology for IT support escalation and ticket documentation.

.DESCRIPTION
    Gathers adapter status, IP configuration, DHCP/DNS state, gateway reachability,
    internet egress, and DNS resolution results into a single structured report.
    Mirrors the Layer 1-7 diagnostic sequence defined in
    networking/network-troubleshooting-guide.md so that script output maps
    directly to that documentation for any technician reading the ticket.

    This script is read-only by default. It makes no configuration changes.
    It is safe to run on any Windows 10/11 workstation without administrative
    privileges.

.NOTES
    Author:         it-support-ops repository
    Run as:         Standard user (no elevation required)
    Compatibility:  Windows 10, Windows 11, PowerShell 5.1+
    Output:         Console output + log file in user's Documents folder

.EXAMPLE
    .\Get-NetworkDiagnostics.ps1

    Runs the full network diagnostic sequence and saves output to:
    $env:USERPROFILE\Documents\IT-Diagnostics\NetworkDiagnostics_<timestamp>.txt

.EXAMPLE
    .\Get-NetworkDiagnostics.ps1 -TestHost "intranet.company.local"

    Runs the diagnostic sequence and additionally tests reachability and DNS
    resolution against a specified internal host.
#>

[CmdletBinding()]
param(
    # Optional custom output path. Defaults to Documents\IT-Diagnostics.
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    # Optional additional internal hostname to test (e.g. an intranet site
    # or file server) alongside the standard external connectivity tests.
    [Parameter(Mandatory = $false)]
    [string]$TestHost
)

# ---------------------------------------------------------------------------
# SETUP
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

if (-not $OutputPath) {
    $diagnosticsFolder = Join-Path $env:USERPROFILE "Documents\IT-Diagnostics"
    if (-not (Test-Path $diagnosticsFolder)) {
        try {
            New-Item -ItemType Directory -Path $diagnosticsFolder -Force | Out-Null
        }
        catch {
            Write-Warning "Could not create diagnostics folder. Output will be console-only."
            $diagnosticsFolder = $null
        }
    }
    if ($diagnosticsFolder) {
        $OutputPath = Join-Path $diagnosticsFolder "NetworkDiagnostics_$timestamp.txt"
    }
}

$reportLines = New-Object System.Collections.Generic.List[string]

function Write-ReportLine {
    param([string]$Text = "")
    Write-Host $Text
    $reportLines.Add($Text)
}

function Write-SectionHeader {
    param([string]$Title)
    Write-ReportLine ""
    Write-ReportLine "=" * 70
    Write-ReportLine " $Title"
    Write-ReportLine "=" * 70
}

# Tracks the first layer at which a failure is detected, so the report can
# give a clear, single-line conclusion at the end rather than requiring the
# reader to infer it from scattered results.
$script:faultLayer = $null
function Set-FaultLayer {
    param([string]$Layer)
    if (-not $script:faultLayer) {
        $script:faultLayer = $Layer
    }
}

# ---------------------------------------------------------------------------
# REPORT HEADER
# ---------------------------------------------------------------------------

Write-ReportLine "=" * 70
Write-ReportLine " IT SUPPORT - NETWORK DIAGNOSTIC REPORT"
Write-ReportLine " (Layer 1-7 sequence per networking/network-troubleshooting-guide.md)"
Write-ReportLine "=" * 70
Write-ReportLine "Generated:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-ReportLine "Computer Name: $env:COMPUTERNAME"
Write-ReportLine "Current User:  $env:USERNAME"

# ---------------------------------------------------------------------------
# LAYER 1/2: ADAPTER STATUS
# ---------------------------------------------------------------------------

Write-SectionHeader "LAYER 1-2: NETWORK ADAPTERS"

$activeAdapter = $null
try {
    $adapters = Get-NetAdapter -ErrorAction Stop
    if (-not $adapters) {
        Write-ReportLine "No network adapters found on this system."
        Set-FaultLayer "Layer 1 (Physical) - No adapters detected"
    }
    else {
        foreach ($adapter in $adapters) {
            Write-ReportLine ("Adapter: {0}" -f $adapter.Name)
            Write-ReportLine ("  Status:      {0}" -f $adapter.Status)
            Write-ReportLine ("  Link Speed:  {0}" -f $adapter.LinkSpeed)
            Write-ReportLine ("  MAC Address: {0}" -f $adapter.MacAddress)
            Write-ReportLine ("  Media Type:  {0}" -f $adapter.MediaType)
            Write-ReportLine ""
        }

        # Identify the active adapter to use for subsequent IP-level tests
        $activeAdapter = $adapters | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1

        if (-not $activeAdapter) {
            Write-ReportLine "FLAG: No adapter is currently in an 'Up' state."
            Set-FaultLayer "Layer 1 (Physical) - No active adapter"
        }
    }
}
catch {
    Write-ReportLine "ERROR: Could not retrieve adapter information - $($_.Exception.Message)"
    Set-FaultLayer "Layer 1 (Physical) - Adapter query failed"
}

# ---------------------------------------------------------------------------
# LAYER 3: IP CONFIGURATION
# ---------------------------------------------------------------------------

Write-SectionHeader "LAYER 3: IP CONFIGURATION"

$ipv4Address = $null
$gateway     = $null
$isApipa     = $false

try {
    if ($activeAdapter) {
        $ipConfig = Get-NetIPConfiguration -InterfaceIndex $activeAdapter.InterfaceIndex -ErrorAction Stop

        $ipv4Address = ($ipConfig.IPv4Address | Select-Object -First 1).IPAddress
        $gateway     = ($ipConfig.IPv4DefaultGateway | Select-Object -First 1).NextHop
        $dnsServers  = $ipConfig.DNSServer | Where-Object { $_.AddressFamily -eq 2 } |
                       Select-Object -ExpandProperty ServerAddresses

        Write-ReportLine "Interface:        $($ipConfig.InterfaceAlias)"
        Write-ReportLine "IPv4 Address:     $ipv4Address"
        Write-ReportLine "Default Gateway:  $gateway"
        Write-ReportLine "DNS Servers:      $($dnsServers -join ', ')"

        # DHCP lease details
        $netAdapterConfig = Get-CimInstance Win32_NetworkAdapterConfiguration -ErrorAction Stop |
            Where-Object { $_.InterfaceIndex -eq $activeAdapter.InterfaceIndex }

        if ($netAdapterConfig) {
            Write-ReportLine "DHCP Enabled:     $($netAdapterConfig.DHCPEnabled)"
            if ($netAdapterConfig.DHCPEnabled -and $netAdapterConfig.DHCPServer) {
                Write-ReportLine "DHCP Server:      $($netAdapterConfig.DHCPServer)"
            }
            if ($netAdapterConfig.DHCPLeaseObtained) {
                Write-ReportLine "Lease Obtained:   $($netAdapterConfig.DHCPLeaseObtained)"
            }
            if ($netAdapterConfig.DHCPLeaseExpires) {
                Write-ReportLine "Lease Expires:    $($netAdapterConfig.DHCPLeaseExpires)"
            }
        }

        # APIPA detection - this is one of the most common and most diagnostic
        # findings in a network ticket, so it is flagged explicitly rather than
        # left for the reader to notice in the raw IP address.
        if ($ipv4Address -and $ipv4Address -like "169.254.*") {
            $isApipa = $true
            Write-ReportLine ""
            Write-ReportLine "FLAG: APIPA address detected (169.254.x.x)."
            Write-ReportLine "      This indicates DHCP failed to assign an address."
            Write-ReportLine "      See networking/dns-dhcp-playbook.md Part 2."
            Set-FaultLayer "Layer 3 (Network) - APIPA / DHCP failure"
        }
        elseif (-not $ipv4Address -or $ipv4Address -eq "0.0.0.0") {
            Write-ReportLine ""
            Write-ReportLine "FLAG: No valid IPv4 address assigned."
            Set-FaultLayer "Layer 3 (Network) - No IP address"
        }

        if (-not $gateway) {
            Write-ReportLine "FLAG: No default gateway configured."
            Set-FaultLayer "Layer 3 (Network) - No default gateway"
        }
    }
    else {
        Write-ReportLine "Skipped - no active adapter identified in Layer 1-2 section."
    }
}
catch {
    Write-ReportLine "ERROR: Could not retrieve IP configuration - $($_.Exception.Message)"
    Set-FaultLayer "Layer 3 (Network) - IP configuration query failed"
}

# ---------------------------------------------------------------------------
# LAYER 3: GATEWAY REACHABILITY
# ---------------------------------------------------------------------------

Write-SectionHeader "LAYER 3: GATEWAY REACHABILITY"

if ($gateway -and -not $isApipa) {
    try {
        $gatewayPing = Test-Connection -ComputerName $gateway -Count 4 -ErrorAction Stop
        $avgLatency  = ($gatewayPing | Measure-Object -Property ResponseTime -Average).Average
        # $lossPercent = [math]::Round((4 - $gatewayPing.Count) / 4 * 100, 0)

        Write-ReportLine "Gateway:          $gateway"
        Write-ReportLine "Replies Received: $($gatewayPing.Count) / 4"
        Write-ReportLine "Average Latency:  $([math]::Round($avgLatency, 1)) ms"

        if ($gatewayPing.Count -eq 0) {
            Write-ReportLine "FLAG: Gateway is unreachable."
            Set-FaultLayer "Layer 3 (Network) - Gateway unreachable"
        }
        elseif ($avgLatency -gt 100) {
            Write-ReportLine "FLAG: High latency to gateway (>100ms)."
        }
    }
    catch {
        Write-ReportLine "FLAG: Gateway is unreachable - $($_.Exception.Message)"
        Set-FaultLayer "Layer 3 (Network) - Gateway unreachable"
    }
}
else {
    Write-ReportLine "Skipped - no valid gateway available to test (see Layer 3 IP section above)."
}

# ---------------------------------------------------------------------------
# LAYER 3/4: INTERNET EGRESS
# ---------------------------------------------------------------------------

Write-SectionHeader "INTERNET EGRESS (BYPASSING DNS)"

$internetReachable = $false
if ($gateway -and -not $isApipa) {
    $externalTargets = @("8.8.8.8", "1.1.1.1")
    foreach ($target in $externalTargets) {
        try {
            $result = Test-Connection -ComputerName $target -Count 2 -ErrorAction Stop
            if ($result.Count -gt 0) {
                $internetReachable = $true
                Write-ReportLine "$target : REACHABLE (avg $([math]::Round(($result | Measure-Object ResponseTime -Average).Average,1)) ms)"
            }
            else {
                Write-ReportLine "$target : UNREACHABLE"
            }
        }
        catch {
            Write-ReportLine "$target : UNREACHABLE"
        }
    }

    if (-not $internetReachable) {
        Write-ReportLine ""
        Write-ReportLine "FLAG: No external IP addresses reachable. Internet egress is blocked"
        Write-ReportLine "      or there is an upstream routing fault."
        Set-FaultLayer "Layer 3/4 - Internet egress unreachable"
    }
}
else {
    Write-ReportLine "Skipped - gateway not reachable, internet test would not be informative."
}

# ---------------------------------------------------------------------------
# LAYER 7: DNS RESOLUTION
# ---------------------------------------------------------------------------

Write-SectionHeader "LAYER 7: DNS RESOLUTION"

if ($internetReachable) {
    $dnsTargets = @("google.com", "microsoft.com")
    if ($TestHost) { $dnsTargets += $TestHost }

    $dnsFailures = 0
    foreach ($target in $dnsTargets) {
        try {
            $dnsResult = Resolve-DnsName -Name $target -ErrorAction Stop |
                Where-Object { $_.Type -eq "A" } | Select-Object -First 1
            if ($dnsResult) {
                Write-ReportLine "$target : RESOLVED -> $($dnsResult.IPAddress)"
            }
            else {
                Write-ReportLine "$target : NO A RECORD RETURNED"
                $dnsFailures++
            }
        }
        catch {
            Write-ReportLine "$target : RESOLUTION FAILED - $($_.Exception.Message)"
            $dnsFailures++
        }
    }

    if ($dnsFailures -gt 0) {
        Write-ReportLine ""
        Write-ReportLine "FLAG: $dnsFailures of $($dnsTargets.Count) DNS lookups failed."
        Write-ReportLine "      See networking/dns-dhcp-playbook.md Part 1."
        Set-FaultLayer "Layer 7 (Application) - DNS resolution failure"
    }
}
else {
    Write-ReportLine "Skipped - internet egress not confirmed, DNS test would not be informative."
}

# ---------------------------------------------------------------------------
# WIRELESS DETAIL (IF APPLICABLE)
# ---------------------------------------------------------------------------

Write-SectionHeader "WIRELESS DETAIL (IF APPLICABLE)"

try {
    $wifiAdapter = Get-NetAdapter -ErrorAction Stop |
        Where-Object { $_.PhysicalMediaType -like "*802.11*" -and $_.Status -eq "Up" }

    if ($wifiAdapter) {
        $wlanInfo = netsh wlan show interfaces
        $wlanInfo | Where-Object { $_ -match "SSID|Signal|Radio type|Channel|Receive rate|Transmit rate|Authentication" } |
            ForEach-Object { Write-ReportLine "  $($_.Trim())" }
    }
    else {
        Write-ReportLine "No active wireless adapter detected (wired connection or Wi-Fi disabled)."
    }
}
catch {
    Write-ReportLine "Could not retrieve wireless details - $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# SUMMARY AND CONCLUSION
# ---------------------------------------------------------------------------

Write-SectionHeader "DIAGNOSTIC SUMMARY"

if ($script:faultLayer) {
    Write-ReportLine "FAULT BOUNDARY IDENTIFIED: $script:faultLayer"
    Write-ReportLine ""
    Write-ReportLine "Refer to the corresponding section of networking/network-troubleshooting-guide.md"
    Write-ReportLine "or the relevant playbook for next steps."
}
else {
    Write-ReportLine "No fault detected in Layers 1-7 automated checks."
    Write-ReportLine "If the user is still reporting an issue, the fault is likely"
    Write-ReportLine "application-specific or intermittent. Refer to"
    Write-ReportLine "networking/connectivity-fault-isolation.md for extended diagnosis."
}

Write-ReportLine ""
Write-ReportLine "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# ---------------------------------------------------------------------------
# FILE OUTPUT
# ---------------------------------------------------------------------------

if ($OutputPath) {
    try {
        $reportLines | Out-File -FilePath $OutputPath -Encoding UTF8 -ErrorAction Stop
        Write-Host ""
        Write-Host "Report saved to: $OutputPath" -ForegroundColor Green
        Write-Host "Attach this file to the ticket per diagnostic-report-template.md" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not save report to file: $($_.Exception.Message)"
        Write-Warning "Report was displayed in console only — copy manually if needed."
    }
}
else {
    Write-Host ""
    Write-Host "No output file path available — report displayed in console only." -ForegroundColor Yellow
}