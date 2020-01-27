####################################################################################################
# Prepares a new test, major, minor, or patch release
#
# Usage:
#  .\PrepareRelease.ps1 -Name "Mod Name" -Type (Test|Major|Minor|Patch) [-NoExceptionTraces]

Param(
    [Parameter(Position = 0, Mandatory = $True)]
    [Alias("Name")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        If (-Not (
            $_ -Match '^[a-zA-Z0-9]' -And `
            $_ -Match '[a-zA-Z0-9]$' -And `
            $_ -Match '^[a-zA-Z0-9 ]+$'
        )) {
            Throw [System.ArgumentException] "Invalid name."
        }
        Return $True
    })]
    [String] $ModName,

    [Parameter(Position = 1, Mandatory = $True)]
    [ValidateSet("Test", "Major", "Minor", "Patch", IgnoreCase = $True)]
    [String] $Type,

    [Switch] $NoExceptionTraces
)

Try {
    $ErrorActionPreference = "Stop"
    $OriginalModules = Get-Module

    Import-Module "$PSScriptRoot\modules\Paths.psm1"
    (Initialize-Paths $PSScriptRoot $ModName)

    Import-Module "$PSScriptRoot\modules\Git.psm1"
    Import-Module "$PSScriptRoot\modules\Version.psm1"

    If ($Type -ine "Test") {
        Confirm-NoUncommittedChanges | Out-Null
    }

    [System.IO.FileInfo] $VersionFile = Get-VersionFile
    [System.IO.FileInfo] $ModSourceFile = Get-ModSourceFile

    ################################################################################################
    # Get current and new versions
    #
    [String] $CurrentVersion = Get-VersionFromFile
    [String] $NewVersion = Get-VersionBump -Type $Type

    If ($Type -ine "Test") {
        Write-Host `
            "Bumping ""$CurrentVersion"" one $($Type.ToLowerInvariant()) level to ""$NewVersion""."
        If (Get-VersionTagExists -VersionString $NewVersion) {
            Throw [System.InvalidOperationException] "Found preexisting tag for ""$NewVersion""."
        }
    } Else {
        Write-Host "Creating test release for working code."
    }

    ################################################################################################
    # Clean release dir
    #
    Clear-ReleaseDir | Out-Null
    Write-Host "Cleaned release directory"

    ################################################################################################
    # Copy mod source to release, update its version number, and copy the release to Raft's mods
    # folder
    #
    Copy-Item -Path $ModSourceFile -Destination (Get-ReleaseModSourceFile)
    [System.IO.FileInfo] $ReleaseModSourceFile = Get-ReleaseModSourceFile -Exists
    ((Get-Content -Path $ReleaseModSourceFile -Raw) -Replace "@VERSION@", $NewVersion) | `
        Set-Content -Path $ReleaseModSourceFile -NoNewline
    Write-Host "Added release mod source"

    Copy-Item -Path $ReleaseModSourceFile -Destination (Get-RaftModDir) -Force
    Write-Host "Installed mod"

    If ($Type -ieq "Test") {
        Write-Host "Done!"
        Exit 0
    }

    ################################################################################################
    # Write and edit changelog in release dir
    #
    Set-Content `
        -Path (Get-ReleaseChangelog) `
        -Value `
            @("# Release $NewVersion", [String]::Empty) + , `
            (Get-Log -FromVersion $CurrentVersion)
    & bash @('-c', (Get-Editor), (Get-ReleaseChangelog -Exists))
    If ($LastExitCode -ne 0) {
        Throw [System.InvalidOperationException] "Failed to edit changelog."
    }
    Write-Host "Saved changelog"

    ################################################################################################
    # Write new version to version.txt
    #
    Set-Content -Path $VersionFile -Value $NewVersion
    Write-Host "Saved new version"

    ################################################################################################
    # Commit changes to version.txt, tag, and push
    #
    Save-Release | Out-Null
    Write-Host "Committed new version and tagged new release"

    Publish-Release | Out-Null
    Write-Host "Pushed new release to remote"

    Write-Host "Done!"
} Catch {
    If (-Not $NoExceptionTraces) {
        Throw
    }
    Write-Host ("Error: {0}" -f $_.Exception.Message)
} Finally {
    Compare-Object $OriginalModules (Get-Module) | `
        Where-Object { $_.SideIndicator -eq '=>' } | `
            Select-Object -ExpandProperty InputObject | `
                ForEach-Object { Remove-Module $_ }
}
