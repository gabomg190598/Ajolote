
$SW_Title = "Windows Identity Foundation"
$SW_Folder = "WinFeature"
if (($null -ne $json.JOBREQUEST.EnableIdentityFoundations) -AND ($json.JOBREQUEST.EnableIdentityFoundations)) { 
    WriteLog -Message "It is required to enable $($SW_Title), checking current status" -Verbose
    $null = Invoke-RunPower -File "cmd.exe" -Params "/c reg load  HKLM\HPImg $($OSDrive)\Windows\System32\Config\SOFTWARE" -WorkDir $PSScriptRoot -OutFile "$($logs)\MountReg.log"
    $RequireEnable=$false
    if (!(Test-Path 'HKLM:\HPImg\Microsoft\Windows Identity Foundation\Setup\v3.5\')) {
        $RequireEnable=$true
    }

    #Unmount registry        
    $maxretry=10
	$retrycount=0
	$SuccessUnmount=$false
	[gc]::Collect()
	Start-Sleep 2
	While (!($SuccessUnmount)) {
		$retrycount++
		$UnMountReg = Invoke-RunPower -File "cmd.exe" -Params "/c reg unload HKLM\HPImg" -WorkDir $PSScriptRoot -OutFile "$($logs)\UnMountReg.log";
		if ($UnMountReg -ne 0) { 
			WriteLog -Message "Not successfully unmount registry[$($UnMountReg)], start sleep 6 secs and try again" -MessageType Warning -Verbose;
			Start-Sleep -Seconds 6
		} else {
			$SuccessUnmount=$true
			WriteLog -Message "Successfully unmounted registry" -Verbose
		}
		if ($retrycount -gt $maxretry) {
			WriteLog -Message "Not successfully unmount registry[$($UnMountReg) after several retries: $($SW_Title)" -MessageType Error -Verbose;
            $global:MessageResults="Not successfully unmount registry[$($UnMountReg) after several retries: $($SW_Title)"
            $global:CodeResults=-1
            Out-WinPE -Backuplogs -RemoveJob
		}
	}

    if ($RequireEnable) {
        #ENABLE HERE  
        WriteLog -Message "It was not possible detect $($SW_Title) installed on $($OSDrive)\ by registry, enabling..." -Verbose   
        $DriveComponents = Invoke-MountServer "/componentspath"
        if ($null -eq $DriveComponents) {
            WriteLog -Message "Not possible mount Component share" -MessageType Error -Verbose
            $global:MessageResults="Not possible mount Component share"
            $global:CodeResults=101
            Out-WinPE -Backuplogs -RemoveJob
        } else {
            WriteLog -Message "Components share was mounted successfully on drive: $($DriveComponents)\ Checking component folder" -Verbose
            if (-Not(Test-Path -Path (Join-Path $DriveComponents "$($SW_Folder)") -PathType Container)) {
                WriteLog -Message "It was not possible to detect folder: $((Join-Path $DriveComponents "$($SW_Folder)"))" -MessageType Error -Verbose
                $global:MessageResults="It was not possible to detect folder: $((Join-Path $DriveComponents "$($SW_Folder)"))"
                $global:CodeResults=404
                Out-WinPE -Backuplogs -RemoveJob
            }
            Switch ($WinVersion) {
                {($_ -eq "19041") -OR ($_ -eq "19042") -OR ($_ -eq "19043") -OR ($_ -eq "19044") -OR ($_ -eq "19045") } { 
                    WriteLog -Message "Build $($WinVersion) detected, Windows 10 files are required" -Verbose;
                    $sourcefolder="19040"
                    break;
                }
                {($_ -eq "22000")} { 
                    WriteLog -Message "Build $($WinVersion) detected, Windows 11 files are required" -Verbose;
                    $sourcefolder="22000"
                    break;
                }
                {($_ -eq "22621")} { 
                    WriteLog -Message "Build $($WinVersion) detected, Windows 11 files are required" -Verbose;
                    $sourcefolder="22621"
                    break;
                }
                {($_ -eq "22631")} { 
                    WriteLog -Message "Build $($WinVersion) detected, Windows 11 files are required" -Verbose;
                    $sourcefolder="22631"
                    break;
                }
                default { $sourcefolder="00000"; WriteLog -Message "invalid or unsupported version $($WinVersion) detected" -MessageType Error -Verbose;  }
            }
            if (-Not(Test-Path -Path (Join-Path (Join-Path $DriveComponents $SW_Folder) $sourcefolder) -PathType Container)) {
                WriteLog -Message "There are no folder available to enable $($SW_Title): $((Join-Path (Join-Path $DriveComponents $SW_Folder) $sourcefolder))" -MessageType Error -Verbose
                $global:MessageResults="There are no folder available to enable $($SW_Title): $((Join-Path (Join-Path $DriveComponents $SW_Folder) $sourcefolder))"
                $global:CodeResults=405
                Out-WinPE -Backuplogs -RemoveJob
            }
            $EnableIdentityFoundations = Invoke-RunPower -File "Dism.exe " -Params "/Image:$($OSDrive)\ /ScratchDir:$($OSDrive)\ /enable-feature /featurename:Windows-Identity-Foundation /All /Source:""$((Join-Path (Join-Path $DriveComponents $SW_Folder) $sourcefolder))\sources\sxs"" /LimitAccess" -WorkDir $PSScriptRoot -OutFile "$($Logs)\EnableIdentityFoundations.log" -Verbose
            if ($EnableIdentityFoundations -ne 0) { 
                WriteLog -Message "Not possible to Enable $($SW_Title)" -MessageType Error -Verbose; 
                $global:MessageResults="Not possible to Enable $($SW_Title)"
                $global:CodeResults=$EnableIdentityFoundations
                Out-WinPE -Backuplogs -RemoveJob
            }
            WriteLog -Message "Process successfully complete: $($SW_Title)"
        }
    } else {
        WriteLog -Message "$($SW_Title) its already enabled on $($OSDrive)\ continue" -Verbose
    }

} else {
    WriteLog -Message "Module not required, continue" -Verbose
}