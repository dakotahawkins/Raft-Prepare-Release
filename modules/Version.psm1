# Handle operations on version strings

Import-Module "$PSScriptRoot\Paths.psm1"

Class ParsedVersion {
    [String] $Prepend
    [System.Version] $Version

    ParsedVersion([String] $VersionString) {
        If ($VersionString -match "^([vV]?)(\d+\.\d+\.\d+)$") {
            $this.Prepend = $Matches[1]
            $this.Version = $Matches[2]
        } Else {
            Throw [System.ArgumentException] "Invalid version string: $VersionString"
        }
    }

    [void] BumpMajor() {
        $this.Version = `
            [System.Version]::new($this.Version.Major + 1, 0, 0)
    }
    [void] BumpMinor() {
        $this.Version = `
            [System.Version]::new($this.Version.Major, $this.Version.Minor + 1, 0)
    }
    [void] BumpPatch() {
        $this.Version = `
            [System.Version]::new($this.Version.Major, $this.Version.Minor, $this.Version.Build + 1)
    }

    [String] ToString() {
        Return ("{0}{1}" -f $this.Prepend, $this.Version)
    }
}

Function Get-VersionFromFile {
    [OutputType([String])]
    Param()

    Return [ParsedVersion]::new(`
        (Get-Content -Path (Get-VersionFile) | Select-Object -First 1) `
    ).ToString()
}

Function Get-VersionBump {
    [OutputType([String])]
    Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [ValidateSet("Test", "Major", "Minor", "Patch", IgnoreCase = $True)]
        [String] $Type
    )

    $Version = [ParsedVersion]::new((Get-VersionFromFile))
    Switch ($Type) {
        "Major" {
            $Version.BumpMajor()
            Return $Version.ToString()
        }
        "Minor" {
            $Version.BumpMinor()
            Return $Version.ToString()
        }
        "Patch" {
            $Version.BumpPatch()
            Return $Version.ToString()
        }
        Default {
            Return $Version.ToString()
        }
    }
}

Function Confirm-ValidVersion {
    [OutputType([Bool])]
    Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String] $VersionString
    )

    [ParsedVersion]::new($VersionString)

    Return $True
}

Export-ModuleMember -Function Get-VersionFromFile
Export-ModuleMember -Function Get-VersionBump
Export-ModuleMember -Function Confirm-ValidVersion
