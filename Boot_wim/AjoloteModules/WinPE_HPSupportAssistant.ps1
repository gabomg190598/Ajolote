<#
HP Support Assistant
    Version 1.0.0
    Date: 10/11/2022
    Root node: $json.JOBREQUEST.HPSupportAssistant
    value: status
        "new", "fail", "pass", "verify"
        "new" means process is running or required, not completed yet
        "fail" process already fail
        "pass" process run successfully
        "verify" files where copied and require install
    Value: error
        Out message

Main Info
https://support.hp.com/mx-es/help/hp-support-assistant
Current version:
    9.20.22.0
Download date:
    10/25/2022
Supported OS:
    Windows (10, 11) x64

Source path:
    <componentspath>\HP_Support_Assistant\<version>

Silent command
    Setup.exe /s

#>


#Confirm if module is required
$SW_Title="HP Support Assistant"
$SW_Folder="HP_Support_Assistant"
$Setup_File="Setup.exe"
if ($null -ne $json.JOBREQUEST.HPSupportAssistant) { 
    if ($null -ne $json.JOBREQUEST.HPSupportAssistant.status) {
        WriteLog -Message "$($SW_Title) Module required, checking current status" -Verbose
        if ($json.JOBREQUEST.HPSupportAssistant.status.ToLower().Trim() -eq "new") {
            #check if expected EXE is present
            $strSW_Path=(Join-Path $OSDrive "\SWSETUP\$($SW_Folder)")
            if ((Test-Path -Path $strSW_Path -PathType Container) -AND ($null -ne (Get-ChildItem -Path $strSW_Path -Filter $Setup_File -File))) {
                if ($null -ne (Get-ChildItem -Path $strSW_Path -Filter $Setup_File -File)) {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "verify" "Waiting for validation"
                }
                foreach ($exe in (Get-ChildItem -Path $strSW_Path -Filter $Setup_File -File)) {
                    WriteLog -Message "Image already contains $($SW_Title) installer file:$($exe.Name), next step during Windows stage" -Verbose
                }
            } else {
                #Not copied yet 
                ##Mount Share drive
                $DriveComponents = Invoke-MountServer "/componentspath"
                if ($null -eq $DriveComponents) {
                    WriteLog -Message "Not possible mount Component share" -MessageType Error -Verbose
                    $global:MessageResults="Not possible mount Component share"
                    $global:CodeResults=101
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "fail" $global:MessageResult
                    Out-WinPE -Backuplogs -RemoveJob
                } else {
                    WriteLog -Message "Components share was mounted successfully on drive: $($DriveComponents)\ Checking component folder" -Verbose
                    if (-Not(Test-Path -Path (Join-Path $DriveComponents "$($SW_Folder)") -PathType Container)) {
                        WriteLog -Message "It was not possible to detect folder: $((Join-Path $DriveComponents "$($SW_Folder)"))" -MessageType Error -Verbose
                        $global:MessageResults="It was not possible to detect folder: $((Join-Path $DriveComponents "$($SW_Folder)"))"
                        $global:CodeResults=404
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    if ($null -eq (Get-ChildItem -Path (Join-Path $DriveComponents "$($SW_Folder)") -Directory)) {
                        WriteLog -Message "There are no version available to install HP Image Assintant" -MessageType Error -Verbose
                        $global:MessageResults="There are no version available to install HP Image Assintant"
                        $global:CodeResults=405
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    foreach ($ver in (Get-ChildItem -Path (Join-Path $DriveComponents "$($SW_Folder)") -Directory | Sort-Object -Property Name -Descending)) {
                        WriteLog -Message "Version available: $($ver.Name)" -Verbose    
                    }
                    $LatestVersion=(Get-ChildItem -Path (Join-Path $DriveComponents "$($SW_Folder)") -Directory | Sort-Object -Property Name -Descending)[0]
                    WriteLog -Message "It will install version: $($LatestVersion.Name)" -Verbose
                    #checking EXE files
                    $Exes_files=Get-ChildItem -Path $LatestVersion.FullName -Filter $Setup_File -File
                    if ($null -eq $Exes_files) {
                        WriteLog -Message "There are no EXE files to install $($SW_Title), not possible perform this action" -MessageType Error -Verbose
                        $global:MessageResults="There are no EXE files to install $($SW_Title), not possible perform this action"
                        $global:CodeResults=404
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    } 
                    $CopyFolder=Invoke-RunPower -file "cmd.exe" -Params "/c XCopy /sehiyk ""$($LatestVersion.FullName)\*"" $($strSW_Path)\" -WorkDir $PSScriptRoot -OutFile "$($logs)\Copy$($SW_Folder).log" -Verbose
                    if ($CopyFolder -ne 0) {
                        WriteLog -Message "There was not possible to copy $($SW_Title) folder into OS Drive" -MessageType Error -Verbose
                        $global:MessageResults="There was not possible to copy $($SW_Title) folder into OS Drive"
                        $global:CodeResults=$CopyFolder
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    #validate 
                    foreach ($file in $Exes_files) {
                        if (Test-Path -Path (Join-Path $strSW_Path $file.Name) -PathType Leaf) {
                            WriteLog -Message "Successfully copied files, executable is present: $((Join-Path $strSW_Path $file.Name))" -Verbose
                        }                
                    }
                    if ($null -eq (Get-ChildItem -Path $strSW_Path -Filter $Setup_File -File)) {
                        WriteLog -Message "Somenthing fail during copying $($SW_Title) folder into OS Drive, not possible locate Setup file" -MessageType Error -Verbose
                        $global:MessageResults="Somenthing fail during copying $($SW_Title) folder into OS Drive, not possible locate Setup file"
                        $global:CodeResults=404
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.HPSupportAssistant "verify" "Waiting for validation"
                    WriteLog -Message "Successfully copied $($SW_Title), next step, install during Windows stage" -Verbose
                }
            }
        } elseif ($json.JOBREQUEST.HPSupportAssistant.status.ToLower().Trim() -eq "pass") {
            WriteLog -Message "This module already executed successfully, continue" -Verbose
        } elseif ($json.JOBREQUEST.HPSupportAssistant.status.ToLower().Trim() -eq "verify") {
            WriteLog -Message "Status [verify] only apply for Windows stage, nothing to do by now" -Verbose
        } elseif ($json.JOBREQUEST.HPSupportAssistant.status.ToLower().Trim() -eq "fail") {
            WriteLog -Message "Module $($SW_Title) status as fail, abort process" -MessageType Error -Verbose
            $global:MessageResults="Module $($SW_Title) status as fail, abort process"
            $global:CodeResults=500
            Out-WinPE -Backuplogs -RemoveJob
        } else {
            WriteLog -Message "Module $($SW_Title) unknown status [$($json.JOBREQUEST.HPSupportAssistant.status)], abort process" -MessageType Error -Verbose
            $global:MessageResults="Module $($SW_Title) unknown status [$($json.JOBREQUEST.HPSupportAssistant.status)], abort process" 
            $global:CodeResults=501
            Out-WinPE -Backuplogs -RemoveJob
        }
    } else {
        WriteLog -Message "Module $($SW_Title) missing status tag" -MessageType Error -Verbose
        $global:MessageResults="Module $($SW_Title) missing status tags" 
        $global:CodeResults=2
        Out-WinPE -Backuplogs -RemoveJob
    }        
} else {
    WriteLog -Message "This module is not required" -Verbose
}
