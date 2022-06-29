####################################################################################################
# Prepares a new test, major, minor, or patch release
#
# Usage:
#  .\PrepareRelease.ps1 -Name "Mod Name" -Type (Test|Major|Minor|Patch) [-DebugRelease]

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

    [Switch] $DebugRelease)

Try {
    $ErrorActionPreference = "Stop"
    $OriginalModules = Get-Module

    Import-Module "$PSScriptRoot\modules\Paths.psm1"
    Initialize-Paths $PSScriptRoot $ModName | Out-Null

    Import-Module "$PSScriptRoot\modules\Git.psm1"
    Import-Module "$PSScriptRoot\modules\Version.psm1"

    If ($Type -ine "Test") {
        Confirm-NoUncommittedChanges -DebugRelease:$DebugRelease.IsPresent | Out-Null
    }
    Confirm-UpToDateWithRemote -DebugRelease:$DebugRelease.IsPresent | Out-Null

    [System.IO.FileInfo] $VersionFile = Get-VersionFile
    [System.IO.FileInfo] $ModSourceFile = Get-ModSourceFile
    [System.IO.FileInfo] $ModInfoFile = Get-ModInfoFile
    [System.IO.FileInfo] $ModBannerFile = Get-ModBannerFile
    [System.IO.FileInfo] $ModIconFile = Get-ModIconFile

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
    Clear-ReleaseDir -DebugRelease:$DebugRelease.IsPresent | Out-Null
    Write-Host "Cleaned release directory"

    ################################################################################################
    # Copy mod files to release, update version number, zip, and copy the release to Raft's mods
    # folder
    #
    Copy-Item -Path $ModSourceFile -Destination (Get-ReleaseModSourceFile)
    Copy-Item -Path $ModInfoFile -Destination (Get-ReleaseModInfoFile)
    Copy-Item -Path $ModBannerFile -Destination (Get-ReleaseDir)
    Copy-Item -Path $ModIconFile -Destination (Get-ReleaseDir)

    [System.IO.FileInfo] $ReleaseModInfoFile = Get-ReleaseModInfoFile -Exists
    ((Get-Content -Path $ReleaseModInfoFile -Raw) -Replace "@VERSION@", $NewVersion) | `
        Set-Content -Path $ReleaseModInfoFile -NoNewline

    [System.IO.FileInfo] $ReleaseModZipFile = Get-ReleaseModZipFile
    Get-ChildItem -Path (Get-ReleaseDir) -Exclude ".gitignore" |
        Compress-Archive -DestinationPath "$ReleaseModZipFile.zip"
    Rename-Item -Path "$ReleaseModZipFile.zip" -NewName $ReleaseModZipFile

    Write-Host "Added release mod files"

    If ($Type -ieq "Test") {
        Copy-Item -Path $ReleaseModZipFile -Destination (Get-RaftModDir) -Force
        Write-Host "Installed mod"

        Write-Host "Done!"
        Exit 0
    }

    ################################################################################################
    # Write and edit changelog in release dir
    #
    Set-Content `
        -Path (Get-ReleaseChangelog).FullName `
        -Value ( `
            @("# Release $NewVersion", [String]::Empty) + `
            (Get-Log -FromVersion $CurrentVersion -DebugRelease:$DebugRelease.IsPresent) `
        )
    & bash @( `
        '-c', `
        "`'$(Get-Editor -DebugRelease:$DebugRelease.IsPresent)" + `
            "$((Get-ReleaseChangelog -Exists).FullName.Replace("\", "/"))`'"
    )
    If ($LastExitCode -ne 0) {
        Throw [System.InvalidOperationException] "Failed to edit changelog."
    }
    Write-Host "Saved changelog"

    ################################################################################################
    # Write new version to version.txt
    #
    if (-Not $DebugRelease) {
        Set-Content -Path $VersionFile -Value $NewVersion
    }
    Write-Host "Saved new version"

    ################################################################################################
    # Commit changes to version.txt, tag, and push
    #
    Save-Release -DebugRelease:$DebugRelease.IsPresent | Out-Null
    Write-Host "Committed new version and tagged new release"

    Confirm-UpToDateWithRemote -DebugRelease:$DebugRelease.IsPresent | Out-Null
    Publish-Release -DebugRelease:$DebugRelease.IsPresent | Out-Null
    Write-Host "Pushed new release to remote"

    Write-Host "Done!"
} Catch {
    Write-Host ("Error: {0}" -f $_.Exception.Message)
    Write-Host
    Write-Host "Stack Trace:"
    Write-Host $_.ScriptStackTrace
    Write-Host
    Throw
} Finally {
    $NewModules = Get-Module
    If ($null -ne $NewModules) {
        If ($null -eq $OriginalModules) {
            $NewModules | ForEach-Object { Remove-Module $_ }
        } Else {
            Compare-Object $OriginalModules $NewModules | `
                Where-Object { $_.SideIndicator -eq '=>' } | `
                    Select-Object -ExpandProperty InputObject | `
                        ForEach-Object { Remove-Module $_ }
        }
    }
}
