$Mod_title="Install Software"
$Mod_Ver="1.0.0"


if ($null -ne $json.JOBREQUEST.InstallSoftware) { 
    if (($null -eq $json.JOBREQUEST.InstallSoftware.status) -OR (($null -ne $json.JOBREQUEST.InstallSoftware.status) -AND ($json.JOBREQUEST.InstallSoftware.status.ToLower() -eq "new"))) { 
        WriteLog -Message "This module will execute software installation, checking information" -Verbose
        WriteLog -Message "Module: $($Mod_title) - $($Mod_Ver)" -Verbose
        if ($null -eq $json.JOBREQUEST.InstallSoftware.Applications) {
            WriteLog -Message "This module require an Applications section, not detected. Abort process" -MessageType Error -Verbose
            Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "fail" "Not found Application section on job"
            $global:MessageResults="Not found Application section on job"
            $global:CodeResults=404
            Out-WinPE -Backuplogs -RemoveJob
        }        
        foreach ($sof in ($json.JOBREQUEST.InstallSoftware.Applications |  Sort-Object -Property id)) {
            if (($null -eq $sof.SourceFolder) -OR ($null -eq $sof.SilentCommand) -OR ($null -eq $sof.Environment) -OR ($null -eq $sof.ErrorCodes)) {
                WriteLog -Message "One or more properties required for Install Software are missing: SourceFolder, SilentCommand, ErrorCodes or/and Environment" -MessageType Error -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "fail" "One or more properties required for Install Software are missing"
                $global:MessageResults="One or more properties required for Install Software are missing"
                $global:CodeResults=405
                Out-WinPE -Backuplogs -RemoveJob
            }
            $FolderName=(Split-Path $sof.SourceFolder -Leaf)
            WriteLog -Message "       Software Path: $($sof.SourceFolder)" -Verbose
            WriteLog -Message "     Software Folder: $($FolderName)" -Verbose
            WriteLog -Message "     Software Silent: $($sof.SilentCommand)" -Verbose
            WriteLog -Message "Software Error Codes: $($sof.ErrorCodes)" -Verbose
            WriteLog -Message "Software Environment: $($sof.Environment)" -Verbose
            #Mount Share             
            $SourceFolder=$sof.SourceFolder
            WriteLog -Message "Mounting share: $($SourceFolder)" -Verbose            
            try {
                $MountShare=Invoke-MountServer -MounParameter $SourceFolder
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                WriteLog -Message "Not possible to mount share: $($SourceFolder), $($ErrorMessage)" -MessageType Error -Verbose
                $global:MessageResults="Not possible to mount share: $($SourceFolder), $($ErrorMessage)"
                $global:CodeResults=403
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
            if ([string]::IsNullOrEmpty($MountShare) -OR $MountShare.Length -ne 2) {
                WriteLog -Message "Not valid mount share: $($SourceFolder)" -MessageType Error -Verbose
                $global:MessageResults="Not valid mount share: $($SourceFolder)"
                $global:CodeResults=402
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
            #move folder to OS drive
            WriteLog -Message "Moving folder $($FolderName) to OS drive..." -Verbose
            $CopyFiles= Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk $($MountShare)\* $($OSDrive)\System.sav\SWINSTALL\$($FolderName)\" -WorkDir $PSScriptRoot -OutFile "$($logs)\CopySWInstall.log"
            if ($CopyFiles -ne 0) {
                WriteLog -Message "Not possible copy $($FolderName) to  local device: $($OSDrive)\System.sav\SWINSTALL\$($FolderName)\" -MessageType Error -Verbose                
                $global:MessageResults="Not possible copy $($FolderName) to  local device: $($OSDrive)\System.sav\SWINSTALL\$($FolderName)\"
                $global:CodeResults=$CopyFiles
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
            #Check if required to be executed on this environment
            if ($sof.Environment.ToString().Trim().ToLower() -eq "winpe") {
                WriteLog -Message "This Software installer need to be execute on this environment, running..." -Verbose
                if ($sof.SilentCommand.StartsWith("""")) {
                    $RunInstaller= Invoke-RunPower -File "cmd.exe" -Params "/c ""$($OSDrive)\System.sav\SWINSTALL\$($FolderName)\$($sof.SilentCommand.Substring(1,$sof.SilentCommand-1))" -WorkDir "$($OSDrive)\System.sav\SWINSTALL\$($FolderName)" -OutFile "$($logs)\SWInstall.log"
                } else {
                    $RunInstaller= Invoke-RunPower -File "cmd.exe" -Params "/c $($OSDrive)\System.sav\SWINSTALL\$($FolderName)\$($sof.SilentCommand)" -WorkDir "$($OSDrive)\System.sav\SWINSTALL\$($FolderName)" -OutFile "$($logs)\SWInstall.log"
                }                
                if (-Not($sof.ErrorCodes.Contains($RunInstaller))) {
                    WriteLog -Message "Failed installation of $($FolderName), Error code: $($RunInstaller)" -MessageType Error -Verbose                
                    $global:MessageResults="Failed installation of $($FolderName), Error code: $($RunInstaller)"
                    $global:CodeResults=$RunInstaller
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "fail" $global:MessageResults
                    Out-WinPE -Backuplogs -RemoveJob
                }
                #Remove installer folder
                WriteLog -Message "Successfully installation for $($FolderName), remove source folder" -Verbose
                $null= Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($OSDrive)\System.sav\SWINSTALL\$($FolderName)" -WorkDir $PSScriptRoot -OutFile "$($logs)\SWInstall.log"
                if ((Get-ChildItem -Path "$($OSDrive)\System.sav\SWINSTALL" | Measure-Object).Count -eq 0) {
                    WriteLog -Message "Removing empty folder: $($OSDrive)\System.sav\SWINSTALL" -Verbose
                    $null= Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($OSDrive)\System.sav\SWINSTALL" -WorkDir $PSScriptRoot -OutFile "$($logs)\SWInstall.log"
                }
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "pass" "Successfully installation for $($FolderName)"
            } elseif ($sof.Environment.ToString().Trim().ToLower() -eq "windows") {
                WriteLog -Message "This process requires to be executed on Windows" -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "winsetup" "Waiting for Windows environment to execute this installer"
            } else {
                WriteLog -Message "Not valid Environment: $($sof.Environment)" -MessageType Error -Verbose
                $global:MessageResults="Not valid Environment: $($sof.Environment)"
                $global:CodeResults=406
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "fail" $global:MessageResults
                Out-WinPE -Backuplogs -RemoveJob
            }
            #Process completed

        }
    } elseif (($null -ne $json.JOBREQUEST.InstallSoftware.status) -AND ($json.JOBREQUEST.InstallSoftware.status.ToLower() -eq "fail")) {
        WriteLog -Message "This module was already processed, but error detected. Abort process" -MessageType Error -Verbose
        Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "fail" "previous failure detected"
        $global:MessageResults="Previous failure detected"
        $global:CodeResults=905
        Out-WinPE -Backuplogs -RemoveJob
    } elseif (($null -ne $json.JOBREQUEST.InstallSoftware.status) -AND ($json.JOBREQUEST.InstallSoftware.status.ToLower() -eq "pass")) {
        WriteLog -Message "This module was already processed and it was successfully, continue" -Verbose
    } elseif (($null -ne $json.JOBREQUEST.InstallSoftware.status) -AND ($json.JOBREQUEST.InstallSoftware.status.ToLower() -eq "winsetup")) {
        WriteLog -Message "This module already done on WinPE mode and it's waiting for Windows execution, no actions at this point" -Verbose
    } else {
        if ($null -ne $json.JOBREQUEST.InstallSoftware.status) {
            WriteLog -Message "It was not expected this status: $($json.JOBREQUEST.InstallSoftware.status)" -MessageType Warning -Verbose
        }
    }

} else {
    WriteLog -Message "This Module is not required" -Verbose
}
