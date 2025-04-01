<#
    REMOVE APPX
    Root node: JOBREQUEST.CustomUnattend
    value: state
        "new"/$null "fail" "pass" "validate"
        change state by status and adding error in order to use function:
        Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "fail" $global:MessageResults
    value: sha256
    value: unattendpath
    value: unattendfile
    JOBREQUEST.RemoveAPPX.APPXList 
        array to list all Display Name
#>

if ($null -ne $json.JOBREQUEST.CustomUnattend) {
    if (([string]::IsNullOrEmpty($json.JOBREQUEST.CustomUnattend.status)) -OR ($json.JOBREQUEST.CustomUnattend.status.ToLower() -eq "new")) {
        if (![string]::IsNullOrEmpty($json.JOBREQUEST.CustomUnattend.unattendpath) -AND ![string]::IsNullOrEmpty($json.JOBREQUEST.CustomUnattend.unattendfile) -AND ![string]::IsNullOrEmpty($json.JOBREQUEST.CustomUnattend.sha256)) {
            $UnattendSha = $json.JOBREQUEST.CustomUnattend.sha256
            $UnattendPath = $json.JOBREQUEST.CustomUnattend.unattendpath
            $UnattendName = $json.JOBREQUEST.CustomUnattend.unattendfile
            #Mount Share 
            try {
                $MountShareCustom=Invoke-MountServer -MounParameter $UnattendPath
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
                    if (Test-Path -Path (Join-Path $MountShareCustom $UnattendName) -PathType Leaf) {
                        $CalculatedUnattendSha = Get-FileHash "$($MountShareCustom)\$($UnattendName)"
                        WriteLog -Message "Calculted SHA-256: $($CalculatedUnattendSha.hash)" -Verbose
                        WriteLog -Message "SHA-256 Obtained from jobfile: $($UnattendSha)" -Verbose
                        if($CalculatedUnattendSha.hash -eq $UnattendSha){
                            #Case 1, PPSolution is required
                            if (($null -ne $json.JOBREQUEST.AddPPSolution) -AND ($json.JOBREQUEST.AddPPSolution)) { 
                                WriteLog -Message "PPSolution is required for this image, Unattend will copied for post processing use" -Verbose
                                $CopyUnattend = Invoke-RunPower -File "cmd.exe" -Params "/c xcopy /hiyk $($MountShareCustom)\$($UnattendName) $($OSDrive)\System.sav\CustomUnattend\" -WorkDir $PSScriptRoot -OutFile "$($logs)\CopyCustomUnattend.log"
                            } else {#Case 2, Standard location 
                                WriteLog -Message "Since PPSolution was not required, Custom unattend will be copied to \Windows\Panther\Unattend" -Verbose
                                if (-Not(Test-Path -Path "$($OSDrive)\Windows\Panther\Unattend" -PathType Container)) { New-Item -Path "$($OSDrive)\Windows\Panther\Unattend" -ItemType Directory -Force | Out-Null }
                                $CopyUnattend = Invoke-RunPower -File "cmd.exe" -Params "/c copy $($MountShareCustom)\$($UnattendName) $($OSDrive)\Windows\Panther\Unattend\Unattend.xml /Y" -WorkDir $PSScriptRoot -OutFile "$($logs)\CopyCustomUnattend.log"
                            } 
                            if ($CopyUnattend -ne 0) {
                                WriteLog -Message "Not possible to copy Unattend, check logs" -MessageType Error -Verbose
                                $global:MessageResults="Not possible to copy Unattend, check logs"
                                $global:CodeResults=$CopyUnattend
                                Out-WinPE -Backuplogs -RemoveJob
                            } 
                            WriteLog -Message "Unattend Copied successfully" -Verbose
                            #Dismount share
                            $null = Invoke-RunPower -File "cmd.exe" -Params "/c net use $($MountShareCustom) /delete" -WorkDir $PSScriptRoot -OutFile "$($logs)\unmountCustomUnattend.log"     
                            Update-JobStatus $jobfile $json $json.JOBREQUEST.CustomUnattend "pass" "Unattend Copied successfully"
                        }
                        else{
                            WriteLog -Message "SHA-256 Verification failed" -MessageType Error -Verbose
                            $global:MessageResults="SHA-256 Verification failed"
                            $global:CodeResults=403
                            Out-WinPE -Backuplogs -RemoveJob
                        }
                    } else {
                        WriteLog -Message "Unattend file is missing, not possible to retrieve it: $($MountShareCustom)\$($UnattendName)" -MessageType Error -Verbose
                        $global:MessageResults="Unattend file is missing, not possible to retrieve it: $($UnattendSourcePath)\$($UnattendName)"
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
        else {
            WriteLog -Message "CustomUnattend module detected but no information added." -MessageType Error -Verbose
            $global:MessageResults="CustomUnattend module detected but no information added."
            $global:CodeResults=500
            Out-WinPE -Backuplogs -RemoveJob
        }
    }
}
else {
    WriteLog -Message "This module is not required" -Verbose
}