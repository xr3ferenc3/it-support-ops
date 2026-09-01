#Requires -Version 5.1
<#
    ITSupportOps.psm1

    This module intentionally does NOT reimplement the diagnostic logic.
    Each exported cmdlet is a thin wrapper that invokes the corresponding
    standalone script bundled in .\Scripts, the same scripts that are
    linted and executed against real Windows runners in this repo's CI
    (see .github/workflows/ci.yml). One source of truth: fix a bug in
    Scripts\Get-NetworkDiagnostics.ps1 and every consumer of this module
    gets the fix on next update, with no logic duplicated or drifted here.
#>

$script:ScriptsRoot = Join-Path $PSScriptRoot 'Scripts'

function Invoke-ITSupportScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptName,

        [Parameter()]
        [hashtable]$BoundParameters = @{}
    )

    $scriptPath = Join-Path $script:ScriptsRoot $ScriptName
    if (-not (Test-Path $scriptPath)) {
        throw "ITSupportOps: bundled script not found: $scriptPath. Reinstall the module (Update-Module ITSupportOps)."
    }

    & $scriptPath @BoundParameters
}

function Get-ITSystemHealthReport {
    <#
    .SYNOPSIS
        Collects a comprehensive system health snapshot for IT support diagnostics.
    .DESCRIPTION
        Module wrapper around Scripts\Get-SystemHealthReport.ps1. See that
        script's help (Get-Help .\Scripts\Get-SystemHealthReport.ps1 -Full)
        for full parameter documentation.
    .EXAMPLE
        Get-ITSystemHealthReport
    .EXAMPLE
        Get-ITSystemHealthReport -OutputPath C:\Temp\health.txt
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )
    Invoke-ITSupportScript -ScriptName 'Get-SystemHealthReport.ps1' -BoundParameters $PSBoundParameters
}

function Get-ITNetworkDiagnostics {
    <#
    .SYNOPSIS
        Collects a comprehensive network diagnostic snapshot following OSI-layer methodology.
    .DESCRIPTION
        Module wrapper around Scripts\Get-NetworkDiagnostics.ps1. See that
        script's help for full parameter documentation.
    .EXAMPLE
        Get-ITNetworkDiagnostics
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [string]$TestHost
    )
    Invoke-ITSupportScript -ScriptName 'Get-NetworkDiagnostics.ps1' -BoundParameters $PSBoundParameters
}

function Get-ITDiskHealthReport {
    <#
    .SYNOPSIS
        Collects disk usage, volume health, and physical disk status.
    .DESCRIPTION
        Module wrapper around Scripts\Get-DiskHealthReport.ps1.
    .EXAMPLE
        Get-ITDiskHealthReport
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$LowSpaceThresholdPercent = 20,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$CriticalSpaceThresholdPercent = 10
    )
    Invoke-ITSupportScript -ScriptName 'Get-DiskHealthReport.ps1' -BoundParameters $PSBoundParameters
}

function Get-ITEventLogSummary {
    <#
    .SYNOPSIS
        Collects and summarises recent errors and warnings from Windows Event Logs.
    .DESCRIPTION
        Module wrapper around Scripts\Get-EventLogSummary.ps1.
    .EXAMPLE
        Get-ITEventLogSummary
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 720)]
        [int]$HoursBack = 24,

        [Parameter(Mandatory = $false)]
        [string]$FilterSource,

        [Parameter(Mandatory = $false)]
        [ValidateRange(5, 200)]
        [int]$MaxEventsPerLog = 30
    )
    Invoke-ITSupportScript -ScriptName 'Get-EventLogSummary.ps1' -BoundParameters $PSBoundParameters
}

function Test-ITConnectivitySuite {
    <#
    .SYNOPSIS
        Runs the staged connectivity fault isolation sequence end to end.
    .DESCRIPTION
        Module wrapper around Scripts\Test-ConnectivitySuite.ps1.
    .EXAMPLE
        Test-ITConnectivitySuite
    .EXAMPLE
        Test-ITConnectivitySuite -InternalHost fileserver.company.local -ServicePort 445
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [string]$InternalHost,

        [Parameter(Mandatory = $false)]
        [string]$ServiceHost,

        [Parameter(Mandatory = $false)]
        [int]$ServicePort = 443,

        [Parameter(Mandatory = $false)]
        [string]$TraceTarget = '8.8.8.8'
    )
    Invoke-ITSupportScript -ScriptName 'Test-ConnectivitySuite.ps1' -BoundParameters $PSBoundParameters
}

Export-ModuleMember -Function @(
    'Get-ITSystemHealthReport',
    'Get-ITNetworkDiagnostics',
    'Get-ITDiskHealthReport',
    'Get-ITEventLogSummary',
    'Test-ITConnectivitySuite'
)