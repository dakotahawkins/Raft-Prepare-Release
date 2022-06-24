# Various git operations

Import-Module "$PSScriptRoot\Paths.psm1"
Import-Module "$PSScriptRoot\Version.psm1"

Function Confirm-NoUncommittedChanges {
    [OutputType([Bool])]
    Param([Switch] $DebugRelease)

    [System.IO.DirectoryInfo] $RepoDir = Get-RepoDir
    [String] $IgnoreSubmodules = ""
    If ($DebugRelease) {
        $IgnoreSubmodules = "--ignore-submodules"
    }
    & git @('-C', $RepoDir, `
        'diff', '--quiet', $IgnoreSubmodules, 'HEAD' `
    ) 2>&1 | Out-Null
    If ($LastExitCode -ne 0) {
        [String] $Error = "There are uncommitted staged or modified files."
        If ($DebugRelease) {
            Write-Host "DEBUG: $Error"
        } Else {
            Throw [System.InvalidOperationException] $Error
        }
    }
    & git @('-C', $RepoDir, `
        'ls-files', '--exclude-standard', '--others', '--error-unmatch', '.' `
    ) 2>&1 | Out-Null
    If ($LastExitCode -eq 0) {
        [String] $Error = "There are uncommitted untracked files."
        If ($DebugRelease) {
            Write-Host "DEBUG: $Error"
        } Else {
            Throw [System.InvalidOperationException] $Error
        }
    }

    Return $True
}

Function Clear-ReleaseDir {
    [OutputType([Bool])]
    Param([Switch] $DebugRelease)

    [System.IO.DirectoryInfo] $RepoDir = Get-RepoDir
    [System.IO.DirectoryInfo] $ReleaseDir = (Get-ReleaseDir)
    & git @('-C', $RepoDir, `
        'clean', '-dfx', '--', $ReleaseDir `
    ) 2>&1 | Out-Null
    If ($LastExitCode -ne 0) {
        [String] $Error = "Failed to clean release dir."
        If ($DebugRelease) {
            Write-Host "DEBUG: $Error"
        } Else {
            Throw [System.InvalidOperationException] $Error
        }
    }
}

Function Get-VersionTagExists {
    [OutputType([Bool])]
    Param(
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            Return Confirm-ValidVersion -VersionString $_
        })]
        [Parameter(Position = 0, Mandatory = $True)]
        [String] $VersionString
    )

    [System.IO.DirectoryInfo] $RepoDir = Get-RepoDir
    & git @('-C', $RepoDir, `
        'rev-parse', '--verify', '--quiet', '--end-of-options', $VersionString `
    ) 2>&1 | Out-Null

    Return $LastExitCode -eq 0
}

