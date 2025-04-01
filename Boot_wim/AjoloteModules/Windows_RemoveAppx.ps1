<#
    REMOVE APPX - Windows
    Root node: JOBREQUEST.RemoveAPPX
    value: state
        "new"/$null "fail" "pass" "validate" "reboot1"
        change state by status and adding error in order to use function:
        Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "fail" $global:MessageResults
    JOBREQUEST.RemoveAPPX.APPXList 
        array to list all Display Name
#>

if ($null -ne $json.JOBREQUEST.RemoveAPPX) {
    #JOB request this module
    if (($null -eq $json.JOBREQUEST.RemoveAPPX.status) -OR ($json.JOBREQUEST.RemoveAPPX.status -eq "new") -OR ($json.JOBREQUEST.RemoveAPPX.status -eq "reboot1")) {
        #process start
        if ($null -ne $json.JOBREQUEST.RemoveAPPX.APPXList) {
            $arrAPPXs=$json.JOBREQUEST.RemoveAPPX.APPXList
            #Run Get | Remove
            $NotRemovedAPPXs=[System.Collections.ArrayList]::new() 
            foreach ($appx in $arrAPPXs) {
                if ($null -ne (Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq $appx})) {
                    WriteLog -Message "Removing $($appx)..." -Verbose
                    #Remove APPX
                    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -eq $appx} | ForEach-Object { Remove-AppxProvisionedPackage -AllUsers -PackageName $_.PackageName -Online -ErrorAction SilentlyContinue } | Out-Host #sending to transcript log
                    Get-AppxPackage -AllUsers -Name $appx -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue | Out-Host
                    #Confirm if persist
                    if ($null -ne (Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq $appx})) {                            
                            WriteLog -Message "APPX $($appx) remains" -MessageType Error -Verbose
                            $NotRemovedAPPXs.Add($appx) #Save errors,at end it will list each one
                            Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq $appx} | Out-Host
                            Get-AppxPackage -AllUsers -Name $appx -ErrorAction SilentlyContinue | Out-Host
                            Get-AppxPackage -AllUsers -Name $appx -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue | Out-Host
                    } else {
                        WriteLog -Message "Successfully removed $($appx)" -Verbose
                    }

                } else {
                    WriteLog -Message "APPX [$($appx)] is not present on this OS, mark as removed" -MessageType Warning -Verbose
                }
            }
            if ($NotRemovedAPPXs.Count -ne 0) {
                if (($json.JOBREQUEST.RemoveAPPX.status -eq "reboot1")) {
                   WriteLog -Message "Some APPX were not removed, please check logs" -MessageType Error -Verbose
                   $NotRemovedAPPXs | ForEach-Object {WriteLog -Message "Not possible to remove Appx: $($_)" -MessageType Error -Verbose }
                   $global:MessageResults="Some APPX were not removed, please check logs"
                   $global:CodeResults=2
                   Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "fail" $global:MessageResults
                   Out-Windows 
                } else {
                    WriteLog -Message "Below appxs were not removed, reboot unit to try again" -Verbose
                    $NotRemovedAPPXs | ForEach-Object {WriteLog -Message "`t[Remain]: $($_)" -MessageType Warning -Verbose }
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "reboot1" "Some APPXs were not removed, reboot and try again"
                    $global:MessageResults="Reboot and try again, some APPXs remain"
                    $global:CodeResults=3010                
                    Out-Windows
                }
                
            } else { #Reboot con tag de validate
                $global:MessageResults="APPX were removed correctly, reboot required"
                $global:CodeResults=3010
                Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "validate" $global:MessageResults
                Out-Windows
            }
            #WriteLog -Message "APPX were removed, marked to validate during Windows stage" -Verbose
            #Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "validate" "Waiting for validation"
        } else {
            WriteLog -Message "List of APPXs doesn't exist, check Job" -MessageType Error -Verbose
            $global:MessageResults="List of APPXs doesn't exist, check Job"
            $global:CodeResults=5
            Out-Windows
        }

    } else {
        if ($json.JOBREQUEST.RemoveAPPX.status -eq "fail") {
            WriteLog -Message "Somenthing fail during APPX removal" -MessageType Error -Verbose
            $global:MessageResults="Somenthing fail during APPX removal"
            $global:CodeResults=1
            Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "fail" $global:MessageResults
            if ($null -ne $json.JOBREQUEST.Job) {
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
            } elseif ($null -ne $json.JOBREQUEST.Control) {
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
            }            
            Out-Windows
        } elseif ($json.JOBREQUEST.RemoveAPPX.status -eq "pass") {
            WriteLog -Message "This module already successfully completed" -Verbose 
        } elseif ($json.JOBREQUEST.RemoveAPPX.status -eq "validate") {   
            WriteLog -Message "Require validate APPX removed" -Verbos
            #Validate that APPXs were removed
            if ($null -ne $json.JOBREQUEST.RemoveAPPX.APPXList) {
                $arrAPPXs=$json.JOBREQUEST.RemoveAPPX.APPXList
                #Run Get | Remove
                $NotRemovedAPPXs=[System.Collections.ArrayList]::new() 
                foreach ($appx in $arrAPPXs) {
                    $result = Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq $appx}
                    if ($null -ne $result) {
                        WriteLog -Message "APPX $($appx) remains, will try to remove it" -MessageType Warning -Verbose
                        Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq $appx} | Remove-AppxProvisionedPackage | Out-Host #sending to transcript log
                        #Confirm if persist
                        if ($null -ne (Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq $appx})) {
                            WriteLog -Message "APPX $($appx) remains" -MessageType Error -Verbose
                            $NotRemovedAPPXs.Add($appx) #Save errors,at end it will list each one
                            Get-AppxPackage -AllUsers -Name $appx -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue | Out-Host
                        } else {
                            WriteLog -Message "APPX $($appx) successfully removed at last try" -Verbose
                        }
                    }
                    elseif ($null -eq $result) {
                        WriteLog -Message "APPX [$($appx)] is not present on this OS, it was successfully removed" -Verbose
                    } else {
                        WriteLog -Message "Unexpected error [$($result)]" -MessageType Error -Verbose
                        $global:MessageResults="Some APPX were not removed, please check logs"
                        $global:CodeResults=2
                        Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "fail" $global:MessageResults
                        Out-Windows
                    }
                }
                if ($NotRemovedAPPXs.Count -ne 0) {
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "reboot1" "Some APPXs were not removed during validation, reboot and try again"
                    WriteLog -Message "Below APPX were not removed, process will try to remove and retry" -MessageType Error -Verbose
                    $NotRemovedAPPXs | ForEach-Object {WriteLog -Message "`tNot possible to remove Appx: $($_)" -MessageType Error -Verbose }
                    $global:MessageResults="Some APPX were not removed, retry and reboot"
                    $global:CodeResults=3010
                    Out-Windows
                } else {
                    WriteLog -Message "All APPX have been removed successfully." -Verbose
                    Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "pass" "Successfully validated APPX removed"
                }
            }
            
        } else {
            WriteLog -Message "Error detected on Remove APPX module, state not expected [$($json.JOBREQUEST.RemoveAPPX.status)], check logs" -MessageType Error -Verbose
            $global:MessageResults="Error detected on Remove APPX module, status not expected [$($json.JOBREQUEST.RemoveAPPX.state)], check logs"
            $global:CodeResults=1
            Update-JobStatus $jobfile $json $json.JOBREQUEST.RemoveAPPX "fail" $global:MessageResults
            if ($null -ne $json.JOBREQUEST.Job) {
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Job "fail" $global:MessageResults
            } elseif ($null -ne $json.JOBREQUEST.Control) {
                Update-JobStatus $jobfile $json $json.JOBREQUEST.Control "fail" $global:MessageResults
            } 
            Out-Windows 
        }
    }
} else {
    WriteLog -Message "This module is not required" -Verbose
}