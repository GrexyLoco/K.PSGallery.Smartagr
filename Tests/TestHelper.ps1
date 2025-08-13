# TestHelper.ps1 - Common test utilities for K.PSGallery.SemanticVersioning

function Initialize-TestModule {
    <#
    .SYNOPSIS
    Safely initializes the test module with proper cleanup
    #>
    [CmdletBinding()]
    param()
    
    # Force remove any existing modules to prevent conflicts
    Get-Module K.PSGallery.SemanticVersioning | Remove-Module -Force -ErrorAction SilentlyContinue
    
    # Clear module from session cache
    if (Get-Module K.PSGallery.SemanticVersioning -ListAvailable -ErrorAction SilentlyContinue) {
        try {
            Remove-Module K.PSGallery.SemanticVersioning -Force -ErrorAction SilentlyContinue
        } catch {
            # Ignore cleanup errors
        }
    }
    
    # Import fresh module
    $ModuleRoot = Split-Path $PSScriptRoot -Parent
    $ModulePath = Join-Path $ModuleRoot "K.PSGallery.SemanticVersioning.psd1"
    
    if (-not (Test-Path $ModulePath)) {
        throw "Module manifest not found at: $ModulePath"
    }
    
    Import-Module $ModulePath -Force -ErrorAction Stop
    Write-Verbose "Module K.PSGallery.SemanticVersioning imported successfully"
}

function Remove-TestModule {
    <#
    .SYNOPSIS
    Safely removes the test module with thorough cleanup
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Remove module from current session
        Get-Module K.PSGallery.SemanticVersioning | Remove-Module -Force -ErrorAction SilentlyContinue
        
        # Clear any cached module information
        $null = Get-Module K.PSGallery.SemanticVersioning -ListAvailable -ErrorAction SilentlyContinue | 
            ForEach-Object { Remove-Module $_.Name -Force -ErrorAction SilentlyContinue }
        
        Write-Verbose "Module K.PSGallery.SemanticVersioning removed successfully"
    } catch {
        Write-Warning "Could not fully clean up module: $($_.Exception.Message)"
    }
}

function New-TestManifest {
    <#
    .SYNOPSIS
    Creates a test module manifest with specified version
    #>
    [CmdletBinding()]
    param(
        [string]$Path,
        [string]$Version = '1.2.3'
    )
    
    $ManifestContent = @"
@{
    ModuleVersion = '$Version'
    GUID = '12345678-1234-1234-1234-123456789012'
    Author = 'Test Author'
    Description = 'Test module for K.PSGallery.SemanticVersioning'
    PowerShellVersion = '5.1'
}
"@
    
    $ManifestContent | Out-File -FilePath $Path -Encoding UTF8 -Force
    Write-Verbose "Test manifest created at: $Path"
}

function Remove-TestManifest {
    <#
    .SYNOPSIS
    Safely removes test manifests
    #>
    [CmdletBinding()]
    param(
        [string[]]$Path
    )
    
    foreach ($file in $Path) {
        if (Test-Path $file) {
            try {
                Remove-Item $file -Force -ErrorAction Stop
                Write-Verbose "Removed test manifest: $file"
            } catch {
                Write-Warning "Could not remove test manifest: $file - $($_.Exception.Message)"
            }
        }
    }
}
