$Mod_title="Install Software"
$Mod_Ver="1.0.0"

if ($null -ne $json.JOBREQUEST.InstallSoftware) { 
    WriteLog -Message "This module will execute software installation, checking information" -Verbose
    WriteLog -Message "Module: $($Mod_title) - $($Mod_Ver)" -Verbose
    if (($null -eq $json.JOBREQUEST.InstallSoftware.status) -OR (($null -ne $json.JOBREQUEST.InstallSoftware.status) -AND ($json.JOBREQUEST.InstallSoftware.status.ToLower() -eq "new"))) { 
        WriteLog -Message "This module reach Windows stage but no changes expected from WinPE, mark as error" -MessageType Error -Verbose
        Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "fail" "Module $($Mod_title) reach Windows stage but no changes expected from WinPE, mark as error" 
        $global:MessageResults="Module $($Mod_title) reach Windows stage but no changes expected from WinPE, mark as error" 
        $global:CodeResults=906
        Out-Windows
    } elseif (($null -ne $json.JOBREQUEST.InstallSoftware.status) -AND ($json.JOBREQUEST.InstallSoftware.status.ToLower() -eq "fail")) {
        WriteLog -Message "This module was already processed, but error detected. Abort process" -MessageType Error -Verbose
        Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "fail" "previous failure detected"
        $global:MessageResults="Previous failure detected"
        $global:CodeResults=905
        Out-Windows
    } elseif (($null -ne $json.JOBREQUEST.InstallSoftware.status) -AND ($json.JOBREQUEST.InstallSoftware.status.ToLower() -eq "pass")) {
        WriteLog -Message "This module was already processed and it was successfully, continue" -Verbose
    } elseif (($null -ne $json.JOBREQUEST.InstallSoftware.status) -AND ($json.JOBREQUEST.InstallSoftware.status.ToLower() -eq "winsetup")) {
        WriteLog -Message "Checking Job information..." -Verbose
        foreach ($sof in ($json.JOBREQUEST.InstallSoftware.Applications |  Sort-Object -Property id)) {
            if (($null -eq $sof.SourceFolder) -OR ($null -eq $sof.SilentCommand) -OR ($null -eq $sof.Environment) -OR ($null -eq $sof.ErrorCodes)) {
                WriteLog -Message "One or more properties required for Install Software are missing: SourceFolder, ErrorCodes, SilentCommand or/and Environment" -MessageType Error -Verbose
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "fail" "One or more properties required for Install Software are missing"
                $global:MessageResults="One or more properties required for Install Software are missing"
                $global:CodeResults=405
                Out-Windows
            }
            $FolderName=(Split-Path $sof.SourceFolder -Leaf)
            #WriteLog -Message "       Software Path: $($sof.SourceFolder)" -Verbose
            WriteLog -Message "     Software Folder: $($FolderName)" -Verbose
            WriteLog -Message "     Software Silent: $($sof.SilentCommand)" -Verbose
            WriteLog -Message "Software Error Codes: $($sof.ErrorCodes)" -Verbose
            WriteLog -Message "Software Environment: $($sof.Environment)" -Verbose
            $SourceFolder=(Get-ChildItem -Path (Join-Path $Env:SystemDrive "\System.sav\SWINSTALL") -Filter $FolderName -ErrorAction SilentlyContinue)[0].FullName
            if ($null -eq $SourceFolder) {
                WriteLog -Message "$($Mod_title) - It was not possible to located $((Join-Path $Env:SystemDrive "\System.sav\SWINSTALL\$($FolderName)"))" -MessageType Error -Verbose                
                $global:MessageResults="$($Mod_title) - It was not possible to located $((Join-Path $Env:SystemDrive "\System.sav\SWINSTALL\$($FolderName)"))"
                $global:CodeResults=405
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "fail" $global:MessageResults
                Out-Windows
            }
            #Check if required to be executed on this environment
            if ($sof.Environment.ToString().Trim().ToLower() -eq "winpe") {
                WriteLog -Message "This process requires to be executed on WinPE, no actions on this stage" -Verbose
            } elseif ($sof.Environment.ToString().Trim().ToLower() -eq "windows") {
                WriteLog -Message "This Software installer need to be execute on this environment, running..." -Verbose
                if ($sof.SilentCommand.StartsWith("""")) {
                    $RunInstaller= Invoke-RunPower -File "cmd.exe" -Params "/c ""$($SourceFolder)\$($sof.SilentCommand.Substring(1,$sof.SilentCommand-1))" -WorkDir "$($SourceFolder)" -OutFile "$($logs)\SWInstall.log"
                } else {
                    $RunInstaller= Invoke-RunPower -File "cmd.exe" -Params "/c $($SourceFolder)\$($sof.SilentCommand)" -WorkDir "$($SourceFolder)" -OutFile "$($logs)\SWInstall.log"
                } 
                $RunInstaller= Invoke-RunPower -File "cmd.exe" -Params "/c $($SourceFolder)\$($sof.SilentCommand)" -WorkDir $SourceFolder -OutFile "$($logs)\SWInstall.log"
                if (-Not($sof.ErrorCodes.Contains($RunInstaller))) {
                    WriteLog -Message "Failed installation of $($FolderName), Error code: $($RunInstaller)" -MessageType Error -Verbose                
                    $global:MessageResults="Failed installation of $($FolderName), Error code: $($RunInstaller)"
                    $global:CodeResults=$RunInstaller
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "fail" $global:MessageResults
                    Out-Windows
                }
                #Remove installer folder
                WriteLog -Message "Successfully installation for $($FolderName), remove source folder" -Verbose
                $null= Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($SourceFolder)" -WorkDir $PSScriptRoot -OutFile "$($logs)\SWInstall.log"
                if ((Get-ChildItem -Path "$($Env:SystemDrive)\System.sav\SWINSTALL" | Measure-Object).Count -eq 0) {
                    WriteLog -Message "Removing empty folder: $($Env:SystemDrive)\System.sav\SWINSTALL" -Verbose
                    $null= Invoke-RunPower -File "cmd.exe" -Params "/c rd /s /q $($Env:SystemDrive)\System.sav\SWINSTALL" -WorkDir $PSScriptRoot -OutFile "$($logs)\SWInstall.log"
                }
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "pass" "Successfully installation for $($FolderName)"
            } else {
                WriteLog -Message "Not valid Environment: $($sof.Environment)" -MessageType Error -Verbose
                $global:MessageResults="Not valid Environment: $($sof.Environment)"
                $global:CodeResults=406
                Update-JobStatus $jobfile $json $json.JOBREQUEST.InstallSoftware "fail" $global:MessageResults
                Out-Windows
            }
        }
    } else {
        if ($null -ne $json.JOBREQUEST.InstallSoftware.status) {
            WriteLog -Message "It was not expected this status: $($json.JOBREQUEST.InstallSoftware.status)" -MessageType Warning -Verbose
        }
    }


} else {
    WriteLog -Message "This Module is not required" -Verbose
}