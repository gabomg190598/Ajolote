<###########################################
Version 1.0.2
Date 6/21/2022
############################################>
if ($null -ne $json.JOBREQUEST.CustomFiles) { 
    if ( (($null -ne $json.JOBREQUEST.Control.status) -AND ($json.JOBREQUEST.Control.status -eq "save")) -OR (($null -ne $json.JOBREQUEST.Job.status) -AND ($json.JOBREQUEST.Job.status -eq "save"))) {
        WriteLog -Message "Job detected ready to save image, this moule can run" -Verbose
        ################################ COPY CUSTOM UNATTEND #########################################################
        ### Check if Unattend is provided - Same format can used here to retrieve and copy files into image
        if ((-Not([string]::IsNullOrEmpty($json.JOBREQUEST.CustomFiles.UnattendPath))) -AND (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.CustomFiles.UnattendFile)))) {
            #Define path and file name
            $UnattendSourcePath=$json.JOBREQUEST.CustomFiles.UnattendPath
            $UnattendSourceFile=$json.JOBREQUEST.CustomFiles.UnattendFile
            WriteLog -Message "Custom Unattend was detected, try to retrieve: $($UnattendSourcePath)\$($UnattendSourceFile)" -Verbose
            #Mount Share 
            try {
                $MountShareCustom=Invoke-MountServer -MounParameter $UnattendSourcePath
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                WriteLog -Message "Not possible to mount share: $($UnattendSourcePath), $($ErrorMessage)" -MessageType Error -Verbose
                $global:MessageResults="Not possible to mount share: $($UnattendSourcePath), $($ErrorMessage)"
                $global:CodeResults=403
                Out-WinPE -Backuplogs -RemoveJob
            }
            #Validate Unattend File
            try {
                if ($null -ne $MountShareCustom) {
                    WriteLog -Message "Share Mounted, checking file" -Verbose
                    if (Test-Path -Path (Join-Path $MountShareCustom $UnattendSourceFile) -PathType Leaf) {
                        #Case 1, PPSolution is required
                        if (($null -ne $json.JOBREQUEST.AddPPSolution) -AND ($json.JOBREQUEST.AddPPSolution)) { 
                            WriteLog -Message "PPSolution is required for this image, Unattend will copied for post processing use" -Verbose
                            $CopyUnattend = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /hiyk $($MountShareCustom)\$($UnattendSourceFile) $($OSDrive)\System.sav\CustomUnattend\" -WorkDir $PSScriptRoot -OutFile "$($logs)\CopyCustomUnattend.log"
                        } else {#Case 2, Standard location 
                            WriteLog -Message "Since PPSolution was not required, Custom unattend will be copied to \Windows\Panther\Unattend" -Verbose
                            if (-Not(Test-Path -Path "$($OSDrive)\Windows\Panther\Unattend" -PathType Container)) { New-Item -Path "$($OSDrive)\Windows\Panther\Unattend" -ItemType Directory -Force | Out-Null }
                            $CopyUnattend = Invoke-RunPower -File "cmd.exe" -Params "/c copy $($MountShareCustom)\$($UnattendSourceFile) $($OSDrive)\Windows\Panther\Unattend\Unattend.xml /Y" -WorkDir $PSScriptRoot -OutFile "$($logs)\CopyCustomUnattend.log"
                        } 
                        if ($CopyUnattend -ne 0) {
                            WriteLog -Message "Not possible to copy Unattend, check logs" -MessageType Error -Verbose
                            $global:MessageResults="Not possible to copy Unattend, check logs"
                            $global:CodeResults=$CopyUnattend
                            Out-WinPE -Backuplogs -RemoveJob
                        } 
                        WriteLog -Message "Unatted Copied successfully" -Verbose
                        #Dismount share
                        $null = Invoke-RunPower -File "cmd.exe" -Params "/c net use $($MountShareCustom) /delete" -WorkDir $PSScriptRoot -OutFile "$($logs)\unmountCustomUnattend.log"     
                    } else {
                        WriteLog -Message "Unattend file is missing, not possible to retrieve it: $($MountShareCustom)\$($UnattendSourceFile)" -MessageType Error -Verbose
                        $global:MessageResults="Unattend file is missing, not possible to retrieve it: $($UnattendSourcePath)\$($UnattendSourceFile)"
                        $global:CodeResults=404
                        Out-WinPE -Backuplogs -RemoveJob
                    }
                } else {
                    WriteLog -Message "It was not possible to mount share folder to copy Unattend" -MessageType Error -Verbose
                    $global:MessageResults="It was not possible to mount share folder to copy Unattend"
                    $global:CodeResults=500
                    Out-WinPE -Backuplogs -RemoveJob
                }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c net use $($MountShareCustom) /delete" -WorkDir $PSScriptRoot -OutFile "$($logs)\unmountCustomUnattend.log"
                WriteLog -Message "Not possible add Custom unattend, $($ErrorMessage)" -MessageType Error -Verbose; 
                $global:MessageResults="Not possible add Custom unattend, $($ErrorMessage)"
                $global:CodeResults=405
                Out-WinPE -Backuplogs -RemoveJob
            }
        }
        ############################# End Copy Custom Unattend ##############################
        if (-Not([string]::IsNullOrEmpty($json.JOBREQUEST.CustomFiles.Copy2HDD))) {
            #All content of mentioned folder is copied to C:, check if path exist
            $SourcePath=$json.JOBREQUEST.CustomFiles.Copy2HDD
            WriteLog -Message "Custom Files Content was detected, try to retrieve: $($SourcePath)\" -Verbose
            #Mount Share 
            try {
                $MountShareCustomContent=Invoke-MountServer -MounParameter $SourcePath
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                WriteLog -Message "Not possible to mount share: $($SourcePath), $($ErrorMessage)" -MessageType Error -Verbose
                $global:MessageResults="Not possible to mount share: $($SourcePath), $($ErrorMessage)"
                $global:CodeResults=403
                Out-WinPE -Backuplogs -RemoveJob
            }
            #Validate Files
            try {
                if ($null -ne $MountShareCustomContent) {
                    WriteLog -Message "Share folder Mounted, checking content:" -Verbose
                    $GetFiles = Get-ChildItem -Path $SourcePath -Recurse | Sort-Object -Descending
                    foreach ($Item in $GetFiles) {
                        WriteLog -Message "`tPath detected: $($Item.FullName)" -Verbose
                    }
                    WriteLog -Message "Copying files..." -Verbose
                    $CopyFiles= Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /sehiyk $($MountShareCustomContent)\* $($OSDrive)\" -WorkDir $PSScriptRoot -OutFile "$($logs)\CopyCustomFiles.log" 
                    if ($CopyFiles -ne 0) {
                        WriteLog -Message "Not possible to copy Files, check logs" -MessageType Error -Verbose
                        $global:MessageResults="Not possible to copy Files, check logs"
                        $global:CodeResults=$CopyFiles
                        Out-WinPE -Backuplogs -RemoveJob
                    } 
                    WriteLog -Message "Unatted Copied successfully" -Verbose
                    #Dismount share
                    $null = Invoke-RunPower -File "cmd.exe" -Params "/c net use $($MountShareCustomContent) /delete" -WorkDir $PSScriptRoot -OutFile "$($logs)\unmountCustomFiles.log"     
                    
                } else {
                    WriteLog -Message "It was not possible to mount share folder to copy Files" -MessageType Error -Verbose
                    $global:MessageResults="It was not possible to mount share folder to copy Files"
                    $global:CodeResults=500
                    Out-WinPE -Backuplogs -RemoveJob
                }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $null = Invoke-RunPower -File "cmd.exe" -Params "/c net use $($MountShareCustomContent) /delete" -WorkDir $PSScriptRoot -OutFile "$($logs)\unmountCustomFiles.log"
                WriteLog -Message "Not possible add Custom Files, $($ErrorMessage)" -MessageType Error -Verbose; 
                $global:MessageResults="Not possible add Custom Files, $($ErrorMessage)"
                $global:CodeResults=405
                Out-WinPE -Backuplogs -RemoveJob
            }
        }
        ############################# End Copy Custom Files ##############################

    } else {
        WriteLog -Message "Add Custom file Module is required but Job is not marked for save yet, skip for now" -MessageType Warning -Verbose
    }


} else {
    WriteLog -Message "This module is not required" -Verbose
}