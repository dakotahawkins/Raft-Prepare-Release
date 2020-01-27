# Various git operations

Import-Module "$PSScriptRoot\Paths.psm1"
Import-Module "$PSScriptRoot\Version.psm1"

Function Confirm-NoUncommittedChanges {
    [OutputType([Bool])]
    Param()

    [System.IO.DirectoryInfo] $RepoDir = Get-RepoDir

    & git @('-C', $RepoDir, `
        'diff', '--quiet', 'HEAD' `
    ) 2> $null
    If ($LastExitCode -ne 0) {
        Throw [System.InvalidOperationException] "There are uncommitted staged or modified files."
    }
    & git @('-C', $RepoDir, `
        'ls-files', '--exclude-standard', '--others', '--error-unmatch' `
    ) 2>&1 | Out-Null
    If ($LastExitCode -eq 0) {
        Throw [System.InvalidOperationException] "There are uncommitted untracked files."
    }

    Return $True
}

Function Clear-ReleaseDir {
    [OutputType([Bool])]
    Param()

    [System.IO.DirectoryInfo] $RepoDir = Get-RepoDir
    [System.IO.DirectoryInfo] $ReleaseDir = (Get-ReleaseDir)
    & git @('-C', $RepoDir, `
        'clean', '-dfx', '--', $ReleaseDir `
    ) 2>&1 | Out-Null
    If ($LastExitCode -ne 0) {
        Throw [System.InvalidOperationException] "Failed to clean release dir."
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

    & git @('-C', $RepoDir, `
        'rev-parse', $VersionString `
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
        [String] $FromVersion
    )

    # If the $FromVersion tag doesn't exist, get the entire history
    If (-Not (Get-VersionTagExists -VersionString $FromVersion)) {
        $FromVersion = "--root"
    }

    [String[]] $Log = `
        & git @('-C', $RepoDir, `
            'log', '--oneline', '--pretty=format:''* %s''', $FromVersion `
        ) 2> $null
    If ($LastExitCode -ne 0) {
        Throw [System.InvalidOperationException] "Failed to get log."
    }

    Return $Log
}

Function Get-Editor {
    [OutputType([String])]
    Param()

    [String] $Editor = $Env:GIT_EDITOR
    If ([String]::IsNullOrWhiteSpace($Editor)) {
        $Editor = `
            & git @('-C', $RepoDir, `
                'var', 'GIT_EDITOR'
            ) 2> $null | Select-Object -First 1
        If ($LastExitCode -ne 0) {
            Throw [System.InvalidOperationException] "Failed to get git editor."
        }
    }

    If ([String]::IsNullOrWhiteSpace($Editor)) {
        Throw [System.InvalidOperationException] "Failed to get git editor."
    }

    Return $Editor
}

Function Save-Release {
    [OutputType([Bool])]
    Param()

    [System.IO.FileInfo] $VersionFile = Get-VersionFile

    & git @('-C', $RepoDir, `
        'add', $VersionFile `
    ) 2>&1 | Out-Null
    If ($LastExitCode -ne 0) {
        Throw [System.InvalidOperationException] "Failed to stage changes to version file."
    }

    [System.IO.FileInfo] $CommitMessageFile = `
        [System.IO.Path]::Combine((Get-ReleaseDir), 'commit.msg')

    [String[]] $CommitContents = Get-Content -Path (Get-ReleaseChangelog -Exists)
    If ($CommitContents.Count -gt 0) {
        $CommitContents[0] = $CommitContents[0] -Replace '^#\s*', ''
    }
    Set-Content -Path $CommitMessageFile -Value $CommitContents
    If (-Not $CommitMessageFile.Exists) {
        Throw [System.InvalidOperationException] "Failed to write commit message file."
    }

    & git @('-C', $RepoDir, `
        'commit', '-e', '-F', $CommitMessageFile `
    ) 2> $null
    If ($LastExitCode -ne 0) {
        Throw [System.InvalidOperationException] "Failed to commit changes to version file."
    }

    Remove-Item -Path $CommitMessageFile

    Confirm-NoUncommittedChanges | Out-Null

    [String] $VersionString = Get-VersionFromFile
    & git @('-C', $RepoDir, `
        'tag', '-m', "Release $VersionString", "$VersionString" `
    ) 2>&1 | Out-Null
    If ($LastExitCode -ne 0) {
        Throw [System.InvalidOperationException] "Failed to tag new release."
    }

    Return $True
}

Function Publish-Release {
    [OutputType([Bool])]
    Param()

    & git @('-C', $RepoDir, `
        'push', '--follow-tags' `
    ) 2>&1 | Out-Null
    If ($LastExitCode -ne 0) {
        Throw [System.InvalidOperationException] "Failed to push new release."
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
