@{
    RootModule        = 'ITSupportOps.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '7de8aaf1-2e63-46a1-a83c-686dfd63efdb'
    Author            = 'it-support-ops contributors'
    CompanyName       = 'Unknown'
    Copyright         = '(c) it-support-ops contributors. MIT License.'
    Description       = 'Read-only IT support diagnostic toolkit: system health, network diagnostics (OSI-layer fault isolation), disk health, event log summaries, and a staged connectivity test suite. Safe to run as a standard user, no admin privileges required. See https://github.com/xr3ferenc3/it-support-ops for the accompanying playbooks and escalation methodology.'
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
            ReleaseNotes = 'Initial module release wrapping the CI-verified diagnostic scripts from scripts/windows. See CHANGELOG.md for full history.'
        }
    }
}