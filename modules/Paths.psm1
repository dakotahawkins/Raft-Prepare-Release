# Common paths

Import-Module "$PSScriptRoot\Get-RaftDir\RaftDir.psm1"

[System.IO.DirectoryInfo] $ScriptRoot = $null
[String] $ModNameNoSpace = $null

[System.IO.DirectoryInfo] $RepoDir = $null
[System.IO.DirectoryInfo] $ReleaseDir = $null
[System.IO.FileInfo] $VersionFile = $null
[System.IO.FileInfo] $ModSourceFile = $null
[System.IO.FileInfo] $ModInfoFile = $null
[System.IO.FileInfo] $ModBannerFile = $null
[System.IO.FileInfo] $ModIconFile = $null
[System.IO.FileInfo] $ReleaseModSourceFile = $null
[System.IO.FileInfo] $ReleaseChangelog = $null
[System.IO.FileInfo] $ReleaseModInfoFile = $null
[System.IO.FileInfo] $ReleaseModZipFile = $null
[System.IO.DirectoryInfo] $RaftModDir = $null

Function Initialize-Paths {
    [OutputType([Bool])]
    Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            If (-Not $_.Exists) {
                Throw [System.ArgumentException] "Invalid script root dir."
            }
            Return $True
        })]
        [System.IO.DirectoryInfo] $ScriptRoot,

        [Parameter(Position = 1, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String] $ModName
    )

    If ($null -ne $script:ScriptRoot) {
        Throw [System.InvalidOperationException] "Paths already initialized."
    }
    $script:ScriptRoot = $ScriptRoot
    $script:ModNameNoSpace = ($ModName -replace ' +', '')

    Return $True
}

Function Confirm-Initialized {
    [OutputType([Bool])]
    Param()

    If ($null -eq $script:ScriptRoot) {
        Throw [System.InvalidOperationException] "Paths not initialized."
    }

    Return $True
}

Function Get-ScriptRoot {
    [OutputType([System.IO.DirectoryInfo])]
    Param()

    Confirm-Initialized | Out-Null

    Return $script:ScriptRoot
}

Function Get-RepoDir {
    [OutputType([System.IO.DirectoryInfo])]
    Param()

    If ($null -ne $script:RepoDir) {
        Return $script:RepoDir
    }

    Confirm-Initialized | Out-Null

    ForEach ($RevParseOption in @("--show-superproject-working-tree", "--show-toplevel")) {
        [System.IO.DirectoryInfo] $RepoDir = `
            & git @('-C', (Get-ScriptRoot), `
                'rev-parse', $RevParseOption
            ) 2> $null

        If (-Not [String]::IsNullOrWhiteSpace($RepoDir.FullName)) {
            $script:RepoDir = [System.IO.DirectoryInfo] $RepoDir.FullName
            Return $script:RepoDir
        }
    }

    Throw [System.IO.DirectoryNotFoundException] "Repo directory not found."
}

Function Get-ReleaseDir {
    [OutputType([System.IO.DirectoryInfo])]
    Param()

    If ($null -ne $script:ReleaseDir) {
        Return $script:ReleaseDir
    }

    Confirm-Initialized | Out-Null

    [System.IO.DirectoryInfo] $ReleaseDir = [System.IO.Path]::Combine((Get-RepoDir), "release")
    If (-Not $ReleaseDir.Exists) {
        Throw [System.IO.DirectoryNotFoundException] "Release directory not found."
    }

    $script:ReleaseDir = $ReleaseDir
    Return $script:ReleaseDir
}

Function Get-VersionFile {
    [OutputType([System.IO.FileInfo])]
    Param()

    If ($null -ne $script:VersionFile) {
        Return $script:VersionFile
    }

    Confirm-Initialized | Out-Null

    [System.IO.FileInfo] $VersionFile = `
        [System.IO.Path]::Combine((Get-RepoDir), "ModResources", "version.txt")
    If (-Not $VersionFile.Exists) {
        Throw [System.IO.FileNotFoundException] "version.txt not found."
    }

    $script:VersionFile = $VersionFile
    Return $script:VersionFile
}

Function Get-ModSourceFile {
    [OutputType([System.IO.FileInfo])]
    Param()

    If ($null -ne $script:ModSourceFile) {
        Return $script:ModSourceFile
    }

    Confirm-Initialized | Out-Null

    [System.IO.FileInfo] $ModSourceFile = `
        [System.IO.Path]::Combine( `
            (Get-RepoDir), $script:ModNameNoSpace, "$script:ModNameNoSpace.cs" `
        )
    If (-Not $ModSourceFile.Exists) {
        Throw [System.IO.FileNotFoundException] "Mod source not found."
    }

    $script:ModSourceFile = $ModSourceFile
    Return $script:ModSourceFile
}

Function Get-ModInfoFile {
    [OutputType([System.IO.FileInfo])]
    Param()

    If ($null -ne $script:ModInfoFile) {
        Return $script:ModInfoFile
    }

    Confirm-Initialized | Out-Null

    [System.IO.FileInfo] $ModInfoFile = `
        [System.IO.Path]::Combine( `
            (Get-RepoDir), "ModResources", "modinfo.json" `
        )
    If (-Not $ModInfoFile.Exists) {
        Throw [System.IO.FileNotFoundException] "Mod info file not found."
    }

    $script:ModInfoFile = $ModInfoFile
    Return $script:ModInfoFile
}

Function Get-ModBannerFile {
    [OutputType([System.IO.FileInfo])]
    Param()

    If ($null -ne $script:ModBannerFile) {
        Return $script:ModBannerFile
    }

    Confirm-Initialized | Out-Null

    [System.IO.FileInfo] $ModBannerFile = `
        [System.IO.Path]::Combine( `
            (Get-RepoDir), "ModResources", "banner.jpg" `
        )
    If (-Not $ModBannerFile.Exists) {
        Throw [System.IO.FileNotFoundException] "Mod banner file not found."
    }

    $script:ModBannerFile = $ModBannerFile
    Return $script:ModBannerFile
}

