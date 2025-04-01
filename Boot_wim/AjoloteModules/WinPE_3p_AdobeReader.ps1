<#
Adobe Acrobat Reader DC
    Version 1.0.0
    Date: 10/05/2022
    Root node: $json.JOBREQUEST.AdobeReader
    value: status
        "new", "fail", "pass", "verify"
        "new" means process is running or required, not completed yet
        "fail" process already fail
        "pass" process run successfully
        "verify" files where copied and require install
    Value: error
        Out message

Main Info
http://get.adobe.com/reader/enterprise/
Current version:
    MUI_DC2022.002.20191x64
    22.002.20191
Download date:
    10/7/2022
Supported OS:
    Windows (10, 11)

Source path:
    <componentspath>\Adobe_Reader\MUI_<version>
    version is the one that appears on programs installed

Silent command
    AcroRdrDCx642200220191_MUI.exe -sfx_nu /sALL /msi EULA_ACCEPT=YES

Available Tools to customize setup, it requires apply for Distributor

#>

#Confirm if module is required
if ($null -ne $json.JOBREQUEST.AdobeReader) { 
    if ($null -ne $json.JOBREQUEST.AdobeReader.status) {
        WriteLog -Message "Adobe Acrobat Reader DC Module required, checking current status" -Verbose
        if ($json.JOBREQUEST.AdobeReader.status.ToLower().Trim() -eq "new") {
            #check if expected EXE is present
            $strSW_Path=(Join-Path $OSDrive "\SWSETUP\AdobeReader")
            if ((Test-Path -Path $strSW_Path -PathType Container) -AND ($null -ne (Get-ChildItem -Path $strSW_Path -Filter "*.exe"))) {
                if ($null -ne (Get-ChildItem -Path $strSW_Path -Filter "*.exe" -File)) {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.AdobeReader "verify" "Waiting for validation"
                }
                foreach ($exe in (Get-ChildItem -Path $strSW_Path -Filter "*.exe" -File)) {
                    WriteLog -Message "Image already contains Adobe Acrobat Reader DC installer file:$($exe.Name), next step during Windows stage" -Verbose
                }
            } else {
                #Not copied yet 
                ##Mount Share drive
                $DriveComponents = Invoke-MountServer "/componentspath"
                if ($null -eq $DriveComponents) {
                    WriteLog -Message "Not possible mount Component share" -MessageType Error -Verbose
                    $global:MessageResults="Not possible mount Component share"
                    $global:CodeResults=101
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.AdobeReader "fail" $global:MessageResult
                    Out-WinPE -Backuplogs -RemoveJob
                } else {
                    WriteLog -Message "Components share was mounted successfully on drive: $($DriveComponents)\ Checking component folder" -Verbose
                    if (-Not(Test-Path -Path (Join-Path $DriveComponents "Adobe_Reader") -PathType Container)) {
                        WriteLog -Message "It was not possible to detect folder: $((Join-Path $DriveComponents "Adobe_Reader"))" -MessageType Error -Verbose
                        $global:MessageResults="It was not possible to detect folder: $((Join-Path $DriveComponents "Adobe_Reader"))"
                        $global:CodeResults=404
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.AdobeReader "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    if ($null -eq (Get-ChildItem -Path (Join-Path $DriveComponents "Adobe_Reader") -Directory)) {
                        WriteLog -Message "There are no version available to install HP Image Assintant" -MessageType Error -Verbose
                        $global:MessageResults="There are no version available to install HP Image Assintant"
                        $global:CodeResults=405
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.AdobeReader "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    foreach ($ver in (Get-ChildItem -Path (Join-Path $DriveComponents "Adobe_Reader") -Directory | Sort-Object -Property Name -Descending)) {
                        if ($ver.Name.Contains("MUI_")) {
                            WriteLog -Message "Version available MUI: $($ver.Name.Replace(""MUI_"",""""))" -Verbose
                        } else {
                            WriteLog -Message "Version available: $($ver.Name)" -Verbose
                        }
                    
                    }
                    $LatestVersion=(Get-ChildItem -Path (Join-Path $DriveComponents "Adobe_Reader") -Directory | Sort-Object -Property Name -Descending)[0]
                    WriteLog -Message "It will install version: $($LatestVersion.Name)" -Verbose
                    #checking EXE files
                    $Exes_files=Get-ChildItem -Path $LatestVersion.FullName -Filter "*.exe" -File
                    if ($null -eq $Exes_files) {
                        WriteLog -Message "There are no EXE files to install Adobe Acrobat Reader DC, not possible perform this action" -MessageType Error -Verbose
                        $global:MessageResults="There are no EXE files to install Adobe Acrobat Reader DC, not possible perform this action"
                        $global:CodeResults=404
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.AdobeReader "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    } 
                    $CopyFolder=Invoke-RunPower -file "cmd.exe" -Params "/c XCopy /sehiyk ""$($LatestVersion.FullName)\*"" $($strSW_Path)\" -WorkDir $PSScriptRoot -OutFile "$($logs)\CopyAdobeReader.log" -Verbose
                    if ($CopyFolder -ne 0) {
                        WriteLog -Message "There was not possible to copy Adobe Acrobat Reader DC folder into OS Drive" -MessageType Error -Verbose
                        $global:MessageResults="There was not possible to copy Adobe Acrobat Reader DC folder into OS Drive"
                        $global:CodeResults=$CopyFolder
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.AdobeReader "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    #validate 
                    foreach ($file in $Exes_files) {
                        if (Test-Path -Path (Join-Path $strSW_Path $file.Name) -PathType Leaf) {
                            WriteLog -Message "Successfully copied file: $((Join-Path $strSW_Path $file.Name))" -Verbose
                        }                
                    }
                    if ($null -eq (Get-ChildItem -Path $strSW_Path -Filter "*.exe" -File)) {
                        WriteLog -Message "Somenthing fail during copying Adobe Acrobat Reader DC folder into OS Drive, not possible locate Executable" -MessageType Error -Verbose
                        $global:MessageResults="Somenthing fail during copying Adobe Acrobat Reader DC folder into OS Drive, not possible locate Executable"
                        $global:CodeResults=404
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.AdobeReader "fail" $global:MessageResult
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.AdobeReader "verify" "Waiting for validation"
                    WriteLog -Message "Successfully copied Adobe Acrobat Reader DC, next step, install during Windows stage" -Verbose
                }
            }
        } elseif ($json.JOBREQUEST.AdobeReader.status.ToLower().Trim() -eq "pass") {
            WriteLog -Message "This module already executed successfully, continue" -Verbose
        } elseif ($json.JOBREQUEST.AdobeReader.status.ToLower().Trim() -eq "verify") {
            WriteLog -Message "Status [verify] only apply for Windows stage, nothing to do by now" -Verbose
        } elseif ($json.JOBREQUEST.AdobeReader.status.ToLower().Trim() -eq "fail") {
            WriteLog -Message "Module Adobe Acrobat Reader DC status as fail, abort process" -MessageType Error -Verbose
            $global:MessageResults="Module Adobe Acrobat Reader DC status as fail, abort process"
            $global:CodeResults=500
            Out-WinPE -Backuplogs -RemoveJob
        } else {
            WriteLog -Message "Module Adobe Acrobat Reader DC unknown status [$($json.JOBREQUEST.AdobeReader.status)], abort process" -MessageType Error -Verbose
            $global:MessageResults="Module Adobe Acrobat Reader DC unknown status [$($json.JOBREQUEST.AdobeReader.status)], abort process" 
            $global:CodeResults=501
            Out-WinPE -Backuplogs -RemoveJob
        }
    } else {
        WriteLog -Message "Module Adobe Acrobat Reader DC missing status tag" -MessageType Error -Verbose
        $global:MessageResults="Module Adobe Acrobat Reader DC missing status tags" 
        $global:CodeResults=2
        Out-WinPE -Backuplogs -RemoveJob
    }        
} else {
    WriteLog -Message "This module is not required" -Verbose
}