Function Get-Log {
    [OutputType([String[]])]
    Param(
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            Return Confirm-ValidVersion -VersionString $_
        })]
        [Parameter(Position = 0, Mandatory = $True)]
        [String] $FromVersion,

        [Switch] $DebugRelease
    )

    # If the $FromVersion tag doesn't exist, get the entire history
    If (-Not (Get-VersionTagExists -VersionString $FromVersion)) {
        $FromVersion = "--root"
    }

    [System.IO.DirectoryInfo] $RepoDir = Get-RepoDir
    [String[]] $Log = `
        & git @('-C', $RepoDir, `
            'log', '--oneline', '--pretty=format:"* %s"', "$FromVersion.." `
        ) 2> $null
    If ($LastExitCode -ne 0) {
        [String] $Error = "Failed to get log."
        If ($DebugRelease) {
            Write-Host "DEBUG: $Error"
            $Log = @("DEBUG LOG")
        } Else {
            Throw [System.InvalidOperationException] $Error
        }
    }

    Return $Log
}

Function Get-Editor {
    [OutputType([String])]
    Param([Switch] $DebugRelease)

    [System.IO.DirectoryInfo] $RepoDir = Get-RepoDir
    [String] $Editor = $Env:GIT_EDITOR
    [String] $Error = "Failed to get log."
    If ([String]::IsNullOrWhiteSpace($Editor)) {
        $Editor = `
            & git @('-C', $RepoDir, `
                'var', 'GIT_EDITOR'
            ) 2> $null | Select-Object -First 1
        If ($LastExitCode -ne 0) {
            If ($DebugRelease) {
                Write-Host "DEBUG: $Error"
                $Editor = "vim"
            } Else {
                Throw [System.InvalidOperationException] $Error
            }
        }
    }

    If ([String]::IsNullOrWhiteSpace($Editor)) {
        If ($DebugRelease) {
            Write-Host "DEBUG: $Error"
            $Editor = "vim"
        } Else {
            Throw [System.InvalidOperationException] $Error
        }
    }

    Return $Editor
}

Function Save-Release {
    [OutputType([Bool])]
    Param([Switch] $DebugRelease)

    [System.IO.DirectoryInfo] $RepoDir = Get-RepoDir
    [System.IO.FileInfo] $VersionFile = Get-VersionFile
    [String] $DryRun = ""
    If ($DebugRelease) {
        $DryRun = " --dry-run"
    }

    & git @('-C', $RepoDir, `
        "add$DryRun", '--', $VersionFile `
    ) 2>&1 | Out-Null
    If ($LastExitCode -ne 0) {
        [String] $Error = "Failed to stage changes to version file."
        If ($DebugRelease) {
            Write-Host "DEBUG: $Error"
        } Else {
            Throw [System.InvalidOperationException] $Error
        }
    }

    [System.IO.FileInfo] $CommitMessageFile = `
        [System.IO.Path]::Combine((Get-ReleaseDir), 'commit.msg')

    [String[]] $CommitContents = Get-Content -Path (Get-ReleaseChangelog -Exists)
    If ($CommitContents.Count -gt 0) {
        $CommitContents[0] = $CommitContents[0] -Replace '^#\s*', ''
    }
    Set-Content -Path $CommitMessageFile -Value $CommitContents
    If (-Not $CommitMessageFile.Exists) {
        [String] $Error = "Failed to write commit message file."
        If ($DebugRelease) {
            Write-Host "DEBUG: $Error"
        } Else {
            Throw [System.InvalidOperationException] $Error
        }
    }

    & git @('-C', $RepoDir, `
        "commit$DryRun", '-F', $CommitMessageFile `
    ) 2>&1 | Out-Null
    If ($LastExitCode -ne 0) {
        [String] $Error = "Failed to commit changes to version file."
        If ($DebugRelease) {
            Write-Host "DEBUG: $Error"
        } Else {
            Throw [System.InvalidOperationException] $Error
        }
    }

    Remove-Item -Path $CommitMessageFile

    Confirm-NoUncommittedChanges -DebugRelease:$DebugRelease.IsPresent | Out-Null

    If (-Not $DebugRelease) {
        [String] $VersionString = Get-VersionFromFile
        & git @('-C', $RepoDir, `
            'tag', '-m', "Release $VersionString", "$VersionString" `
        ) 2>&1 | Out-Null
        If ($LastExitCode -ne 0) {
            Throw [System.InvalidOperationException] "Failed to tag new release."
        }
    }

    Return $True
}

Function Publish-Release {
    [OutputType([Bool])]
    Param([Switch] $DebugRelease)

    [System.IO.DirectoryInfo] $RepoDir = Get-RepoDir
    [String] $DryRun = ""
    If ($DebugRelease) {
        $DryRun = " --dry-run"
    }
    & git @('-C', $RepoDir, `
        "push$DryRun", '--follow-tags' `
    ) 2>&1 | Out-Null
    If ($LastExitCode -ne 0) {
        [String] $Error = "Failed to push new release."
        If ($DebugRelease) {
            Write-Host "DEBUG: $Error"
        } Else {
            Throw [System.InvalidOperationException] $Error
        }
    }
}

Export-ModuleMember -Function Get-RepoDir
Export-ModuleMember -Function Confirm-NoUncommittedChanges
Export-ModuleMember -Function Clear-ReleaseDir
Export-ModuleMember -Function Get-VersionTagExists
Export-ModuleMember -Function Get-Log
Export-ModuleMember -Function Get-Editor
Export-ModuleMember -Function Save-Release
Export-ModuleMember -Function Publish-Release
