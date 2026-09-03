@{
    RootModule        = 'ITSupportOps.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '7de8aaf1-2e63-46a1-a83c-686dfd63efdb'
    Author            = 'it-support-ops contributors'
    CompanyName       = 'it-support-ops contributors'
    Copyright         = '(c) it-support-ops contributors. MIT License.'
    Description       = 'Read-only IT support diagnostic toolkit: system health, network diagnostics (OSI-layer fault isolation), disk health, event log summaries, and a staged connectivity test suite - plus an opt-in integration to attach a report directly to an existing Freshservice ticket. Every cmdlet is safe to run as a standard user; no admin privileges required. See https://github.com/xr3ferenc3/it-support-ops for the accompanying playbooks and escalation methodology.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Get-ITSystemHealthReport',
        'Get-ITNetworkDiagnostics',
        'Get-ITDiskHealthReport',
        'Get-ITEventLogSummary',
        'Test-ITConnectivitySuite',
        'Send-ITDiagnosticToTicket'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('ITSupport', 'Helpdesk', 'Diagnostics', 'SysAdmin', 'Troubleshooting', 'Windows', 'NetworkDiagnostics', 'Freshservice', 'Ticketing')
            LicenseUri   = 'https://github.com/xr3ferenc3/it-support-ops/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/xr3ferenc3/it-support-ops'
            ReleaseNotes = 'Initial public release. Five read-only diagnostic cmdlets (system health, network diagnostics, disk health, event log summary, staged connectivity suite) plus Send-ITDiagnosticToTicket for attaching a report directly to an existing Freshservice ticket. Every cmdlet, plus the module import itself, is executed for real on a Windows runner in CI before each release - see the CI badge in the repository README. Full history in CHANGELOG.md.'
        }
    }
}