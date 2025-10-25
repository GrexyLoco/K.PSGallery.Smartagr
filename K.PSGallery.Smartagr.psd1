@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'K.PSGallery.Smartagr.psm1'

    # Version number of this module.
    ModuleVersion = '0.1.21'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = 'c9a7d1e5-4f2b-4c8a-9e6d-3b7f8c4a2e1d'

    # Author of this module
    Author = '1d70f'

    # Company or vendor of this module
    CompanyName = '1d70f'

    # Copyright statement for this module
    Copyright = '(c) 2025 1d70f. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Smart Git Tag Management with Semantic Versioning Intelligence. Automatically creates and manages Git tags with sophisticated version progression logic, smart tag intelligence, and moving tag management.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # SafeLogging.ps1 provides logging abstraction and must be loaded before the main module
    ScriptsToProcess = @('src/SafeLogging.ps1')

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @()
    
    # List of all files packaged with this module (for documentation and validation)
    FileList = @(
        'K.PSGallery.Smartagr.psd1',
        'K.PSGallery.Smartagr.psm1',
        'LICENSE',
        'README.md',
        'src/SafeLogging.ps1',
        'src/GitOperations.ps1',
        'src/GitHubIntegration.ps1',
        'src/GitHubReleaseManagement.ps1',
        'src/SemanticVersionUtilities.ps1'
    )

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'New-SemanticReleaseTags', 
        'Get-SemanticVersionTags', 
        'Get-LatestSemanticTag', 
        'New-SmartRelease'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Git', 'Tags', 'SemanticVersioning', 'Versioning', 'Release', 'Automation', 'SmartTags', 'PowerShell')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/GrexyLoco/K.PSGallery.Smartagr/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/GrexyLoco/K.PSGallery.Smartagr'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
## Version 0.1.0
- Initial release of K.PSGallery.Smartagr
- Smart Git tag management with semantic versioning
- Automatic smart tag creation and moving tag intelligence
- Support for major, minor, and patch version progression
- Pre-release version handling with alpha/beta/rc support
- PowerShell 7.0+ optimized with comprehensive parameter validation
- Integration with K.PSGallery.LoggingModule for structured logging
'@

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        }
    }

    # HelpInfo URI of this module
    HelpInfoURI = 'https://github.com/GrexyLoco/K.PSGallery.Smartagr/blob/main/README.md'

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}
