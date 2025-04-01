if ([string]::IsNullOrEmpty($json.JOBREQUEST.IPK)) {
    WriteLog -Message "Product Key is not provided as part of JOB, detecting based on selected OS" -Verbose
    $IPK="";
    if ($json.JOBREQUEST.OperatingSystem.osindex.ToString().Trim().Tolower().Contains("pro for workstations")) {
        WriteLog -Message "Product requested: Microsoft Windows Pro for Workstations" -Verbose
        Switch ($WinVersion) {
            {($_ -eq "19041") -OR ($_ -eq "19042") -OR ($_ -eq "19043") -OR ($_ -eq "19044") -OR ($_ -eq "19045") -OR ($_ -eq "22000") } { 
                $IPK="TGMNB-2M6M7-39WWG-MT7JH-6XYV4"; WriteLog -Message "Build Version requested $($WinVersion)" -Verbose; 
            }
            default { $IPK="TGMNB-2M6M7-39WWG-MT7JH-6XYV4"; WriteLog -Message "Set default product key since was not validate version $($WinVersion)" -MessageType Warning -Verbose;  }
        }
    } elseif ($json.JOBREQUEST.OperatingSystem.osindex.ToString().Trim().Tolower().Contains("pro education")) {
        WriteLog -Message "Product detected Microsoft Windows Pro Education" -Verbose
        Switch ($WinVersion) {
            {($_ -eq "19041") -OR ($_ -eq "19042") -OR ($_ -eq "19043") -OR ($_ -eq "19044") -OR ($_ -eq "19045") -OR ($_ -eq "22000") } { 
                $IPK="JMGNM-VTCK8-VTP9W-CYHBD-TCRBY"; WriteLog -Message "Build Version requested $($WinVersion)" -Verbose; 
            }
            default { $IPK="JMGNM-VTCK8-VTP9W-CYHBD-TCRBY"; WriteLog -Message "Set default product key since was not validate version $($WinVersion)" -MessageType Warning -Verbose;  }
        }
    } elseif ($json.JOBREQUEST.OperatingSystem.osindex.ToString().Trim().Tolower().Contains("pro")) {
        WriteLog -Message "Product detected Microsoft Windows Pro" -Verbose
        Switch ($WinVersion) {
            {($_ -eq "19041") -OR ($_ -eq "19042") -OR ($_ -eq "19043") -OR ($_ -eq "19044") -OR ($_ -eq "19045") -OR ($_ -eq "22000") } { 
                $IPK="NF6HC-QH89W-F8WYV-WWXV4-WFG6P"; WriteLog -Message "Build Version requested $($WinVersion)" -Verbose; 
            }
            default { WriteLog -Message "Set default product key since was not validate version $($WinVersion)" -MessageType Warning -Verbose; $IPK="NF6HC-QH89W-F8WYV-WWXV4-WFG6P" }
        }
    } elseif ($json.JOBREQUEST.OperatingSystem.osindex.ToString().Trim().Tolower().Contains("home single language")) {
        WriteLog -Message "Product detected Windows 10 Home Single Language" -Verbose
        Switch ($WinVersion) {
            {($_ -eq "19041") -OR ($_ -eq "19042") -OR ($_ -eq "19043") -OR ($_ -eq "19044") -OR ($_ -eq "19045") -OR ($_ -eq "22000") } { 
                $IPK="NTRHT-XTHTG-GBWCG-4MTMP-HH64C"; WriteLog -Message "Build Version requested $($WinVersion)" -Verbose; 
            }
            default { WriteLog -Message "Set default product key since was not validate version $($WinVersion)" -MessageType Warning -Verbose; $IPK="NTRHT-XTHTG-GBWCG-4MTMP-HH64C" }
        }
    } elseif ($json.JOBREQUEST.OperatingSystem.osindex.ToString().Trim().Tolower().Contains("home")) {
        WriteLog -Message "Product detected Windows 10 Home" -Verbose
        Switch ($WinVersion) {
            {($_ -eq "19041") -OR ($_ -eq "19042") -OR ($_ -eq "19043") -OR ($_ -eq "19044") -OR ($_ -eq "19045") -OR ($_ -eq "22000") } { 
                $IPK="37GNV-YCQVD-38XP9-T848R-FC2HD"; WriteLog -Message "Build Version requested $($WinVersion)" -Verbose; 
            }
            default { WriteLog -Message "Set default product key since was not validate version $($WinVersion)" -MessageType Warning -Verbose; $IPK="37GNV-YCQVD-38XP9-T848R-FC2HD" }
        }
    } else {
        WriteLog -Message "Current product[$($json.JOBREQUEST.OperatingSystem.osindex)] was not expected and OEM PK was not possible to set" -MessageType Error -Verbose
        if (Test-Path -Path $JobFIle -PathType Leaf) { Move-Item -Path $JobFile -Destination "$($logs)Job.err" -Force -ErrorAction SilentlyContinue }
        $global:MessageResults="Current product[$($json.JOBREQUEST.OperatingSystem.osindex)] was not expected and OEM PK was not possible to set"
        $global:CodeResults=211
        Out-WinPE -Backuplogs
    }
    WriteLog -Message "Saving IPK=[$($IPK)]" -Verbose
    if ($null -eq $json.JOBREQUEST.IPK) {
        $json.JOBREQUEST | Add-Member -Name "IPK" -MemberType NoteProperty -Value $IPK
    } else {
        $json.JOBREQUEST.IPK=$IPK
    }
    ### Save JOB file
    try {
        $json | ConvertTo-Json -Depth 16 | Out-File -FilePath $jobfile -Encoding ascii -Force
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        WriteLog -Message "Failed updating JOB file: $($ErrorMessage)" -MessageType Error -Verbose
        $global:MessageResults="Failed updating JOB file: $($ErrorMessage)"
        $global:CodeResults=209
        Out-WinPE -Backuplogs
    }
} else {
    WriteLog -Message "It was detected a Product Key on JOB file, it will be used: [$($json.JOBREQUEST.IPK)]" -Verbose
}
