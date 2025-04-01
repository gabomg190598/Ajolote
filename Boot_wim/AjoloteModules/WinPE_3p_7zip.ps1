<#
7-Zip
    Version 1.0.0
    Date: 10/11/2022
    Root node: $json.JOBREQUEST.SevenZip
    value: status
        "new", "fail", "pass", "verify"
        "new" means process is running or required, not completed yet
        "fail" process already fail
        "pass" process run successfully
        "verify" files where copied and require install
    Value: error
        Out message

Main Info
https://www.7-zip.org/
Current version:
    22.01 x64
Download date:
    10/11/2022
Supported OS:
    Windows (10, 11) x64

Source path:
    <componentspath>\7Zip\<version>_<architecture>

Silent command
    7z2201-x64.exe /S


#>


#Confirm if module is required
if ($null -ne $json.JOBREQUEST.SevenZip) { 
    if ($null -ne $json.JOBREQUEST.SevenZip.status) {
        WriteLog -Message "7-Zip Module required, checking current status" -Verbose
        if ($json.JOBREQUEST.SevenZip.status.ToLower().Trim() -eq "new") {
            #check if expected EXE is present
            $strSW_Path=(Join-Path $OSDrive "\SWSETUP\7Zip")
            if ((Test-Path -Path $strSW_Path -PathType Container) -AND ($null -ne (Get-ChildItem -Path $strSW_Path -Filter "*.exe"))) {
                if ($null -ne (Get-ChildItem -Path $strSW_Path -Filter "*.exe" -File)) {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.SevenZip "verify" "Waiting for validation"
                }
                foreach ($exe in (Get-ChildItem -Path $strSW_Path -Filter "*.exe" -File)) {
                    WriteLog -Message "Image already contains 7-Zip installer file:$($exe.Name), next step during Windows stage" -Verbose
                }
            } else {
                #Not copied yet 
                ##Mount Share drive
                $DriveComponents = Invoke-MountServer "/componentspath"
                if ($null -eq $DriveComponents) {
                    WriteLog -Message "Not possible mount Component share" -MessageType Error -Verbose
                    $global:MessageResults="Not possible mount Component share"
                    $global:CodeResults=101
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.SevenZip "fail" $global:MessageResult
                    Out-WinPE -Backuplogs -RemoveJob
                } else {
                    WriteLog -Message "Components share was mounted successfully on drive: $($DriveComponents)\ Checking component folder" -Verbose
                    if (-Not(Test-Path -Path (Join-Path $DriveComponents "7Zip") -PathType Container)) {
                        WriteLog -Message "It was not possible to detect folder: $((Join-Path $DriveComponents "7Zip"))" -MessageType Error -Verbose
                        $global:MessageResults="It was not possible to detect folder: $((Join-Path $DriveComponents "7Zip"))"
                        $global:CodeResults=404
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.SevenZip "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    if ($null -eq (Get-ChildItem -Path (Join-Path $DriveComponents "7Zip") -Directory)) {
                        WriteLog -Message "There are no version available to install HP Image Assintant" -MessageType Error -Verbose
                        $global:MessageResults="There are no version available to install HP Image Assintant"
                        $global:CodeResults=405
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.SevenZip "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    foreach ($ver in (Get-ChildItem -Path (Join-Path $DriveComponents "7Zip") -Directory | Sort-Object -Property Name -Descending)) {
                        WriteLog -Message "Version available: $($ver.Name)" -Verbose    
                    }
                    $LatestVersion=(Get-ChildItem -Path (Join-Path $DriveComponents "7Zip") -Directory | Sort-Object -Property Name -Descending)[0]
                    WriteLog -Message "It will install version: $($LatestVersion.Name)" -Verbose
                    #checking EXE files
                    $Exes_files=Get-ChildItem -Path $LatestVersion.FullName -Filter "*.exe" -File
                    if ($null -eq $Exes_files) {
                        WriteLog -Message "There are no EXE files to install 7-Zip, not possible perform this action" -MessageType Error -Verbose
                        $global:MessageResults="There are no EXE files to install 7-Zip, not possible perform this action"
                        $global:CodeResults=404
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.SevenZip "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    } 
                    $CopyFolder=Invoke-RunPower -file "cmd.exe" -Params "/c XCopy /sehiyk ""$($LatestVersion.FullName)\*"" $($strSW_Path)\" -WorkDir $PSScriptRoot -OutFile "$($logs)\Copy7Zip.log" -Verbose
                    if ($CopyFolder -ne 0) {
                        WriteLog -Message "There was not possible to copy 7-Zip folder into OS Drive" -MessageType Error -Verbose
                        $global:MessageResults="There was not possible to copy 7-Zip folder into OS Drive"
                        $global:CodeResults=$CopyFolder
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.SevenZip "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    #validate 
                    foreach ($file in $Exes_files) {
                        if (Test-Path -Path (Join-Path $strSW_Path $file.Name) -PathType Leaf) {
                            WriteLog -Message "Successfully copied file: $((Join-Path $strSW_Path $file.Name))" -Verbose
                        }                
                    }
                    if ($null -eq (Get-ChildItem -Path $strSW_Path -Filter "*.exe" -File)) {
                        WriteLog -Message "Somenthing fail during copying 7-Zip folder into OS Drive, not possible locate Executable" -MessageType Error -Verbose
                        $global:MessageResults="Somenthing fail during copying 7-Zip folder into OS Drive, not possible locate Executable"
                        $global:CodeResults=404
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.SevenZip "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.SevenZip "verify" "Waiting for validation"
                    WriteLog -Message "Successfully copied 7-Zip, next step, install during Windows stage" -Verbose
                }
            }
        } elseif ($json.JOBREQUEST.SevenZip.status.ToLower().Trim() -eq "pass") {
            WriteLog -Message "This module already executed successfully, continue" -Verbose
        } elseif ($json.JOBREQUEST.SevenZip.status.ToLower().Trim() -eq "verify") {
            WriteLog -Message "Status [verify] only apply for Windows stage, nothing to do by now" -Verbose
        } elseif ($json.JOBREQUEST.SevenZip.status.ToLower().Trim() -eq "fail") {
            WriteLog -Message "Module 7-Zip status as fail, abort process" -MessageType Error -Verbose
            $global:MessageResults="Module 7-Zip status as fail, abort process"
            $global:CodeResults=500
            Out-WinPE -Backuplogs -RemoveJob
        } else {
            WriteLog -Message "Module 7-Zip unknown status [$($json.JOBREQUEST.SevenZip.status)], abort process" -MessageType Error -Verbose
            $global:MessageResults="Module 7-Zip unknown status [$($json.JOBREQUEST.SevenZip.status)], abort process" 
            $global:CodeResults=501
            Out-WinPE -Backuplogs -RemoveJob
        }
    } else {
        WriteLog -Message "Module 7-Zip missing status tag" -MessageType Error -Verbose
        $global:MessageResults="Module 7-Zip missing status tags" 
        $global:CodeResults=2
        Out-WinPE -Backuplogs -RemoveJob
    }        
} else {
    WriteLog -Message "This module is not required" -Verbose
}
