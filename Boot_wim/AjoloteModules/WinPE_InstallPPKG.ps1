<#
Module: PPKG preparation
Description: This module copy PPKGs into C:\system.sav\PPKG\ Windows module will take and install
Version: 1.0.0
Date: 03/07/2024
#>
if ($null -ne $json.JOBREQUEST.InstallPPKG) {
    if (($null -eq $json.JOBREQUEST.InstallPPKG.status) -OR (($null -ne $json.JOBREQUEST.InstallPPKG.status) -AND ($json.JOBREQUEST.InstallPPKG.status.ToLower() -eq "new"))) {
        WriteLog -Message "Install PPKG is requested" -Verbose
        if (([string]::IsNullOrEmpty($json.JOBREQUEST.InstallPPKG.localpath)) -OR ($null -eq $json.JOBREQUEST.InstallPPKG.files)) {
            WriteLog -Message "This module requires path and file name to grab from share location" -MessageType Error -Verbose
            Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "This module requires path and file name to grab from share location" 
            $global:MessageResults="This module requires path and file name to grab from share location" 
            $global:CodeResults=404
            Out-WinPE -Backuplogs -RemoveJob
        }
        $PPKGSource=$json.JOBREQUEST.InstallPPKG.localpath
        WriteLog -Message "Mounting share: $($PPKGSource)" -Verbose
        #Mount Share 
        try {
            $MountShare=Invoke-MountServer -MounParameter $PPKGSource
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            WriteLog -Message "Not possible to mount share: $($PPKGSource), $($ErrorMessage)" -MessageType Error -Verbose
            $global:MessageResults="Not possible to mount share: $($PPKGSource), $($ErrorMessage)"
            $global:CodeResults=403
            Out-WinPE -Backuplogs -RemoveJob
        }
        if ([string]::IsNullOrEmpty($MountShare) -OR $MountShare.Length -ne 2) {
            WriteLog -Message "Not possible to mount share: $($PPKGSource)" -MessageType Error -Verbose
            $global:MessageResults="Not possible to mount share: $($PPKGSource)"
            $global:CodeResults=402
            Out-WinPE -Backuplogs -RemoveJob
        }
        WriteLog -Message "Searching PPKG files" -Verbose
        foreach ($file in $json.JOBREQUEST.InstallPPKG.files) {
            WriteLog -Message "Searching for $($file)" -Verbose
            $getPPKG=Get-ChildItem -Path "$($MountShare)\" -Recurse -Filter $file
            if ($null -ne $getPPKG) {
                WriteLog -Message "$($file) located on $($getPPKG[0].DirectoryName)" -Verbose
                $CopyFiles= Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /hiyk $($getPPKG[0].FullName) $($OSDrive)\System.sav\PPKG\" -WorkDir $PSScriptRoot -OutFile "$($logs)\CopyPPKG.log" 
                if ($CopyFiles -ne 0) {
                    WriteLog -Message "Not possible copy PPKG to  local device: $($getPPKG[0].FullName)" -MessageType Error -Verbose
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "Not possible copy PPKG to  local device: $($getPPKG[0].FullName)" 
                    $global:MessageResults="Not possible copy PPKG to  local device: $($getPPKG[0].FullName)"
                    $global:CodeResults=$CopyFiles
                    Out-WinPE -Backuplogs -RemoveJob
                }
                WriteLog -Message "$($getPPKG[0].Name) copied sucessfully" -Verbose
            } else {
                WriteLog -Message "Not possible locate $($file) on mounted path ($($PPKGSource))" -MessageType Error -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "Not possible locate $($file) on mounted path ($($PPKGSource))"
                $global:MessageResults="Not possible locate $($file) on mounted path ($($PPKGSource))"
                $global:CodeResults=404
                Out-WinPE -Backuplogs -RemoveJob
            }
        }
        WriteLog -Message "PPKG was placed on OS drive and ready for Installation" -Verbose
        Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "ready" "PPKG was copied to OS drive and ready for installation"
    } elseif (($null -ne $json.JOBREQUEST.InstallPPKG.status) -AND ($json.JOBREQUEST.InstallPPKG.status.ToLower() -eq "ready")) {
        WriteLog -Message "PPKG was already copied to OS drive and waiting for setup during Windows stage" -Verbose
    } elseif (($null -ne $json.JOBREQUEST.InstallPPKG.status) -AND ($json.JOBREQUEST.InstallPPKG.status.ToLower() -eq "pass")) {
        WriteLog -Message "This module was already processed" -Verbose
    } elseif (($null -ne $json.JOBREQUEST.InstallPPKG.status) -AND ($json.JOBREQUEST.InstallPPKG.status.ToLower() -eq "fail")) { 
        WriteLog -Message "This module was already processed, but error detected. Abort process" -MessageType Error -Verbose
        Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallPPKG "fail" "previous failure detected"
        $global:MessageResults="Previous failure detected"
        $global:CodeResults=905
        Out-WinPE -Backuplogs -RemoveJob
    } else {
        WriteLog -Message "Not expected status ""$($json.JOBREQUEST.InstallPPKG.status)"" for this module" -MessageType Warning -Verbose
    }
} else {
    WriteLog -Message "This module is not required" -Verbose
}