Function Get-ModIconFile {
    [OutputType([System.IO.FileInfo])]
    Param()

    If ($null -ne $script:ModIconFile) {
        Return $script:ModIconFile
    }

    Confirm-Initialized | Out-Null

    [System.IO.FileInfo] $ModIconFile = `
        [System.IO.Path]::Combine( `
            (Get-RepoDir), "ModResources", "icon.png" `
        )
    If (-Not $ModIconFile.Exists) {
        Throw [System.IO.FileNotFoundException] "Mod icon file not found."
    }

    $script:ModIconFile = $ModIconFile
    Return $script:ModIconFile
}

Function Get-ReleaseModSourceFile {
    [OutputType([System.IO.FileInfo])]
    Param(
        [Switch] $Exists
    )

    If ($null -ne $script:ReleaseModSourceFile) {
        Return $script:ReleaseModSourceFile
    }

    Confirm-Initialized | Out-Null

    [System.IO.FileInfo] $ReleaseModSourceFile = `
        [System.IO.Path]::Combine((Get-ReleaseDir), "$script:ModNameNoSpace.cs")
    If (-Not $Exists) {
        Return $ReleaseModSourceFile
    }
    If (-Not $ReleaseModSourceFile.Exists) {
        Throw [System.IO.FileNotFoundException] "Release mod source not found."
    }

    $script:ReleaseModSourceFile = $ReleaseModSourceFile
    Return $script:ReleaseModSourceFile
}

Function Get-ReleaseChangelog {
    [OutputType([System.IO.FileInfo])]
    Param(
        [Switch] $Exists
    )

    If ($null -ne $script:ReleaseChangelog) {
        Return $script:ReleaseChangelog
    }

    Confirm-Initialized | Out-Null

    [System.IO.FileInfo] $ReleaseChangelog = `
        [System.IO.Path]::Combine((Get-ReleaseDir), "CHANGELOG.md")
    If (-Not $Exists) {
        Return $ReleaseChangelog
    }
    If (-Not $ReleaseChangelog.Exists) {
        Throw [System.IO.FileNotFoundException] "Release changelog not found."
    }

    $script:ReleaseChangelog = $ReleaseChangelog
    Return $script:ReleaseChangelog
}

Function Get-ReleaseModInfoFile {
    [OutputType([System.IO.FileInfo])]
    Param(
        [Switch] $Exists
    )

    If ($null -ne $script:ReleaseModInfoFile) {
        Return $script:ReleaseModInfoFile
    }

    Confirm-Initialized | Out-Null

    [System.IO.FileInfo] $ReleaseModInfoFile = `
        [System.IO.Path]::Combine((Get-ReleaseDir), "modinfo.json")
    If (-Not $Exists) {
        Return $ReleaseModInfoFile
    }
    If (-Not $ReleaseModInfoFile.Exists) {
        Throw [System.IO.FileNotFoundException] "Release mod info file not found."
    }

    $script:ReleaseModInfoFile = $ReleaseModInfoFile
    Return $script:ReleaseModInfoFile
}

Function Get-ReleaseModZipFile {
    [OutputType([System.IO.FileInfo])]
    Param(
        [Switch] $Exists
    )

    If ($null -ne $script:ReleaseModZipFile) {
        Return $script:ReleaseModZipFile
    }

    Confirm-Initialized | Out-Null

    [System.IO.FileInfo] $ReleaseModZipFile = `
        [System.IO.Path]::Combine((Get-ReleaseDir),"$script:ModNameNoSpace.rmod")
    If (-Not $Exists) {
        Return $ReleaseModZipFile
    }
    If (-Not $ReleaseModZipFile.Exists) {
        Throw [System.IO.FileNotFoundException] "Release mod zip file not found."
    }

    $script:ReleaseModZipFile = $ReleaseModZipFile
    Return $script:ReleaseModZipFile
}

Function Get-RaftModDir {
    [OutputType([System.IO.DirectoryInfo])]
    Param()

    If ($null -ne $script:RaftModDir) {
        Return $script:RaftModDir
    }

    [System.IO.DirectoryInfo] $RaftDir = Get-RaftDir
    [System.IO.DirectoryInfo] $RaftModDir = [System.IO.Path]::Combine($RaftDir, "mods")
    If (-Not $RaftModDir.Exists) {
        # Create if not found
        $RaftModDir.Create()
    }

    If (-Not $RaftModDir.Exists) {
        Throw [System.IO.DirectoryNotFoundException] "Raft mod directory not found."
    }

    $script:RaftModDir = $RaftModDir
    Return $script:RaftModDir
}

Export-ModuleMember -Function Initialize-Paths
Export-ModuleMember -Function Get-ScriptRoot
Export-ModuleMember -Function Get-RepoDir
Export-ModuleMember -Function Get-ReleaseDir
Export-ModuleMember -Function Get-VersionFile
Export-ModuleMember -Function Get-ModSourceFile
Export-ModuleMember -Function Get-ModInfoFile
Export-ModuleMember -Function Get-ModBannerFile
Export-ModuleMember -Function Get-ModIconFile
Export-ModuleMember -Function Get-ReleaseModSourceFile
Export-ModuleMember -Function Get-ReleaseChangelog
Export-ModuleMember -Function Get-ReleaseModInfoFile
Export-ModuleMember -Function Get-ReleaseModZipFile
Export-ModuleMember -Function Get-RaftModDir
